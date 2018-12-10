require_relative "base"
require "wamp/client/message"

module Wamp
  module Client
    module Request

      class Message::Unregistered
        def request_id
          self.unregister_request
        end
      end

      class Unregister < Base

        def create_request(request_id, registration, &callback)

          # Create the lookup
          lookup = { r: registration, c: callback }

          # Create the message
          message = Message::Unregister.new(request_id, registration.id)

          # Return
          [lookup, message]
        end

        def process_success(message, lookup)
          if lookup
            # Get the params
            registration = lookup[:r]
            callback = lookup[:c]

            # Create the details
            details = {}
            details[:procedure] = registration.procedure
            details[:type] = 'unregister'

            # Call the on_success method
            self.on_success.call(registration.id)

            # Return the values
            [callback, registration, details]
          else
            [nil, nil, nil]
          end
        end

        def process_error(message, lookup)
          if lookup
            # Get the params
            registration = lookup[:r]
            callback = lookup[:c]

            # Create the details
            details = message.details || {}
            details[:procedure] = registration.procedure unless details[:procedure]
            details[:type] = 'unregister'

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
