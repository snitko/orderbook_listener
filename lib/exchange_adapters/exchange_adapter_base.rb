require 'net/http'
require File.dirname(__FILE__) + '/../observable_roles'

class ExchangeAdapterBase

  include ObservableRoles::Publisher

  def initialize
    @orders       = {}
    @connection   = nil
    @trading_pair = 'USD/BTC'
    @role         = :exchange
  end

  # Freeing the memory here, we don't really need to hold full depth forever,
  # because it is stored in the Orderbook object.
  def clear_orderbook!
    @orders = nil
  end

  def orders(direction: 1)
    { timestamp: @orders[:timestamp].to_i, data: @orders[direction] }
  end

  def self.standartize_item(item)
    item
  end

end