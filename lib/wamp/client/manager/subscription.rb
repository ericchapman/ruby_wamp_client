require_relative "base_multiple"

module Wamp
  module Client
    module Manager

      class SubscriptionObject
        attr_accessor :topic, :handler, :options, :session, :id

        def initialize(topic, handler, options, session, id)
          self.topic = topic
          self.handler = handler
          self.options = options
          self.session = session
          self.id = id
        end

        def unsubscribe
          self.session.unsubscribe(self)
        end

      end

      class Subscription < BaseMultiple

        # Processes and incoming event
        #
        # @param message [Message::Event] - The incoming event message
        def event(message)

          # Get the arguments
          subscription_id = message.subscribed_subscription
          args = message.publish_arguments || []
          kwargs = message.publish_argumentskw || {}

          # If we have a subscription, execute it
          subscription = self.objects[subscription_id]
          if subscription

            # Create the detials
            details = message.details || {}
            details[:publication] = message.published_publication
            details[:topic] = subscription.topic
            details[:session] = self.session

            # Call the handler
            handler = subscription.handler
            handler.call(args, kwargs, details) if handler
          end
        end
      end

    end
  end
end