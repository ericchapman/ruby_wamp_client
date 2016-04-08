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
      @on_message.call(msg) unless @on_message.nil?
    end

  end

end