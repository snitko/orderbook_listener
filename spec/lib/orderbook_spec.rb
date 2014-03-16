require 'spec_helper'

class ExchangeAdapterBase
  attr_writer :orders
end


class OrderbookReporter

  include ObservableRoles::Subscriber

  set_observed_publisher_callbacks(
    # Remember, Orderbook is not just a Subscriber to exchange adapter,
    # it publishes events itself as well! And we define callbacks for these events here.
    orderbook: {
      item_added:   -> (me, data) { data.delete(:timestamp); me.add_event(:item_added, data)   },
      item_removed: -> (me, data) { data.delete(:timestamp); me.add_event(:item_removed, data) }
    }
  )

  attr_accessor :events

  def add_event(name, data)
    @events ||= []
    @events << { name: name, data: data }
  end

end


describe Orderbook do

  before(:all) do
    @test_exchange = ExchangeAdapterBase.new
  end

  before(:each) do
    @ob = Orderbook.new(exchange_adapter: @test_exchange)
    @test_exchange.orders = {
      timestamp: 111,
      1  => [{ price: 850, size: 50 }, { price: 855.5, size: 51 }, { price: 857.3, size: 0.006 }],
      -1 => [{ price: 849, size: 50 }, { price: 847.5, size: 51 }, { price: 845.3, size: 0.006 }]
    }
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

  it "ignores all updates with timestamps older than the full_depth_timestamp of the orderbook" do
    @ob.load!
    @ob.add_item(865, 1, timestamp: 12) # Timestamp 12 is older than 111 (12 < 111)
    @ob.items.should_not include({ price: 865, size: 1 })
    @ob.remove_item(850, 50, timestamp: 12) # Timestamp 12 is older than 111 (12 < 111)
    @ob.items.should include({ price: 850, size: 50 })
    @ob.trade_item(0, 50, timestamp: 12) # Timestamp 12 is older than 111 (12 < 111)
    @ob.items.should include({ price: 850, size: 50 })
  end

  it "when full depth is reloaded, it generates 'item_added' or 'item_removed' events based on the difference" do
    reporter = OrderbookReporter.new
    @ob.subscribe(reporter)
    @ob.load!
    reporter.events.should == [
      { name: :item_added, data: { price: 850,   size: 50    }},
      { name: :item_added, data: { price: 855.5, size: 51    }},
      { name: :item_added, data: { price: 857.3, size: 0.006 }}
    ]
    reporter.events = []

    @test_exchange.orders = {
      timestamp: 111,
      1  => [{ price: 850, size: 31 }, { price: 855.5, size: 101 }],
    }
    @ob.load!
    reporter.events.should == [
      { name: :item_removed, data: { price: 850,   size: 19    }},
      { name: :item_added,   data: { price: 855.5, size: 50    }},
      { name: :item_removed, data: { price: 857.3, size: 0.006 }}
    ]
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
      @ob.subscriber_lock = false
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
