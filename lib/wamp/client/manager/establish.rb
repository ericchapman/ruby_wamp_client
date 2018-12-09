require_relative "base"

module Wamp
  module Client
    module Manager

      class Establish < Base
        attr_accessor :goodbye_sent, :id, :realm

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

        # Constructor
        #
        def initialize(session, send_message)
          super session, send_message
          self.goodbye_sent = false

          # Initialize the session
          self.id = nil
          self.realm = nil
        end

        # Returns true if the session is open
        #
        def is_open?
          self.id != nil
        end

        # Will attempt to join a router
        #
        def join(realm)

          # Set the realm
          self.realm = realm

          # Create the details
          details = {}
          details[:roles] = WAMP_FEATURES
          details[:agent] = "Ruby-Wamp::Client-#{VERSION}"
          details[:authid] = self.session.options[:authid] if self.session.options[:authid]
          details[:authmethods] = self.session.options[:authmethods] if self.session.options[:authmethods]

          # Create the message
          hello = Message::Hello.new(realm, details)

          # Send it
          send_message(hello)
        end

        # Leave the session
        def leave(reason, message)

          # Create the details
          details = {}
          details[:message] = message

          # Create the goobdbye message
          goodbye = Message::Goodbye.new(details, reason)

          # Send it
          send_message(goodbye)

          # Send it
          self.goodbye_sent = true
        end

        # Handles the goodbye message
        #
        def goodbye(message)
          # If we didn't send the goodbye, respond
          unless self.goodbye_sent
            goodbye = Message::Goodbye.new({}, 'wamp.error.goodbye_and_out')
            send_message(goodbye)
          end

          # Close out session
          self.id = nil
          self.realm = nil
          self.goodbye_sent = false

          # Trigger leave event
          trigger :leave, message.reason, message.details
        end

        # Handles the welcome message
        #
        def welcome(message)
          # Get the session ID
          self.id = message.session

          # Log the message
          logger.info("#{self.session.class.name} joined session with realm '#{message.details[:realm]}'")

          # Trigger join event
          trigger :join, message.details
        end

        # Handles a challenge message
        #
        def challenge(message)
          # Log challenge received
          logger.debug("#{self.session.class.name} auth challenge '#{message.authmethod}', extra: #{message.extra}")

          # Call the callback if set
          signature, extra = trigger :challenge, message.authmethod, message.extra

          # Set with initial values
          signature ||= ''
          extra ||= {}

          # Create the message
          authenticate = Message::Authenticate.new(signature, extra)

          # Send it
          send_message(authenticate)
        end

        # Handles an abort message
        #
        def abort(message)
          # Log leaving the session
          logger.info("#{self.session.class.name} left session '#{message.reason}'")

          # Trigger the leave event
          trigger :leave, message.reason, message.details
        end

      end

    end
  end
end
