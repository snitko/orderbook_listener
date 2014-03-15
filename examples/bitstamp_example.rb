# Run this file from your terminal

require_relative '../lib/orderbook_listener'
require_relative '../lib/orderbook_listener/exchange_adapters/bitstamp_adapter'
require_relative 'orderbook_reporter'


reporter = OrderbookReporter.new
exchange = KrakenAdapter.new
orderbook_pair = OrderbookPair.new exchange_adapter: exchange 
orderbook_pair.subscribe(reporter)

puts "Start listening to updates...\n**************************\n"
exchange.subscribe_to_trade_data!

puts "Loading full depth..."
orderbook_pair.load!
puts "...done!"

sleep(500)
