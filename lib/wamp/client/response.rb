require "wamp/client/event"

module Wamp
  module Client
    module Response
      DEFAULT_ERROR = "wamp.error.runtime"

      # This method wraps the handling of the result from a procedure.
      # or interrupt.  It is intended to standardize the processing
      #
      # @param [Bool] - "true" is we want an error out of this
      # @return [CallResult, CallError, CallDefer] - A response object
      def self.invoke_handler(error: false, &callback)
        logger = Wamp::Client.logger

        # Invoke the request
        begin
          result = callback.call
        rescue CallError => e
          result = e
        rescue StandardError => e
          logger.error("Wamp::Client::Response - #{e.message}")
          e.backtrace.each { |line| logger.error("   #{line}") }
          result = CallError.new(DEFAULT_ERROR, [e.message], { backtrace: e.backtrace })
        end

        # Ensure an expected class is returned
        if error
          CallError.ensure(result)
        else
          CallResult.ensure(result, allow_error: true, allow_defer: true)
        end
      end

      # This method will instantiate either a CallResult or CallError based
      # on the payload
      #
      # @param hash [Hash] - The hash
      # @return [CallResult, CallError] - The result
      def self.from_hash(hash)
        if hash[:error] != nil
          CallError.from_hash(hash)
        else
          CallResult.from_hash(hash)
        end
      end

      class CallResult
        attr_reader :args, :kwargs

        def initialize(args=nil, kwargs=nil)
          @args = args || []
          @kwargs = kwargs || {}
        end

        def self.from_hash(hash)
          self.new(hash[:args], hash[:kwargs])
        end

        def to_hash
          { args: self.args, kwargs: self.kwargs }
        end

        def self.from_yield_message(msg)
          self.new(msg.yield_arguments, msg.yield_argumentskw)
        end

        def self.ensure(result, allow_error: false, allow_defer: false)
          unless result.is_a?(self) or
              (allow_error and result.is_a?(CallError)) or
              (allow_defer and result.is_a?(CallDefer))
            result = result != nil ? self.new([result]) : self.new
          end

          result
        end
      end

      class CallError < StandardError
        attr_reader :error, :args, :kwargs

        def initialize(error, args=nil, kwargs=nil)
          @error = error
          @args = args || []
          @kwargs = kwargs || {}
        end

        def self.from_hash(hash)
          self.new(hash[:error], hash[:args], hash[:kwargs])
        end

        def to_hash
          { error: self.error, args: self.args, kwargs: self.kwargs }
        end

        def self.from_message(msg)
          self.new(msg.error, msg.arguments, msg.argumentskw)
        end

        def self.ensure(result)
          unless result.is_a?(self)
            args = result != nil ? [result] : nil
            result = self.new(DEFAULT_ERROR, args)
          end

          result
        end
      end

      class CallDefer
        include Event
        attr_accessor :request, :registration

        create_event [:complete, :error, :progress]

        def succeed(result)
          trigger :complete, self, result
        end

        def fail(error)
          trigger :error, self, error
        end

      end

      class ProgressiveCallDefer < CallDefer

        def progress(result)
          trigger :progress, self, result
        end

      end

    end
  end
end