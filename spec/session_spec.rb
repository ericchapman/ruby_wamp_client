require 'spec_helper'

describe WampClient::Session do

  describe 'session establishment' do
    let (:transport) { SpecHelper::TestTransport.new({}) }
    let (:session) { WampClient::Session.new(transport) }

    before(:each) do
      @join_count = 0
      session.on_join = lambda do |details|
        @join_count += 1
      end
      @leave_count = 0
      session.on_leave = lambda do |reason, details|
        @leave_count += 1
      end
    end

    it 'performs a tx-hello/rx-welcome' do

      session.join('test')

      # Check generated message
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(1)  # Hello Message ID
      expect(transport.messages[0][1]).to eq('test')  # Realm Test
      expect(transport.messages[0][2][:roles]).not_to be_nil  # Roles exists

      # Check State
      expect(session.id).to be_nil
      expect(session.is_open?).to eq(false)
      expect(session.realm).to eq('test')
      expect(@join_count).to eq(0)
      expect(@leave_count).to eq(0)

      # Send welcome message
      welcome = WampClient::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      # Check new state of session
      expect(session.id).to eq(1234)
      expect(session.is_open?).to eq(true)
      expect(session.realm).to eq('test')
      expect(@join_count).to eq(1)
      expect(@leave_count).to eq(0)

    end

    it 'performs a tx-hello/rx-abort' do

      session.join('test')

      # Send abort message
      abort = WampClient::Message::Abort.new({}, 'test.reason')
      transport.receive_message(abort.payload)

      # Check new state of session
      expect(session.id).to be_nil
      expect(session.is_open?).to eq(false)
      expect(@join_count).to eq(0)
      expect(@leave_count).to eq(1)

    end

    it 'performs a connect then client initiated goodbye' do

      session.join('test')
      welcome = WampClient::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      # Leave the session
      session.leave('felt.like.it')

      # Check state
      expect(transport.messages.count).to eq(2)
      expect(session.id).to eq(1234)
      expect(session.realm).to eq('test')
      expect(session.is_open?).to eq(true)
      expect(session._goodbye_sent).to eq(true)
      expect(@leave_count).to eq(0)

      # Send Goodbye response from server
      goodbye = WampClient::Message::Goodbye.new({}, 'wamp.error.goodbye_and_out')
      transport.receive_message(goodbye.payload)

      # Check state
      expect(transport.messages.count).to eq(2)
      expect(session.id).to be_nil
      expect(session.is_open?).to eq(false)
      expect(session.realm).to be_nil
      expect(session._goodbye_sent).to eq(false)
      expect(@leave_count).to eq(1)

    end

    it 'performs a connect then server initiated goodbye' do

      session.join('test')
      welcome = WampClient::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      # Send Goodbye from server
      goodbye = WampClient::Message::Goodbye.new({}, 'felt.like.it')
      transport.receive_message(goodbye.payload)

      # Check state
      expect(transport.messages.count).to eq(2)
      expect(transport.messages[1][0]).to eq(6)  # Goodbye Message ID
      expect(transport.messages[1][2]).to eq('wamp.error.goodbye_and_out')  # Realm Test
      expect(session.id).to be_nil
      expect(session.is_open?).to eq(false)
      expect(session.realm).to be_nil
      expect(session._goodbye_sent).to eq(false)
      expect(@leave_count).to eq(1)

    end

  end

end
