require 'spec_helper'
require File.dirname(__FILE__) + '/../../lib/observable_roles'

class DummySubscriber

  include ObservableRoles::Subscriber

  set_observed_publisher_callbacks(
    kitty: { myau: -> (me, data) { data.myau }}
  )

end

class DummyPublisher
  include ObservableRoles::Publisher
end

describe ObservableRoles do

  before(:each) do
    @subscriber     = DummySubscriber.new
    @publisher      = DummyPublisher.new
    @publisher.role = :kitty
    @publisher.subscribe(@subscriber)
  end

  it "executes a callback when an event is published" do
    kitty_mock = double()
    kitty_mock.should_receive(:myau).once
    @publisher.publish_event(:myau, kitty_mock)
  end

  it "puts callbacks in a queue and executes them one by one until the queue is empty" do
    kitty_mock = double()
    kitty_mock.should_receive(:myau).exactly(3).times
    @subscriber.subscriber_lock = true
    3.times { @publisher.publish_event(:myau, kitty_mock) }
    @subscriber.subscriber_lock = false
    @subscriber.captured_observable_events.should have(3).items
    @subscriber.send(:release_captured_events)
    @subscriber.captured_observable_events.should have(0).items
  end

end
