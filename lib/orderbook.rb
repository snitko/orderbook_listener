class Orderbook

  attr_reader   :exchange_adapter, :items
  attr_accessor :opposing_orderbook

  def initialize(exchange_adapter: nil, direction: 1, opposing_orderbook: nil)
    raise "Set exchange adapter!" unless exchange_adapter
    @exchange_adapter = exchange_adapter
    @items            = []
    @direction        = direction
    self.opposing_orderbook  = opposing_orderbook
  end

  def load
    @exchange_adapter.orders[@direction].each do |item|
      add_item(item[:price], item[:size], force: true)
    end
  end
  
  def add_item(price, size, force: false)
    if force || (@opposing_orderbook && price_below?(price, @opposing_orderbook.items.first[:price]))

      new_item = { price: price, size: size }
      
      if item_i = find_item_index_by_price(price)
        @items[item_i][:size] = @items[item_i][:size] + size
      elsif item_i = find_next_item_index_by_price(price)
        @items.insert(item_i, new_item)
      else
        @items << new_item
      end

    end
  end

  def remove_item(price, size)
    if item_i = find_item_index_by_price(price)
      if @items[item_i][:size] <= size
        remaining = size - @items.delete_at(item_i)[:size]
        return remaining
      else
        @items[item_i][:size] = @items[item_i][:size] - size
        return 0
      end
    else
      false
    end
  end

  # It doesn't matter at what price was the trade made, we always start from the head
  def trade_item(size)
    deals = {}
    while size > 0 && !@items.empty?
      deal_price        = @items.first[:price]
      remaining_size    = remove_item(deal_price, size)
      deal_size         = size - remaining_size
      size              = remaining_size
      deals[deal_price] = deal_size
    end
    return deals
  end

  def opposing_orderbook=(ob)
    unless ob.nil?
      @opposing_orderbook   = ob
      ob.opposing_orderbook = self unless ob.opposing_orderbook == self
    end
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
