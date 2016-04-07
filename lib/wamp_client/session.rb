require 'wamp_client/transport'
require 'wamp_client/message'

module WampClient

  WAMP_FEATURES = {
      caller: {
          features: {
              # caller_identification: true,
              ##call_timeout: true,
              ##call_canceling: true,
              # progressive_call_results: true
          }
      },
      callee: {
          features: {
              # caller_identification: true,
              ##call_trustlevels: true,
              # pattern_based_registration: true,
              # shared_registration: true,
              ##call_timeout: true,
              ##call_canceling: true,
              # progressive_call_results: true,
              # registration_revocation: true
          }
      },
      publisher: {
          features: {
              # publisher_identification: true,
              # subscriber_blackwhite_listing: true,
              # publisher_exclusion: true
          }
      },
      subscriber: {
          features: {
              # publisher_identification: true,
              ##publication_trustlevels: true,
              # pattern_based_subscription: true,
              # subscription_revocation: true
              ##event_history: true,
          }
      }
  }

  class Session
    # on_join callback is called when the session joins the router.  It has the following parameters
    # @param details [Hash] Object containing information about the joined session
    attr_accessor :on_join

    # on_leave callback is called when the session leaves the router.  It has the following attributes
    # @param reason [String] The reason the session left the router
    # @param details [Hash] Object containing information about the left session
    attr_accessor :on_leave

    attr_accessor :id, :realm

    # Private attributes
    attr_accessor :_goodbye_sent

    # Constructor
    # @param transport [WampClient::Transport::Base] The transport that the session will use
    def initialize(transport)

      # Parameters
      self.id = nil
      self.realm = nil

      # Outstanding Requests
      @requests = {
          publish: {},
          subscribe: {},
          unsubscribe: {},
          call: {},
          register: {},
          unregister: {}
      }

      # Subscriptions in place;
      @subscriptions = {}

      # Registrations in place;
      @registrations = {}

      # Incoming invocations;
      @invocations = {}

      # Setup Transport
      @transport = transport
      @transport.on_message = lambda do |msg|
        self._process_message(msg)
      end

      # Other parameters
      self._goodbye_sent = false

      # Setup session callbacks
      self.on_join = nil
      self.on_leave = nil

    end

    # Returns 'true' if the session is open
    def is_open?
      !self.id.nil?
    end

    # Joins the WAMP Router
    # @param realm [String] The name of the realm
    def join(realm)
      self.realm = realm

      if is_open?
        # TODO: Throw Exception??
      end

      details = {}
      details[:roles] = WAMP_FEATURES

      # Send Hello message
      hello = WampClient::Message::Hello.new(realm, details)
      @transport.send_message(hello.payload)
    end

    # Leaves the WAMP Router
    # @param reason [String] URI signalling the reason for leaving
    def leave(reason='wamp.close.normal', message=nil)

      unless is_open?
        # TODO: Throw Exception??
      end

      details = {}
      details[:message] = message

      # Send Goodbye message
      goodbye = WampClient::Message::Goodbye.new(details, reason)
      @transport.send_message(goodbye.payload)
      self._goodbye_sent = true
    end

    #region Private Methods

    # Generates and ID according to the specification (Section 5.1.2)
    def _generate_id
      rand(0..9007199254740992)
    end

    # Processes received messages
    def _process_message(msg)
      puts msg

      message = WampClient::Message::Base.parse(msg)

      # WAMP Session is not open
      if self.id.nil?

        # Parse the welcome message
        if message.is_a? WampClient::Message::Welcome
          self.id = message.session
          self.on_join.call(message.details) unless self.on_join.nil?
        elsif message.is_a? WampClient::Message::Abort
          self.on_leave.call(message.reason, message.details) unless self.on_leave.nil?
        end

      # Wamp Session is open
      else

        # If goodbye, close the session
        if message.is_a? WampClient::Message::Goodbye

          # If we didn't send the goodbye, respond
          unless self._goodbye_sent
            goodbye = WampClient::Message::Goodbye.new({}, 'wamp.error.goodbye_and_out')
            @transport.send_message(goodbye.payload)
          end

          # Close out session
          self.id = nil
          self.realm = nil
          self._goodbye_sent = false
          self.on_leave.call(message.reason, message.details) unless self.on_leave.nil?

        else

          if message.is_a? WampClient::Message::Error
            # TODO: Find method that this error is for and return
          else
            # TODO: Process message
          end

        end
      end

    end

    #endregion

  end
end