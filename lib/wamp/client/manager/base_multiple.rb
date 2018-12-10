require_relative "base"

module Wamp
  module Client
    module Manager

      class BaseMultiple < Base
        attr_reader :objects

        # Constructor
        #
        # @param session [Wamp::Client::Session] - The session
        # @param success [Block] - A block to run when the request was successful
        def initialize(session, send_message)
          super session, send_message
          @objects = {}
        end

        # Adds an object to the manager
        #
        # @param id [Int] - The ID of the object
        # @param object [Object] - The object to handle
        def add(id, object)
          self.objects[id] = object
        end

        # Removes an object
        #
        # @param id [Int] - The ID of the object
        def remove(id)
          self.objects.delete(id)
        end

      end
    end
  end
end
