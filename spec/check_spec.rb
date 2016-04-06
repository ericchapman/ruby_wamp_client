require 'spec_helper'

describe WampClient::Check do

  class DummyClass
    include WampClient::Check
  end

  describe '#check_equal' do

    it 'raises exception when value does not equal expected' do
      expect { DummyClass.check_equal('test', false, true) }.to raise_exception("The 'test' argument must have the value 'false'.  Instead the value was 'true'")
    end

    it 'does not raise exception when value equals expected' do
      expect { DummyClass.check_equal('test', true, true) }.not_to raise_exception
    end

  end

  describe '#check_gte' do

    it 'raises exception when value is less than expected' do
      expect { DummyClass.check_gte('test', 3, 2) }.to raise_exception("The 'test' argument must be greater than or equal to '3'.  Instead the value was '2'")
    end

    it 'does not raise exception when value equals expected' do
      expect { DummyClass.check_gte('test', 3, 3) }.not_to raise_exception
    end

    it 'does not raise exception when value is greater than expected' do
      expect { DummyClass.check_gte('test', 3, 4) }.not_to raise_exception
    end

  end

  describe '#check_nil' do

    it 'raises exception when nil and nil is not allowed' do
      expect { DummyClass.check_nil('test', nil, false) }.to raise_exception("The 'test' argument cannot be nil")
    end

    it 'does not raise exception when nil and nil is allowed' do
      expect { DummyClass.check_nil('test', nil, true) }.not_to raise_exception
    end

    it 'does not raise exception when not nil and nil is not allowed' do
      expect { DummyClass.check_nil('test', 'value', false) }.not_to raise_exception
    end

    it 'does not raise exception when not nil and nil is allowed' do
      expect { DummyClass.check_nil('test', 'value', true) }.not_to raise_exception
    end

  end

  describe '#check_integer' do

    it 'raises exception when nil and nil is not allowed' do
      expect { DummyClass.check_int('test', nil, false) }.to raise_exception("The 'test' argument cannot be nil")
    end

    it 'does not raise exception when nil and nil is allowed' do
      expect { DummyClass.check_int('test', nil, true) }.not_to raise_exception
    end

    it 'raises exception when not an integer' do
      expect { DummyClass.check_int('test', '1') }.to raise_exception("The 'test' argument must be an integer")
    end

    it 'does not raise exception when it is an integer' do
      expect { DummyClass.check_int('test', 1) }.not_to raise_exception
    end

  end

  describe '#check_string' do

    it 'raises exception when nil and nil is not allowed' do
      expect { DummyClass.check_string('test', nil, false) }.to raise_exception("The 'test' argument cannot be nil")
    end

    it 'does not raise exception when nil and nil is allowed' do
      expect { DummyClass.check_string('test', nil, true) }.not_to raise_exception
    end

    it 'raises exception when not an integer' do
      expect { DummyClass.check_string('test', 1) }.to raise_exception("The 'test' argument must be a string")
    end

    it 'does not raise exception when it is an integer' do
      expect { DummyClass.check_string('test', '1') }.not_to raise_exception
    end

  end

  describe '#check_bool' do

    it 'raises exception when nil and nil is not allowed' do
      expect { DummyClass.check_bool('test', nil, false) }.to raise_exception("The 'test' argument cannot be nil")
    end

    it 'does not raise exception when nil and nil is allowed' do
      expect { DummyClass.check_bool('test', nil, true) }.not_to raise_exception
    end

    it 'raises exception when not a boolean' do
      expect { DummyClass.check_bool('test', 1) }.to raise_exception("The 'test' argument must be a boolean")
    end

    it 'does not raise exception when it is a boolean' do
      expect { DummyClass.check_bool('test', true) }.not_to raise_exception
    end

  end

  describe '#check_dict' do

    it 'raises exception when nil and nil is not allowed' do
      expect { DummyClass.check_dict('test', nil, false) }.to raise_exception("The 'test' argument cannot be nil")
    end

    it 'does not raise exception when nil and nil is allowed' do
      expect { DummyClass.check_dict('test', nil, true) }.not_to raise_exception
    end

    it 'raises exception when not a hash' do
      expect { DummyClass.check_dict('test', 1) }.to raise_exception("The 'test' argument must be a hash")
    end

    it 'does not raise exception when it is a hash' do
      expect { DummyClass.check_dict('test', {}) }.not_to raise_exception
    end

  end

  describe '#check_list' do

    it 'raises exception when nil and nil is not allowed' do
      expect { DummyClass.check_list('test', nil, false) }.to raise_exception("The 'test' argument cannot be nil")
    end

    it 'does not raise exception when nil and nil is allowed' do
      expect { DummyClass.check_list('test', nil, true) }.not_to raise_exception
    end

    it 'raises exception when not a hash' do
      expect { DummyClass.check_list('test', 1) }.to raise_exception("The 'test' argument must be an array")
    end

    it 'does not raise exception when it is a hash' do
      expect { DummyClass.check_list('test', []) }.not_to raise_exception
    end

  end

  describe '#check_id' do

    it 'raises exception when nil and nil is not allowed' do
      expect { DummyClass.check_id('test', nil, false) }.to raise_exception("The 'test' argument cannot be nil")
    end

    it 'does not raise exception when nil and nil is allowed' do
      expect { DummyClass.check_id('test', nil, true) }.not_to raise_exception
    end

    it 'raises exception when not an integer' do
      expect { DummyClass.check_id('test', '1') }.to raise_exception("The 'test' argument must be an integer")
    end

    it 'does not raise exception when it is an integer' do
      expect { DummyClass.check_id('test', 1) }.not_to raise_exception
    end

  end

  describe '#check_uri' do

    it 'raises exception when nil and nil is not allowed' do
      expect { DummyClass.check_uri('test', nil, false) }.to raise_exception("The 'test' argument cannot be nil")
    end

    it 'does not raise exception when nil and nil is allowed' do
      expect { DummyClass.check_uri('test', nil, true) }.not_to raise_exception
    end

    it 'raises exception when not an integer' do
      expect { DummyClass.check_uri('test', 1) }.to raise_exception("The 'test' argument must be a string")
    end

    it 'does not raise exception when it is an integer' do
      expect { DummyClass.check_uri('test', '1') }.not_to raise_exception
    end

  end

end