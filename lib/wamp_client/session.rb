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

require 'wamp_client/transport'
require 'wamp_client/message'
require 'wamp_client/check'
require 'wamp_client/version'

module WampClient

  WAMP_FEATURES = {
      caller: {
          features: {
              caller_identification: true,
              ##call_timeout: true,
              ##call_canceling: true,
              progressive_call_results: true
          }
      },
      callee: {
          features: {
              caller_identification: true,
              ##call_trustlevels: true,
              pattern_based_registration: true,
              shared_registration: true,
              ##call_timeout: true,
              ##call_canceling: true,
              progressive_call_results: true,
              registration_revocation: true
          }
      },
      publisher: {
          features: {
              publisher_identification: true,
              subscriber_blackwhite_listing: true,
              publisher_exclusion: true
          }
      },
      subscriber: {
          features: {
              publisher_identification: true,
              ##publication_trustlevels: true,
              pattern_based_subscription: true,
              subscription_revocation: true
              ##event_history: true,
          }
      }
  }

  class CallResult
    attr_accessor :args, :kwargs

    def initialize(args=nil, kwargs=nil)
      self.args = args || []
      self.kwargs = kwargs || {}
    end
  end

  class CallError < Exception
    attr_accessor :error, :args, :kwargs

    def initialize(error, args=nil, kwargs=nil)
      self.error = error
      self.args = args || []
      self.kwargs = kwargs || {}
    end
  end

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

  class Registration
    attr_accessor :procedure, :handler, :options, :session, :id

    def initialize(procedure, handler, options, session, id)
      self.procedure = procedure
      self.handler = handler
      self.options = options
      self.session = session
      self.id = id
    end

    def unregister
      self.session.unregister(self)
    end

  end


  class Session
    include WampClient::Check

    # on_join callback is called when the session joins the router.  It has the following parameters
    # @param details [Hash] Object containing information about the joined session
    @on_join
    def on_join(&on_join)
      @on_join = on_join
    end

    # on_leave callback is called when the session leaves the router.  It has the following attributes
    # @param reason [String] The reason the session left the router
    # @param details [Hash] Object containing information about the left session
    @on_leave
    def on_leave(&on_leave)
      @on_leave = on_leave
    end

    # on_challenge callback is called when an authentication challenge is received from the router.  It has the
    # following attributes
    # @param authmethod [String] The type of auth being requested
    # @param extra [Hash] Hash containing additional information
    # @return signature, extras
    @on_challenge
    def on_challenge(&on_challenge)
      @on_challenge = on_challenge
    end

    attr_accessor :id, :realm, :transport, :verbose, :options

    # Private attributes
    attr_accessor :_goodbye_sent, :_requests, :_subscriptions, :_registrations, :_defers

    # Constructor
    # @param transport [WampClient::Transport::Base] The transport that the session will use
    # @param options [Hash] Hash containing different session options
    # @option options [String] :authid The authentication ID
    # @option options [Array] :authmethods Different auth methods that this client supports
    def initialize(transport, options={})

      # Parameters
      self.id = nil
      self.realm = nil
      self.options = options || {}
      self.verbose = self.options[:verbose]

      # Outstanding Requests
      self._requests = {
          publish: {},
          subscribe: {},
          unsubscribe: {},
          call: {},
          register: {},
          unregister: {}
      }

      # Init Subs and Regs in place
      self._subscriptions = {}
      self._registrations = {}
      self._defers = {}

      # Setup Transport
      self.transport = transport
      self.transport.on_message do |msg|
        self._receive_message(msg)
      end

      # Other parameters
      self._goodbye_sent = false

      # Setup session callbacks
      @on_join = nil
      @on_leave = nil

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
      details[:agent] = "Ruby-WampClient-#{WampClient::VERSION}"
      details[:authid] = self.options[:authid] if self.options[:authid]
      details[:authmethods] = self.options[:authmethods] if self.options[:authmethods]

      # Send Hello message
      hello = WampClient::Message::Hello.new(realm, details)
      self._send_message(hello)
    end

    # Leaves the WAMP Router
    # @param reason [String] URI signalling the reason for leaving
    def leave(reason='wamp.close.normal', message='user initiated')
      unless is_open?
        raise RuntimeError, "Session must be opened to call 'leave'"
      end

      self.class.check_uri('reason', reason, true)
      self.class.check_string('message', message, true)

      details = {}
      details[:message] = message

      # Send Goodbye message
      goodbye = WampClient::Message::Goodbye.new(details, reason)
      self._send_message(goodbye)
      self._goodbye_sent = true
    end

    # Generates an ID according to the specification (Section 5.1.2)
    def _generate_id
      rand(0..9007199254740992)
    end

    # Converts and error message to a hash
    # @param msg [WampClient::Message::Error]
    def _error_to_hash(msg)
      {
          error: msg.error,
          args: msg.arguments,
          kwargs: msg.argumentskw
      }
    end

    # Sends a message
    # @param msg [WampClient::Message::Base]
    def _send_message(msg)
      puts 'TX: ' + msg.to_s if self.verbose
      self.transport.send_message(msg.payload)
    end

    # Processes received messages
    # @param msg [Array]
    def _receive_message(msg)

      message = WampClient::Message::Base.parse(msg)

      if self.verbose
        puts 'RX: ' + message.to_s if message
        puts 'RX(non-wamp): ' + msg.to_s unless message
      end

      # WAMP Session is not open
      if self.id.nil?

        # Parse the welcome message
        if message.is_a? WampClient::Message::Welcome
          self.id = message.session
          @on_join.call(message.details) unless @on_join.nil?
        elsif message.is_a? WampClient::Message::Challenge

          if @on_challenge
            signature, extra = @on_challenge.call(message.authmethod, message.extra)
          else
            signature = nil
            extra = nil
          end

          signature ||= ''
          extra ||= {}

          authenticate = WampClient::Message::Authenticate.new(signature, extra)
          self._send_message(authenticate)

        elsif message.is_a? WampClient::Message::Abort
          @on_leave.call(message.reason, message.details) unless @on_leave.nil?
        end

      # Wamp Session is open
      else

        # If goodbye, close the session
        if message.is_a? WampClient::Message::Goodbye

          # If we didn't send the goodbye, respond
          unless self._goodbye_sent
            goodbye = WampClient::Message::Goodbye.new({}, 'wamp.error.goodbye_and_out')
            self._send_message(goodbye)
          end

          # Close out session
          self.id = nil
          self.realm = nil
          self._goodbye_sent = false
          @on_leave.call(message.reason, message.details) unless @on_leave.nil?

        else

          # Process Errors
          if message.is_a? WampClient::Message::Error
            if message.request_type == WampClient::Message::Types::SUBSCRIBE
              self._process_SUBSCRIBE_error(message)
            elsif message.request_type == WampClient::Message::Types::UNSUBSCRIBE
              self._process_UNSUBSCRIBE_error(message)
            elsif message.request_type == WampClient::Message::Types::PUBLISH
              self._process_PUBLISH_error(message)
            elsif message.request_type == WampClient::Message::Types::REGISTER
              self._process_REGISTER_error(message)
            elsif message.request_type == WampClient::Message::Types::UNREGISTER
              self._process_UNREGISTER_error(message)
            elsif message.request_type == WampClient::Message::Types::CALL
              self._process_CALL_error(message)
            else
              # TODO: Some Error??  Not Implemented yet
            end

          # Process Messages
          else
            if message.is_a? WampClient::Message::Subscribed
              self._process_SUBSCRIBED(message)
            elsif message.is_a? WampClient::Message::Unsubscribed
              self._process_UNSUBSCRIBED(message)
            elsif message.is_a? WampClient::Message::Published
              self._process_PUBLISHED(message)
            elsif message.is_a? WampClient::Message::Event
              self._process_EVENT(message)
            elsif message.is_a? WampClient::Message::Registered
              self._process_REGISTERED(message)
            elsif message.is_a? WampClient::Message::Unregistered
              self._process_UNREGISTERED(message)
            elsif message.is_a? WampClient::Message::Invocation
              self._process_INVOCATION(message)
            elsif message.is_a? WampClient::Message::Result
              self._process_RESULT(message)
            else
              # TODO: Some Error??  Not Implemented yet
            end
          end

        end
      end

    end

    #region Subscribe Logic

    # Subscribes to a topic
    # @param topic [String] The topic to subscribe to
    # @param handler [lambda] The handler(args, kwargs, details) when an event is received
    # @param options [Hash] The options for the subscription
    # @param callback [block] The callback(subscription, error) called to signal if the subscription was a success or not
    def subscribe(topic, handler, options={}, &callback)
      unless is_open?
        raise RuntimeError, "Session must be open to call 'subscribe'"
      end

      self.class.check_uri('topic', topic)
      self.class.check_dict('options', options)
      self.class.check_nil('handler', handler, false)

      # Create a new subscribe request
      request = self._generate_id
      self._requests[:subscribe][request] = {t: topic, h: handler, o: options, c: callback}

      # Send the message
      subscribe = WampClient::Message::Subscribe.new(request, options, topic)
      self._send_message(subscribe)
    end

    # Processes the response to a subscribe request
    # @param msg [WampClient::Message::Subscribed] The response from the subscribe
    def _process_SUBSCRIBED(msg)

      # Remove the pending subscription, add it to the registered ones, and inform the caller
      s = self._requests[:subscribe].delete(msg.subscribe_request)
      if s

        details = {}
        details[:topic] = s[:t] unless details[:topic]
        details[:type] = 'subscribe'

        n_s = Subscription.new(s[:t], s[:h], s[:o], self, msg.subscription)
        self._subscriptions[msg.subscription] = n_s
        c = s[:c]
        c.call(n_s, nil, details) if c
      end

    end

    # Processes an error from a request
    # @param msg [WampClient::Message::Error] The response from the subscribe
    def _process_SUBSCRIBE_error(msg)

      # Remove the pending subscription and inform the caller of the failure
      s = self._requests[:subscribe].delete(msg.request_request)
      if s

        details = msg.details || {}
        details[:topic] = s[:t] unless details[:topic]
        details[:type] = 'subscribe'

        c = s[:c]
        c.call(nil, self._error_to_hash(msg), details) if c
      end

    end

    # Processes and event from the broker
    # @param msg [WampClient::Message::Event] An event that was published
    def _process_EVENT(msg)

      args = msg.publish_arguments || []
      kwargs = msg.publish_argumentskw || {}

      s = self._subscriptions[msg.subscribed_subscription]
      if s
        details = msg.details || {}
        details[:publication] = msg.published_publication

        h = s.handler
        h.call(args, kwargs, details) if h
      end

    end

    #endregion

    #region Unsubscribe Logic

    # Unsubscribes from a subscription
    # @param subscription [Subscription] The subscription object from when the subscription was created
    # @param callback [block] The callback(subscription, error, details) called to signal if the subscription was a success or not
    def unsubscribe(subscription, &callback)
      unless is_open?
        raise RuntimeError, "Session must be open to call 'unsubscribe'"
      end

      self.class.check_nil('subscription', subscription, false)

      # Create a new unsubscribe request
      request = self._generate_id
      self._requests[:unsubscribe][request] = { s: subscription, c: callback }

      # Send the message
      unsubscribe = WampClient::Message::Unsubscribe.new(request, subscription.id)
      self._send_message(unsubscribe)
    end

    # Processes the response to a unsubscribe request
    # @param msg [WampClient::Message::Unsubscribed] The response from the unsubscribe
    def _process_UNSUBSCRIBED(msg)

      # Remove the pending unsubscription, add it to the registered ones, and inform the caller
      s = self._requests[:unsubscribe].delete(msg.unsubscribe_request)
      if s
        n_s = s[:s]
        self._subscriptions.delete(n_s.id)

        details = {}
        details[:topic] = s[:s].topic
        details[:type] = 'unsubscribe'

        c = s[:c]
        c.call(n_s, nil, details) if c
      end

    end


    # Processes an error from a request
    # @param msg [WampClient::Message::Error] The response from the subscribe
    def _process_UNSUBSCRIBE_error(msg)

      # Remove the pending subscription and inform the caller of the failure
      s = self._requests[:unsubscribe].delete(msg.request_request)
      if s

        details = msg.details || {}
        details[:topic] = s[:s].topic unless details[:topic]
        details[:type] = 'unsubscribe'

        c = s[:c]
        c.call(nil, self._error_to_hash(msg), details) if c
      end

    end

    #endregion

    #region Publish Logic

    # Publishes and event to a topic
    # @param topic [String] The topic to publish the event to
    # @param args [Array] The arguments
    # @param kwargs [Hash] The keyword arguments
    # @param options [Hash] The options for the publish
    # @param callback [block] The callback(publish, error, details) called to signal if the publish was a success or not
    def publish(topic, args=nil, kwargs=nil, options={}, &callback)
      unless is_open?
        raise RuntimeError, "Session must be open to call 'publish'"
      end

      self.class.check_uri('topic', topic)
      self.class.check_dict('options', options)
      self.class.check_list('args', args, true)
      self.class.check_dict('kwargs', kwargs, true)

      # Create a new publish request
      request = self._generate_id
      self._requests[:publish][request] = {t: topic, a: args, k: kwargs, o: options, c: callback} if options[:acknowledge]

      # Send the message
      publish = WampClient::Message::Publish.new(request, options, topic, args, kwargs)
      self._send_message(publish)
    end

    # Processes the response to a publish request
    # @param msg [WampClient::Message::Published] The response from the subscribe
    def _process_PUBLISHED(msg)

      # Remove the pending publish and alert the callback
      p = self._requests[:publish].delete(msg.publish_request)
      if p

        details = {}
        details[:topic] = p[:t]
        details[:type] = 'publish'
        details[:publication] = msg.publication

        c = p[:c]
        c.call(p, nil, details) if c
      end

    end

    # Processes an error from a publish request
    # @param msg [WampClient::Message::Error] The response from the subscribe
    def _process_PUBLISH_error(msg)

      # Remove the pending publish and inform the caller of the failure
      s = self._requests[:publish].delete(msg.request_request)
      if s

        details = msg.details || {}
        details[:topic] = s[:t] unless details[:topic]
        details[:type] = 'publish'

        c = s[:c]
        c.call(nil, self._error_to_hash(msg), details) if c
      end

    end

    #endregion

    #region Register Logic

    # Register to a procedure
    # @param procedure [String] The procedure to register for
    # @param handler [lambda] The handler(args, kwargs, details) when a invocation is received
    # @param options [Hash] The options for the registration
    # @param callback [block] The callback(registration, error, details) called to signal if the registration was a success or not
    def register(procedure, handler, options={}, &callback)
      unless is_open?
        raise RuntimeError, "Session must be open to call 'register'"
      end

      self.class.check_uri('procedure', procedure)
      self.class.check_dict('options', options)
      self.class.check_nil('handler', handler, false)

      # Create a new registration request
      request = self._generate_id
      self._requests[:register][request] = {p: procedure, h: handler, o: options, c: callback}

      # Send the message
      register = WampClient::Message::Register.new(request, options, procedure)
      self._send_message(register)
    end

    # Processes the response to a register request
    # @param msg [WampClient::Message::Registered] The response from the subscribe
    def _process_REGISTERED(msg)

      # Remove the pending subscription, add it to the registered ones, and inform the caller
      r = self._requests[:register].delete(msg.register_request)
      if r
        n_r = Registration.new(r[:p], r[:h], r[:o], self, msg.registration)
        self._registrations[msg.registration] = n_r

        details = {}
        details[:procedure] = r[:p]
        details[:type] = 'register'

        c = r[:c]
        c.call(n_r, nil, details) if c
      end

    end

    # Processes an error from a request
    # @param msg [WampClient::Message::Error] The response from the register
    def _process_REGISTER_error(msg)

      # Remove the pending registration and inform the caller of the failure
      r = self._requests[:register].delete(msg.request_request)
      if r

        details = msg.details || {}
        details[:procedure] = r[:p] unless details[:procedure]
        details[:type] = 'register'

        c = r[:c]
        c.call(nil, self._error_to_hash(msg), details) if c
      end

    end

    # Processes and event from the broker
    # @param msg [WampClient::Message::Invocation] An procedure that was called
    def _process_INVOCATION(msg)

      request = msg.request
      args = msg.call_arguments || []
      kwargs = msg.call_argumentskw || {}

      details = msg.details || {}
      details[:request] = request

      r = self._registrations[msg.registered_registration]
      if r
        h = r.handler
        if h
          begin
            value = h.call(args, kwargs, details)

            def send_error(request, error)
              if error.nil?
                error = CallError.new('wamp.error.runtime')
              elsif not error.is_a?(CallError)
                error = CallError.new('wamp.error.runtime', [error.to_s])
              end

              error_msg = WampClient::Message::Error.new(WampClient::Message::Types::INVOCATION, request, {}, error.error, error.args, error.kwargs)
              self._send_message(error_msg)
            end

            def send_result(request, result, options={})
              if result.nil?
                result = CallResult.new
              elsif result.is_a?(CallError)
                # Do nothing
              elsif not result.is_a?(CallResult)
                result = CallResult.new([result])
              end

              if result.is_a?(CallError)
                send_error(request, result)
              else
                yield_msg = WampClient::Message::Yield.new(request, options, result.args, result.kwargs)
                self._send_message(yield_msg)
              end
            end

            # If a defer was returned, handle accordingly
            if value.is_a? WampClient::Defer::CallDefer
              value.request = request

              # Store the defer
              self._defers[request] = value

              # On complete, send the result
              value.on_complete do |defer, result|
                send_result(defer.request, result)
                self._defers.delete(defer.request)
              end

              # On error, send the error
              value.on_error do |defer, error|
                send_error(defer.request, error)
                self._defers.delete(defer.request)
              end

              # For progressive, return the progress
              if value.is_a? WampClient::Defer::ProgressiveCallDefer
                value.on_progress do |defer, result|
                  send_result(defer.request, result, {progress: true})
                end
              end

            # Else it was a normal response
            else
              send_result(request, value)
            end

          rescue Exception => error
            send_error(request, error)
          end

        end
      end
    end

    #endregion

    #region Unregister Logic

    # Unregisters from a procedure
    # @param registration [Registration] The registration object from when the registration was created
    # @param callback [block] The callback(registration, error, details) called to signal if the unregistration was a success or not
    def unregister(registration, &callback)
      unless is_open?
        raise RuntimeError, "Session must be open to call 'unregister'"
      end

      self.class.check_nil('registration', registration, false)

      # Create a new unsubscribe request
      request = self._generate_id
      self._requests[:unregister][request] = { r: registration, c: callback }

      # Send the message
      unregister = WampClient::Message::Unregister.new(request, registration.id)
      self._send_message(unregister)
    end

    # Processes the response to a unregister request
    # @param msg [WampClient::Message::Unregistered] The response from the unsubscribe
    def _process_UNREGISTERED(msg)

      # Remove the pending unregistration, add it to the registered ones, and inform the caller
      r = self._requests[:unregister].delete(msg.unregister_request)
      if r
        r_s = r[:r]
        self._registrations.delete(r_s.id)

        details = {}
        details[:procedure] = r_s.procedure
        details[:type] = 'unregister'

        c = r[:c]
        c.call(r_s, nil, details) if c
      end

    end

    # Processes an error from a request
    # @param msg [WampClient::Message::Error] The response from the subscribe
    def _process_UNREGISTER_error(msg)

      # Remove the pending subscription and inform the caller of the failure
      r = self._requests[:unregister].delete(msg.request_request)
      if r

        details = msg.details || {}
        details[:procedure] = r[:r].procedure unless details[:procedure]
        details[:type] = 'unregister'

        c = r[:c]
        c.call(nil, self._error_to_hash(msg), details) if c
      end

    end

    #endregion

    #region Call Logic

    # Publishes and event to a topic
    # @param procedure [String] The procedure to invoke
    # @param args [Array] The arguments
    # @param kwargs [Hash] The keyword arguments
    # @param options [Hash] The options for the call
    # @param callback [block] The callback(result, error, details) called to signal if the call was a success or not
    def call(procedure, args=nil, kwargs=nil, options={}, &callback)
      unless is_open?
        raise RuntimeError, "Session must be open to call 'call'"
      end

      self.class.check_uri('procedure', procedure)
      self.class.check_dict('options', options)
      self.class.check_list('args', args, true)
      self.class.check_dict('kwargs', kwargs, true)

      # Create a new call request
      request = self._generate_id
      self._requests[:call][request] = {p: procedure, a: args, k: kwargs, o: options, c: callback}

      # Send the message
      call = WampClient::Message::Call.new(request, options, procedure, args, kwargs)
      self._send_message(call)
    end

    # Processes the response to a publish request
    # @param msg [WampClient::Message::Result] The response from the call
    def _process_RESULT(msg)

      details = msg.details || {}

      call = self._requests[:call][msg.call_request]

      # Don't remove if progress is true and the options had receive_progress true
      self._requests[:call].delete(msg.call_request) unless (details[:progress] and (call and call[:o][:receive_progress]))

      if call
        details[:procedure] = call[:p] unless details[:procedure]
        details[:type] = 'call'

        c = call[:c]
        c.call(CallResult.new(msg.yield_arguments, msg.yield_argumentskw), nil, details) if c
      end

    end

    # Processes an error from a call request
    # @param msg [WampClient::Message::Error] The response from the call
    def _process_CALL_error(msg)

      # Remove the pending publish and inform the caller of the failure
      call = self._requests[:call].delete(msg.request_request)
      if call

        details = msg.details || {}
        details[:procedure] = call[:p] unless details[:procedure]
        details[:type] = 'call'

        c = call[:c]
        c.call(nil, self._error_to_hash(msg), details) if c
      end

    end

    #endregion

  end
end