require 'spec_helper'

describe WampClient::Message do

  describe WampClient::Message::Hello do

    it 'raises exception when realm is nil' do
      expect { WampClient::Message::Hello.new(nil, {})}.to raise_exception("The 'realm' argument cannot be nil")
    end

    it 'raises exception when realm is not string' do
      expect { WampClient::Message::Hello.new(1, {})}.to raise_exception("The 'realm' argument must be a string")
    end

    it 'raises exception when details is nil' do
      expect { WampClient::Message::Hello.new('realm', nil)}.to raise_exception("The 'details' argument cannot be nil")
    end

    it 'raises exception when details is not a hash' do
      expect { WampClient::Message::Hello.new('realm', 'string')}.to raise_exception("The 'details' argument must be a hash")
    end

    it 'does not raise exception when both are provided' do
      expect { WampClient::Message::Hello.new('realm', {})}.not_to raise_exception
    end

    it 'does not raise exception when details is omitted' do
      expect { WampClient::Message::Hello.new('realm')}.not_to raise_exception
    end

  end

  describe WampClient::Message::Welcome do

    it 'raises exception when session is nil' do
      expect { WampClient::Message::Welcome.new(nil, {})}.to raise_exception("The 'session' argument cannot be nil")
    end

    it 'raises exception when session is not an integer' do
      expect { WampClient::Message::Welcome.new('string', {})}.to raise_exception("The 'session' argument must be an integer")
    end

    it 'raises exception when details is nil' do
      expect { WampClient::Message::Welcome.new(1, nil)}.to raise_exception("The 'details' argument cannot be nil")
    end

    it 'raises exception when details is not a hash' do
      expect { WampClient::Message::Welcome.new(1, 'string')}.to raise_exception("The 'details' argument must be a hash")
    end

    it 'does not raise exception when both are provided' do
      expect { WampClient::Message::Welcome.new(1, {})}.not_to raise_exception
    end

    it 'does not raise exception when details is omitted' do
      expect { WampClient::Message::Welcome.new(1)}.not_to raise_exception
    end

  end

  describe WampClient::Message::Abort do

    it 'raises exception when reason is nil' do
      expect { WampClient::Message::Abort.new({}, nil)}.to raise_exception("The 'reason' argument cannot be nil")
    end

    it 'raises exception when reason is not a uri' do
      expect { WampClient::Message::Abort.new({}, 1)}.to raise_exception("The 'reason' argument must be a string")
    end

    it 'raises exception when details is nil' do
      expect { WampClient::Message::Abort.new(nil, 'reason')}.to raise_exception("The 'details' argument cannot be nil")
    end

    it 'raises exception when details is not a hash' do
      expect { WampClient::Message::Abort.new('string', 'reason')}.to raise_exception("The 'details' argument must be a hash")
    end

    it 'does not raise exception when both are provided' do
      expect { WampClient::Message::Abort.new({}, 'reason')}.not_to raise_exception
    end

    it 'does not raise exception when reason is omitted' do
      expect { WampClient::Message::Abort.new({})}.not_to raise_exception
    end

    it 'does not raise exception when both are omitted' do
      expect { WampClient::Message::Abort.new}.not_to raise_exception
    end

  end

  describe WampClient::Message::Goodbye do

    it 'raises exception when reason is nil' do
      expect { WampClient::Message::Goodbye.new({}, nil)}.to raise_exception("The 'reason' argument cannot be nil")
    end

    it 'raises exception when reason is not a uri' do
      expect { WampClient::Message::Goodbye.new({}, 1)}.to raise_exception("The 'reason' argument must be a string")
    end

    it 'raises exception when details is nil' do
      expect { WampClient::Message::Goodbye.new(nil, 'reason')}.to raise_exception("The 'details' argument cannot be nil")
    end

    it 'raises exception when details is not a hash' do
      expect { WampClient::Message::Goodbye.new('string', 'reason')}.to raise_exception("The 'details' argument must be a hash")
    end

    it 'does not raise exception when both are provided' do
      expect { WampClient::Message::Goodbye.new({}, 'reason')}.not_to raise_exception
    end

    it 'does not raise exception when reason is omitted' do
      expect { WampClient::Message::Goodbye.new({})}.not_to raise_exception
    end

    it 'does not raise exception when both are omitted' do
      expect { WampClient::Message::Goodbye.new}.not_to raise_exception
    end

  end

  describe WampClient::Message::Error do

    it 'raises exception when request_type is nil' do
      expect { WampClient::Message::Error.new(nil, 1, {}, 'error', [], {})}.to raise_exception("The 'request_type' argument cannot be nil")
    end

    it 'raises exception when request_id is nil' do
      expect { WampClient::Message::Error.new(1, nil, {}, 'error', [], {})}.to raise_exception("The 'request_id' argument cannot be nil")
    end

    it 'does not raise exception when all are provided' do
      expect { WampClient::Message::Error.new(1, 1, {}, 'error', [], {})}.not_to raise_exception
    end

    it 'does not raise exception when kwargs is omitted' do
      expect { WampClient::Message::Error.new(1, 1, {}, 'error', [])}.not_to raise_exception
    end

    it 'does not raise exception when args and kwargs are omitted' do
      expect { WampClient::Message::Error.new(1, 1, {}, 'error')}.not_to raise_exception
    end

    it 'does not raise exception when error, args and kwargs are omitted' do
      expect { WampClient::Message::Error.new(1, 1, {})}.not_to raise_exception
    end

    it 'does not raise exception when details, error, args and kwargs are omitted' do
      expect { WampClient::Message::Error.new(1, 1)}.not_to raise_exception
    end

    it 'raises exception when request_type is the wrong type' do
      expect { WampClient::Message::Error.new('string', 1, {}, 'error', [], {})}.to raise_exception("The 'request_type' argument must be an integer")
    end

    it 'raises exception when request_id is the wrong type' do
      expect { WampClient::Message::Error.new(1, 'string', {}, 'error', [], {})}.to raise_exception("The 'request_id' argument must be an integer")
    end

    it 'raises exception when details is the wrong type' do
      expect { WampClient::Message::Error.new(1, 1, 'string', 'error', [], {})}.to raise_exception("The 'details' argument must be a hash")
    end

    it 'raises exception when error is the wrong type' do
      expect { WampClient::Message::Error.new(1, 1, {}, 1, [], {})}.to raise_exception("The 'error' argument must be a string")
    end

    it 'raises exception when args is the wrong type' do
      expect { WampClient::Message::Error.new(1, 1, {}, 'error', 'string', {})}.to raise_exception("The 'args' argument must be an array")
    end

    it 'raises exception when kwargs is the wrong type' do
      expect { WampClient::Message::Error.new(1, 1, {}, 'error', [], 'string')}.to raise_exception("The 'kwargs' argument must be a hash")
    end

  end

end