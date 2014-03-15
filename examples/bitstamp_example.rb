# Run this file from your terminal

require_relative '../lib/orderbook_listener'
require_relative '../lib/orderbook_listener/exchange_adapters/bitstamp_adapter'

# This sucker's gonna print updates from bitstamp right into your terminal
class OrderbookReporter

  include ObservableRoles::Subscriber

  set_observed_publisher_callbacks(
    # Remember, Orderbook is not just a Subscriber to exchange adapter,
    # it publishes events itself as well! And we define callbacks for these events here.
    orderbook: {
      item_added:   -> (me, data) { puts "******* ORDERBOOK EVENT 'order added':   #{data}" },
      item_removed: -> (me, data) { puts "******* ORDERBOOK EVENT 'order removed': #{data}" },
      item_traded:  -> (me, data) { puts "******* ORDERBOOK EVENT 'order traded':  #{data}" }
    }
  )

end

reporter = OrderbookReporter.new
exchange = BitstampAdapter.new
orderbook_pair = OrderbookPair.new exchange_adapter: exchange 
orderbook_pair.subscribe(reporter)

puts "Loading full depth..."
orderbook_pair.load!
puts "...done!"

puts "Start listening to updates...\n**************************\n"
exchange.subscribe_to_trade_data!

sleep(500)
