require_relative 'event_machine_base'

# This implementation uses the 'websocket-eventmachine-client' Gem.
# This is the default if no transport is included
module Wamp
  module Client
    module Transport
      class WebSocketEventMachine < EventMachineBase
        attr_accessor :socket

        def initialize(options)
          super(options)
          self.socket = nil

          # Only make them include the gem if they are going to use it
          require 'websocket-eventmachine-client'

          # Raise an exception if proxy was included (not supported)
          if self.proxy != nil
            raise RuntimeError, "The WebSocketEventMachine transport does not support 'proxy'.  Try using 'faye-websocket' transport instead"
          end
        end

        def connect
          self.socket = WebSocket::EventMachine::Client.connect(
              :uri => self.uri,
              :headers => self.headers
          )

          self.socket.onopen do
            self.connected = true
            trigger :open
          end

          self.socket.onmessage do |msg, type|
            trigger :message, self.serializer.deserialize(msg)
          end

          self.socket.onclose do |code, reason|
            self.connected = false
            trigger :close, reason
          end
        end

        def disconnect
          self.connected = !self.socket.close  # close returns 'true' if the connection was closed immediately
        end

        def send_message(msg)
          if self.connected
            self.socket.send(self.serializer.serialize(msg), {type: 'text'})
          else
            raise RuntimeError, "Socket must be open to call 'send_message'"
          end
        end

      end
    end
  end
end

