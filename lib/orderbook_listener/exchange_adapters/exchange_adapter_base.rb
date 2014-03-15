class ExchangeAdapterBase

  include ObservableRoles::Publisher

  def initialize
    @orders       = {}
    @connection   = nil
    @trading_pair = 'USD/BTC'
    @role         = :exchange
  end

  def load_orderbook!
  end

  # Freeing the memory here, we don't really need to hold full depth forever,
  # because it is stored in the Orderbook object.
  def clear_orderbook!
    @orders = nil
  end

  # This one is usually replaced in descendant classes,
  # because full depth orderbooks that come from exchanges API
  # are in various formats, depending on the exchange.
  def orders(direction: 1)
    { timestamp: @orders[:timestamp].to_i, data: @orders[direction] }
  end

  # Usually replaced in descendant classes.
  # Converts an exchange internal representation of an order item
  # into something that Orderbook object can understand.
  def self.standartize_item(item)
    item
  end


  private

    def fetch_orderbook
      begin
        return Net::HTTP.get(URI.parse(full_depth_orderbook_url))
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e 
        raise e
        # TODO: retry a couple of times
        # TODO: send email with error
      end
    end

    # Redefine this method in descendant classes if you need to add additional parameters to the
    # url that define, for example, which pair of currencies is loaded.
    def full_depth_orderbook_url
      self.class::FULL_DEPTH_ORDERBOOK_URL
    end

end
