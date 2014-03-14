require 'spec_helper'

require File.dirname(__FILE__) + '/../../../lib/exchange_adapters/exchange_adapter_base'
require File.dirname(__FILE__) + '/../../../lib/exchange_adapters/bitstamp_adapter'

class BitstampAdapter
  private
    def fetch_orderbook
      '{"timestamp": "1394755456", "bids": [["640.00", "6.71588852"], ["639.96", "0.02343896"], ["639.92", "0.02344043"]],"asks": [["641.02", "0.01587314"], ["642.50", "0.49763960"], ["642.93", "0.05000000"]]}'
    end
end

describe BitstampAdapter do

  before(:each) do
    @bitstamp = BitstampAdapter.new
  end

  it "fetches full depth orderbook from Bitstamp and converts it into a hash" do
    @bitstamp.load_orderbook.should == {"timestamp"=>"1394755456", "bids"=>[["640.00", "6.71588852"], ["639.96", "0.02343896"], ["639.92", "0.02344043"]], "asks"=>[["641.02", "0.01587314"], ["642.50", "0.49763960"], ["642.93", "0.05000000"]]} 
  end

  it "converts each item in the orderbook into a standard format on demand" do
    @bitstamp.load_orderbook
    BitstampAdapter.standartize_item(@bitstamp.orders.first).should == { price: 641.02, size: 0.01587314 }
  end
  
  describe "updating orderbook by connecting to Pusher" do

    it "fetches orderbook changes"
    it "fetches trades"

  end

  describe "callbacks" do

    it "notifies subscribers of orderbook changes"
    it "notifies subscribers of trades"
    it "notifies subscribers when a full depth orderbook is loaded"

  end

end
