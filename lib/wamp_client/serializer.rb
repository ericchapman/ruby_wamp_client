require 'json'

module WampClient
  module Serializer
    class Base

      attr_accessor :type

      # Serializes the object
      # @param object - The object to serialize
      def serialize(object)

      end

      # Deserializes the object
      # @param string [String] - The string to deserialize
      # @return The deserialized object
      def deserialize(string)

      end

    end

    class JSONSerializer < Base

      def initialize
        self.type = 'json'
      end

      def serialize(object)
        JSON.generate object
      end

      def deserialize(string)
        JSON.parse(string, {:symbolize_names => true})
      end

    end
  end
end