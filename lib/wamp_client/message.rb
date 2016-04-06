require 'wamp_client/check'

module WampClient
  module Message

    module Types
      # TODO: Create message types
    end

    class Message
      include WampClient::Check
    end

    #region Basic Profile

    # Hello
    # Sent by a Client to initiate opening of a WAMP session to a Router attaching to a Realm.
    # [HELLO, Realm|uri, Details|dict]
    class Hello < Message

      @realm      # The realm to say hello to
      @details    # The details of the message

      # @param realm [String]
      # @param details [Hash]
      def initialize(realm, details={})
        self.class.check_uri('realm', realm)
        self.class.check_dict('details', details)

        @realm = realm
        @details = details
      end

    end

    # Welcome
    # Sent by a Router to accept a Client.  The WAMP session is now open.
    # [WELCOME, Session|id, Details|dict]
    class Welcome < Message

      @session    # The session id
      @details    # The details of the message

      # @param session [Integer]
      # @param details [Hash]
      def initialize(session, details={})
        self.class.check_id('session', session)
        self.class.check_dict('details', details)

        @session = session
        @details = details
      end

    end

    # Abort
    # Sent by a Peer*to abort the opening of a WAMP session.  No response is expected.
    # [ABORT, Details|dict, Reason|uri]
    class Abort < Message

      @details    # The details of the message
      @reason     # The reason for the abort

      # @param details [Hash]
      # @param reason [String]
      def initialize(details={}, reason='')
        self.class.check_dict('details', details)
        self.class.check_uri('reason', reason)

        @details = details
        @reason = reason
      end

    end

    # Goodbye
    # Sent by a Peer to close a previously opened WAMP session.  Must be echo'ed by the receiving Peer.
    # [GOODBYE, Details|dict, Reason|uri]
    class Goodbye < Abort

    end

    # Error
    # Error reply sent by a Peer as an error response to different kinds of requests.
    # [ERROR, REQUEST.Type|int, REQUEST.Request|id, Details|dict, Error|uri]
    # [ERROR, REQUEST.Type|int, REQUEST.Request|id, Details|dict, Error|uri, Arguments|list]
    # [ERROR, REQUEST.Type|int, REQUEST.Request|id, Details|dict, Error|uri, Arguments|list, ArgumentsKw|dict]
    class Error < Message

      @request_type   # The type of the request
      @request_id     # The id of the request
      @details        # The details of the message
      @error          # The error
      @args           # The arguments for the error
      @kwargs         # The keyword arguments for the error

      # @param details [Hash]
      def initialize(request_type, request_id, details={}, error=nil, args=nil, kwargs=nil)
        self.class.check_integer('request_type', request_type)
        self.class.check_id('request_id', request_id)
        self.class.check_dict('details', details)
        self.class.check_uri('error', error, true)
        self.class.check_list('args', args, true)
        self.class.check_dict('kwargs', kwargs, true)

        @request_type = request_type
        @request_id = request_id
        @details = details
        @error = error
        @args = args
        @kwargs = kwargs
      end

    end

    #endregion

  end
end