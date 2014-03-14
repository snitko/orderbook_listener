require File.dirname(__FILE__) + '/../lib/orderbook_listener'

RSpec.configure do |config|

  # Remove this line if you don't want RSpec's should and should_not
  # methods or matchers
  require 'rspec/expectations'
  config.include RSpec::Matchers

  # == Mock Framework
  config.mock_with :rspec

  config.before(:suite) do
  end

  config.after(:suite) do
  end

end
