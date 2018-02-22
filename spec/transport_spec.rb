require 'spec_helper'
require "rspec/em"
require 'websocket-eventmachine-client'
require 'faye/websocket'

describe WampClient::Transport do
  describe WampClient::Transport::EventMachineBase do
    it '#start/stop' do
      value = 0
      described_class.start_event_machine do
        EM.tick_loop do
          value += 1
          described_class.stop_event_machine if value == 10
        end
      end

      expect(value).to eq(10)
    end

    context '#add_timer' do
      include RSpec::EM::FakeClock

      before { clock.stub }
      after { clock.reset }

      it 'adds a timer with the class method' do
        value = 0
        described_class.add_timer(3000) do
          value = 1
        end

        expect(value).to eq(0)
        clock.tick(1)
        expect(value).to eq(0)
        clock.tick(1)
        expect(value).to eq(0)
        clock.tick(1)
        expect(value).to eq(1)
      end

      it 'adds a timer with the instance method' do
        transport = described_class.new({})

        value = 0
        transport.add_timer(2000) do
          value = 1
        end

        expect(value).to eq(0)
        clock.tick(1)
        expect(value).to eq(0)
        clock.tick(1)
        expect(value).to eq(1)
      end
    end
  end

  context 'transports' do
    let(:test_uri) { 'wss://router.examples.com' }
    let(:test_proxy) { 'http://proxy.examples.com' }
    let(:options) {
      {
          uri: test_uri,
          headers: {}
      }
    }

    describe WampClient::Transport::WebSocketEventMachine do
      include RSpec::EM::FakeClock
      before { clock.stub }
      after { clock.reset }

      let(:transport) { described_class.new(options) }
      let(:socket) { transport.socket }
      before(:each) {
        allow(WebSocket::EventMachine::Client).to receive(:connect) { |options|
          SpecHelper::WebSocketEventMachineClientStub.new
        }

        transport.connect
        clock.tick(1)  # Simulate connecting
      }

      it 'initializes' do
        expect(transport.uri).to eq(test_uri)
      end

      it 'connects to the router' do
        expect(transport.connected?).to eq(true)
      end

      it 'disconnects from the router' do
        value = false
        transport.on_close do
          value = true
        end

        transport.disconnect

        expect(transport.connected?).to eq(false)
        expect(value).to eq(true)
      end

      it 'sends a message' do
        transport.send_message({test: 'value'})
        expect(socket.last_message).to eq('{"test":"value"}')
      end

      it 'receives a message' do
        message = nil
        transport.on_message do |msg, type|
          message = msg
        end

        socket.receive('{"test":"value"}')
        expect(message).to eq({test: 'value'})
      end

      it 'raises exception if sending message when closed' do
        transport.disconnect
        expect {
          transport.send_message({test: 'value'})
        }.to raise_error(RuntimeError)
      end

      it 'raises exception if proxy is included' do
        expect {
          options[:proxy] = { origin: 'something', headers: 'something' }
          described_class.new(options)
        }.to raise_error(RuntimeError)
      end
    end

    describe WampClient::Transport::FayeWebSocket do
      include RSpec::EM::FakeClock
      before { clock.stub }
      after { clock.reset }

      let(:transport) { described_class.new(options) }
      let(:socket) { transport.socket }
      before(:each) {
        allow(Faye::WebSocket::Client).to receive(:new) { |uri, protocols, options|
          SpecHelper::FayeWebSocketClientStub.new
        }

        transport.connect
        clock.tick(1)  # Simulate connecting
      }

      it 'initializes' do
        expect(transport.uri).to eq(test_uri)
      end

      it 'connects to the router' do
        expect(transport.connected?).to eq(true)
      end

      it 'disconnects from the router' do
        value = false
        transport.on_close do
          value = true
        end

        transport.disconnect

        expect(transport.connected?).to eq(false)
        expect(value).to eq(true)
      end

      it 'sends a message' do
        transport.send_message({test: 'value'})
        expect(socket.last_message).to eq('{"test":"value"}')
      end

      it 'receives a message' do
        message = nil
        transport.on_message do |msg, type|
          message = msg
        end

        socket.receive('{"test":"value"}')
        expect(message).to eq({test: 'value'})
      end

      it 'raises exception if sending message when closed' do
        transport.disconnect
        expect {
          transport.send_message({test: 'value'})
        }.to raise_error(RuntimeError)
      end

      it 'does not raise exception if proxy is included' do
        expect {
          options[:proxy] = { origin: 'something', headers: 'something' }
          described_class.new(options)
        }.not_to raise_error
      end
    end
  end
end
