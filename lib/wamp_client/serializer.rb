require 'json'

module WampClient
  module Serializer
    class Base

      @type       # [String] The type of serialization

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
        @type = 'json'
      end

      def serialize(object)
        JSON.generate object
      end

      def deserialize(string)
        JSON.parse string
      end

    end
  end
end