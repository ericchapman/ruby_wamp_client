require_relative "base_multiple"
require 'wamp/client/response'

module Wamp
  module Client
    module Manager

      class RegistrationObject
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

      class Registration < BaseMultiple
        attr_reader :defers

        # Constructor
        #
        # @param session [Wamp::Client::Session] - The session
        # @param success [Block] - A block to run when the request was successful
        def initialize(session, send_message)
          super session, send_message
          @defers = {}
        end

        # Processes an incoming call
        #
        # @param message [Message::Event] - The incoming invoke message
        def invoke(message)

          # Get the arguments
          registration_id = message.registered_registration
          request_id = message.request
          args = message.call_arguments || []
          kwargs = message.call_argumentskw || {}

          # If we have a registration, execute it
          registration = self.objects[registration_id]
          if registration

            # Create the details
            details = message.details || {}
            details[:request] = request_id
            details[:procedure] = registration.procedure
            details[:session] = self

            handler = registration.handler
            if handler
              # Use the invoke wrapper to process the result
              value = Response.invoke_handler do
                handler.call(args, kwargs, details)
              end

              # If a defer was returned, handle accordingly
              if value.is_a? Response::CallDefer
                value.request = request_id
                value.registration = registration_id

                # Store the defer
                self.defers[request_id] = value

                # On complete, send the result
                value.on :complete do |defer, result|
                  result = Response::CallResult.ensure(result)
                  self.yield(defer.request, result, {}, true)
                end

                # On error, send the error
                value.on :error do |defer, error|
                  error = Response::CallError.ensure(error)
                  self.yield(defer.request, error, {}, true)
                end

                # For progressive, return the progress
                if value.is_a? Response::ProgressiveCallDefer
                  value.on :progress do |defer, result|
                    result = Response::CallResult.ensure(result)
                    self.yield(defer.request, result, { progress: true }, true)
                  end
                end

                # Else it was a normal response
              else
                self.yield(request_id, value)
              end
            end
          end
        end

        # Processes a yield request
        #
        def yield(request_id, result, options={}, check_defer=false)
          # Prevent responses for defers that have already completed or had an error
          if check_defer and not self.defers[request_id]
            return
          end

          # Wrap the result accordingly
          result = Response::CallResult.ensure(result, allow_error: true)

          # Send either the error or the response
          if result.is_a?(Response::CallError)
            send_error(request_id, result)
          else
            yield_msg = Message::Yield.new(request_id, options, result.args, result.kwargs)
            send_message(yield_msg)
          end

          # Remove the defer if this was not a progress update
          if check_defer and not options[:progress]
            self.defers.delete(request_id)
          end

        end

        # Call Interrupt Handler
        #
        def interrupt(message)

          # Get parameters
          request_id = message.invocation_request
          mode = message.options[:mode]

          # Check if we have a pending request
          defer = self.defers[request_id]
          if defer
            registration = self.objects[defer.registration]
            if registration
              # If it exists, call the interrupt handler to inform it of the interrupt
              i_handler = registration.i_handler
              error = nil
              if i_handler
                error = Response.invoke_handler error: true do
                  i_handler.call(request_id, mode)
                end

                # Add a default reason if none was supplied
                error.args << "interrupt" if error.args.count == 0
              end

              # Send the error back to the client
              send_error(request_id, error)
            end

            # Delete the defer
            self.defers.delete(request_id)
          end

        end

        private

        def send_error(request_id, error)
          # Make sure the response is an error
          error = Response::CallError.ensure(error)

          # Create error message
          error_msg = Message::Error.new(
              Message::Types::INVOCATION,
              request_id, {},
              error.error, error.args, error.kwargs)

          # Send it
          send_message(error_msg)
        end

      end

    end
  end
end
