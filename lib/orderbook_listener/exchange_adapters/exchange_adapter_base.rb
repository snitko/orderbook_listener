class ExchangeAdapterBase

  include ObservableRoles::Publisher

  def initialize
    @orders       = {}
    @connection   = nil
    @trading_pair = 'USD/BTC'
    @role         = :exchange
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

end
