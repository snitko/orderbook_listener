orderbook_listener
==================

This library was built as a part of Coinancier app: http://coinancier.com

The purpose of this library is to serve as a backend orderbook storage,
which populates and then updates itself using data from various exchanges
(see `/lib/orderbook_listener/exchange_adapters` for the list of supported exchanges).
We store the whole orderbook in an Orderbook object. This library should thus most
probably be used as a part of program that is constantly loaded (a daemon or a webapp, maybe)
and thus the whole orderbook is always loaded into memory and is continiously updated.

The use case it was created for is to be a part of a websocket server app, which feeds
data collected from various Bitcoin exchanges to a frontend - in single unified format this
frontend understands. That way, the frontend doesn't have to implement all the different Bitcoin Exchange's
API and can use a single websocket API provided by the backend this library is a part of.

Please note this library DOES NOT provide an actual websocket server, it's just an Orderbook implementation
with a number of Bitcoin Exchanges' adapters.

For usage examples, please see `/examples`.

Would be happy to see your exchange adapters added to this library, so please don't hesitate to contribute.
