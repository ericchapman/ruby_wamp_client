module Wamp
  module Client
    module Event

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def create_event(events, attribute: nil, setter: nil, trigger: nil)
          attribute ||= :event_callbacks
          setter ||= :on
          trigger ||= :trigger

          attr_accessor attribute

          event_name = "#{attribute}_events"

          define_method event_name do
            events
          end

          define_method setter do |event, &handler|
            unless self.send(event_name).include?(event)
              raise RuntimeError, "unknown #{setter}(event) '#{event}'"
            end

            callback = self.send(attribute) || {}
            callback[event] = handler
            self.send("#{attribute}=", callback)
          end

          define_method trigger do |event, *args|
            handler = (self.send(attribute) || {})[event]
            if handler != nil
              handler.call(*args)
            end
          end
        end
      end

    end
  end
end