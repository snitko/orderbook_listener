require 'json'
require 'pusher-client'

class BitstampAdapter < ExchangeAdapterBase

  def load_orderbook!
    @orders = JSON.parse(fetch_orderbook)
  end

  def orders(direction: 1)
    { timestamp: @orders['timestamp'].to_i, data: @orders[direction == 1 ? 'asks' : 'bids'] }
  end

  def self.standartize_item(item)
    { price: item[0].to_f, size: item[1].to_f }
  end

  def subscribe_to_trade_data!
    @connection = PusherClient::Socket.new('de504dc5763aeef9ff52')
    @connection.connect(true)
    @connection.subscribe('live_orders')
    @connection.subscribe('live_trades')
    @connection['live_orders'].bind('order_created') { |data| publish_ordebook_change('added',   data) }
    @connection['live_orders'].bind('order_deleted') { |data| publish_ordebook_change('removed', data) }
    #@connection['live_orders'].bind('order_changed')  { |data| publish_ordebook_change('changed', data) }
    @connection['live_trades'].bind('trade')         { |data| publish_ordebook_change('traded', data)  }
  end

  private

    def fetch_orderbook
      url = 'http://www.bitstamp.net/api/order_book/'
      begin
        return Net::HTTP.get(URI.parse(url))
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e 
        raise e
        # retry a couple of times
        # send email with error
      end
    end

    def publish_ordebook_change(event_name, data)
      # Example of Bitstamp JSON data:
      #   {"price": "733.70", "amount": "0.00360502", "datetime": "1394809959", "id": 19496875, "order_type": 1}
      
      direction = (data["order_type"] == 1 ? 1 : -1)

      standartized_data = {
        price:     data["price"].to_f,
        size:      data["amount"].to_f,
        timestamp: data["datetime"].to_i,
        direction: direction
      }
      publish_event("order_#{event_name}", standartized_data) { |orderbook| orderbook.direction == direction }
    end


end
