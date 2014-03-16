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
