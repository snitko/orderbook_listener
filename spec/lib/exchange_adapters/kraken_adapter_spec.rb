require 'spec_helper'

require File.dirname(__FILE__) + '/../../../lib/orderbook_listener/exchange_adapters/kraken_adapter'

class KrakenListener

  attr_accessor :data, :direction

  include ObservableRoles::Subscriber
  set_observed_publisher_callbacks(
    exchange: { order_traded:  -> (me, data) { me.data = data },
                order_changed: -> (me, data) { puts data      }}
  )

end

class KrakenAdapter
  private
    def fetch_data(url)
      JSON.parse '{"result":{"XXBTZUSD":{' +
      '"asks":[["646.00000","0.960",1394838815],["650.00000","0.010",1394884158],["650.10080","0.014",1394846392]],' +
      '"bids":[["640.01000","1.403",1394910367],["640.00000","0.010",1394883827],["637.35372","0.014",1394846392]]' +
      '}}}'
    end
end

describe KrakenAdapter do

  before(:each) do
    @kraken             = KrakenAdapter.new
    @listener           = KrakenListener.new
    @listener.direction = -1
  end

  #it "fetches full depth" do
    #puts @kraken.load_orderbook!
  #end

  it "fetches full depth orderbook from Kraken and converts it into a hash" do
    @kraken.load_orderbook!.should == {"timestamp"=> @kraken.orders[:timestamp], "bids"=>[["640.01000", "1.403", 1394910367], ["640.00000", "0.010", 1394883827], ["637.35372", "0.014", 1394846392]], "asks"=>[["646.00000", "0.960", 1394838815], ["650.00000", "0.010", 1394884158], ["650.10080", "0.014", 1394846392]]} 
  end

  it "converts each item in the orderbook into a standard format on demand" do
    @kraken.load_orderbook!
    KrakenAdapter.standartize_item(@kraken.orders[:data].first).should == { price: 646.00000, size: 0.960 }
  end
  
  it "converts Kraken orders data into a standartized form" do
    @kraken.subscribe(@listener)
    @kraken.send(:publish_ordebook_change, :traded, ["575.00000","0.17446660",1394578863.9025,"s","l",""])
    @listener.data.should == {
      price:     575.00000,
      size:      0.17446660,
      timestamp: @listener.data[:timestamp],
      direction: -1
    }
  end

end
