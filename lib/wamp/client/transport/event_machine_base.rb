require 'eventmachine'
require_relative 'base'

module Wamp
  module Client
    module Transport
      class EventMachineBase < Base

        def self.start_event_machine(&block)
          EM.run do
            block.call
          end
        end

        def self.stop_event_machine
          EM.stop
        end

        def self.add_timer(milliseconds, &callback)
          delay = (milliseconds.to_f/1000.0).ceil
          EM.add_timer(delay) {
            callback.call
          }
        end

        def self.add_tick_loop(&block)
          EM.tick_loop(&block)
        end

      end
    end
  end
end

