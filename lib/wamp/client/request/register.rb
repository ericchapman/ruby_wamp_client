require_relative "base"
require "wamp/client/message"
require "wamp/client/manager/registration"

module Wamp
  module Client
    module Request

      class Message::Registered
        def request_id
          self.register_request
        end
      end

      class Register < Base

        # Create the request message and lookup data structure
        def create_request(request_id, procedure, handler, options=nil, interrupt=nil, &callback)

          # Create the lookup
          lookup = {p: procedure, h: handler, i: interrupt, o: options, c: callback}

          # Create the message
          message = Message::Register.new(request_id, options, procedure)

          # Return
          [lookup, message]
        end

        # Called when the response was a success
        #
        def process_success(message, lookup)
          if lookup
            # Get the params
            procedure = lookup[:p]
            handler = lookup[:h]
            options = lookup[:o]
            interrupt = lookup[:i]
            callback = lookup[:c]

            # Create the subscription
            r_id = message.registration
            r = Manager::RegistrationObject.new(procedure, handler, options, interrupt, self.session, r_id)

            # Create the details
            details = {}
            details[:procedure] = procedure
            details[:type] = 'register'

            # Call the on_success method
            self.on_success.call(r_id, r)

            # Return the values
            [callback, r, details]
          else
            [nil, nil, nil]
          end
        end

        def process_error(message, lookup)
          if lookup
            # Get the params
            procedure = lookup[:p]
            callback = lookup[:c]

            # Create the details
            details = message.details || {}
            details[:procedure] = procedure unless details[:procedure]
            details[:type] = 'register'

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
