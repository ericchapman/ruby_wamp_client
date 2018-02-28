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

# This implementation uses the 'websocket-eventmachine-client' Gem.
# This is the default if no transport is included
module WampClient
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
          @on_open.call if @on_open
        end

        self.socket.onmessage do |msg, type|
          @on_message.call(self.serializer.deserialize(msg)) if @on_message
        end

        self.socket.onclose do |code, reason|
          self.connected = false
          @on_close.call(reason) if @on_close
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

