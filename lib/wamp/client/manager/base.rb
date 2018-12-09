module Wamp
  module Client
    module Manager

      class Base
        attr_reader :session, :send_message_callback

        # Constructor
        #
        # @param session [Wamp::Client::Session] - The session
        # @param success [Block] - A block to run when the request was successful
        def initialize(session, send_message)
          @session = session
          @send_message_callback = send_message
        end

        private

        # Returns the logger
        #
        def logger
          Wamp::Client.logger
        end

        # Sends a message
        #
        def send_message(message)
          self.send_message_callback.call(message) if self.send_message_callback
        end

        # Triggers an event
        def trigger(event, *args)
          self.session.trigger event, *args
        end
      end
    end
  end
end

