require_relative "base"
require "wamp/client/message"

module Wamp
  module Client
    module Request

      class Message::Unsubscribed
        def request_id
          self.unsubscribe_request
        end
      end

      class Unsubscribe < Base

        def create_request(request_id, subscription, &callback)

          # Create the lookup
          lookup = { s: subscription, c: callback }

          # Create the message
          message = Message::Unsubscribe.new(request_id, subscription.id)

          # Return
          [lookup, message]
        end

        def process_success(message, lookup)
          if lookup
            # Get the params
            subscription = lookup[:s]
            callback = lookup[:c]

            # Create the details
            details = {}
            details[:topic] = subscription.topic
            details[:type] = 'unsubscribe'

            # Call the on_success method
            self.on_success.call(subscription.id)

            # Return the values
            [callback, subscription, details]
          else
            [nil, nil, nil]
          end
        end

        def process_error(message, lookup)
          if lookup
            # Get the params
            subscription = lookup[:s]
            callback = lookup[:c]

            # Create the details
            details = message.details || {}
            details[:topic] = subscription.topic unless details[:topic]
            details[:type] = 'unsubscribe'

            # Return the values
            [callback, details]
          else
            [nil, nil]
          end

        end

      end

    end
  end
end
