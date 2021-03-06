module Wamp
  module Client
    module Request

      class Message::Error
        def request_id
          self.request_request
        end
      end

      # The request base class is used to abstract all of the requests that
      # will go to the broker/dealer.  The model supports a request followed
      # by a response that is either a "success" or an error
      class Base
        attr_reader :requests, :session, :send_message_callback, :on_success

        # Constructor
        #
        # @param session [Wamp::Client::Session] - The session
        # @param send_message [lambda] - A lambda to send the message
        # @param success [Block] - A block to run when the request was successful
        def initialize(session, send_message, &on_success)
          @requests = {}
          @session = session
          @send_message_callback = send_message
          @on_success = on_success
        end

        # Generates a new ID for the request according to the specification
        # (Section 5.1.2)
        #
        # @param [Int] - A new ID
        def generate_id
          rand(0..9007199254740992)
        end

        # Makes the request to the broker/dealer
        #
        # @return [Int] - request_id
        def request(*args, &callback)

          # Generate an ID
          request_id = self.generate_id

          # Get the unique lookup/message for the request
          lookup, message = self.create_request(request_id, *args, &callback)

          # Store in the pending requests
          self.requests[request_id] = lookup if lookup

          # Send the message
          send_message(message)

          request_id
        end

        # Called when the response was a success
        #
        def success(message)
          # Get the request_id
          request_id = message.request_id

          # Get the lookup
          lookup = self.requests[request_id]

          # Parse the result
          callback, result, details, should_keep = self.process_success(message, lookup)

          if callback and details
            # Add items to details
            details[:session] = self.session

            # Call the callback
            callback.call(result, nil, details) if callback
          end

          # Delete if "should_keep" if false
          self.requests.delete(request_id) unless should_keep
        end

        def error(message)
          # Get the request_id
          request_id = message.request_id

          # Get the lookup
          lookup = self.requests.delete(request_id)

          # Parse the result
          callback, details = self.process_error(message, lookup)

          if callback and details
            # Add items to details
            details[:session] = self.session

            # Create the error
            error = Response::CallError.from_message(message)

            # Call the callback
            callback.call(nil, error.to_hash, details) if callback
          end
        end

        #region Override Methods
        def create_request(*args)
        end

        def process_success(message, lookup)
        end

        def process_error(message, lookup)
        end
        #endregion

        private

        # Sends a message
        #
        def send_message(message)
          self.send_message_callback.call(message) if self.send_message_callback
        end

      end
    end
  end
end