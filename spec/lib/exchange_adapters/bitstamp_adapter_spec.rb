require 'spec_helper'

require File.dirname(__FILE__) + '/../../../lib/exchange_adapters/exchange_adapter_base'
require File.dirname(__FILE__) + '/../../../lib/exchange_adapters/bitstamp_adapter'

class BitstampListener

  attr_accessor :data, :direction

  include ObservableRoles::Subscriber
  set_observed_publisher_callbacks(
    exchange: { order_added:   -> (me, data) { me.data = data },
                order_changed: -> (me, data) { puts data      }}
  )

end

class BitstampAdapter
  private
    def fetch_orderbook
      '{"timestamp": "1394755456", "bids": [["640.00", "6.71588852"], ["639.96", "0.02343896"], ["639.92", "0.02344043"]],"asks": [["641.02", "0.01587314"], ["642.50", "0.49763960"], ["642.93", "0.05000000"]]}'
    end
end

describe BitstampAdapter do

  before(:each) do
    @bitstamp           = BitstampAdapter.new
    @bitstamp.role      = :exchange
    @listener           = BitstampListener.new
    @listener.direction = -1
  end

  #it "fetches live stream" do
    #@bitstamp.subscribe(@listener)
    #@bitstamp.subscribe_to_trade_data!
    #sleep(100)
  #end

  it "fetches full depth orderbook from Bitstamp and converts it into a hash" do
    @bitstamp.load_orderbook!.should == {"timestamp"=>"1394755456", "bids"=>[["640.00", "6.71588852"], ["639.96", "0.02343896"], ["639.92", "0.02344043"]], "asks"=>[["641.02", "0.01587314"], ["642.50", "0.49763960"], ["642.93", "0.05000000"]]} 
  end

  it "converts each item in the orderbook into a standard format on demand" do
    @bitstamp.load_orderbook!
    BitstampAdapter.standartize_item(@bitstamp.orders[:data].first).should == { price: 641.02, size: 0.01587314 }
  end
  
  it "converts Bitstamp live feed data into a standartized form" do
    @bitstamp.subscribe(@listener)
    @bitstamp.send(:publish_ordebook_change, :added, { "price" => "733.70", "amount" => "0.00360502", "datetime" => "1394809959", "id" => 19496875, "order_type" => 0 })
    @listener.data.should == {
      price:     733.70,
      size:      0.00360502,
      timestamp: 1394809959,
      direction: -1
    }
  end

  it "returns timestamp from the fulldepth orderbook" do
    @bitstamp.load_orderbook!
    @bitstamp.orders[:timestamp].should == 1394755456
  end

end
