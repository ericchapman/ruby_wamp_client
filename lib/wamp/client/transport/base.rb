require 'wamp/client/serializer'
require 'wamp/client/event'

module Wamp
  module Client
    module Transport
      class Base
        include Event

        attr_accessor :uri, :proxy, :headers, :protocol, :serializer, :connected

        create_event [:open, :close, :message, :error]

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
          self.serializer = options[:serializer] || Wamp::Client::Serializer::JSONSerializer.new

          # Add the wamp.2.json protocol header
          self.headers['Sec-WebSocket-Protocol'] = self.protocol
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

        # Method to add a tick loop to the event machine
        def self.add_tick_loop(&block)
          # Implement in subclass
        end
      end
    end
  end
end