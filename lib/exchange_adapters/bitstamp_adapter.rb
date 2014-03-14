require 'json'

class BitstampAdapter < ExchangeAdapterBase

  def load_orderbook
    @orders = JSON.parse(fetch_orderbook)
  end

  def orders(direction: 1)
    @orders[direction == 1 ? 'asks' : 'bids']
  end

  def self.standartize_item(item)
    { price: item[0].to_f, size: item[1].to_f }
  end

  def subscribe_to_trade_data
    subscribe_to_orderbook_changes
    subscribe_to_trades
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

    def subscribe_to_orderbook_changes
    end

    def subscribe_to_trades
    end

end
