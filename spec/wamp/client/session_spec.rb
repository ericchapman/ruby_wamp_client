require 'spec_helper'

describe Wamp::Client::Session do
  let (:transport) { SpecHelper::TestTransport.new({}) }
  let (:session) { Wamp::Client::Session.new(transport) }

  describe 'establishment' do

    before(:each) do
      @join_count = 0
      session.on_join do |details|
        @join_count += 1
      end
      @leave_count = 0
      session.on_leave do |reason, details|
        @leave_count += 1
      end
    end

    it 'performs a tx-hello/rx-welcome' do

      session.join('test')

      # Check generated message
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::HELLO)
      expect(transport.messages[0][1]).to eq('test')  # Realm Test
      expect(transport.messages[0][2][:roles]).not_to be_nil  # Roles exists
      expect(transport.messages[0][2].key?(:authid)).to eq(false)  # Ensure authid is omitted
      expect(transport.messages[0][2].key?(:authmethods)).to eq(false)  # Ensure authmethods is ommitted

      # Check State
      expect(session.id).to be_nil
      expect(session.is_open?).to eq(false)
      expect(session.realm).to eq('test')
      expect(@join_count).to eq(0)
      expect(@leave_count).to eq(0)

      # Send welcome message
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
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
      abort = Wamp::Client::Message::Abort.new({}, 'test.reason')
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
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
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
      goodbye = Wamp::Client::Message::Goodbye.new({}, 'wamp.error.goodbye_and_out')
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
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      # Send Goodbye from server
      goodbye = Wamp::Client::Message::Goodbye.new({}, 'felt.like.it')
      transport.receive_message(goodbye.payload)

      # Check state
      expect(transport.messages.count).to eq(2)
      expect(transport.messages[1][0]).to eq(Wamp::Client::Message::Types::GOODBYE)
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
      expect { session.subscribe('test.topic', nil, {test: 1}) }.to raise_exception("Session must be open to call 'subscribe'")

      session.join('test')
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)
      transport.messages = []
    end

    it 'adds subscribe request to queue' do
      session.subscribe('test.topic', lambda {}, {test: 1})

      expect(session._requests[:subscribe].count).to eq(1)
      request_id = session._requests[:subscribe].keys.first

      # Check the transport messages
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::SUBSCRIBE)
      expect(transport.messages[0][1]).to eq(request_id)
      expect(transport.messages[0][2]).to eq({test: 1})
      expect(transport.messages[0][3]).to eq('test.topic')

      # Check the request dictionary
      expect(session._requests[:subscribe][request_id][:t]).to eq('test.topic')
      expect(session._requests[:subscribe][request_id][:o]).to eq({test: 1})

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(0)
    end

    it 'confirms subscription' do
      count = 0
      session.subscribe('test.topic', lambda {}, {test: 1}) do |subscription, error, details|
        count += 1

        expect(subscription).not_to be_nil
        expect(subscription.id).to eq(3456)
        expect(error).to be_nil
        expect(details).to eq({topic: 'test.topic', type: 'subscribe', session: session})
      end

      request_id = session._requests[:subscribe].keys.first

      expect(count).to eq(0)

      # Generate server response
      subscribed = Wamp::Client::Message::Subscribed.new(request_id, 3456)
      transport.receive_message(subscribed.payload)

      expect(count).to eq(1)

      # Check that the requests are empty
      expect(session._requests[:subscribe].count).to eq(0)

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(1)
      expect(session._subscriptions[3456].topic).to eq('test.topic')
      expect(session._subscriptions[3456].options).to eq({test: 1})

    end

    it 'errors confirming a subscription' do
      count = 0
      session.subscribe('test.topic', lambda {}, {test: 1}) do |subscription, error, details|
        count += 1

        expect(subscription).to be_nil
        expect(error[:error]).to eq('this.failed')
        expect(details).to eq({fail: true, topic: 'test.topic', type: 'subscribe', session: session})
      end

      request_id = session._requests[:subscribe].keys.first

      # Generate server response
      error = Wamp::Client::Message::Error.new(Wamp::Client::Message::Types::SUBSCRIBE,
                                             request_id, {fail: true}, 'this.failed')
      transport.receive_message(error.payload)

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

        expect(details).to eq({test:1, publication:7890, session: session})
        expect(args).to eq([2])
        expect(kwargs).to eq({param: 'value'})
      end

      session.subscribe('test.topic', handler, {test: 1})
      request_id = session._requests[:subscribe].keys.first

      expect(count).to eq(0)

      # Generate server response
      subscribed = Wamp::Client::Message::Subscribed.new(request_id, 3456)
      transport.receive_message(subscribed.payload)

      expect(count).to eq(0)

      # Generate server event
      event = Wamp::Client::Message::Event.new(3456, 7890, {test:1}, [2], {param: 'value'})
      transport.receive_message(event.payload)

      expect(count).to eq(1)

    end

  end

  describe 'unsubscribe' do

    before(:each) do
      # Check Exception
      expect { session.unsubscribe(nil) }.to raise_exception("Session must be open to call 'unsubscribe'")

      session.join('test')
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      session.subscribe('test.topic', lambda {}, {test: 1}) do |subscription, error, details|
        @subscription = subscription
      end

      # Get the request ID
      @request_id = session._requests[:subscribe].keys.first

      # Generate server response
      subscribed = Wamp::Client::Message::Subscribed.new(@request_id, 3456)
      transport.receive_message(subscribed.payload)

      transport.messages = []
    end

    it 'adds unsubscribe request to the queue' do
      session.unsubscribe(@subscription)

      @request_id = session._requests[:unsubscribe].keys.first

      # Check the transport messages
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::UNSUBSCRIBE)
      expect(transport.messages[0][1]).to eq(@request_id)
      expect(transport.messages[0][2]).to eq(@subscription.id)

      # Check the request dictionary
      expect(session._requests[:unsubscribe][@request_id]).not_to be_nil

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(1)

    end

    it 'grants an unsubscription' do

      count = 0
      session.unsubscribe(@subscription) do |subscription, error, details|
        count += 1

        expect(subscription.id).to eq(@subscription.id)
        expect(error).to be_nil
        expect(details).to eq({topic: 'test.topic', type: 'unsubscribe', session: session})
      end

      @request_id = session._requests[:unsubscribe].keys.first

      expect(count).to eq(0)

      # Generate Server Response
      unsubscribed = Wamp::Client::Message::Unsubscribed.new(@request_id)
      transport.receive_message(unsubscribed.payload)

      # Check the request dictionary
      expect(session._requests[:unsubscribe].count).to eq(0)

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(0)

    end

    it 'confirms an unsubscription' do

      @subscription.unsubscribe

      @request_id = session._requests[:unsubscribe].keys.first

      # Generate Server Response
      unsubscribed = Wamp::Client::Message::Unsubscribed.new(@request_id)
      transport.receive_message(unsubscribed.payload)

      # Check the request dictionary
      expect(session._requests[:unsubscribe].count).to eq(0)

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(0)

    end

    it 'errors confirming an unsubscription' do

      count = 0
      session.unsubscribe(@subscription) do |subscription, error, details|
        count += 1

        expect(subscription).to be_nil
        expect(error[:error]).to eq('this.failed')
        expect(details).to eq({fail: true, topic: 'test.topic', type: 'unsubscribe', session: session})
      end

      @request_id = session._requests[:unsubscribe].keys.first

      expect(count).to eq(0)

      # Generate Server Response
      error = Wamp::Client::Message::Error.new(Wamp::Client::Message::Types::UNSUBSCRIBE,
                                             @request_id, {fail: true}, 'this.failed')
      transport.receive_message(error.payload)

      expect(count).to eq(1)

      # Check the request dictionary
      expect(session._requests[:unsubscribe].count).to eq(0)

      # Check the subscriptions
      expect(session._subscriptions.count).to eq(1)

    end

  end

  describe 'publish' do

    before(:each) do
      # Check Exception
      expect { session.publish('test.topic') }.to raise_exception("Session must be open to call 'publish'")

      session.join('test')
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      transport.messages = []
    end

    it 'adds a publish to the publish request queue' do
      session.publish('test.topic', nil, nil, {acknowledge:true})

      @request_id = session._requests[:publish].keys.first

      # Check the transport messages
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::PUBLISH)
      expect(transport.messages[0][1]).to eq(@request_id)
      expect(transport.messages[0][2]).to eq({acknowledge:true})

      # Check the request dictionary
      expect(session._requests[:publish][@request_id]).not_to be_nil

    end

    it 'publishes with no confirmation' do

      expect(transport.messages.count).to eq(0)

      session.publish('test.topic', nil, nil, {})

      expect(transport.messages.count).to eq(1)

      # Check the request dictionary
      expect(session._requests[:publish].count).to eq(0)

    end

    it 'publishes with confirmation' do

      expect(transport.messages.count).to eq(0)

      count = 0
      session.publish('test.topic', nil, nil, {acknowledge: true}) do |publication, error, details|
        count += 1

        expect(publication).not_to be_nil
        expect(error).to be_nil
        expect(details).to eq({topic: 'test.topic', type: 'publish', session: session, publication: 5678})
      end

      @request_id = session._requests[:publish].keys.first

      expect(count).to eq(0)

      # Generate Server Response
      published = Wamp::Client::Message::Published.new(@request_id, 5678)
      transport.receive_message(published.payload)

      # Check the request dictionary
      expect(session._requests[:publish].count).to eq(0)

      expect(count).to eq(1)

    end

    it 'errors confirming a publish' do

      count = 0
      session.publish('test.topic', nil, nil, {acknowledge: true}) do |publication, error, details|
        count += 1

        expect(publication).to be_nil
        expect(error[:error]).to eq('this.failed')
        expect(details).to eq({fail: true, topic: 'test.topic', type: 'publish', session: session})
      end

      @request_id = session._requests[:publish].keys.first

      expect(count).to eq(0)

      # Generate Server Response
      error = Wamp::Client::Message::Error.new(Wamp::Client::Message::Types::PUBLISH,
                                             @request_id, {fail: true}, 'this.failed')
      transport.receive_message(error.payload)

      expect(count).to eq(1)

      # Check the request dictionary
      expect(session._requests[:publish].count).to eq(0)

    end

  end

  describe 'register' do

    before(:each) do
      # Check Exception
      expect { session.register('test.procedure', nil, {test: 1}) }.to raise_exception("Session must be open to call 'register'")

      session.join('test')
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)
      transport.messages = []
    end

    it 'adds register request to queue' do
      session.register('test.procedure', lambda {}, {test: 1})

      expect(session._requests[:register].count).to eq(1)
      request_id = session._requests[:register].keys.first

      # Check the transport messages
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::REGISTER)
      expect(transport.messages[0][1]).to eq(request_id)
      expect(transport.messages[0][2]).to eq({test: 1})
      expect(transport.messages[0][3]).to eq('test.procedure')

      # Check the request dictionary
      expect(session._requests[:register][request_id][:p]).to eq('test.procedure')
      expect(session._requests[:register][request_id][:o]).to eq({test: 1})

      # Check the subscriptions
      expect(session._registrations.count).to eq(0)
    end

    it 'confirms register' do
      count = 0

      session.register('test.procedure', lambda {}, {test: 1}) do |registration, error, details|
        count += 1

        expect(registration).not_to be_nil
        expect(registration.id).to eq(3456)
        expect(error).to be_nil
        expect(details).to eq({procedure: 'test.procedure', type: 'register', session: session})
      end
      request_id = session._requests[:register].keys.first

      expect(count).to eq(0)

      # Generate server response
      registered = Wamp::Client::Message::Registered.new(request_id, 3456)
      transport.receive_message(registered.payload)

      expect(count).to eq(1)

      # Check that the requests are empty
      expect(session._requests[:register].count).to eq(0)

      # Check the subscriptions
      expect(session._registrations.count).to eq(1)
      expect(session._registrations[3456].procedure).to eq('test.procedure')
      expect(session._registrations[3456].options).to eq({test: 1})

    end

    it 'errors confirming a registration' do
      count = 0
      session.register('test.procedure', lambda {}, {test: 1}) do |registration, error, details|
        count += 1

        expect(registration).to be_nil
        expect(error[:error]).to eq('this.failed')
        expect(details).to eq({fail: true, procedure: 'test.procedure', type: 'register', session: session})
      end

      request_id = session._requests[:register].keys.first

      # Generate server response
      error = Wamp::Client::Message::Error.new(Wamp::Client::Message::Types::REGISTER,
                                             request_id, {fail: true}, 'this.failed')
      transport.receive_message(error.payload)

      expect(count).to eq(1)

      # Check that the requests are empty
      expect(session._requests[:register].count).to eq(0)

      # Check the subscriptions
      expect(session._registrations.count).to eq(0)
    end

  end

  describe 'invocation' do
    before(:each) do
      @mode = nil
      @request = nil

      # Check Exception
      expect { session.register('test.procedure', nil, {test: 1}) }.to raise_exception("Session must be open to call 'register'")

      session.join('test')
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      # Register Response
      handler = lambda do |args, kwargs, details|
        @response
      end
      session.register('test.procedure', handler, {test: 1})
      request_id = session._requests[:register].keys.first
      registered = Wamp::Client::Message::Registered.new(request_id, 3456)
      transport.receive_message(registered.payload)

      # Defer Register
      defer_handler = lambda do |args, kwargs, details|
        @defer
      end
      session.register('test.defer.procedure', defer_handler)

      request_id = session._requests[:register].keys.first
      registered = Wamp::Client::Message::Registered.new(request_id, 4567)
      transport.receive_message(registered.payload)

      # Register Error Response
      handler = lambda do |args, kwargs, details|
        raise 'error'
      end
      session.register('test.procedure.error', handler, {test: 1})
      request_id = session._requests[:register].keys.first
      registered = Wamp::Client::Message::Registered.new(request_id, 5678)
      transport.receive_message(registered.payload)

      # Register Call Error Response
      handler = lambda do |args, kwargs, details|
        raise Wamp::Client::CallError.new('test.error', ['error'])
      end
      session.register('test.procedure.call.error', handler, {test: 1})
      request_id = session._requests[:register].keys.first
      registered = Wamp::Client::Message::Registered.new(request_id, 6789)
      transport.receive_message(registered.payload)

      # Defer Interrupt Register
      defer_interrupt_handler = lambda do |request, mode|
        @request = request
        @mode = mode
        @response
      end
      session.register('test.defer.interrupt.procedure', defer_handler, nil, defer_interrupt_handler)

      request_id = session._requests[:register].keys.first
      registered = Wamp::Client::Message::Registered.new(request_id, 7896)
      transport.receive_message(registered.payload)

      transport.messages = []
    end

    it 'nil response' do

      @response = nil

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 3456, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      # Check and make sure yield message was sent
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[0][1]).to eq(7890)
      expect(transport.messages[0][2]).to eq({})
      expect(transport.messages[0][3]).to be_nil

    end

    it 'normal response' do

      @response = 'response'

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 3456, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      # Check and make sure yield message was sent
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[0][1]).to eq(7890)
      expect(transport.messages[0][2]).to eq({})
      expect(transport.messages[0][3]).to eq(['response'])

    end

    it 'result response' do

      @response = Wamp::Client::CallResult.new(['test'], {test:1})

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 3456, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      # Check and make sure yield message was sent
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[0][1]).to eq(7890)
      expect(transport.messages[0][2]).to eq({})
      expect(transport.messages[0][3]).to eq(['test'])
      expect(transport.messages[0][4]).to eq({test:1})

    end

    it 'raise error response' do

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 5678, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      # Check and make sure yield message was sent
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::ERROR)
      expect(transport.messages[0][1]).to eq(Wamp::Client::Message::Types::INVOCATION)
      expect(transport.messages[0][2]).to eq(7890)
      expect(transport.messages[0][3]).to eq({})
      expect(transport.messages[0][4]).to eq('wamp.error.runtime')
      expect(transport.messages[0][5]).to eq(['error'])
      expect(transport.messages[0][6][:backtrace]).not_to be_nil

    end

    it 'raise call error response' do

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 6789, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      # Check and make sure yield message was sent
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::ERROR)
      expect(transport.messages[0][1]).to eq(Wamp::Client::Message::Types::INVOCATION)
      expect(transport.messages[0][2]).to eq(7890)
      expect(transport.messages[0][3]).to eq({})
      expect(transport.messages[0][4]).to eq('test.error')
      expect(transport.messages[0][5]).to eq(['error'])

    end

    it 'return error response' do

      @response = Wamp::Client::CallError.new('wamp.error.runtime', ['error'], {error: true})

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 3456, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      # Check and make sure yield message was sent
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::ERROR)
      expect(transport.messages[0][1]).to eq(Wamp::Client::Message::Types::INVOCATION)
      expect(transport.messages[0][2]).to eq(7890)
      expect(transport.messages[0][3]).to eq({})
      expect(transport.messages[0][4]).to eq('wamp.error.runtime')
      expect(transport.messages[0][5]).to eq(['error'])
      expect(transport.messages[0][6]).to eq({error: true})

    end

    it 'defer normal response' do

      @response = Wamp::Client::CallResult.new(['test'], {test:1})

      @defer = Wamp::Client::Defer::CallDefer.new

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 4567, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      expect(transport.messages.count).to eq(0)

      @defer.succeed(@response)

      # Check and make sure yield message was sent
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[0][1]).to eq(7890)
      expect(transport.messages[0][2]).to eq({})
      expect(transport.messages[0][3]).to eq(['test'])
      expect(transport.messages[0][4]).to eq({test:1})

    end

    it 'defer error normal response' do

      @defer = Wamp::Client::Defer::CallDefer.new

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 4567, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      expect(transport.messages.count).to eq(0)

      @defer.fail('error')

      # Check and make sure yield message was sent
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::ERROR)
      expect(transport.messages[0][1]).to eq(Wamp::Client::Message::Types::INVOCATION)
      expect(transport.messages[0][2]).to eq(7890)
      expect(transport.messages[0][3]).to eq({})
      expect(transport.messages[0][4]).to eq('wamp.error.runtime')
      expect(transport.messages[0][5]).to eq(['error'])

    end

    it 'defer error object response' do

      @response = Wamp::Client::CallError.new('wamp.error.runtime', ['error'], {error: true})

      @defer = Wamp::Client::Defer::CallDefer.new

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 4567, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      expect(transport.messages.count).to eq(0)

      @defer.fail(@response)

      # Check and make sure yield message was sent
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::ERROR)
      expect(transport.messages[0][1]).to eq(Wamp::Client::Message::Types::INVOCATION)
      expect(transport.messages[0][2]).to eq(7890)
      expect(transport.messages[0][3]).to eq({})
      expect(transport.messages[0][4]).to eq('wamp.error.runtime')
      expect(transport.messages[0][5]).to eq(['error'])
      expect(transport.messages[0][6]).to eq({error: true})

    end

    context 'cancels' do
      it 'default response' do

        @response = nil

        @defer = Wamp::Client::Defer::CallDefer.new

        # Generate server event
        invocation = Wamp::Client::Message::Invocation.new(7890, 7896, {test:1}, [2], {param: 'value'})
        transport.receive_message(invocation.payload)

        expect(transport.messages.count).to eq(0)

        # Generate the interrupt from the broker/dealer
        interrupt = Wamp::Client::Message::Interrupt.new(7890, { mode: 'killnowait'})
        transport.receive_message(interrupt.payload)

        # Check and make sure request and mode were sent
        expect(@request).to eq(7890)
        expect(@mode).to eq('killnowait')

        # Check and make sure error message was sent
        expect(transport.messages.count).to eq(1)
        expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::ERROR)
        expect(transport.messages[0][1]).to eq(Wamp::Client::Message::Types::INVOCATION)
        expect(transport.messages[0][2]).to eq(7890)
        expect(transport.messages[0][3]).to eq({})
        expect(transport.messages[0][4]).to eq('wamp.error.runtime')
        expect(transport.messages[0][5]).to eq(['interrupt'])

        # Check and make sure the additional response is ignored
        @defer.succeed('test')
        expect(transport.messages.count).to eq(1)

      end

      it 'custom response' do

        @response = 'custom'

        @defer = Wamp::Client::Defer::CallDefer.new

        # Generate server event
        invocation = Wamp::Client::Message::Invocation.new(7890, 7896, {test:1}, [2], {param: 'value'})
        transport.receive_message(invocation.payload)

        expect(transport.messages.count).to eq(0)

        # Generate the interrupt from the broker/dealer
        interrupt = Wamp::Client::Message::Interrupt.new(7890, { mode: 'kill'})
        transport.receive_message(interrupt.payload)

        # Check and make sure request and mode were sent
        expect(@request).to eq(7890)
        expect(@mode).to eq('kill')

        # Check and make sure error message was sent
        expect(transport.messages.count).to eq(1)
        expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::ERROR)
        expect(transport.messages[0][1]).to eq(Wamp::Client::Message::Types::INVOCATION)
        expect(transport.messages[0][2]).to eq(7890)
        expect(transport.messages[0][3]).to eq({})
        expect(transport.messages[0][4]).to eq('wamp.error.runtime')
        expect(transport.messages[0][5]).to eq(['custom'])

      end

    end
  end

  describe 'unregister' do

    before(:each) do
      # Check Exception
      expect { session.unregister(nil) }.to raise_exception("Session must be open to call 'unregister'")

      session.join('test')
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      session.register('test.procedure', lambda {}, {test: 1}) do |registration, error, details|
        @registration = registration
      end

      # Get the request ID
      @request_id = session._requests[:register].keys.first

      # Generate server response
      registered = Wamp::Client::Message::Registered.new(@request_id, 3456)
      transport.receive_message(registered.payload)

      transport.messages = []
    end

    it 'adds unregister request to the queue' do
      session.unregister(@registration)

      @request_id = session._requests[:unregister].keys.first

      # Check the transport messages
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::UNREGISTER)
      expect(transport.messages[0][1]).to eq(@request_id)
      expect(transport.messages[0][2]).to eq(@registration.id)

      # Check the request dictionary
      expect(session._requests[:unregister][@request_id]).not_to be_nil

      # Check the subscriptions
      expect(session._registrations.count).to eq(1)

    end

    it 'grants an unregister' do

      count = 0
      session.unregister(@registration) do |registration, error, details|
        count += 1

        expect(registration.id).to eq(@registration.id)
        expect(error).to be_nil
        expect(details).to eq({procedure: 'test.procedure', type: 'unregister', session: session})
      end

      @request_id = session._requests[:unregister].keys.first

      expect(count).to eq(0)

      # Generate Server Response
      unregistered = Wamp::Client::Message::Unregistered.new(@request_id)
      transport.receive_message(unregistered.payload)

      # Check the request dictionary
      expect(session._requests[:unregister].count).to eq(0)

      # Check the subscriptions
      expect(session._registrations.count).to eq(0)

    end

    it 'confirms an unregister' do

      @registration.unregister

      @request_id = session._requests[:unregister].keys.first

      # Generate Server Response
      unregistered = Wamp::Client::Message::Unregistered.new(@request_id)
      transport.receive_message(unregistered.payload)

      # Check the request dictionary
      expect(session._requests[:unregister].count).to eq(0)

      # Check the subscriptions
      expect(session._registrations.count).to eq(0)

    end

    it 'errors confirming an unregister' do

      count = 0
      session.unregister(@registration) do |registration, error, details|
        count += 1

        expect(registration).to be_nil
        expect(error[:error]).to eq('this.failed')
        expect(details).to eq({fail: true, procedure:'test.procedure', type: 'unregister', session: session})
      end

      @request_id = session._requests[:unregister].keys.first

      expect(count).to eq(0)

      # Generate Server Response
      error = Wamp::Client::Message::Error.new(Wamp::Client::Message::Types::UNREGISTER,
                                             @request_id, {fail: true}, 'this.failed')
      transport.receive_message(error.payload)

      expect(count).to eq(1)

      # Check the request dictionary
      expect(session._requests[:unregister].count).to eq(0)

      # Check the subscriptions
      expect(session._registrations.count).to eq(1)

    end

  end

  describe 'call' do

    before(:each) do
      # Check Exception
      expect { session.call('test.procedure') }.to raise_exception("Session must be open to call 'call'")

      session.join('test')
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      transport.messages = []
    end

    it 'adds a call to the call request queue' do
      session.call('test.procedure', nil, nil, {})

      @request_id = session._requests[:call].keys.first

      # Check the transport messages
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::CALL)
      expect(transport.messages[0][1]).to eq(@request_id)
      expect(transport.messages[0][2]).to eq({})

      # Check the request dictionary
      expect(session._requests[:call][@request_id]).not_to be_nil

    end

    it 'calls and gets result' do

      expect(transport.messages.count).to eq(0)

      count = 0
      session.call('test.procedure') do |result, error, details|
        count += 1

        expect(result).not_to be_nil
        expect(result.args).to eq(['test'])
        expect(result.kwargs).to eq({test:true})
        expect(error).to be_nil
        expect(details).to eq({procedure: 'test.procedure', type: 'call', session: session})
      end

      @request_id = session._requests[:call].keys.first

      expect(count).to eq(0)

      # Generate Server Response
      result = Wamp::Client::Message::Result.new(@request_id, {}, ['test'], {test:true})
      transport.receive_message(result.payload)

      # Check the request dictionary
      expect(session._requests[:call].count).to eq(0)

      expect(count).to eq(1)

    end

    it 'errors calling a procedure' do

      count = 0
      session.call('test.procedure', nil, nil, {acknowledge: true}) do |result, error, details|
        count += 1

        expect(result).to be_nil
        expect(error[:error]).to eq('this.failed')
        expect(details).to eq({fail: true, procedure: 'test.procedure', type: 'call', session: session})
      end

      @request_id = session._requests[:call].keys.first

      expect(count).to eq(0)

      # Generate Server Response
      error = Wamp::Client::Message::Error.new(Wamp::Client::Message::Types::CALL,
                                             @request_id, {fail: true}, 'this.failed')
      transport.receive_message(error.payload)

      expect(count).to eq(1)

      # Check the request dictionary
      expect(session._requests[:call].count).to eq(0)

    end

    it 'cancels calling a procedure' do

      count = 0
      call = session.call('test.procedure', nil, nil, {acknowledge: true}) do |result, error, details|
        count += 1

        expect(result).to be_nil
        expect(error[:error]).to eq('this.cancelled')
        expect(details).to eq({fail: true, procedure: 'test.procedure', type: 'call', session: session})
      end

      @request_id = session._requests[:call].keys.first

      expect(count).to eq(0)

      # Call Cancel
      call.cancel('kill')

      # Check transport
      expect(transport.messages.count).to eq(2)
      expect(transport.messages[1][0]).to eq(Wamp::Client::Message::Types::CANCEL)
      expect(transport.messages[1][1]).to eq(call.id)
      expect(transport.messages[1][2]).to eq({mode: 'kill'})

      # Generate Server Response
      error = Wamp::Client::Message::Error.new(Wamp::Client::Message::Types::CALL,
                                             @request_id, {fail: true}, 'this.cancelled')
      transport.receive_message(error.payload)

      expect(count).to eq(1)

      # Check the request dictionary
      expect(session._requests[:call].count).to eq(0)

    end

    context 'timeout' do
      include RSpec::EM::FakeClock

      before { clock.stub }
      after { clock.reset }

      it 'does not cancel a call if no timeout specified' do
        @defer = Wamp::Client::Defer::ProgressiveCallDefer.new

        count = 0
        session.call('test.procedure', nil, nil) do |result, error, details|
          count += 1
        end

        clock.tick(2)
        expect(transport.messages.count).to eq(1)
      end

      it 'does cancel a call if a timeout is specified' do
        @defer = Wamp::Client::Defer::ProgressiveCallDefer.new

        count = 0
        call = session.call('test.procedure', nil, nil, {timeout: 1000}) do |result, error, details|
          count += 1
        end

        clock.tick(2)

        expect(transport.messages.count).to eq(2)

        expect(transport.messages[1][0]).to eq(Wamp::Client::Message::Types::CANCEL)
        expect(transport.messages[1][1]).to eq(call.id)
        expect(transport.messages[1][2]).to eq({mode: 'skip'})
      end
    end
  end

  describe 'progressive_call_results' do

    before(:each) do
      session.join('test')
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      transport.messages = []
    end

    it 'caller ignores (should only get the first response because receive_progress is false)' do

      results = []
      session.call('test.procedure', [], {}, {}) do |result, error, details|
        results = results + result.args
      end

      @request_id = session._requests[:call].keys.first

      # Send results
      result = Wamp::Client::Message::Result.new(@request_id, {progress:true}, ['test'])
      transport.receive_message(result.payload)
      transport.receive_message(result.payload)
      transport.receive_message(result.payload)
      transport.receive_message(result.payload)

      # Send ending
      result = Wamp::Client::Message::Result.new(@request_id, {}, ['test'])
      transport.receive_message(result.payload)

      expect(results.count).to eq(1)

    end

    it 'caller support' do

      results = []
      session.call('test.procedure', [], {}, {receive_progress: true}) do |result, error, details|
        results = results + result.args
      end

      @request_id = session._requests[:call].keys.first

      # Send results
      result = Wamp::Client::Message::Result.new(@request_id, {progress:true}, ['test'])
      transport.receive_message(result.payload)
      transport.receive_message(result.payload)
      transport.receive_message(result.payload)
      transport.receive_message(result.payload)

      # Send ending
      result = Wamp::Client::Message::Result.new(@request_id, {}, ['test'])
      transport.receive_message(result.payload)

      expect(results.count).to eq(5)

      # Send More to ensure they are not appended
      result = Wamp::Client::Message::Result.new(@request_id, {progress:true}, ['test'])
      transport.receive_message(result.payload)
      transport.receive_message(result.payload)
      transport.receive_message(result.payload)
      transport.receive_message(result.payload)

      # Ensure they were not appended
      expect(results.count).to eq(5)

    end

    it 'callee result support' do

      # Defer Register
      @defer = Wamp::Client::Defer::ProgressiveCallDefer.new
      defer_handler = lambda do |args, kwargs, details|
        @defer
      end
      session.register('test.defer.procedure', defer_handler)

      request_id = session._requests[:register].keys.first
      registered = Wamp::Client::Message::Registered.new(request_id, 4567)
      transport.receive_message(registered.payload)

      transport.messages = []

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 4567, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      expect(transport.messages.count).to eq(0)
      expect(session._defers.count).to eq(1)

      @defer.progress(Wamp::Client::CallResult.new(['test1']))
      expect(session._defers.count).to eq(1)
      @defer.progress(Wamp::Client::CallResult.new(['test2']))
      expect(session._defers.count).to eq(1)
      @defer.succeed(Wamp::Client::CallResult.new(['test3']))
      expect(session._defers.count).to eq(0)

      expect(transport.messages.count).to eq(3)

      # Check and make sure yield message was sent
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[0][1]).to eq(7890)
      expect(transport.messages[0][2]).to eq({progress: true})
      expect(transport.messages[0][3]).to eq(['test1'])

      expect(transport.messages[1][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[1][1]).to eq(7890)
      expect(transport.messages[1][2]).to eq({progress: true})
      expect(transport.messages[1][3]).to eq(['test2'])

      expect(transport.messages.count).to eq(3)
      expect(transport.messages[2][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[2][1]).to eq(7890)
      expect(transport.messages[2][2]).to eq({})
      expect(transport.messages[2][3]).to eq(['test3'])

    end

    it 'callee error support' do

      # Defer Register
      @defer = Wamp::Client::Defer::ProgressiveCallDefer.new
      defer_handler = lambda do |args, kwargs, details|
        @defer
      end
      session.register('test.defer.procedure', defer_handler)

      request_id = session._requests[:register].keys.first
      registered = Wamp::Client::Message::Registered.new(request_id, 4567)
      transport.receive_message(registered.payload)

      transport.messages = []

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 4567, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      expect(transport.messages.count).to eq(0)
      expect(session._defers.count).to eq(1)

      @defer.progress(Wamp::Client::CallResult.new(['test1']))
      expect(session._defers.count).to eq(1)
      @defer.progress(Wamp::Client::CallResult.new(['test2']))
      expect(session._defers.count).to eq(1)
      @defer.fail(Wamp::Client::CallError.new('test.error'))
      expect(session._defers.count).to eq(0)

      expect(transport.messages.count).to eq(3)

      # Check and make sure yield message was sent
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[0][1]).to eq(7890)
      expect(transport.messages[0][2]).to eq({progress: true})
      expect(transport.messages[0][3]).to eq(['test1'])

      expect(transport.messages[1][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[1][1]).to eq(7890)
      expect(transport.messages[1][2]).to eq({progress: true})
      expect(transport.messages[1][3]).to eq(['test2'])

      expect(transport.messages[2][0]).to eq(Wamp::Client::Message::Types::ERROR)
      expect(transport.messages[2][1]).to eq(Wamp::Client::Message::Types::INVOCATION)
      expect(transport.messages[2][2]).to eq(7890)
      expect(transport.messages[2][3]).to eq({})
      expect(transport.messages[2][4]).to eq('test.error')

    end

    it 'callee error support' do

      # Defer Register
      @defer = Wamp::Client::Defer::ProgressiveCallDefer.new
      defer_handler = lambda do |args, kwargs, details|
        @defer
      end
      session.register('test.defer.procedure', defer_handler)

      request_id = session._requests[:register].keys.first
      registered = Wamp::Client::Message::Registered.new(request_id, 4567)
      transport.receive_message(registered.payload)

      transport.messages = []

      # Generate server event
      invocation = Wamp::Client::Message::Invocation.new(7890, 4567, {test:1}, [2], {param: 'value'})
      transport.receive_message(invocation.payload)

      expect(transport.messages.count).to eq(0)
      expect(session._defers.count).to eq(1)

      @defer.progress(Wamp::Client::CallResult.new(['test1']))
      expect(session._defers.count).to eq(1)
      @defer.progress(Wamp::Client::CallResult.new(['test2']))
      expect(session._defers.count).to eq(1)
      @defer.fail(Wamp::Client::CallError.new('test.error'))
      expect(session._defers.count).to eq(0)

      expect(transport.messages.count).to eq(3)

      # Check and make sure yield message was sent
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[0][1]).to eq(7890)
      expect(transport.messages[0][2]).to eq({progress: true})
      expect(transport.messages[0][3]).to eq(['test1'])

      expect(transport.messages[1][0]).to eq(Wamp::Client::Message::Types::YIELD)
      expect(transport.messages[1][1]).to eq(7890)
      expect(transport.messages[1][2]).to eq({progress: true})
      expect(transport.messages[1][3]).to eq(['test2'])

      expect(transport.messages[2][0]).to eq(Wamp::Client::Message::Types::ERROR)
      expect(transport.messages[2][1]).to eq(Wamp::Client::Message::Types::INVOCATION)
      expect(transport.messages[2][2]).to eq(7890)
      expect(transport.messages[2][3]).to eq({})
      expect(transport.messages[2][4]).to eq('test.error')

    end

  end

  describe 'auth' do

    let (:challenge) {"{ \"nonce\": \"LHRTC9zeOIrt_9U3\", \"authprovider\": \"userdb\", \"authid\": \"peter\", \"timestamp\": \"2014-06-22T16:36:25.448Z\", \"authrole\": \"user\", \"authmethod\": \"wampcra\", \"session\": 3251278072152162}"}
    let (:secret) {'secret'}

    before(:each) do
      session.join('test')
      transport.messages = []

      session.on_challenge do |authmethod, extra|
        expect(authmethod).to eq('wampcra')
        Wamp::Client::Auth::Cra.sign(secret, extra[:challenge])
      end
    end

    it 'challenge => authenticate' do

      # Send the challenge
      challenge_msg = Wamp::Client::Message::Challenge.new('wampcra', {challenge: challenge})
      transport.receive_message(challenge_msg.payload)

      # Check the transport messages
      expect(transport.messages.count).to eq(1)
      expect(transport.messages[0][0]).to eq(Wamp::Client::Message::Types::AUTHENTICATE)
      expect(transport.messages[0][1]).to eq('Pji30JC9tb/T9tbEwxw5i0RyRa5UVBxuoIVTgT7hnkE=')
      expect(transport.messages[0][2]).to eq({})

    end

    it 'accepts a wampcra challenge' do

      # Send the challenge
      challenge_msg = Wamp::Client::Message::Challenge.new('wampcra', {challenge: challenge})
      transport.receive_message(challenge_msg.payload)

      # Send welcome message
      welcome = Wamp::Client::Message::Welcome.new(1234, {})
      transport.receive_message(welcome.payload)

      # Check new state of session
      expect(session.id).to eq(1234)
      expect(transport.messages.count).to eq(1)

    end

    it 'rejects a wampcra challenge' do

      # Send the challenge
      challenge_msg = Wamp::Client::Message::Challenge.new('wampcra', {challenge: challenge})
      transport.receive_message(challenge_msg.payload)

      # Send abort message
      abort = Wamp::Client::Message::Abort.new({}, 'test.reason')
      transport.receive_message(abort.payload)

      # Check new state of session
      expect(session.id).to be_nil
      expect(transport.messages.count).to eq(1)

    end

  end

end
