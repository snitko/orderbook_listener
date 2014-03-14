require 'json'

class OrderbookPair

  attr_accessor :exchange

  def initialize(exchange_adapter: ExchangeAdapterBase.new)
    @exchange = exchange
    @bids     = Orderbook.new(direction: -1, exchange_adapter: exchange_adapter)
    @asks     = Orderbook.new(direction:  1, exchange_adapter: exchange_adapter, opposing_orderbook: @bids)
    @bids.load!
    @asks.load!
  end

  def to_json
    timestamp = @bids.timestamp > @asks.timestamp ? @bids.timestamp : @asks.timestamp
    { :timestamp => timestamp, bids: @bids.items, asks: @asks.items }.to_json
  end

end
