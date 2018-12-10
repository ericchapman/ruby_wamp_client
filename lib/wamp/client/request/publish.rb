require_relative "base"
require "wamp/client/message"

module Wamp
  module Client
    module Request

      class Message::Published
        def request_id
          self.publish_request
        end
      end

      class Publish < Base

        def create_request(request_id, topic, args=nil, kwargs=nil, options={}, &callback)

          # Create the lookup
          lookup = options[:acknowledge] ? {t: topic, a: args, k: kwargs, o: options, c: callback} : nil

          # Create the message
          message = Message::Publish.new(request_id, options, topic, args, kwargs)

          # Return
          [lookup, message]
        end

        def process_success(message, lookup)
          if lookup
            # Get the params
            topic = lookup[:t]
            args = lookup[:a]
            kwargs = lookup[:k]
            options = lookup[:o]
            callback = lookup[:c]

            # Create the details
            details = {}
            details[:topic] = topic
            details[:type] = 'publish'
            details[:publication] = message.publication

            # Return the values
            [callback, { args: args, kwargs: kwargs, options: options }, details]
          else
            [nil, nil, nil]
          end
        end

        def process_error(message, lookup)
          if lookup
            # Get the params
            topic = lookup[:t]
            callback = lookup[:c]

            # Create the details
            details = message.details || {}
            details[:topic] = topic unless details[:topic]
            details[:type] = 'publish'

            # Return the values
            [callback, details]
          else
            [nil, nil]
          end
        end

      end

    end
  end
end
