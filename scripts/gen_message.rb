#!/usr/bin/ruby

def value_from_type(type)

  value = nil

  if type == 'int' or type == 'id'
    value = '123'
  elsif type == 'uri' or type == 'string'
    value = "'string'"
  elsif type == 'list'
    value = "['test']"
  elsif type == 'dict'
    value = '{ test: 1 }'
  end

  value

end

def empty_value_from_type(type)

  value = nil

  if type == 'int' or type == 'id'
    value = '0'
  elsif type == 'uri' or type == 'string'
    value = "''"
  elsif type == 'list'
    value = "[]"
  elsif type == 'dict'
    value = '{}'
  end

  value

end

message_type_lookup = {
    'HELLO' => 1,
    'WELCOME' => 2,
    'ABORT' => 3,
    'CHALLENGE' => 4,
    'AUTHENTICATE' => 5,
    'GOODBYE' => 6,
    'ERROR' => 8,
    'PUBLISH' => 16,
    'PUBLISHED' => 17,
    'SUBSCRIBE' => 32,
    'SUBSCRIBED' => 33,
    'UNSUBSCRIBE' => 34,
    'UNSUBSCRIBED' => 35,
    'EVENT' => 36,
    'CALL' => 48,
    'CANCEL' => 49,
    'RESULT' => 50,
    'REGISTER' => 64,
    'REGISTERED' => 65,
    'UNREGISTER' => 66,
    'UNREGISTERED' => 67,
    'INVOCATION' => 68,
    'INTERRUPT' => 69,
    'YIELD' => 70
}

message_type_define = ''
message_lookup_define = ''
message_type_lookup.each do |name, value|

  # Generate the defines
  message_type_define += "        #{name} = #{value}\n"

  # Generate the lookup
  message_lookup_define += "          Types::#{name} => #{name.downcase.capitalize},\n"
end

source_file_header = "require 'wamp/client/check'

# !!!!THIS FILE IS AUTOGENERATED.  DO NOT HAND EDIT!!!!

module Wamp
  module Client
    module Message

      module Types
#{message_type_define}      end

      class Base
        include Wamp::Client::Check

        def payload
          []
        end

        # @param params [Array]
        def self.parse(params)
          nil
        end
      end
"

source_file_footer = "
      TYPE_LOOKUP = {
#{message_lookup_define}      }

      # @param params [Array]
      def self.parse(params)
        klass = TYPE_LOOKUP[params[0]]
        klass ? klass.parse(params.clone) : nil
      end

    end
  end
end
"

test_file_header = "require 'spec_helper'

# !!!!THIS FILE IS AUTOGENERATED.  DO NOT HAND EDIT!!!!

describe Wamp::Client::Message do
"

test_file_footer = "
end
"

source_file = source_file_header
test_file = test_file_header

###############################################
# Iterate through message types
###############################################

messages = [
    {
        name: 'hello',
        description: 'Sent by a Client to initiate opening of a WAMP session to a Router attaching to a Realm.',
        formats: [
            '[HELLO, Realm|uri, Details|dict]'
        ]
    },
    {
        name: 'welcome',
        description: 'Sent by a Router to accept a Client.  The WAMP session is now open.',
        formats: [
            '[WELCOME, Session|id, Details|dict]'
        ]
    },
    {
        name: 'abort',
        description: 'Sent by a Peer*to abort the opening of a WAMP session.  No response is expected.',
        formats: [
            '[ABORT, Details|dict, Reason|uri]'
        ]
    },
    {
        name: 'goodbye',
        description: "Sent by a Peer to close a previously opened WAMP session.  Must be echo'ed by the receiving Peer.",
        formats: [
            '[GOODBYE, Details|dict, Reason|uri]'
        ]
    },
    {
        name: 'error',
        description: 'Error reply sent by a Peer as an error response to different kinds of requests.',
        formats: [
            '[ERROR, REQUEST.Type|int, REQUEST.Request|id, Details|dict, Error|uri]',
            '[ERROR, REQUEST.Type|int, REQUEST.Request|id, Details|dict, Error|uri, Arguments|list]',
            '[ERROR, REQUEST.Type|int, REQUEST.Request|id, Details|dict, Error|uri, Arguments|list, ArgumentsKw|dict]'
        ]
    },
    {
        name: 'publish',
        description: 'Sent by a Publisher to a Broker to publish an event.',
        formats: [
            '[PUBLISH, Request|id, Options|dict, Topic|uri]',
            '[PUBLISH, Request|id, Options|dict, Topic|uri, Arguments|list]',
            '[PUBLISH, Request|id, Options|dict, Topic|uri, Arguments|list, ArgumentsKw|dict]'
        ]
    },
    {
        name: 'published',
        description: 'Acknowledge sent by a Broker to a Publisher for acknowledged publications.',
        formats: [
            '[PUBLISHED, PUBLISH.Request|id, Publication|id]'
        ]
    },
    {
        name: 'subscribe',
        description: 'Subscribe request sent by a Subscriber to a Broker to subscribe to a topic.',
        formats: [
            '[SUBSCRIBE, Request|id, Options|dict, Topic|uri]'
        ]
    },
    {
        name: 'subscribed',
        description: 'Acknowledge sent by a Broker to a Subscriber to acknowledge a subscription.',
        formats: [
            '[SUBSCRIBED, SUBSCRIBE.Request|id, Subscription|id]'
        ]
    },
    {
        name: 'unsubscribe',
        description: 'Unsubscribe request sent by a Subscriber to a Broker to unsubscribe a subscription.',
        formats: [
            '[UNSUBSCRIBE, Request|id, SUBSCRIBED.Subscription|id]'
        ]
    },
    {
        name: 'unsubscribed',
        description: 'Acknowledge sent by a Broker to a Subscriber to acknowledge unsubscription.',
        formats: [
            '[UNSUBSCRIBED, UNSUBSCRIBE.Request|id]'
        ]
    },
    {
        name: 'event',
        description: 'Event dispatched by Broker to Subscribers for subscriptions the event was matching.',
        formats: [
            '[EVENT, SUBSCRIBED.Subscription|id, PUBLISHED.Publication|id, Details|dict]',
            '[EVENT, SUBSCRIBED.Subscription|id, PUBLISHED.Publication|id, Details|dict, PUBLISH.Arguments|list]',
            '[EVENT, SUBSCRIBED.Subscription|id, PUBLISHED.Publication|id, Details|dict, PUBLISH.Arguments|list, PUBLISH.ArgumentsKw|dict]'
        ]
    },
    {
        name: 'call',
        description: 'Call as originally issued by the _Caller_ to the _Dealer_.',
        formats: [
            '[CALL, Request|id, Options|dict, Procedure|uri]',
            '[CALL, Request|id, Options|dict, Procedure|uri, Arguments|list]',
            '[CALL, Request|id, Options|dict, Procedure|uri, Arguments|list, ArgumentsKw|dict]'
        ]
    },
    {
        name: 'result',
        description: 'Result of a call as returned by _Dealer_ to _Caller_.',
        formats: [
            '[RESULT, CALL.Request|id, Details|dict]',
            '[RESULT, CALL.Request|id, Details|dict, YIELD.Arguments|list]',
            '[RESULT, CALL.Request|id, Details|dict, YIELD.Arguments|list, YIELD.ArgumentsKw|dict]'
        ]
    },
    {
        name: 'register',
        description: 'A _Callees_ request to register an endpoint at a _Dealer_.',
        formats: [
            '[REGISTER, Request|id, Options|dict, Procedure|uri]'
        ]
    },
    {
        name: 'registered',
        description: 'Acknowledge sent by a _Dealer_ to a _Callee_ for successful registration.',
        formats: [
            '[REGISTERED, REGISTER.Request|id, Registration|id]'
        ]
    },
    {
        name: 'unregister',
        description: 'A _Callees_ request to unregister a previously established registration.',
        formats: [
            '[UNREGISTER, Request|id, REGISTERED.Registration|id]'
        ]
    },
    {
        name: 'unregistered',
        description: 'Acknowledge sent by a _Dealer_ to a _Callee_ for successful unregistration.',
        formats: [
            '[UNREGISTERED, UNREGISTER.Request|id]'
        ]
    },
    {
        name: 'invocation',
        description: 'Actual invocation of an endpoint sent by _Dealer_ to a _Callee_.',
        formats: [
            '[INVOCATION, Request|id, REGISTERED.Registration|id, Details|dict]',
            '[INVOCATION, Request|id, REGISTERED.Registration|id, Details|dict, CALL.Arguments|list]',
            '[INVOCATION, Request|id, REGISTERED.Registration|id, Details|dict, CALL.Arguments|list, CALL.ArgumentsKw|dict]'
        ]
    },
    {
        name: 'yield',
        description: 'Actual yield from an endpoint sent by a _Callee_ to _Dealer_.',
        formats: [
            '[YIELD, INVOCATION.Request|id, Options|dict]',
            '[YIELD, INVOCATION.Request|id, Options|dict, Arguments|list]',
            '[YIELD, INVOCATION.Request|id, Options|dict, Arguments|list, ArgumentsKw|dict]'
        ]
    },
    {
        name: 'challenge',
        description: 'The "CHALLENGE" message is used with certain Authentication Methods. During authenticated session establishment, a *Router* sends a challenge message.',
        formats: [
            '[CHALLENGE, AuthMethod|string, Extra|dict]'
        ]
    },
    {
        name: 'authenticate',
        description: 'The "AUTHENTICATE" message is used with certain Authentication Methods.  A *Client* having received a challenge is expected to respond by sending a signature or token.',
        formats: [
            '[AUTHENTICATE, Signature|string, Extra|dict]'
        ]
    },
    {
        name: 'cancel',
        description: 'The "CANCEL" message is used with the Call Canceling advanced feature.  A _Caller_ can cancel and issued call actively by sending a cancel message to the _Dealer_.',
        formats: [
            '[CANCEL, CALL.Request|id, Options|dict]'
        ]
    },
    {
        name: 'interrupt',
        description: 'The "INTERRUPT" message is used with the Call Canceling advanced feature.  Upon receiving a cancel for a pending call, a _Dealer_ will issue an interrupt to the _Callee_.',
        formats: [
            '[INTERRUPT, INVOCATION.Request|id, Options|dict]'
        ]
    }
]

messages.each do |message|

  ###############################################
  # Generate Lookups
  ###############################################
  count = 0
  params_lookup = {}
  params = []
  required_count = 0
  param_formats = ''
  message[:formats].each do |format|
    param_formats += '      #   ' + format + "\n"

    # Generate the params
    temp_format = format.delete(' ')
    temp_format = temp_format.delete('[')
    temp_format = temp_format.delete(']')
    temp_format = temp_format.gsub('.', '_')
    format_params = temp_format.split(',')
    format_params.shift

    format_params.each do |format_param|
      parsed_param = format_param.split('|')
      param_name = parsed_param[0].downcase
      param_type = parsed_param[1]

      if params_lookup[param_name].nil?
        params.push(
            {
                name: param_name,
                type: param_type,
                required: count == 0
            })
        params_lookup[param_name] = true
      end
    end

    if count == 0
      required_count = params.count
    end

    count += 1
  end

  ###############################################
  # Source File
  ###############################################
  source_file += "\n"
  source_file += '      # ' + message[:name].capitalize + "\n"
  source_file += '      # ' + message[:description] + "\n"
  source_file += "      # Formats:\n"
  source_file += param_formats
  source_file += '      class ' + message[:name].capitalize + " < Base\n"

  # Generate the local variables
  source_file += '        attr_accessor'
  count = 0
  params.each do |param|
    source_file += ',' unless count == 0
    source_file += " :#{param[:name]}"
    count += 1
  end
  source_file += "\n"

  # Generate the constructor
  source_file += "\n        def initialize("
  count = 0
  checks = ''
  setters = ''
  params.each do |param|
    setters += "          self.#{param[:name]} = #{param[:name]}\n"

    source_file += ', ' if count > 0
    if param[:required]
      source_file += "#{param[:name]}"
      checks += "          self.class.check_#{param[:type]}('#{param[:name]}', #{param[:name]})\n"
    else
      source_file += "#{param[:name]}=nil"
      checks += "          self.class.check_#{param[:type]}('#{param[:name]}', #{param[:name]}, true)\n"
    end

    count += 1
  end
  source_file += ")\n\n"
  source_file += checks + "\n"
  source_file += setters + "\n"
  source_file += "        end\n"

  # Generate the 'type' method
  source_file += "\n        def self.type\n          Types::#{message[:name].upcase}\n        end\n"

  # Generate the parser
  source_file += "\n        def self.parse(params)\n"
  source_file += "\n          self.check_gte('params list', #{required_count+1}, params.count)\n"
  source_file += "          self.check_equal('message type', self.type, params[0])\n"
  source_file += "\n          params.shift\n          self.new(*params)\n"
  source_file += "\n        end\n"

  # Generate the payload
  source_file += "\n        def payload\n"

  optional_params = []
  params.each do |param|
    unless param[:required]
      optional_params.push(param)
      source_file += "          self.#{param[:name]} ||= #{empty_value_from_type(param[:type])}\n"
    end
  end
  source_file += "\n"

  source_file += "          payload = [self.class.type]\n"
  optional_count = 0
  params.each do |param|
    if param[:required]
      source_file += "          payload.push(self.#{param[:name]})\n"
    else
      optional_count += 1
      source_file += "\n          return payload if (self.#{param[:name]}.empty?"

      # Insert remaining parameters
      for i in optional_count..(optional_params.size-1) do
        source_file += " and self.#{optional_params[i][:name]}.empty?"
      end

      source_file += ")\n"
      source_file += "          payload.push(self.#{param[:name]})\n"
    end
  end
  source_file += "\n          payload\n"
  source_file += "        end\n"

  # Generate the string
  source_file += "\n        def to_s\n"
  source_file += "          '#{message[:name].upcase} > ' + self.payload.to_s\n"
  source_file += "        end\n"


  source_file += "\n      end\n"

  ###############################################
  # Test File
  ###############################################

  value_array = []
  params.each do |param|
    if param[:required]
      value_array.push(value_from_type(param[:type]))
    end
  end

  class_name = "Wamp::Client::Message::#{message[:name].capitalize}"

  test_file += "\n  describe #{class_name} do\n"

  # Generate Constructor Test
  test_file += "\n    it 'creates the message object' do\n"
  test_file += "      params = [#{value_array.join(',')}]\n"
  test_file += "      object = #{class_name}.new(*params)\n\n"
  params.each do |param|
    if param[:required]
      test_file += "      expect(object.#{param[:name]}).to eq(#{value_from_type(param[:type])})\n"
    end
  end
  test_file += "      expect(object.is_a?(#{class_name})).to eq(true)\n"
  test_file += "    end\n"

  # Generate Parser Test
  test_file += "\n    it 'parses the message and creates an object' do\n"
  test_file += "      params = [#{message_type_lookup[message[:name].upcase]},#{value_array.join(',')}]\n"
  test_file += "      object = #{class_name}.parse(params)\n\n"
  params.each do |param|
    if param[:required]
      test_file += "      expect(object.#{param[:name]}).to eq(#{value_from_type(param[:type])})\n"
    end
  end
  test_file += "      expect(object.is_a?(#{class_name})).to eq(true)\n"
  test_file += "    end\n"

  # Generate Global Parser Test
  test_file += "\n    it 'globally parses the message and creates an object' do\n"
  test_file += "      params = [#{message_type_lookup[message[:name].upcase]},#{value_array.join(',')}]\n"
  test_file += "      object = Wamp::Client::Message.parse(params)\n\n"
  params.each do |param|
    if param[:required]
      test_file += "      expect(object.#{param[:name]}).to eq(#{value_from_type(param[:type])})\n"
    end
  end
  test_file += "      expect(object.is_a?(#{class_name})).to eq(true)\n"
  test_file += "    end\n"

  # Generate Payload Test
  test_file += "\n    it 'generates the payload' do\n"
  test_file += "      params = [#{value_array.join(',')}]\n"
  test_file += "      object = #{class_name}.new(*params)\n"
  test_file += "      payload = object.payload\n\n"
  count = 0
  test_file += "      expect(payload.count).to eq(#{value_array.count+1})\n"
  test_file += "      expect(payload[0]).to eq(#{message_type_lookup[message[:name].upcase]})\n"
  value_array.each do |value|
    test_file += "      expect(payload[#{count+1}]).to eq(#{value})\n"
    count += 1
  end
  test_file += "    end\n"

  number_of_optional_params = 0

  # Generate non-required parameter tests
  params.each do |param|
    unless param[:required]
      number_of_optional_params += 1

      temp_value_array = Array.new(value_array)
      temp_value_array.push(value_from_type(param[:type]))

      test_file += "\n    describe 'checks optional parameter #{param[:name]}' do\n"

      # Generate Constructor Test
      test_file += "\n      it 'creates the message object' do\n"
      test_file += "        params = [#{temp_value_array.join(',')}]\n"
      test_file += "        object = #{class_name}.new(*params)\n\n"
      test_file += "        expect(object.is_a?(#{class_name})).to eq(true)\n"
      test_file += "      end\n"

      # Generate Parser Test
      test_file += "\n      it 'parses the message and creates an object' do\n"
      test_file += "        params = [#{message_type_lookup[message[:name].upcase]},#{temp_value_array.join(',')}]\n"
      test_file += "        object = #{class_name}.parse(params)\n\n"
      test_file += "        expect(object.is_a?(#{class_name})).to eq(true)\n"
      test_file += "      end\n"

      # Generate Payload Test
      test_file += "\n      it 'generates the payload' do\n"
      test_file += "        params = [#{temp_value_array.join(',')}]\n"
      test_file += "        object = #{class_name}.new(*params)\n"
      test_file += "        payload = object.payload\n\n"
      count = 0
      test_file += "        expect(payload.count).to eq(#{temp_value_array.count+1})\n"
      test_file += "        expect(payload[0]).to eq(#{message_type_lookup[message[:name].upcase]})\n"
      temp_value_array.each do |value|
        test_file += "        expect(payload[#{count+1}]).to eq(#{value})\n"
        count += 1
      end
      test_file += "      end\n"

      test_file += "\n    end\n"

      value_array.push(empty_value_from_type(param[:type]))
    end
  end

  ## Test the final one and make sure they omit
  if number_of_optional_params > 0

    # Generate check params
    check_params = []
    for i in 0..(value_array.size-number_of_optional_params-1) do
      check_params.push(value_array[i])
    end

    test_file += "\n    describe 'checks optional parameters' do\n"

    # Generate Constructor Test
    test_file += "\n      it 'creates the message object' do\n"
    test_file += "        params = [#{value_array.join(',')}]\n"
    test_file += "        object = #{class_name}.new(*params)\n\n"
    test_file += "        expect(object.is_a?(#{class_name})).to eq(true)\n"
    test_file += "      end\n"

    # Generate Parser Test
    test_file += "\n      it 'parses the message and creates an object' do\n"
    test_file += "        params = [#{message_type_lookup[message[:name].upcase]},#{value_array.join(',')}]\n"
    test_file += "        object = #{class_name}.parse(params)\n\n"
    test_file += "        expect(object.is_a?(#{class_name})).to eq(true)\n"
    test_file += "      end\n"

    # Generate Payload Test
    test_file += "\n      it 'generates the payload' do\n"
    test_file += "        params = [#{value_array.join(',')}]\n"
    test_file += "        object = #{class_name}.new(*params)\n"
    test_file += "        payload = object.payload\n\n"
    count = 0
    test_file += "        expect(payload.count).to eq(#{check_params.count+1})\n"
    test_file += "        expect(payload[0]).to eq(#{message_type_lookup[message[:name].upcase]})\n"
    check_params.each do |value|
      test_file += "        expect(payload[#{count+1}]).to eq(#{value})\n"
      count += 1
    end
    test_file += "      end\n"

    test_file += "\n    end\n"

  end

  test_file += "\n  end\n"

end

source_file += source_file_footer
test_file += test_file_footer

File.open('message.rb.tmp', 'w') { |file| file.write(source_file) }
File.open('message_spec.rb.tmp', 'w') { |file| file.write(test_file) }

