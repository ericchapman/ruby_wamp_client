require 'wamp/client/session'
require 'wamp/client/event'
require 'wamp/client/transport/web_socket_event_machine'
require 'wamp/client/transport/faye_web_socket'

module Wamp
  module Client
    class Connection
      include Event

      attr_accessor :options, :transport_class, :transport, :session

      create_event [:connect, :join, :challenge, :leave, :disconnect]

      # @param options [Hash] The different options to pass to the connection
      # @option options [String] :uri The uri of the WAMP router to connect to
      # @option options [String] :proxy The proxy to get to the router
      # @option options [String] :realm The realm to connect to
      # @option options [String,nil] :protocol The protocol (default if wamp.2.json)
      # @option options [String,nil] :authid The id to authenticate with
      # @option options [Array, nil] :authmethods The different auth methods that the client supports
      # @option options [Hash] :headers Custom headers to include during the connection
      # @option options [WampClient::Serializer::Base] :serializer The serializer to use (default is json)
      def initialize(options)
        self.transport_class = options.delete(:transport) || Wamp::Client::Transport::WebSocketEventMachine
        self.options = options || {}

        @reconnect = true
        @open = false

        logger.info("#{self.class.name} using version #{Wamp::Client::VERSION}")
      end

      # Opens the connection
      def open

        raise RuntimeError, 'connection is already open' if self.is_open?

        @reconnect = true
        @retry_timer = 1
        @retrying = false

        self.transport_class.start_event_machine do
          # Create the transport
          create_transport
        end

      end

      # Closes the connection
      def close

        raise RuntimeError, 'connection is already closed' unless self.is_open?

        # Leave the session
        @reconnect = false
        @retrying = false
        session.leave

      end

      # Returns true if the connection is open
      #
      def is_open?
        @open
      end

      private

      def create_session
        self.session = Wamp::Client::Session.new(self.transport, self.options)

        # Setup session callbacks
        self.session.on(:challenge) do |authmethod, extra|
          finish_retry
          trigger :challenge, authmethod, extra
        end

        self.session.on(:join) do |details|
          finish_retry
          trigger :join, self.session, details
        end

        self.session.on(:leave) do |reason, details|

          unless @retrying
            trigger :leave, reason, details
          end

          if @reconnect
            # Retry
            retry_connect unless @retrying
          else
            # Close the transport
            self.transport.disconnect
          end
        end

        self.session.join(self.options[:realm])
      end

      def create_transport

        if self.transport
          self.transport.disconnect
          self.transport = nil
        end

        # Initialize the transport
        self.transport = self.transport_class.new(self.options)

        # Setup transport callbacks
        self.transport.on(:open) do

          logger.info("#{self.class.name} transport open")

          # Call the callback
          trigger :connect

          # Create the session
          create_session

        end

        self.transport.on(:close) do |reason|
          logger.info("#{self.class.name} transport closed: #{reason}")
          @open = false

          unless @retrying
            trigger :disconnect, reason
          end

          # Nil out the session since the transport closed underneath it
          self.session = nil

          if @reconnect
            # Retry
            retry_connect unless @retrying
          else
            # Stop the Event Machine
            self.transport_class.stop_event_machine
          end
        end

        self.transport.on(:error) do |message|
          logger.error("#{self.class.name} transport error: #{message}")
        end

        @open = true

        self.transport.connect

      end

      def finish_retry
        @retry_timer = 1
        @retrying = false
      end

      def retry_connect

        if self.session == nil or not self.session.is_open?
          @retry_timer = 2*@retry_timer unless @retry_timer == 32
          @retrying = true

          create_transport

          logger.info("#{self.class.name} reconnect in #{@retry_timer} seconds")
          self.transport_class.add_timer(@retry_timer*1000) do
            retry_connect if @retrying
          end
        end

      end

      # Returns the logger
      #
      def logger
        Wamp::Client.logger
      end

    end
  end
end