require_relative "base"
require "wamp/client/message"
require "wamp/client/manager/subscription"

module Wamp
  module Client
    module Request

      class Message::Subscribed
        def request_id
          self.subscribe_request
        end
      end

      class Subscribe < Base

        def create_request(request_id, topic, handler, options={}, &callback)

          # Create the lookup
          lookup = {t: topic, h: handler, o: options, c: callback}

          # Create the message
          message = Message::Subscribe.new(request_id, options, topic)

          # Return
          [lookup, message]
        end

        def process_success(message, lookup)
          if lookup
            # Get the params
            topic = lookup[:t]
            handler = lookup[:h]
            options = lookup[:o]
            callback = lookup[:c]

            # Create the subscription
            s_id = message.subscription
            s = Manager::SubscriptionObject.new(topic, handler, options, self.session, s_id)

            # Create the details
            details = {}
            details[:topic] = topic unless details[:topic]
            details[:type] = 'subscribe'

            # Call the on_success method
            self.on_success.call(s_id, s)

            # Return the values
            [callback, s, details]
          else
            [nil, nil, nil]
          end
        end

        def process_error(message, lookup)
          if lookup
            # Get the params
            topic = lookup[:t]
            callback = lookup[:c]

            # Create the details
            details = message.details || {}
            details[:topic] = topic unless details[:topic]
            details[:type] = 'subscribe'

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
