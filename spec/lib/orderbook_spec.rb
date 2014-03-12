require 'spec_helper'

require File.dirname(__FILE__) + '/../../lib/exchange_adapters/base_exchange_adapter'
require File.dirname(__FILE__) + '/../../lib/orderbook'



describe Orderbook do

  before(:all) do
    @test_exchange        = BaseExchangeAdapter.new
    @test_exchange.orders = {
      1  => [{ price: 850, size: 50 }, { price: 855.5, size: 51 }, { price: 857.3, size: 0.006 }],
      -1 => [{ price: 849, size: 50 }, { price: 847.5, size: 51 }, { price: 845.3, size: 0.006 }]
    }
  end

  before(:each) do
    @ob = Orderbook.new(exchange_adapter: @test_exchange)
  end

  it "loads full depth orderbook into the storage" do
    @ob.load
    @ob.items.should == [
      { price: 850, size: 50 },
      { price: 855.5, size: 51 },
      { price: 857.3, size: 0.006 }
    ]
  end

  describe "adding new items" do

    before(:each) do
      @ob2 = Orderbook.new(exchange_adapter: @test_exchange, opposing_orderbook: @ob, direction: -1)
      @ob2.load
      @ob.load
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
      @ob.load
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
      @ob.load
    end

    it "removes items from the head according to the size of the trade" do
      @ob.trade_item(55).should == { 850 => 50, 855.5 => 5 }
      @ob.items.should == [
        { price: 855.5, size: 46 },
        { price: 857.3, size: 0.006 }
      ]
    end

  end

end
