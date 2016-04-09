require 'simplecov'
SimpleCov.start

require_relative '../lib/wamp_client'

require 'codecov'
SimpleCov.formatter = SimpleCov::Formatter::Codecov

require 'wamp_client'

module SpecHelper

  class TestTransport < WampClient::Transport::Base

    attr_accessor :messages

    def initialize(options)
      super(options)
      @connected = true
      self.messages = []
    end

    def connect

    end

    def send_message(msg)
      self.messages.push(msg)
    end

    def receive_message(msg)

      # Emulate serialization/deserialization
      serialize = self.serializer.serialize(msg)
      deserialize = self.serializer.deserialize(serialize)

      # Call the received message
      @on_message.call(deserialize) unless @on_message.nil?
    end

  end

end