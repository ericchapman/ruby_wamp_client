require 'spec_helper'

describe WampClient::Session do
  let (:transport) { SpecHelper::TestTransport.new({}) }
  let (:session) { WampClient::Session.new(transport) }

  describe 'establishment' do

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
      expect(transport.messages[0][0]).to eq(WampClient::Message::Types.HELLO)
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

      # Check Exception
      expect { session.join('test') }.to raise_exception("Session must be closed to call 'join'")

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

      # Check Exception
      expect { session.leave('felt.like.it') }.to raise_exception("Session must be opened to call 'leave'")

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
      expect(transport.messages[1][0]).to eq(WampClient::Message::Types.GOODBYE)
      expect(transport.messages[1][2]).to eq('wamp.error.goodbye_and_out')  # Realm Test
      expect(session.id).to be_nil
      expect(session.is_open?).to eq(false)
      expect(session.realm).to be_nil
      expect(session._goodbye_sent).to eq(false)
      expect(@leave_count).to eq(1)

    end

  end

  describe 'subscribe' do

    before(:each) do
      # Check Exception
      expect { session.subscribe('test.test', nil, {test: 1}, nil) }.to raise_exception("Session must be opened to call 'subscribe'")

      session.join('test')
      welcome = WampClient::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)
      transport.messages = []
    end

    it 'adds a request to the request queue' do
      session.subscribe('test.test', nil, {test: 1}, nil)

      expect(session._requests[:subscribe].count).to eq(1)
      request_id = session._requests[:subscribe].keys.first

      # Check the transport messages
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(WampClient::Message::Types.SUBSCRIBE)
      expect(transport.messages[0][1]).to eq(request_id)
      expect(transport.messages[0][2]).to eq({test: 1})
      expect(transport.messages[0][3]).to eq('test.test')

      # Check the request dictionary
      expect(session._requests[:subscribe][request_id][:t]).to eq('test.test')
      expect(session._requests[:subscribe][request_id][:o]).to eq({test: 1})

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(0)
    end

    it 'grants a request' do
      count = 0
      callback = lambda do |subscription, error, details|
        count += 1

        expect(subscription).not_to be_nil
        expect(subscription.id).to eq(3456)
        expect(error).to be_nil
        expect(details).to be_nil
      end

      session.subscribe('test.test', nil, {test: 1}, callback)
      request_id = session._requests[:subscribe].keys.first

      expect(count).to eq(0)

      # Generate server response
      subscribed = WampClient::Message::Subscribed.new(request_id, 3456)
      transport.receive_message(subscribed.payload)

      expect(count).to eq(1)

      # Check that the requests are empty
      expect(session._requests[:subscribe].count).to eq(0)

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(1)
      expect(session._subscriptions[3456].topic).to eq('test.test')
      expect(session._subscriptions[3456].options).to eq({test: 1})

    end

    it 'errors on a request' do
      count = 0
      callback = lambda do |subscription, error, details|
        count += 1

        expect(subscription).not_to be_nil
        expect(error).to eq('this.failed')
        expect(details).to eq({fail:true})
      end

      session.subscribe('test.test', nil, {test: 1}, callback)
      request_id = session._requests[:subscribe].keys.first

      # Generate server response
      subscribed = WampClient::Message::Error.new(WampClient::Message::Types.SUBSCRIBE,
                                                  request_id, {fail:true}, 'this.failed')
      transport.receive_message(subscribed.payload)

      expect(count).to eq(1)

      # Check that the requests are empty
      expect(session._requests[:subscribe].count).to eq(0)

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(0)
    end

    it 'receives an event' do

      count = 0
      handler = lambda do |args, kwargs, details|
        count += 1

        expect(details).to eq({test:1, publication:7890})
        expect(args).to eq([2])
        expect(kwargs).to eq({param: 'value'})
      end

      session.subscribe('test.test', handler, {test: 1})
      request_id = session._requests[:subscribe].keys.first

      expect(count).to eq(0)

      # Generate server response
      subscribed = WampClient::Message::Subscribed.new(request_id, 3456)
      transport.receive_message(subscribed.payload)

      expect(count).to eq(0)

      # Generate server event
      event = WampClient::Message::Event.new(3456, 7890, {test:1}, [2], {param: 'value'})
      transport.receive_message(event.payload)

      expect(count).to eq(1)

    end

  end

  describe 'unsubscribe' do

    before(:each) do
      # Check Exception
      expect { session.unsubscribe(nil) }.to raise_exception("Session must be opened to call 'unsubscribe'")

      session.join('test')
      welcome = WampClient::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      callback = lambda do |subscription, error, details|
        @subscription = subscription
      end

      session.subscribe('test.test', nil, {test: 1}, callback)

      # Get the request ID
      @request_id = session._requests[:subscribe].keys.first

      # Generate server response
      subscribed = WampClient::Message::Subscribed.new(@request_id, 3456)
      transport.receive_message(subscribed.payload)

      transport.messages = []
    end

    it 'adds a request to the request queue' do
      session.unsubscribe(@subscription, nil)

      @request_id = session._requests[:unsubscribe].keys.first

      # Check the transport messages
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(WampClient::Message::Types.UNSUBSCRIBE)
      expect(transport.messages[0][1]).to eq(@request_id)
      expect(transport.messages[0][2]).to eq(@subscription.id)

      # Check the request dictionary
      expect(session._requests[:unsubscribe][@request_id]).not_to be_nil

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(1)

    end

    it 'grants a request' do

      count = 0
      callback = lambda do |subscription, error, details|
        count += 1

        expect(subscription.id).to eq(@subscription.id)
        expect(error).to be_nil
        expect(details).to be_nil
      end

      session.unsubscribe(@subscription, callback)

      @request_id = session._requests[:unsubscribe].keys.first

      expect(count).to eq(0)

      # Generate Server Response
      unsubscribed = WampClient::Message::Unsubscribed.new(@request_id)
      transport.receive_message(unsubscribed.payload)

      # Check the request dictionary
      expect(session._requests[:unsubscribe].count).to eq(0)

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(0)

    end

    it 'grants a request from calling object' do

      @subscription.unsubscribe

      @request_id = session._requests[:unsubscribe].keys.first

      # Generate Server Response
      unsubscribed = WampClient::Message::Unsubscribed.new(@request_id)
      transport.receive_message(unsubscribed.payload)

      # Check the request dictionary
      expect(session._requests[:unsubscribe].count).to eq(0)

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(0)

    end

    it 'errors on a request' do

      count = 0
      callback = lambda do |subscription, error, details|
        count += 1

        expect(subscription).not_to be_nil
        expect(error).to eq('this.failed')
        expect(details).to eq({fail:true})
      end

      session.unsubscribe(@subscription, callback)

      @request_id = session._requests[:unsubscribe].keys.first

      expect(count).to eq(0)

      # Generate Server Response
      subscribed = WampClient::Message::Error.new(WampClient::Message::Types.UNSUBSCRIBE,
                                                  @request_id, {fail:true}, 'this.failed')
      transport.receive_message(subscribed.payload)

      expect(count).to eq(1)

      # Check the request dictionary
      expect(session._requests[:unsubscribe].count).to eq(0)

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(1)

    end


  end


end
