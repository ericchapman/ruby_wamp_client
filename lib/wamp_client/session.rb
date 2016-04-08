require 'wamp_client/transport'
require 'wamp_client/message'
require 'wamp_client/check'

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

  class Subscription
    attr_accessor :topic, :handler, :options, :session, :id

    def initialize(topic, handler, options, session, id)
      self.topic = topic
      self.handler = handler
      self.options = options
      self.session = session
      self.id = id
    end

    def unsubscribe
      self.session.unsubscribe(self)
    end

  end

  class Session
    include WampClient::Check

    # on_join callback is called when the session joins the router.  It has the following parameters
    # @param details [Hash] Object containing information about the joined session
    attr_accessor :on_join

    # on_leave callback is called when the session leaves the router.  It has the following attributes
    # @param reason [String] The reason the session left the router
    # @param details [Hash] Object containing information about the left session
    attr_accessor :on_leave

    attr_accessor :id, :realm, :transport

    # Private attributes
    attr_accessor :_goodbye_sent, :_requests, :_subscriptions

    # Constructor
    # @param transport [WampClient::Transport::Base] The transport that the session will use
    def initialize(transport)

      # Parameters
      self.id = nil
      self.realm = nil

      # Outstanding Requests
      self._requests = {
          publish: {},
          subscribe: {},
          unsubscribe: {},
          call: {},
          register: {},
          unregister: {}
      }

      # Subscriptions in place;
      self._subscriptions = {}

      # Registrations in place;
      @registrations = {}

      # Incoming invocations;
      @invocations = {}

      # Setup Transport
      self.transport = transport
      self.transport.on_message = lambda do |msg|
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
      if is_open?
        raise RuntimeError, "Session must be closed to call 'join'"
      end

      self.class.check_uri('realm', realm)

      self.realm = realm

      details = {}
      details[:roles] = WAMP_FEATURES

      # Send Hello message
      hello = WampClient::Message::Hello.new(realm, details)
      self.transport.send_message(hello.payload)
    end

    # Leaves the WAMP Router
    # @param reason [String] URI signalling the reason for leaving
    def leave(reason='wamp.close.normal', message=nil)
      unless is_open?
        raise RuntimeError, "Session must be opened to call 'leave'"
      end

      self.class.check_uri('reason', reason, true)
      self.class.check_string('message', message, true)

      details = {}
      details[:message] = message

      # Send Goodbye message
      goodbye = WampClient::Message::Goodbye.new(details, reason)
      self.transport.send_message(goodbye.payload)
      self._goodbye_sent = true
    end

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
            self.transport.send_message(goodbye.payload)
          end

          # Close out session
          self.id = nil
          self.realm = nil
          self._goodbye_sent = false
          self.on_leave.call(message.reason, message.details) unless self.on_leave.nil?

        else

          if message.is_a? WampClient::Message::Error
            if message.request_type == 32
              self._process_subscribed_error(message)
            elsif message.request_type == 34
              self._process_unsubscribed_error(message)
            end
            # TODO: Remaining Errors
          else
            if message.is_a? WampClient::Message::Subscribed
              self._process_subscribed_success(message)
            elsif message.is_a? WampClient::Message::Unsubscribed
              self._process_unsubscribed_success(message)
            elsif message.is_a? WampClient::Message::Event
              self._process_event(message)
            else
              # TODO: Some Error?  Not Implemented yet
            end
            # TODO: Process message
          end

        end
      end

    end

    #region Subscribe Logic

    # Subscribes to a topic
    # @param topic [String] The topic to subscribe to
    # @param handler [lambda] The handler(args, kwargs, details) when a publish is received
    # @param options [Hash] The options for the subscription
    # @param callback [lambda] The callback(subscription, error, details) called to signal if the subscription was a success or not
    def subscribe(topic, handler, options={}, callback=nil)
      unless is_open?
        raise RuntimeError, "Session must be opened to call 'subscribe'"
      end

      self.class.check_uri('topic', topic)
      self.class.check_dict('options', options)

      # Create a new subscribe request
      request = self._generate_id
      self._requests[:subscribe][request] = {t: topic, h: handler, o: options, c: callback}

      # Send the message
      subscribe = WampClient::Message::Subscribe.new(request, options, topic)
      self.transport.send_message(subscribe.payload)
    end

    # Processes the response to a subscribe request
    # @param msg [WampClient::Message::Subscribed] The response from the subscribe
    def _process_subscribed_success(msg)

      r_id = msg.subscribe_request
      s_id = msg.subscription

      # Remove the pending subscription, add it to the registered ones, and inform the caller
      s = self._requests[:subscribe].delete(r_id)
      if s
        n_s = Subscription.new(s[:t], s[:h], s[:o], self, s_id)
        self._subscriptions[s_id] = n_s
        c = s[:c]
        c.call(n_s, nil, nil) if c
      end

    end

    # Processes an error from a request
    # @param msg [WampClient::Message::Error] The response from the subscribe
    def _process_subscribed_error(msg)

      r_id = msg.request_request
      d = msg.details
      e = msg.error

      # Remove the pending subscription and inform the caller of the failure
      s = self._requests[:subscribe].delete(r_id)
      if s
        c = s[:c]
        c.call(nil, e, d) if c
      end

    end

    # Processes and event from the broker
    # @param msg [WampClient::Message::Event] An event that was published
    def _process_event(msg)

      s_id = msg.subscribed_subscription
      details = msg.details
      args = msg.publish_arguments
      kwargs = msg.publish_argumentskw

      s = self._subscriptions[s_id]
      if s
        h = s.handler
        h.call(args, kwargs, details) if h
      end

    end

    #endregion

    #region Unsubscribe Logic

    # Unsubscribes from a subscription
    # @param subscription [Subscription] The subscription object from when the subscription was created
    # @param callback [lambda] The callback(subscription, error, details) called to signal if the subscription was a success or not
    def unsubscribe(subscription, callback=nil)
      unless is_open?
        raise RuntimeError, "Session must be opened to call 'unsubscribe'"
      end

      self.class.check_nil('subscription', subscription, false)

      # Create a new unsubscribe request
      request = self._generate_id
      self._requests[:unsubscribe][request] = { s: subscription, c: callback }

      # Send the message
      unsubscribe = WampClient::Message::Unsubscribe.new(request, subscription.id)
      self.transport.send_message(unsubscribe.payload)
    end

    # Processes the response to a subscribe request
    # @param msg [WampClient::Message::Unsubscribed] The response from the unsubscribe
    def _process_unsubscribed_success(msg)

      r_id = msg.unsubscribe_request

      # Remove the pending unsubscription, add it to the registered ones, and inform the caller
      s = self._requests[:unsubscribe].delete(r_id)
      if s
        n_s = s[:s]
        self._subscriptions.delete(n_s.id)
        c = s[:c]
        c.call(n_s, nil, nil) if c
      end

    end


    # Processes an error from a request
    # @param msg [WampClient::Message::Error] The response from the subscribe
    def _process_unsubscribed_error(msg)

      r_id = msg.request_request
      d = msg.details
      e = msg.error

      # Remove the pending subscription and inform the caller of the failure
      s = self._requests[:unsubscribe].delete(r_id)
      if s
        c = s[:c]
        c.call(nil, e, d) if c
      end

    end

    #endregion

    #region Publish Logic

    # Subscribes to a topic
    # @param topic [String] The topic to subscribe to
    # @param handler [lambda] The handler(args, kwargs, details) when a publish is received
    # @param options [Hash] The options for the subscription
    # @param callback [lambda] The callback(subscription, error, details) called to signal if the subscription was a success or not
    def subscribe(topic, handler, options={}, callback=nil)
      unless is_open?
        raise RuntimeError, "Session must be opened to call 'subscribe'"
      end

      self.class.check_uri('topic', topic)
      self.class.check_dict('options', options)

      # Create a new subscribe request
      request = self._generate_id
      self._requests[:subscribe][request] = {t: topic, h: handler, o: options, c: callback}

      # Send the message
      subscribe = WampClient::Message::Subscribe.new(request, options, topic)
      self.transport.send_message(subscribe.payload)
    end

    # Processes the response to a subscribe request
    # @param msg [WampClient::Message::Subscribed] The response from the subscribe
    def _process_subscribed_success(msg)

      r_id = msg.subscribe_request
      s_id = msg.subscription

      # Remove the pending subscription, add it to the registered ones, and inform the caller
      s = self._requests[:subscribe].delete(r_id)
      if s
        n_s = Subscription.new(s[:t], s[:h], s[:o], self, s_id)
        self._subscriptions[s_id] = n_s
        c = s[:c]
        c.call(n_s, nil, nil) if c
      end

    end

    # Processes an error from a request
    # @param msg [WampClient::Message::Error] The response from the subscribe
    def _process_subscribed_error(msg)

      r_id = msg.request_request
      d = msg.details
      e = msg.error

      # Remove the pending subscription and inform the caller of the failure
      s = self._requests[:subscribe].delete(r_id)
      if s
        c = s[:c]
        c.call(nil, e, d) if c
      end

    end

    #endregion

  end
end