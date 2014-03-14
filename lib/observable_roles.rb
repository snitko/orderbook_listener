# Thread safe implementation of the Observable pattern which also supports roles.
#
# For usage examples refer to the _spec file with unit tests.
# The following will be a short explanation of how this implementation works.
#
# You have two objects: one is a Subscriber, another one is Publisher.
# You subscribe a Subscriber to the Publisher events with a Publisher#subscribe.
# However the Subscriber would still ignore anything that Publisher publishes.
#
# In order for it to be notified of the events, you must define callbacks with
# Subscriber.set_observed_publisher_callbacks. These callbacks have the following form:
#
#   role_name: { event_name: -> (me, data) { } }
#
# where `me` is a reference to the Subscriber object and `data` is a hash of some info
# that is passed from the Publisher.
#
# Now `role_name` is a role of the Pubslisher, which can be set as follows:
#
#   publisher.role = :good_cop
#
# Obviously, each role may have many different events and those events may come from various
# publishers who play the same role. This approach is more flexible than the standard Observer pattern,
# since it allows easy many-to-many relationship to be established.
#
# ### Thread safety ###
#
# Each new event that has a callback doesn't execute this callback immediately after said event is caught.
# Instead, it is added into a queue of events, which are then executed one by one. This ensures that each event
# callback execution doesn't interfere with the other.
module ObservableRoles

  module Subscriber

    module ClassMethods
      def set_observed_publisher_callbacks(callbacks)
        @observed_publisher_callbacks = callbacks
      end
      def get_observed_publisher_callbacks
        @observed_publisher_callbacks
      end
    end

    def self.included(base)
      attr_accessor :subscriber_lock
      attr_reader   :captured_observable_events
      base.extend(ClassMethods)
    end

    def capture_observable_event(role, event_name, data={})
      role       = role.to_sym
      event_name = event_name.to_sym
      if self.class.get_observed_publisher_callbacks[role].nil? || self.class.get_observed_publisher_callbacks[role][event_name].nil?
        raise "No callback for role `#{role}` and event `#{event_name}` defined in #{self}!"
      end

      @captured_observable_events ||= []
      @captured_observable_events.push({ callback: self.class.get_observed_publisher_callbacks[role][event_name], data: data })
      release_captured_events unless @subscriber_lock
    end


    private

      def release_captured_events
        @subscriber_lock = true
        while !@captured_observable_events.empty?
          e = @captured_observable_events.shift
          e[:callback].call(self, e[:data])
        end
        @subscriber_lock = false
      end

  end


  module Publisher

    def self.included(base)
      attr_accessor :role
    end

    def subscribe(s)
      @observing_subscriber = [] unless @observing_subscriber
      @observing_subscriber << s
    end

    def unsubscribe(s)
      unless @observing_subscriber.blank?
        @observing_subscriber.delete(s)
      end
    end

    def publish_event(event_name, data={})
      return unless @observing_subscriber
      @observing_subscriber.each do |s|
        if !block_given? || yield(s)
          s.capture_observable_event(role, event_name, data)
        end
      end
    end

  end

end
