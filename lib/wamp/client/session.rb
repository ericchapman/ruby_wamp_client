require 'wamp/client/transport/base'
require 'wamp/client/message'
require 'wamp/client/check'
require 'wamp/client/version'
require 'wamp/client/event'
require 'wamp/client/request/require'
require 'wamp/client/manager/require'

module Wamp
  module Client

    CLOSED_SESSION_METHOD_LOOKUP = {
        Message::Types::WELCOME => -> s, m { s.establish.welcome(m) },
        Message::Types::CHALLENGE => -> s, m { s.establish.challenge(m) },
        Message::Types::ABORT => -> s, m { s.establish.abort(m) },
    }

    OPEN_SESSION_METHOD_LOOKUP = {
        # Establish Response
        Message::Types::GOODBYE => -> s, m { s.establish.goodbye(m) },

        # Error Responses
        Message::Types::SUBSCRIBE => -> s, m { s.request[:subscribe].error(m) },
        Message::Types::UNSUBSCRIBE => -> s, m { s.request[:unsubscribe].error(m) },
        Message::Types::PUBLISH => -> s, m { s.request[:publish].error(m) },
        Message::Types::REGISTER => -> s, m { s.request[:register].error(m) },
        Message::Types::UNREGISTER => -> s, m { s.request[:unregister].error(m) },
        Message::Types::CALL => -> s, m { s.request[:call].error(m) },

        # Result Responses
        Message::Types::SUBSCRIBED => -> s, m { s.request[:subscribe].success(m) },
        Message::Types::UNSUBSCRIBED => -> s, m { s.request[:unsubscribe].success(m) },
        Message::Types::PUBLISHED => -> s, m { s.request[:publish].success(m) },
        Message::Types::EVENT => -> s, m { s.subscription.event(m) },
        Message::Types::REGISTERED => -> s, m { s.request[:register].success(m) },
        Message::Types::UNREGISTERED => -> s, m { s.request[:unregister].success(m) },
        Message::Types::INVOCATION => -> s, m { s.registration.invoke(m) },
        Message::Types::INTERRUPT => -> s, m { s.registration.interrupt(m) },
        Message::Types::RESULT => -> s, m { s.request[:call].success(m) },
    }

    class Session
      include Check
      include Event

      attr_accessor :transport, :options, :request, :callback, :subscription, :registration, :establish

      create_event [:join, :challenge, :leave]

      # Constructor
      # @param transport [Transport::Base] The transport that the session will use
      # @param options [Hash] Hash containing different session options
      # @option options [String] :authid The authentication ID
      # @option options [Array] :authmethods Different auth methods that this client supports
      def initialize(transport, options={})

        # Parameters
        self.options = options || {}

        # Create the send message lambda for the request objects
        send_message_lambda = -> m { send_message(m) }

        # Outstanding Requests
        self.request = {
            publish: Request::Publish.new(self, send_message_lambda),
            subscribe: Request::Subscribe.new(self, send_message_lambda) { |s_id, s| self.subscription.add(s_id, s) },
            unsubscribe: Request::Unsubscribe.new(self, send_message_lambda) { |s_id| self.subscription.remove(s_id) },
            call: Request::Call.new(self, send_message_lambda),
            register: Request::Register.new(self, send_message_lambda) { |r_id, r| self.registration.add(r_id, r) },
            unregister: Request::Unregister.new(self, send_message_lambda) { |r_id| self.registration.remove(r_id) },
        }

        # Init Subs and Regs in place
        self.subscription = Manager::Subscription.new(self, send_message_lambda)
        self.registration = Manager::Registration.new(self, send_message_lambda)
        self.establish = Manager::Establish.new(self, send_message_lambda)

        # Setup session callbacks
        self.callback = {}

        # Setup Transport
        self.transport = transport
        self.transport.on :message do |msg|
          receive_message(msg)
        end

      end

      # Returns 'true' if the session is open
      #
      def is_open?
        self.establish.is_open?
      end

      # Returns the ID of the session
      #
      def id
        self.establish.id
      end

      # Returns the realm of the session
      #
      def realm
        self.establish.realm
      end

      # Joins the WAMP Router
      #
      # @param realm [String] The name of the realm
      def join(realm)
        check_closed

        # Check params
        self.class.check_uri('realm', realm)

        # Attempt to join
        self.establish.join(realm)
      end

      # Leaves the WAMP Router
      #
      # @param reason [String] URI signalling the reason for leaving
      def leave(reason='wamp.close.normal', message='user initiated')
        check_open

        # Check params
        self.class.check_uri('reason', reason, true)
        self.class.check_string('message', message, true)

        # Leave the session
        self.establish.leave(reason, message)
      end


      # Subscribes to a topic
      #
      # @param topic [String] The topic to subscribe to
      # @param handler [lambda] The handler(args, kwargs, details) when an event is received
      # @param options [Hash] The options for the subscription
      # @param callback [block] The callback(subscription, error) called to signal if the subscription was a success or not
      def subscribe(topic, handler, options={}, &callback)
        check_open

        # Check params
        self.class.check_uri('topic', topic)
        self.class.check_dict('options', options)
        self.class.check_nil('handler', handler, false)

        # Make the request
        make_request(:subscribe, :request, topic, handler, options, &callback)
      end

      # Unsubscribes from a subscription
      #
      # @param subscription [Subscription] The subscription object from when the subscription was created
      # @param callback [block] The callback(subscription, error, details) called to signal if the subscription was a success or not
      def unsubscribe(subscription, &callback)
        check_open

        # Check params
        self.class.check_nil('subscription', subscription, false)

        # Make the request
        make_request(:unsubscribe, :request, subscription, &callback)
      end

      # Publishes and event to a topic
      #
      # @param topic [String] The topic to publish the event to
      # @param args [Array] The arguments
      # @param kwargs [Hash] The keyword arguments
      # @param options [Hash] The options for the publish
      # @param callback [block] The callback(publish, error, details) called to signal if the publish was a success or not
      def publish(topic, args=nil, kwargs=nil, options={}, &callback)
        check_open

        # Check params
        self.class.check_uri('topic', topic)
        self.class.check_dict('options', options)
        self.class.check_list('args', args, true)
        self.class.check_dict('kwargs', kwargs, true)

        # Make the request
        make_request(:publish, :request, topic, args, kwargs, options, &callback)
      end

      # Register to a procedure
      #
      # @param procedure [String] The procedure to register for
      # @param handler [lambda] The handler(args, kwargs, details) when an invocation is received
      # @param options [Hash, nil] The options for the registration
      # @param interrupt [lambda] The handler(request, mode) when an interrupt is received
      # @param callback [block] The callback(registration, error, details) called to signal if the registration was a success or not
      def register(procedure, handler, options=nil, interrupt=nil, &callback)
        check_open

        options ||= {}

        # Check params
        self.class.check_uri('procedure', procedure)
        self.class.check_nil('handler', handler, false)

        # Make the request
        make_request(:register, :request, procedure, handler, options, interrupt, &callback)
      end

      # Sends a result for the invocation
      #
      # @param request [Integer] - The id of the request
      # @param result [CallError, CallResult, anything] - If it is a CallError, the error will be returned
      # @param options [Hash] - The options to be sent with the yield
      def yield(request, result, options={}, check_defer=false)
        check_open

        # Call the registration yield method
        self.registration.yield(request, result, options, check_defer)
      end

      # Unregisters from a procedure
      #
      # @param registration [Registration] The registration object from when the registration was created
      # @param callback [block] The callback(registration, error, details) called to signal if the unregistration was a success or not
      def unregister(registration, &callback)
        check_open

        # Check params
        self.class.check_nil('registration', registration, false)

        # Make the request
        make_request(:unregister, :request, registration, &callback)
      end

      # Publishes and event to a topic
      #
      # @param procedure [String] The procedure to invoke
      # @param args [Array] The arguments
      # @param kwargs [Hash] The keyword arguments
      # @param options [Hash] The options for the call
      # @param callback [block] The callback(result, error, details) called to signal if the call was a success or not
      # @return [Call] An object representing the call
      def call(procedure, args=nil, kwargs=nil, options={}, &callback)
        check_open

        # Check params
        self.class.check_uri('procedure', procedure)
        self.class.check_dict('options', options)
        self.class.check_list('args', args, true)
        self.class.check_dict('kwargs', kwargs, true)

        # Make the request
        request_id = make_request(:call, :request, procedure, args, kwargs, options, &callback)

        # Create the call object
        call = Request::CallObject.new(self, request_id)

        # Timeout Logic
        if options[:timeout] and options[:timeout] > 0
          # Once the timer expires, if the call hasn't completed, cancel it
          self.transport.add_timer(options[:timeout]) do
            call.cancel
          end
        end

        call
      end

      # Cancels a call
      #
      # @param call [Call] - The call object
      # @param mode [String] - The mode of the skip.  Options are 'skip', 'kill', 'killnowait'
      def cancel(call, mode='skip')
        check_open

        # Check params
        self.class.check_nil('call', call, false)

        # Cancel the request
        make_request(:call, :cancel, call.id, mode)
      end

      private

      def check_closed
        if is_open?
          raise RuntimeError, "session must be closed to call this method"
        end
      end

      def check_open
        unless is_open?
          raise RuntimeError, "session must be open to call this method"
        end
      end

      def make_request(name, method, *args, &callback)
        self.request[name].send(method, *args, &callback)
      end

      def logger
        Wamp::Client.logger
      end

      def send_message(msg)

        # Log the message
        logger.debug("#{self.class.name} TX: #{msg.to_s}")

        # Send it to the transport
        self.transport.send_message(msg.payload)
      end

      def receive_message(msg)

        # Print the raw message
        logger.debug("#{self.class.name} RX(raw): #{msg.to_s}")

        # Parse the WAMP message
        message = Message.parse(msg)

        # Print the parsed WAMP message
        logger.debug("#{self.class.name} RX: #{message.to_s}")

        # Get the lookup based on the state of the session
        lookup = self.is_open? ? OPEN_SESSION_METHOD_LOOKUP : CLOSED_SESSION_METHOD_LOOKUP

        # Get the type of message
        type = message.is_a?(Message::Error) ? message.request_type : message.class.type

        # Get the handler
        handler = lookup[type]

        # Execute the handler
        if handler != nil
          # Catch any standard exception and log it
          begin
            handler.call(self, message)
          rescue StandardError => e
            logger.error("#{self.class.name} - #{e.message}")
            e.backtrace.each { |line| logger.error("   #{line}") }
          end
        else
          logger.error("#{self.class.name} unknown message type '#{type}'")
        end
      end

    end
  end
end