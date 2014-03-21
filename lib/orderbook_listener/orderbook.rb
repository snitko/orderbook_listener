class Orderbook

  attr_reader   :exchange_adapter, :items, :timestamp, :full_depth_timestamp, :direction
  attr_accessor :opposing_orderbook, :role

  include ObservableRoles::Subscriber

  # Because orderbook also publishes its own events,
  # we include ObservableRoles::Publisher as well.
  # It's a good idea to seperate exchange adapter events
  # from Orderbook events, although they might actually be similar,
  # like adding or removing orderbook items.
  include ObservableRoles::Publisher


  set_observed_publisher_callbacks(
    exchange: {
      order_added:   -> (me, data) { me.apply_exchange_updates('add', data)    },
      order_removed: -> (me, data) { me.apply_exchange_updates('remove', data) },
      order_traded:  -> (me, data) { me.apply_exchange_updates('trade', data)  },
      full_depth_reloaded: -> (me, data) { me.load! }
    }
  )

  def initialize(exchange_adapter: nil, direction: 1, opposing_orderbook: nil)
    raise "Set exchange adapter!" unless exchange_adapter
    @exchange_adapter = exchange_adapter
    @exchange_adapter.subscribe(self)
    @items            = []
    @direction        = direction
    @role             = :orderbook
    @subscriber_lock  = true # true by default, we don't update an empty orderbook
    self.opposing_orderbook  = opposing_orderbook
  end

  # Populates the orderbook using full depth data from the exchange adapter,
  # which should have already loaded the orderbook from the exchange API.
  #
  # This method is capable of generating 'item_added' and 'item_removed' events
  # by reloading fulldepth - for retarded exchanges API.
  #
  # What's retarded? Well, some exchanges don't feed you added and cancelled orders, only traded ones.
  # Thus we have to support generating 'item_added' and 'item_removed'
  # events in the Orderbook simply by comparing old full depth with a new full_depth orderbook.
  # While this might actually be slow and should be properly benchmarked,
  # I believe it's a nice workaround for now.
  def load!
    orders = @exchange_adapter.orders(direction: @direction)
    @subscriber_lock   = true
    standartized_items = []
    orders[:data].each { |item| standartized_items << @exchange_adapter.class.standartize_item(item) }
 
    standartized_items.each do |item|
      # Let's not play the game of guessing what's added or removed if we're
      # populating this orderbook for the first time. Thus, the @full_depth_timestamp check.
      if @full_depth_timestamp && i = find_item_index_by_price(item[:price])
        if @items[i][:size] < item[:size]
          # Update existing items when size increases
          add_item(item[:price], item[:size]-@items[i][:size], force: true)
        elsif @items[i][:size] > item[:size]
          # Update existing items when size decreases
          remove_item(item[:price], @items[i][:size]-item[:size], force: true)
        end
      else
        # Add a brand new item
        add_item(item[:price], item[:size], force: true)
      end

    end

    if @full_depth_timestamp
      # Remove an item completely by subtracting new orderbook contents
      # from the old orderbook contents. That way we know for sure which items should
      # be deleted.
      (@items - standartized_items).each do |item|
        remove_item(item[:price], item[:size], force: true)
      end
    end

    @subscriber_lock      = false
    @timestamp            = orders[:timestamp]
    @full_depth_timestamp = @timestamp
  end
  
  # Adds new item to the orderbook or updates the size field of the existing one,
  # in case the price is the same. Unless `force` option is set to true or the oppopsing orderbook is empty
  # it will ignore all attempts to add an item whose price is below the opposing orderbook head.
  # If you don't understand why this is important, let me draw you a picture:
  # 
  # -----bids------        -----asks-----
  # PRICE   SIZE           PRICE   SIZE
  # $850    1.5            $851    1.1
  # $845    10             $855    12.54534
  # $840    15.43          $857    3.324
  #
  # Now think, would it be okay to add an item with the price of $847 in to the second orderbook?
  #
  def add_item(price, size, timestamp: Time.now.to_i, force: false)

    if !force && (
          # Do not add orders that are below the head of the opposing orderbook
          (@opposing_orderbook && !@opposing_orderbook.items.empty? && @opposing_orderbook.price_below?(price, @opposing_orderbook.items.first[:price])) ||

          # Do not add orders with timestamp older than the timstamp of a full depth orderbook download
          (timestamp && @full_depth_timestamp && timestamp <= @full_depth_timestamp)
        )
      return false
    end
    
    new_item = { price: price, size: size }
    
    if item_i = find_item_index_by_price(price)
      @items[item_i][:size] = @items[item_i][:size] + size
    elsif item_i = find_next_item_index_by_price(price)
      @items.insert(item_i, new_item)
    else
      @items << new_item
    end

    @timestamp = timestamp
    publish_event(:item_added, { price: price, size: size, timestamp: timestamp })

  end

  # Removes item from the orderbook completely or updates its size
  # if the size of the item in the orderbook is larger than the size
  # of the one that is being removed.
  def remove_item(price, size, timestamp: Time.now.to_i, force: false)
    
    return false if !force && (timestamp && @full_depth_timestamp && timestamp <= @full_depth_timestamp)

    if item_i = find_item_index_by_price(price)
      result = if @items[item_i][:size] <= size
        remaining = size - @items.delete_at(item_i)[:size]
        remaining
      else
        @items[item_i][:size] = @items[item_i][:size] - size
        0
      end
      @timestamp = timestamp
      publish_event(:item_removed, { price: price, size: size, timestamp: timestamp })
      return result
    else
      false
    end
  end

  # Same as #remove_item with just one crucial distinction:
  # it doesn't matter at what price was the trade made, we always start from the head
  # and go down removing all items until we remove enough of them to satisfy the size.
  # `price` attribute is kept for compatability and is always ignored.
  def trade_item(price, size, timestamp: Time.now.to_i, force: false)

    return false if !force && (timestamp && @full_depth_timestamp && timestamp <= @full_depth_timestamp)

    publish_event(:item_traded, { price: price, size: size, timestamp: timestamp })
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

  # The concept of an opposing orderbook is important in some circumstances (see #add_item description).
  # An opposing orderbook for 'bids' (direction: -1) should always be an orderbook of asks (direction: 1)
  # and vice versa.
  def opposing_orderbook=(ob)
    unless ob.nil?
      @opposing_orderbook   = ob
      ob.opposing_orderbook = self unless ob.opposing_orderbook == self
    end
  end

  # This is a wrapper method used by all the exchange callbacks.
  # Depending on the event that was triggered, we choose the right Orderbook method to call.
  def apply_exchange_updates(callback_method_prefix, data)
    self.send("#{callback_method_prefix}_item", data[:price], data[:size], timestamp: data[:timestamp])
  end

  def price_below?(price1, price2)
    if @direction > 0
      price1 >= price2
    else
      price1 <= price2
    end
  end

  # Do not publish events until we load full depth for the first time
  def publish_event(event_name, data)
    return unless @full_depth_timestamp
    data.merge!({direction: @direction})
    super(event_name, data)
  end


  private

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
