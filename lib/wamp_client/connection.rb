module WampClient
  class Connection
    attr_accessor :options

    # Called when the connection is established
    @on_connect
    def on_connect(&on_connect)
      @on_connect = on_connect
    end

    # Called when the WAMP session is established
    @on_join
    def on_join(&on_join)
      @on_join = on_join
    end

    # Called when the WAMP session presents a challenge
    @on_challenge
    def on_challenge(&on_challenge)
      @on_challenge = on_challenge
    end

    # Called when the WAMP session is terminated
    @on_leave
    def on_leave(&on_leave)
      @on_leave = on_leave
    end

    # Called when the connection is terminated
    @on_disconnect
    def on_disconnect(&on_disconnect)
      @on_disconnect = on_disconnect
    end

    # @param options [Hash] The different options to pass to the connection
    def initialize(options)
      self.options = options || {}
    end

    def open

    end

    def close

    end

  end
end