require 'websocket-eventmachine-client'
require 'wamp_client/session'
require 'wamp_client/transport'

module WampClient
  class Connection
    attr_accessor :options, :transport, :session

    @reconnect = true

    @open = false
    def is_open?
      @open
    end

    # Called when the connection is established
    @on_connect
    def on_connect(&on_connect)
      @on_connect = on_connect
    end

    # Called when the WAMP session is established
    # @param session [WampClient::Session]
    # @param details [Hash]
    @on_join
    def on_join(&on_join)
      @on_join = on_join
    end

    # Called when the WAMP session presents a challenge
    # @param authmethod [String]
    # @param extra [Hash]
    @on_challenge
    def on_challenge(&on_challenge)
      @on_challenge = on_challenge
    end

    # Called when the WAMP session is terminated
    # @param reason [String] The reason the session left the router
    # @param details [Hash] Object containing information about the left session
    @on_leave
    def on_leave(&on_leave)
      @on_leave = on_leave
    end

    # Called when the connection is terminated
    # @param reason [String] The reason the transport was disconnected
    @on_disconnect
    def on_disconnect(&on_disconnect)
      @on_disconnect = on_disconnect
    end

    # @param options [Hash] The different options to pass to the connection
    # @option options [String] :uri The uri of the WAMP router to connect to
    # @option options [String] :realm The realm to connect to
    # @option options [String] :protocol The protocol (default if wamp.2.json)
    # @option options [Hash] :headers Custom headers to include during the connection
    # @option options [WampClient::Serializer::Base] :serializer The serializer to use (default is json)
    def initialize(options)
      self.options = options || {}
    end

    # Opens the connection
    def open

      raise RuntimeError, 'The connection is already open' if self.is_open?

      EM.run do

        # Initialize the transport
        if self.options[:transport]
          self.transport = self.options[:transport]
        else
          self.transport = WampClient::Transport::WebSocketTransport.new(self.options)
        end

        # Setup transport callbacks
        self.transport.on_open do

          # Call the callback
          @on_connect.call if @on_connect

          # Create the session
          self.session = WampClient::Session.new(self.transport, self.options)

          # Setup session callbacks
          self.session.on_challenge do |authmethod, extra|
            @on_challenge.call(authmethod, extra) if @on_challenge
          end

          self.session.on_join do |details|
            @on_join.call(self.session, details) if @on_join
          end

          self.session.on_leave do |reason, details|
            @on_leave.call(reason, details) if @on_leave

            if @reconnect
              # TODO: Retry Logic
            else
              # Close the transport
              self.transport.disconnect
            end
          end

          self.session.join(self.options[:realm])

        end

        self.transport.on_close do |reason|
          @on_disconnect.call(reason) if @on_disconnect

          if @reconnect
            # TODO: Retry Logic
          else
            # Stop the Event Machine
            EM.stop
          end
        end

        @reconnect = true
        @open = true

        self.transport.connect
      end
    end

    # Closes the connection
    def close

      raise RuntimeError, 'The connection is already closed' unless self.is_open?

      @reconnect = false
      session.leave
    end

  end
end