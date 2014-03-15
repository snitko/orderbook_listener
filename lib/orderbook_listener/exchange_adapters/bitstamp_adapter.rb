require 'pusher-client'

class BitstampAdapter < ExchangeAdapterBase

  FULL_DEPTH_ORDERBOOK_URL = 'https://www.bitstamp.net/api/order_book/'

  def load_orderbook!
    @orders = JSON.parse(fetch_orderbook)

    # Ignore Bitstamp's timestamps they're rather useless
    # as far as the Orderbook class is concerned. We're better off
    # using real time instead
    @orders['timestamp'] = Time.now.to_i
    
    return @orders
  end

  def orders(direction: 1)
    { timestamp: @orders['timestamp'].to_i, data: @orders[direction == 1 ? 'asks' : 'bids'] }
  end

  def self.standartize_item(item)
    { price: item[0].to_f, size: item[1].to_f }
  end

  # Starts new thread for each connection. It's important to remember
  # that in order for this to keep running, the program should also be running (as a daemon
  # or maybe within a webserver app, like Sinatra), otherwise those threads are simply destroyed
  # as soon as the program exits.
  def subscribe_to_trade_data!
    @connection = PusherClient::Socket.new('de504dc5763aeef9ff52')
    @connection.connect(true)
    @connection.subscribe('live_orders')
    @connection.subscribe('live_trades')
    @connection['live_orders'].bind('order_created') { |data| publish_ordebook_change('added',   data) }
    @connection['live_orders'].bind('order_deleted') { |data| publish_ordebook_change('removed', data) }
    # TODO: pending support request to Bitstamp, will know what to do with these type of orders soon
    #@connection['live_orders'].bind('order_changed')  { |data| publish_ordebook_change('changed', data) }
    @connection['live_trades'].bind('trade')         { |data| publish_ordebook_change('traded', data)  }
  end

  private

    # Notifies orderbook of a change.
    # It's wrapper around publish_event methos added to this class
    # by ObservableRoles::Publisher mixin.
    def publish_ordebook_change(event_name, data)

      # Example of Bitstamp JSON data:
      #   {"price": "733.70", "amount": "0.00360502",
      #    "datetime": "1394809959", "id": 19496875, "order_type": 1 }
      #

      data = JSON.parse(data) if data.kind_of?(String)
      
      direction = (data["order_type"].to_i == 1 ? 1 : -1)

      standartized_data = {
        price:     data["price"].to_f,
        size:      data["amount"].to_f,
        timestamp: Time.now.to_i, # Ignore Bitstamp's timestamps
        direction: direction
      }

      # Note the block that is passed. We only want to notify orderbook with the right direction,
      # that is if the update is to 'asks' orderbook, we only notify 'asks' orderbook.
      publish_event("order_#{event_name}", standartized_data) { |orderbook| orderbook.direction == direction }
    end


end
