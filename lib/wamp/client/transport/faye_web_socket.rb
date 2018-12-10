require_relative 'event_machine_base'

# This implementation uses the 'faye-websocket' Gem.
module Wamp
  module Client
    module Transport
      class FayeWebSocket < EventMachineBase
        attr_accessor :socket

        def initialize(options)
          super(options)
          self.socket = nil

          # Only make them include the gem if they are going to use it
          require 'faye/websocket'
        end

        def connect
          options = { :headers => self.headers }
          options[:proxy] = self.proxy if self.proxy != nil
          self.socket = Faye::WebSocket::Client.new(self.uri, [self.protocol], options)

          self.socket.on(:open) do |event|
            self.connected = true
            trigger :open
          end

          self.socket.on(:message) do |event|
            trigger :message, self.serializer.deserialize(event.data)
          end

          self.socket.on(:close) do |event|
            self.connected = false
            trigger :close, event.reason
          end

          self.socket.on(:error) do |event|
            trigger :error, event.message
          end
        end

        def disconnect
          self.socket.close
          self.connected = false
        end

        def send_message(msg)
          if self.connected
            self.socket.send(self.serializer.serialize(msg))
          else
            raise RuntimeError, "Socket must be open to call 'send_message'"
          end
        end

      end
    end
  end
end
