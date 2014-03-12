class BaseExchangeAdapter

  attr_accessor :orders

  def initialize
    @orders       = {}
    @connection   = nil
    @trading_pair = 'USD/BTC'
  end

  # Freeing the memory here, we don't really need to hold full depth forever,
  # because it is stored in Redis through the Orderbook object.
  def clean_orderbook!
  end

end
