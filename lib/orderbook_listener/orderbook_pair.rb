require 'json'

# A class which purpose is to simply combine to part of the orderbook - asks and bids -
# into one. Should mainly be used to access both orderbooks and render them to json
# or possibly some other format.
class OrderbookPair

  attr_accessor :exchange_adapter
  attr_reader   :bids, :asks

  def initialize(exchange_adapter: ExchangeAdapterBase.new)
    @exchange_adapter = exchange_adapter
    @bids             = Orderbook.new(direction: -1, exchange_adapter: exchange_adapter)
    @asks             = Orderbook.new(direction:  1, exchange_adapter: exchange_adapter, opposing_orderbook: @bids)
  end

  def load!
    @exchange_adapter.load_orderbook!
    @bids.load!
    @asks.load!
  end

  def subscribe(subscriber)
    @bids.subscribe(subscriber)
    @asks.subscribe(subscriber)
  end

  def to_json
    timestamp = @bids.timestamp > @asks.timestamp ? @bids.timestamp : @asks.timestamp
    { :timestamp => timestamp, bids: @bids.items, asks: @asks.items }.to_json
  end

end
