require 'spec_helper'

require File.dirname(__FILE__) + '/../../lib/exchange_adapters/exchange_adapter_base'
require File.dirname(__FILE__) + '/../../lib/exchange_adapters/bitstamp_adapter'

describe BistampAdapter do

  it "fetches full depth orderbook from Bitstamp"
  
  describe "updating orderbook by connecting to Pusher" do

    it "fetches orderbook changes"
    it "fetches trades"

  end

  describe "callbacks" do

    it "notifies subscribers of orderbook changes"
    it "notifies subscribers of trades"
    it "notifies subscribers when a full depth orderbook is loaded"

  end

end
