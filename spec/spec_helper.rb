require 'simplecov'
SimpleCov.start

require_relative '../lib/wamp/client'

if ENV['CODECOV_TOKEN']
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require 'wamp/client'
require "rspec/em"

module SpecHelper

  class TestTransport < Wamp::Client::Transport::EventMachineBase
    @@event_machine_on = false
    attr_accessor :messages

    def initialize(options)
      super(options)
      @connected = true
      self.messages = []
    end

    def connect
      self.add_timer(1000) do
        @on_open.call if @on_open
      end
    end

    def disconnect
      @connected = false
      @on_close.call if @on_close
    end

    def self.start_event_machine(&block)
      @@event_machine_on = true
      block.call
    end

    def self.stop_event_machine
      @@event_machine_on = false
    end

    def self.event_machine_on?
      @@event_machine_on
    end

    def send_message(msg)
      self.messages.push(msg)
    end

    def receive_message(msg)

      # Emulate serialization/deserialization
      serialize = self.serializer.serialize(msg)
      deserialize = self.serializer.deserialize(serialize)

      # Call the received message
      @on_message.call(deserialize) if @on_message
    end

  end

  class WebSocketEventMachineClientStub
    attr_accessor :last_message

    def initialize
      EM.add_timer(1) {
        @onopen.call if @onopen != nil
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
      @onclose.call if @onclose != nil
      true
    end

    def send(message, type)
      self.last_message = message
    end

    def receive(message)
      @onmessage.call(message, {type:'text'}) if @onmessage != nil
    end

  end

  class FayeWebSocketClientStub
    class Event
      attr_accessor :data, :reason
    end

    attr_accessor :last_message

    def initialize
      EM.add_timer(1) {
        @on_open.call(Event.new) if @on_open != nil
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
      @on_close.call(event) if @on_close != nil
    end

    def send(message)
      self.last_message = message
    end

    def receive(message)
      event = Event.new
      event.data = message
      @on_message.call(event) if @on_message != nil
    end

  end
end