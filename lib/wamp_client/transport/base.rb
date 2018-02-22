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

require 'wamp_client/serializer'

module WampClient
  module Transport
    class Base

      # Callback when the socket is opened
      @on_open
      def on_open(&on_open)
        @on_open = on_open
      end

      # Callback when the socket is closed.  Parameters are
      # @param reason [String] String telling the reason it was closed
      @on_close
      def on_close(&on_close)
        @on_close = on_close
      end

      # Callback when a message is received.  Parameters are
      # @param msg [Array] The parsed message that was received
      @on_message
      def on_message(&on_message)
        @on_message = on_message
      end

      # Callback when there is an error.  Parameters are
      @on_error
      def on_error(&on_error)
        @on_error = on_error
      end

      attr_accessor :uri, :proxy, :headers, :protocol, :serializer, :connected

      # Constructor for the transport
      # @param options [Hash] The connection options.  the different options are as follows
      # @option options [String] :uri The url to connect to
      # @option options [String] :proxy The proxy to use
      # @option options [String] :protocol The protocol
      # @option options [Hash] :headers Custom headers to include during the connection
      # @option options [WampClient::Serializer::Base] :serializer The serializer to use
      def initialize(options)

        # Initialize the parameters
        self.connected = false
        self.uri = options[:uri]
        self.proxy = options[:proxy]
        self.headers = options[:headers] || {}
        self.protocol = options[:protocol] || 'wamp.2.json'
        self.serializer = options[:serializer] || WampClient::Serializer::JSONSerializer.new

        # Add the wamp.2.json protocol header
        self.headers['Sec-WebSocket-Protocol'] = self.protocol

        # Initialize callbacks
        @on_open = nil
        @on_close = nil
        @on_message = nil
        @on_error = nil

      end

      # Connects to the WAMP Server using the transport
      def connect
        # Implement in subclass
      end

      # Disconnects from the WAMP Server
      def disconnect
        # Implement in subclass
      end

      # Returns true if the transport it connected
      def connected?
        self.connected
      end

      # Sends a Message
      # @param [Array] msg - The message payload to send
      def send_message(msg)
        # Implement in subclass
      end

      # Process the callback when the timer expires
      # @param [Integer] milliseconds - The number
      # @param [block] callback - The callback that is fired when the timer expires
      def self.add_timer(milliseconds, &callback)
        # Implement in subclass
      end
      def add_timer(milliseconds, &callback)
        self.class.add_timer(milliseconds, &callback)
      end

      # Method to start the event machine for the socket
      def self.start_event_machine(&block)
        # Implement in subclass
      end

      # Method to stop the vent machine
      def self.stop_event_machine
        # Implement in subclass
      end

    end

  end
end