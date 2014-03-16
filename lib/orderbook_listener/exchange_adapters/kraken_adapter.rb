class KrakenAdapter < ExchangeAdapterBase

  FULL_DEPTH_ORDERBOOK_URL = 'https://api.kraken.com/0/public/Depth'
  RECENT_TRADES_URL        = 'https://api.kraken.com/0/public/Trades' 
  ORDERBOOK_UPDATE_PERIOD  = 10 # seconds

  def load_orderbook!
    @orders  = unwrap_order_data(fetch_data(self.class::FULL_DEPTH_ORDERBOOK_URL + "?pair=#{trading_pair}"))

    # Kraken doesn't provide timestamp for the orderbook as whole,
    # so we add it ourselevs.
    @orders['timestamp'] = Time.now.to_i

    return @orders
  end

  def orders(direction: 1)
    { timestamp: @orders['timestamp'].to_i, data: @orders[direction == 1 ? 'asks' : 'bids'] }
  end

  def self.standartize_item(item)
    { price: item[0].to_f, size: item[1].to_f }
  end

  def subscribe_to_trade_data!
    Thread.new { subscribe_to_trades!        }
    Thread.new { subscribe_to_order_updates! }
  end

  private

    # Notifies orderbook of a change.
    # It's wrapper around publish_event methos added to this class
    # by ObservableRoles::Publisher mixin.
    def publish_ordebook_change(event_name, data)

      # Example of Kraken JSON data:
      #
      #  { "result": {"XXBTZUSD": {
      #    "asks":[["646.00000","0.960",1394838815],["650.00000","0.010",1394884158],["650.10080","0.014",1394846392]],
      #    "bids":[["640.01000","1.403",1394910367],["640.00000","0.010",1394883827],["637.35372","0.014",1394846392]]
      #  }}}'

      data = JSON.parse(data) if data.kind_of?(String)
      
      direction = (data[3].to_i == 'b' ? 1 : -1)

      standartized_data = {
        price:     data[0].to_f,
        size:      data[1].to_f,
        # As of now, we can't rely on timestamps with Kraken.
        # Kraken doesn't provide a timestamp for a full depth orderbook
        # so Orderbook can't check it against what we've got here.
        # Thus we use real time.
        timestamp: Time.now.to_i,
        direction: direction
      }

      # Note the block that is passed. We only want to notify orderbook with the right direction,
      # that is if the update is to 'asks' orderbook, we only notify 'asks' orderbook.
      publish_event("order_#{event_name}", standartized_data) { |orderbook| orderbook.direction == direction }
    end

    # Convert standart trading pair string representation
    # into what Kraken API understands
    def trading_pair
      @trading_pair.split('/').reverse.join('/').sub('BTC', 'XBT').sub('/','')
    end

    def subscribe_to_trades!(condition=true)
      while condition
        sleep(ORDERBOOK_UPDATE_PERIOD)
        data = unwrap_order_data(fetch_data(self.class::RECENT_TRADES_URL + "?pair=#{trading_pair}&since=TODO"))
        data.each do |item_data|
          publish_ordebook_change(:traded, item_data)
        end
      end
    end

    def subscribe_to_order_updates!
      # TODO: not yet known if possible to receive such data
    end

    # Orders are received from kraken in some bullshit JSON wrapper like
    #   { "result": { "XXBTZUSD" {
    # which we would like to just ignore. This method bypasses this wrapper
    # and only returns the relevant content.
    def unwrap_order_data(data)
      pair_key = data["result"].keys.first
      data["result"][pair_key]
    end

end
