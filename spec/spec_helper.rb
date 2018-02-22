require 'simplecov'
SimpleCov.start

require_relative '../lib/wamp_client'

if ENV['CODECOV_TOKEN']
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require 'wamp_client'
require "rspec/em"

module SpecHelper

  class TestTransport < WampClient::Transport::Base

    attr_accessor :messages, :timer_callback

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

    def add_timer(milliseconds, &callback)
      self.timer_callback = callback
    end

  end

  class WebSocketEventMachineClientStub
    attr_accessor :last_message

    def initialize
      EM.add_timer(1) {
        @onopen&.call
      }
    end

    @onopen
    def onopen(&onopen)
      @onopen = onopen
    end

    @onmessage
    def onmessage(&onmessage)
      @onmessage = onmessage
    end

    @onclose
    def onclose(&onclose)
      @onclose = onclose
    end

    def close
      @onclose&.call
      true
    end

    def send(message, type)
      self.last_message = message
    end

    def receive(message)
      @onmessage&.call(message, {type:'text'})
    end

  end

  class FayeWebSocketClientStub
    class Event
      attr_accessor :data, :reason
    end

    attr_accessor :last_message

    def initialize
      EM.add_timer(1) {
        @on_open&.call(Event.new)
      }
    end

    @on_open
    @on_message
    @on_close
    def on(event, &block)
      if event == :open
        @on_open = block
      elsif event == :close
        @on_close = block
      elsif event == :message
        @on_message = block
      end
    end

    def close
      event = Event.new
      event.reason = 'closed'
      @on_close&.call(event)
    end

    def send(message)
      self.last_message = message
    end

    def receive(message)
      event = Event.new
      event.data = message
      @on_message&.call(event)
    end

  end
end