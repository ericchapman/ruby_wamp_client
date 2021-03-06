module Wamp
  module Client

    # Module that adds event capabilities to the class.
    #
    # Usage:
    #
    #   class MyClass
    #     include Event
    #
    #     create_event [:open, :close]
    #
    #     def do_something
    #       trigger :open, 4
    #     end
    #
    #   end
    #
    #   object = MyClass.new
    #
    #   object.on(:open) do |value|
    #     puts value
    #   end
    #
    #   object.do_something
    #
    # Prints:
    #
    #   4
    #
    module Event

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def create_event(events, attribute: nil, setter: nil, trigger: nil)
          attribute ||= :event
          setter ||= :on
          trigger ||= :trigger

          # Create the attributes
          callback_name = "#{attribute}_callbacks"
          event_list_name = "#{attribute}_list"

          # Creates the attribute to store the callbacks
          attr_accessor callback_name

          # Creates the attributes to store the allowed events
          define_method event_list_name do
            events
          end

          # Creates the setter.  Default: "on"
          define_method setter do |event, &handler|
            unless self.send(event_list_name).include?(event)
              raise RuntimeError, "unknown #{setter}(event) '#{event}'"
            end

            callback = self.send(callback_name) || {}
            callback[event] = handler
            self.send("#{callback_name}=", callback)
          end

          # Create the trigger.  Default: "trigger"
          define_method trigger do |event, *args|
            handler = (self.send(callback_name) || {})[event]
            if handler != nil
              handler.call(*args)
            end
          end
        end
      end

    end
  end
end