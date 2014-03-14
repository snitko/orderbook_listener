require 'spec_helper'

class ExchangeAdapterBase
  attr_writer :orders
  include ObservableRoles::Publisher
end


describe Orderbook do

  before(:all) do
    @test_exchange        = ExchangeAdapterBase.new
    @test_exchange.orders = {
      timestamp: 111,
      1  => [{ price: 850, size: 50 }, { price: 855.5, size: 51 }, { price: 857.3, size: 0.006 }],
      -1 => [{ price: 849, size: 50 }, { price: 847.5, size: 51 }, { price: 845.3, size: 0.006 }]
    }
  end

  before(:each) do
    @ob = Orderbook.new(exchange_adapter: @test_exchange)
  end

  it "loads full depth orderbook into the storage" do
    @ob.load!
    @ob.items.should == [
      { price: 850, size: 50 },
      { price: 855.5, size: 51 },
      { price: 857.3, size: 0.006 }
    ]
    @ob.timestamp.should == 111
  end

  describe "adding new items" do

    before(:each) do
      @ob2 = Orderbook.new(exchange_adapter: @test_exchange, opposing_orderbook: @ob, direction: -1)
      @ob2.load!
      @ob.load!
    end

    it "updates an existing item incrementing its size by the size of the added one" do
      @ob.add_item(855.5, 1)
      @ob.items.should == [
        { price: 850, size: 50 },
        { price: 855.5, size: 52 },
        { price: 857.3, size: 0.006 }
      ]
    end

    it "adds a completely new one if it doesn't yet exist" do
      @ob.add_item(853.5, 1)
      @ob.items.should == [
        { price: 850, size: 50 },
        { price: 853.5, size: 1 },
        { price: 855.5, size: 51 },
        { price: 857.3, size: 0.006 }
      ]
    end

    it "ignores an added item if it's NOT above the head of the opposing orderbook" do
      @ob.add_item(849, 1)
      @ob.items.should == [
        { price: 850, size: 50 },
        { price: 855.5, size: 51 },
        { price: 857.3, size: 0.006 }
      ]
    end

  end

  describe "removing existing items" do

    before(:each) do
      @ob.load!
    end

    it "updates an existing item decrementing its size by the size of the removed one" do
      @ob.remove_item(850, 1).should == 0
      @ob.items.should == [
        { price: 850, size: 49 },
        { price: 855.5, size: 51 },
        { price: 857.3, size: 0.006 }
      ]
    end

    it "removes an item completely if the specified size is equal of larger than its actual size" do
      @ob.remove_item(850, 100).should == 50
      @ob.items.should == [
        { price: 855.5, size: 51 },
        { price: 857.3, size: 0.006 }
      ]
    end

    it "ignores removal if item doesn't exist" do
      @ob.remove_item(900, 100).should be_false
      @ob.items.should == [
        { price: 850, size: 50 },
        { price: 855.5, size: 51 },
        { price: 857.3, size: 0.006 }
      ]
    end

  end

  describe "trading item" do

    before(:each) do
      @ob.load!
    end

    it "removes items from the head according to the size of the trade" do
      @ob.trade_item(0, 55).should == { 850 => 50, 855.5 => 5 }
      @ob.items.should == [
        { price: 855.5, size: 46 },
        { price: 857.3, size: 0.006 }
      ]
    end

  end

  describe "reacting to exchange's events" do

    before(:each) do
      @test_exchange.subscribe(@ob)
    end

    it "adds item to itself" do
      @test_exchange.publish_event(:order_added, { price: 849.5, size: 50 })
      @ob.items.should == [{ price: 849.5, size: 50 }]
    end

    it "removes item from itself" do
      @ob.load!
      @test_exchange.publish_event(:order_removed, { price: 850, size: 50 })
      @ob.items.should == [
        { price: 855.5, size: 51 },
        { price: 857.3, size: 0.006 }
      ]
    end

    it "trades item" do
      @ob.load!
      @test_exchange.publish_event(:order_traded, { price: 850, size: 1000 })
      @ob.items.should be_empty
    end

    it "updates orderbook timestamp according to the timestamp received from the exchange" do
      @test_exchange.publish_event(:order_traded, { price: 850, size: 1000, timestamp: 222 })
      @ob.timestamp.should == 222
    end

  end

end
