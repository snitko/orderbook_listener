require 'spec_helper'

require File.dirname(__FILE__) + '/../../lib/exchange_adapters/exchange_adapter_base'
require File.dirname(__FILE__) + '/../../lib/orderbook'
require File.dirname(__FILE__) + '/../../lib/orderbook_pair'

class ExchangeAdapterBase
  attr_writer :orders
  include ObservableRoles::Publisher
end

describe OrderbookPair do

  before(:all) do
    @exchange = ExchangeAdapterBase.new
    @exchange.orders = {
      timestamp: 111,
      1  => [{ price: 850, size: 50 }, { price: 855.5, size: 51 }, { price: 857.3, size: 0.006 }],
      -1 => [{ price: 849, size: 50 }, { price: 847.5, size: 51 }, { price: 845.3, size: 0.006 }]
    }
    @orderbook_pair = OrderbookPair.new(exchange_adapter: @exchange)
  end

  it "combines both orderbooks into JSON with a timestamp" do 
    @orderbook_pair.to_json.should == '{"timestamp":111,"bids":[{"price":849,"size":50},{"price":847.5,"size":51},{"price":845.3,"size":0.006}],"asks":[{"price":850,"size":50},{"price":855.5,"size":51},{"price":857.3,"size":0.006}]}'
  end

end
