=begin

Copyright (c) 2018 Eric Chapman

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

require 'wamp/client/transport/base'
require 'wamp/client/message'
require 'wamp/client/check'
require 'wamp/client/version'
require 'wamp/client/response'
require 'wamp/client/request/subscribe'
require 'wamp/client/request/unsubscribe'
require 'wamp/client/request/register'
require 'wamp/client/request/unregister'
require 'wamp/client/request/publish'

module Wamp
  module Client
    WAMP_FEATURES = {
        caller: {
            features: {
                caller_identification: true,
                call_timeout: true,
                call_canceling: true,
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
                call_canceling: true,
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

    METHOD_LOOKUP = {
        # Error Responses
        Message::Types::SUBSCRIBE => -> s, m { s.request_subscribe.error(m) },
        Message::Types::UNSUBSCRIBE => -> s, m { s.request_unsubscribe.error(m) },
        Message::Types::PUBLISH => -> s, m { s.request_publish.error(m) },
        Message::Types::REGISTER => -> s, m { s.request_register.error(m) },
        Message::Types::UNREGISTER => -> s, m { s.request_unregister.error(m) },
        Message::Types::CALL => -> s, m { s._process_CALL_error(m) },

        # Result Responses
        Message::Types::SUBSCRIBED => -> s, m { s.request_subscribe.success(m) },
        Message::Types::UNSUBSCRIBED => -> s, m { s.request_unsubscribe.success(m) },
        Message::Types::PUBLISHED => -> s, m { s.request_publish.success(m) },
        Message::Types::EVENT => -> s, m { s._process_EVENT(m) },
        Message::Types::REGISTERED => -> s, m { s.request_register.success(m) },
        Message::Types::UNREGISTERED => -> s, m { s.request_unregister.success(m) },
        Message::Types::INVOCATION => -> s, m { s._process_INVOCATION(m) },
        Message::Types::INTERRUPT => -> s, m { s._process_INTERRUPT(m) },
        Message::Types::RESULT => -> s, m { s._process_RESULT(m) },
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

    class Registration
      attr_accessor :procedure, :handler, :i_handler, :options, :session, :id

      def initialize(procedure, handler, options, i_handler, session, id)
        self.procedure = procedure
        self.handler = handler
        self.options = options
        self.i_handler = i_handler
        self.session = session
        self.id = id
      end

      def unregister
        self.session.unregister(self)
      end

    end

    class Call
      attr_accessor :session, :id

      def initialize(session, id)
        self.session = session
        self.id = id
      end

      def cancel(mode='skip')
        self.session.cancel(self, mode)
      end

    end

    class Session
      include Check

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

      # Simple setter for callbacks
      def on(event, &callback)
        case event
        when :join
          self.on_join(&callback)
        when :challenge
          self.on_challenge(&callback)
        when :leave
          self.on_leave(&callback)
        else
          raise RuntimeError, "Unknown on(event) '#{event}'"
        end
      end

      attr_accessor :id, :realm, :transport, :options

      # Private attributes
      attr_accessor :_goodbye_sent, :_requests, :_subscriptions, :_registrations, :_defers

      attr_reader :request_subscribe, :request_unsubscribe,
                  :request_register, :request_unregister,
                  :request_publish
      # Constructor
      # @param transport [Transport::Base] The transport that the session will use
      # @param options [Hash] Hash containing different session options
      # @option options [String] :authid The authentication ID
      # @option options [Array] :authmethods Different auth methods that this client supports
      def initialize(transport, options={})

        # Parameters
        self.id = nil
        self.realm = nil
        self.options = options || {}

        # Outstanding Requests
        self._requests = {
            publish: {},
            call: {},
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
        @on_challenge = nil

        send_message_lambda = -> message {
          self._send_message(message)
        }

        @request_subscribe = Request::Subscribe.new(self, send_message_lambda) do |s_id, s|
          self._subscriptions[s_id] = s
        end

        @request_unsubscribe = Request::Unsubscribe.new(self, send_message_lambda) do |s_id|
          self._subscriptions.delete(s_id)
        end

        @request_register = Request::Register.new(self, send_message_lambda) do |r_id, r|
          self._registrations[r_id] = r
        end

        @request_unregister = Request::Unregister.new(self, send_message_lambda) do |r_id|
          self._registrations.delete(r_id)
        end

        @request_publish = Request::Publish.new(self, send_message_lambda) do |r_id|
        end

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
        details[:agent] = "Ruby-Wamp::Client-#{VERSION}"
        details[:authid] = self.options[:authid] if self.options[:authid]
        details[:authmethods] = self.options[:authmethods] if self.options[:authmethods]

        # Send Hello message
        hello = Message::Hello.new(realm, details)
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
        goodbye = Message::Goodbye.new(details, reason)
        self._send_message(goodbye)
        self._goodbye_sent = true
      end

      # Generates an ID according to the specification (Section 5.1.2)
      def _generate_id
        rand(0..9007199254740992)
      end

      # Sends a message
      # @param msg [Message::Base]
      def _send_message(msg)
        # Log the message
        logger.debug("#{self.class.name} TX: #{msg.to_s}")

        # Send it to the transport
        self.transport.send_message(msg.payload)
      end

      # Processes received messages
      # @param msg [Array]
      def _receive_message(msg)

        # Print the raw message
        logger.debug("#{self.class.name} RX(raw): #{msg.to_s}")

        # Parse the WAMP message
        message = Message.parse(msg)

        # Print the parsed WAMP message
        logger.debug("#{self.class.name} RX: #{message.to_s}")

        # WAMP Session is not open
        if self.id.nil?

          # Parse the welcome message
          if message.is_a? Message::Welcome
            # Get the session ID
            self.id = message.session

            # Log joining the session
            logger.info("#{self.class.name} joined session with realm '#{message.details[:realm]}'")

            # Call the callback if it is set
            @on_join.call(message.details) unless @on_join.nil?
          elsif message.is_a? Message::Challenge
            # Log challenge received
            logger.debug("#{self.class.name} auth challenge '#{message.authmethod}', extra: #{message.extra}")

            # Call the callback if set
            if @on_challenge
              signature, extra = @on_challenge.call(message.authmethod, message.extra)
            else
              signature = nil
              extra = nil
            end

            signature ||= ''
            extra ||= {}

            authenticate = Message::Authenticate.new(signature, extra)
            self._send_message(authenticate)

          elsif message.is_a? Message::Abort
            # Log leaving the session
            logger.info("#{self.class.name} left session '#{message.reason}'")

            # Call the callback if it is set
            @on_leave.call(message.reason, message.details) unless @on_leave.nil?
          end

          # Wamp Session is open
        else

          # If goodbye, close the session
          if message.is_a? Message::Goodbye

            # If we didn't send the goodbye, respond
            unless self._goodbye_sent
              goodbye = Message::Goodbye.new({}, 'wamp.error.goodbye_and_out')
              self._send_message(goodbye)
            end

            # Close out session
            self.id = nil
            self.realm = nil
            self._goodbye_sent = false
            @on_leave.call(message.reason, message.details) unless @on_leave.nil?

          else

            # Else this is a normal message.  Lookup the handler and call it
            type = message.is_a?(Message::Error) ? message.request_type : message.class.type
            method = METHOD_LOOKUP[type]

            if method != nil
              method.call(self, message)
            else
              logger.error("#{self.class.name} unknown message type '#{type}'")
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

        # Make the request
        self.request_subscribe.request(topic, handler, options, &callback)
      end

      # Processes and event from the broker
      # @param msg [Message::Event] An event that was published
      def _process_EVENT(msg)

        args = msg.publish_arguments || []
        kwargs = msg.publish_argumentskw || {}

        s = self._subscriptions[msg.subscribed_subscription]
        if s
          details = msg.details || {}
          details[:publication] = msg.published_publication
          details[:session] = self

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

        # Make the request
        self.request_unsubscribe.request(subscription, &callback)
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

        # Make the request
        self.request_publish.request(topic, args, kwargs, options, &callback)
      end
      #endregion

      #region Register Logic

      # Register to a procedure
      # @param procedure [String] The procedure to register for
      # @param handler [lambda] The handler(args, kwargs, details) when an invocation is received
      # @param options [Hash, nil] The options for the registration
      # @param interrupt [lambda] The handler(request, mode) when an interrupt is received
      # @param callback [block] The callback(registration, error, details) called to signal if the registration was a success or not
      def register(procedure, handler, options=nil, interrupt=nil, &callback)
        unless is_open?
          raise RuntimeError, "Session must be open to call 'register'"
        end

        options ||= {}

        self.class.check_uri('procedure', procedure)
        self.class.check_nil('handler', handler, false)

        # Make the request
        self.request_register.request(procedure, handler, options, interrupt, &callback)
      end

      # Sends an error back to the caller
      # @param request[Integer] - The request ID
      # @param error
      def _send_INVOCATION_error(request, error, check_defer=false)
        # Make sure the response is an error
        error = Response::CallError.ensure(error)

        # Create error message
        error_msg = Message::Error.new(
            Message::Types::INVOCATION, request, {}, error.error, error.args, error.kwargs)

        # Send it
        self._send_message(error_msg)
      end

      # Sends a result for the invocation
      # @param request [Integer] - The id of the request
      # @param result [CallError, CallResult, anything] - If it is a CallError, the error will be returned
      # @param options [Hash] - The options to be sent with the yield
      def yield(request, result, options={}, check_defer=false)
        # Prevent responses for defers that have already completed or had an error
        if check_defer and not self._defers[request]
          return
        end

        # Wrap the result accordingly
        result = Response::CallResult.ensure(result, allow_error: true)

        # Send either the error or the response
        if result.is_a?(Response::CallError)
          self._send_INVOCATION_error(request, result)
        else
          yield_msg = Message::Yield.new(request, options, result.args, result.kwargs)
          self._send_message(yield_msg)
        end

        # Remove the defer if this was not a progress update
        if check_defer and options[:progress] == nil
          self._defers.delete(request)
        end
      end


      # Processes and event from the broker
      # @param msg [Message::Invocation] An procedure that was called
      def _process_INVOCATION(msg)

        request = msg.request
        args = msg.call_arguments || []
        kwargs = msg.call_argumentskw || {}

        details = msg.details || {}
        details[:request] = request
        details[:session] = self

        r = self._registrations[msg.registered_registration]
        if r
          h = r.handler
          if h
            # Use the invoke wrapper to process the result
            value = Response.invoke_handler do
              h.call(args, kwargs, details)
            end

            # If a defer was returned, handle accordingly
            if value.is_a? Response::CallDefer
              value.request = request
              value.registration = msg.registered_registration

              # Store the defer
              self._defers[request] = value

              # On complete, send the result
              value.on_complete do |defer, result|
                result = Response::CallResult.ensure(result)
                self.yield(defer.request, result, {}, true)
              end

              # On error, send the error
              value.on_error do |defer, error|
                error = Response::CallError.ensure(error)
                self.yield(defer.request, error, {}, true)
              end

              # For progressive, return the progress
              if value.is_a? Response::ProgressiveCallDefer
                value.on_progress do |defer, result|
                  result = Response::CallResult.ensure(result)
                  self.yield(defer.request, result, {progress: true}, true)
                end
              end

              # Else it was a normal response
            else
              self.yield(request, value)
            end
          end
        end
      end

      # Processes the interrupt
      # @param msg [Message::Interrupt] An interrupt to a procedure
      def _process_INTERRUPT(msg)

        request = msg.invocation_request
        mode = msg.options[:mode]

        defer = self._defers[request]
        if defer
          r = self._registrations[defer.registration]
          if r
            # If it exists, call the interrupt handler to inform it of the interrupt
            i = r.i_handler
            error = nil
            if i
              error = Response.invoke_handler error: true do
                i.call(request, mode)
              end

              # Add a default reason if none was supplied
              error.args << "interrupt" if error.args.count == 0
            end

            # Send the error back to the client
            self._send_INVOCATION_error(request, error, true)
          end

          # Delete the defer
          self._defers.delete(request)
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

        # Make the request
        self.request_unregister.request(registration, &callback)
      end
      #endregion

      #region Call Logic

      # Publishes and event to a topic
      # @param procedure [String] The procedure to invoke
      # @param args [Array] The arguments
      # @param kwargs [Hash] The keyword arguments
      # @param options [Hash] The options for the call
      # @param callback [block] The callback(result, error, details) called to signal if the call was a success or not
      # @return [Call] An object representing the call
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
        msg = Message::Call.new(request, options, procedure, args, kwargs)
        self._send_message(msg)

        call = Call.new(self, request)

        # Timeout Logic
        if options[:timeout] and options[:timeout] > 0
          self.transport.add_timer(options[:timeout]) do
            # Once the timer expires, if the call hasn't completed, cancel it
            if self._requests[:call][call.id]
              call.cancel
            end
          end
        end

        call
      end

      # Processes the response to a publish request
      # @param msg [Message::Result] The response from the call
      def _process_RESULT(msg)

        details = msg.details || {}

        call = self._requests[:call][msg.call_request]

        # Don't remove if progress is true and the options had receive_progress true
        self._requests[:call].delete(msg.call_request) unless (details[:progress] and (call and call[:o][:receive_progress]))

        if call
          details[:procedure] = call[:p] unless details[:procedure]
          details[:type] = 'call'
          details[:session] = self

          c = call[:c]
          result = Response::CallResult.from_yield_message(msg)
          c.call(result.to_hash, nil, details) if c
        end

      end

      # Processes an error from a call request
      # @param msg [Message::Error] The response from the call
      def _process_CALL_error(msg)

        # Remove the pending publish and inform the caller of the failure
        call = self._requests[:call].delete(msg.request_request)
        if call

          details = msg.details || {}
          details[:procedure] = call[:p] unless details[:procedure]
          details[:type] = 'call'
          details[:session] = self

          c = call[:c]
          error = Response::CallError.from_message(msg)
          c.call(nil, error.to_hash, details) if c
        end

      end

      #endregion

      #region Cancel Logic

      # Cancels a call
      # @param call [Call] - The call object
      # @param mode [String] - The mode of the skip.  Options are 'skip', 'kill', 'killnowait'
      def cancel(call, mode='skip')
        unless is_open?
          raise RuntimeError, "Session must be open to call 'cancel'"
        end

        self.class.check_nil('call', call, false)

        # Send the message
        cancel = Message::Cancel.new(call.id, { mode: mode })
        self._send_message(cancel)
      end

      #endregion

      private

      # Returns the logger
      #
      def logger
        Wamp::Client.logger
      end

    end
  end
end