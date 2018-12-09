require 'spec_helper'

describe Wamp::Client::Connection do
  include RSpec::EM::FakeClock

  before { clock.stub }
  after { clock.reset }

  before(:each) { TestTransport.stop_event_machine }

  let(:options) {
    {
        uri: 'wss://example.com',
        realm: 'realm1',
        transport: TestTransport,
    }
  }
  let(:connection) { described_class.new(options) }
  let(:transport) { connection.transport }
  let(:session) { connection.session }

  def open_connection
    connection.open
    clock.tick(1)
  end

  def open_session_from_server
    # Send welcome form server
    welcome = Wamp::Client::Message::Welcome.new(1234, {})
    transport.receive_message(welcome.payload)
  end

  def close_session_from_server
    # Send goodbye from server
    goodbye = Wamp::Client::Message::Goodbye.new({}, 'felt.like.it')
    transport.receive_message(goodbye.payload)
  end

  def check_em_on
    expect(TestTransport.event_machine_on?).to eq(true)
  end

  def check_em_off
    expect(TestTransport.event_machine_on?).to eq(false)
  end

  describe 'transport' do
    it 'selects the default transport' do
      connection = described_class.new({})
      expect(connection.transport_class).to be(Wamp::Client::Transport::WebSocketEventMachine)
    end

    it 'overrides the default transport' do
      connection = described_class.new({ transport: Wamp::Client::Transport::FayeWebSocket })
      expect(connection.transport_class).to be(Wamp::Client::Transport::FayeWebSocket)
    end
  end

  it 'opens the transport/session and sends the hello message' do
    called = false
    connection.on(:connect) do
      called = true
    end

    open_connection

    expect(transport).not_to be_nil
    expect(session).not_to be_nil
    expect(transport.messages.count).to eq(1)
    expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::HELLO)

    expect(called).to eq(true)
  end

  it 'opens the transport/session and joins' do
    called = false
    connection.on(:join) do
      called = true
    end

    open_connection
    open_session_from_server

    check_em_on
    expect(called).to eq(true)
  end

  it 'closes the connection' do
    left = false
    connection.on(:leave) do
      left = true
    end
    disconnected = false
    connection.on(:disconnect) do
      disconnected = true
    end

    open_connection
    open_session_from_server

    connection.close

    # Nothing happens until the server responds
    check_em_on
    expect(left).to eq(false)
    expect(disconnected).to eq(false)

    close_session_from_server

    check_em_off
    expect(left).to eq(true)
    expect(disconnected).to eq(true)
  end

  it 'retries if the session is closed from the server' do
    left = false
    connection.on(:leave) do
      left = true
    end

    joined = false
    connection.on(:join) do
      joined = true
    end

    open_connection
    open_session_from_server

    check_em_on
    expect(joined).to eq(true)
    joined = false
    expect(left).to eq(false)

    close_session_from_server

    check_em_on
    expect(joined).to eq(false)
    expect(left).to eq(true)
    left = false

    clock.tick(5)
    open_session_from_server

    check_em_on

    expect(joined).to eq(true)
    joined = false
    expect(left).to eq(false)
  end
end
