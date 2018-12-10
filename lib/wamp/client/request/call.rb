require_relative "base"
require "wamp/client/message"

module Wamp
  module Client
    module Request

      class Message::Result
        def request_id
          self.call_request
        end
      end

      class CallObject
        attr_accessor :session, :id

        def initialize(session, id)
          self.session = session
          self.id = id
        end

        def cancel(mode='skip')
          self.session.cancel(self, mode)
        end

      end

      class Call < Base

        # Method specific to this request that will cancel it
        #
        def cancel(request_id, mode='skip')

          # If the request is still in flight
          if self.requests[request_id]
            # Create the message
            message = Message::Cancel.new(request_id, { mode: mode })

            # Send it
            send_message(message)
          end

        end

        def create_request(request_id, procedure, args=nil, kwargs=nil, options={}, &callback)

          # Create the lookup
          lookup = {p: procedure, a: args, k: kwargs, o: options, c: callback}

          # Create the message
          message = Message::Call.new(request_id, options, procedure, args, kwargs)

          # Return
          [lookup, message]
        end

        def process_success(message, lookup)
          if lookup
            # Get the params
            procedure = lookup[:p]
            options = lookup[:o] || {}
            callback = lookup[:c]

            # Create the details
            details = message.details || {}
            details[:procedure] = procedure unless details[:procedure]
            details[:type] = 'call'

            # Set the should keep flag if this is a progress message
            should_keep = details[:progress]

            # Only return the information if not progress or receive progress is true
            if not details[:progress] or (details[:progress] and options[:receive_progress])

              # Create the response
              result = Response::CallResult.from_yield_message(message)

              # Return the values
              [callback, result.to_hash, details, should_keep]

            else
              [nil, nil, nil, should_keep]
            end
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
            details[:type] = 'call'

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
