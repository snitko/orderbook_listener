class Orderbook

  attr_reader   :exchange_adapter, :items
  attr_accessor :opposing_orderbook
  attr_reader   :timestamp

  include ObservableRoles::Subscriber

  set_observed_publisher_callbacks(
    exchange: {
      order_added:   -> (me, data) { me.apply_exchange_updates('add', data)    },
      order_removed: -> (me, data) { me.apply_exchange_updates('remove', data) },
      order_traded:  -> (me, data) { me.apply_exchange_updates('trade', data)  }
    }
  )

  def initialize(exchange_adapter: nil, direction: 1, opposing_orderbook: nil)
    raise "Set exchange adapter!" unless exchange_adapter
    @exchange_adapter = exchange_adapter
    @items            = []
    @direction        = direction
    self.opposing_orderbook  = opposing_orderbook
  end

  def load!
    orders = @exchange_adapter.orders(direction: @direction)
    orders[:data].each do |item|
      item = @exchange_adapter.class.standartize_item(item)
      add_item(item[:price], item[:size], force: true)
    end
    @timestamp = orders[:timestamp]
  end
  
  def add_item(price, size, timestamp: Time.now.to_i, force: false)
    if force || !@opposing_orderbook || @opposing_orderbook.items.empty? || price_below?(price, @opposing_orderbook.items.first[:price])

      new_item = { price: price, size: size }
      
      if item_i = find_item_index_by_price(price)
        @items[item_i][:size] = @items[item_i][:size] + size
      elsif item_i = find_next_item_index_by_price(price)
        @items.insert(item_i, new_item)
      else
        @items << new_item
      end

      @timestamp = timestamp

    end
  end

  def remove_item(price, size, timestamp: Time.now.to_i)
    if item_i = find_item_index_by_price(price)
      if @items[item_i][:size] <= size
        remaining = size - @items.delete_at(item_i)[:size]
        return remaining
      else
        @items[item_i][:size] = @items[item_i][:size] - size
        return 0
      end
      @timestamp = timestamp
    else
      false
    end
  end

  # It doesn't matter at what price was the trade made, we always start from the head
  def trade_item(price, size, timestamp: Time.now.to_i)
    price = nil # is always ignored!
    deals = {}
    while size > 0 && !@items.empty?
      deal_price        = @items.first[:price]
      remaining_size    = remove_item(deal_price, size)
      deal_size         = size - remaining_size
      size              = remaining_size
      deals[deal_price] = deal_size
    end
    @timestamp = timestamp
    return deals
  end

  def opposing_orderbook=(ob)
    unless ob.nil?
      @opposing_orderbook   = ob
      ob.opposing_orderbook = self unless ob.opposing_orderbook == self
    end
  end

  def apply_exchange_updates(callback_method_prefix, data)
    self.send("#{callback_method_prefix}_item", data[:price], data[:size], timestamp: data[:timestamp])
  end

  private

    def price_below?(price1, price2)
      if @direction > 0
        price1 > price2
      else
        price1 < price2
      end
    end

    # Searches items from head to tail until item with the right price is found
    def find_item_index_by_price(price)
      @items.each_with_index do |item, i|
        return i   if item[:price] == price
        return nil if price_below?(item[:price], price)
      end
      return nil
    end

    def find_next_item_index_by_price(price)
      @items.each_with_index do |item, i|
        return i if price_below?(item[:price], price)
      end
      return nil
    end

end
