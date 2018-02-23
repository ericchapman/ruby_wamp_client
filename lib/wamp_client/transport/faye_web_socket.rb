=begin

Copyright (c) 2016 Eric Chapman

MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=end

require_relative 'event_machine_base'

# This implementation uses the 'faye-websocket' Gem.
module WampClient
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
          @on_open.call if @on_open
        end

        self.socket.on(:message) do |event|
          @on_message.call(self.serializer.deserialize(event.data)) if @on_message
        end

        self.socket.on(:close) do |event|
          self.connected = false
          @on_close.call(event.reason) if @on_close
        end

        self.socket.on(:error) do |event|
          @on_error.call(event.message) if @on_error
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
