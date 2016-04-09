# WampClient

**!!!!UNDER DEVELOPMENT!!!!**

Client for talking to a WAMP Router.  This is defined at

    https://tools.ietf.org/html/draft-oberstet-hybi-tavendo-wamp-02

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wamp_client'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wamp_client

## Usage

### Connection
The connection object is used to instantiate and maintain a WAMP session as well as the underlying transport.  A user
creates a connection and then operates on the session once the session has been established.

#### Creating a connection
A connection can be created as follows

```ruby
require 'wamp_client'

options = {
    uri: 'ws://127.0.0.1:8080/ws',
    realm: 'realm1'
}
connection = WampClient::Connection.new(options)

connection.on_join do |session, details|
  puts "Session Open"

  # Register for something
  def add(args, kwargs, details)
    args[0] + args[1]
  end
  session.register('com.example.procedure', method(:add)) do |registration, error, details|

    # Call It
    session.call('com.example.procedure', [3,4]) do |result, error, details|
      if result
        puts result.args[0] # => 7
      end
    end

  end


end

connection.open
```

#### Closing a connection
A connection is closed by simply calling "close"

```ruby
connection.close
```

Note that the connection will still call "on_leave" and "on_disconnect" as it closes the session and the transport

#### Callbacks
A session has the following callbacks

**on_connect** - Called when the transport is opened
```ruby
connection.on_connect do

end
```

**on_join** - Called when the session is established
```ruby
connection.on_join do |session, details|

end
```

**on_leave** - Called when the session is terminated
```ruby
connection.on_leave do |reason, details|

end
```

**on_disconnect** - Called when the connection is terminated
```ruby
connection.on_disconnect do |reason|

end
```

**oon_challenge** - Called when an authentication challenge is created
```ruby
connection.on_challenge do |authmethod, extra|

end
```

### Authentication
The library supports authentication.  Here is how to perform the different methods

#### WAMPCRA
To perform WAMP CRA, do the following

```ruby
require 'wamp_client'

options = {
    uri: 'ws://127.0.0.1:8080/ws',
    realm: 'realm1',
    authid: 'joe',
    authmethods: ['wampcra']
}
connection = WampClient::Connection.new(options)

connection.on_challenge do |authmethod, extra|
  puts 'Challenge'
  if authmethod == 'wampcra'
    WampClient::Auth::Cra.sign('secret', extra[:challenge])
  else
    raise RuntimeError, "Unsupported auth method #{authmethod}"
  end
end

connection.on_join do |session, details|
  puts "Session Open"
end

connection.open
```

### Handlers and Callbacks
This library makes extensive use of "blocks", "lambdas", "procs", and method pointers for any returned values because
all communication is performed asynchronously.  The library defines two types of methods

 - handlers - Can be called **AT ANY TIME**.  These can be blocks, lambdas, procs, or method pointers
 - callbacks - Only invoked in response to specific call.  These are only blocks

Note that all callbacks can be set to nil, handlers however cannot since the user is explicitly setting them up.

#### Handlers
All handlers are called with the following parameters

 - args [Array] - Array of arguments
 - kwargs [Hash] - Hash of key/value arguments
 - details [Hash] - Hash containing some details about the call

Some examples of this are shown below

**lambda**

```ruby
handler = lambda do |args, kwargs, details|
    # TODO: Do Something!!
end
session.subscribe('com.example.topic', handler)
```

**method**

```ruby
def handler(args, kwargs, details)
    # TODO: Do Something!!
end
session.subscribe('com.example.topic', method(:handler))
```

#### Callbacks
All callbacks are called with the following parameters

 - result [Object] - Some object with the result information (depends on the call)
 - error [Hash] - Hash containing "error", "args", and "kwargs" if an error occurred
 - details [Hash] - Hash containing some details about the call

An example of this is shown below

```ruby
session.call('com.example.procedure') do |result, error, details|
    # TODO: Do something
end
```

### Topic Subscriptions and Publications

#### Subscribe
This method subscribes to a topic.  The prototype for the method is

```ruby
subscribe(topic, handler, options={}, &callback)
```

where the parameters are defined as

 - topic [String] - The topic to subscribe to
 - handler [lambda] - The handler(args, kwargs, details) when an event is received
 - options [Hash] - The options for the subscription
 - callback [block] - The callback(subscription, error, details) called to signal if the subscription was a success or not

To subscribe, do the following

```ruby
handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.subscribe('com.example.topic', handler)
```

If you would like confirmation of the success of the subscription, do the following

```ruby
handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.subscribe('com.example.topic', handler) do |subscription, error, details|
  # TODO: Do something
end
```

Options are

 - match [String] - "exact", "prefix", or "wildcard"

#### Unsubscribe
This method unsubscribes from a topic.  The prototype for the method is as follows

```ruby
def unsubscribe(subscription, &callback)
```

where the parameters are defined as

 - subscription [Subscription] - The subscription object from when the subscription was created
 - callback [block] - The callback(subscription, error, details) called to signal if the unsubscription was a success or not

To unsubscribe, do the following

```ruby
handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.subscribe('com.example.topic', handler) do |subscription, error, details|
  @subscription = subscription
end

# At some later time...

session.unsubscribe(@subscription)

# or ...

@subscription.unsubscribe

```

#### Publish
This method publishes an event to all of the subscribers.  The prototype for the method is

```ruby
publish(topic, args=nil, kwargs=nil, options={}, &callback)
```

where the parameters are defined as

 - topic [String] - The topic to publish the event to
 - args [Array] - The arguments
 - kwargs [Hash] - The keyword arguments
 - options [Hash] - The options for the subscription
 - callback [block] - The callback(publish, error, details) is called to signal if the publish was a success or not

To publish, do the following

```ruby
session.publish('com.example.topic', [15], {param: value})
```

If you would like confirmation, do the following

```ruby
session.publish('com.example.topic', [15], {param: value}, {acknowledge: true}, callback) do |publish, error, details|
  # TODO: Do something
end
```

Options are

 - acknowledge [Boolean] - set to "true" if you want the Broker to acknowledge if the Publish was successful or not
 - disclose_me [Boolean] - "true" if the publisher would like the subscribers to know his identity
 - exclude [Array[Integer]] - Array of session IDs to exclude
 - exclude_authid [Array[String]] - Array of auth IDs to exclude
 - exclude_authrole [Array[String]] - Array of auth roles to exclude
 - eligible [Array[Integer]] - Array of session IDs to include
 - eligible_authid [Array[String]] - Array of auth IDs to include
 - eligible_authrole [Array[String]] - Array of auth roles to include
 - exclude_me [Boolean] - set to "false" if you would like yourself to receive an event that you fired

### Procedure Registrations and Calls

#### Register
This method registers to a procedure.  The prototype for the method is

```ruby
register(procedure, handler, options={}, &callback)
```

where the parameters are defined as

 - procedure [String] - The procedure to register for
 - handler [lambda] - The handler(args, kwargs, details) when a invocation is received
 - options [Hash] - The options for the registration
 - callback [block] - The callback(registration, error, details) called to signal if the registration was a success or not

To register, do the following

```ruby
handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.register('com.example.procedure', handler)
```

If you would like confirmation of the success of the registration, do the following

```ruby
handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.register('com.example.procedure', handler, {}, callback) do |registration, error, details|
  # TODO: Do something
end
```

Options are

 - match [String] - "exact", "prefix", or "wildcard"
 - invoke [String] - "single", "roundrobin", "random", "first", "last"

#### Unregister
This method unregisters from a procedure.  The prototype for the method is as follows

```ruby
def unregister(registration, &callback)
```

where the parameters are defined as

 - registration [Registration] - The registration object from when the registration was created
 - callback [lambda] - The callback(registration, error, details) called to signal if the unregistration was a success
   or not

To unregister, do the following

```ruby
handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.register('com.example.procedure', handler, {}) do |registration, error, details|
  @registration = registration
end

# At some later time...

session.unregister(@registration)

# or ...

@registration.unregister

```

#### Call
This method calls a procedure.  The prototype for the method is

```ruby
call(procedure, args=nil, kwargs=nil, options={}, &callback)
```

where the parameters are defined as

 - procedure [String] - The procedure to invoke
 - args [Array] - The arguments
 - kwargs [Hash] - The keyword arguments
 - options [Hash] - The options for the call
 - callback [block] - The callback(result, error, details) called to signal if the call was a success or not

To call, do the following

```ruby
session.call('com.example.procedure', [15], {param: value}, {}) do |result, error, details|
  # TODO: Do something
  args = result.args
  kwargs = result.kwargs
end
```

Options are

 - receive_progress [Boolean] - "true" if you support results being able to be sent progressively
 - disclose_me [Boolean] - "true" if the caller would like the callee to know the identity

## Contributing

1. Fork it ( https://github.com/ericchapman/ruby_wamp_client )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### TODOs

 - progressive_call_results (callee)
 - call_timeout
 - call_canceling

### Testing

The unit tests are run as follows

    $ bundle exec rake spec

### Scripts

#### Message

The *lib/wamp_client/message.rb* file and the *spec/message_spec.rb* file are autogenerated using the script
*scripts/gen_message.rb*.  This is done as follows

    $ cd scripts
    $ ./gen_message.rb
    $ mv message.rb.tmp ../lib/wamp_client/message.rb
    $ mv message_spec.rb.tmp ../spec/message_spec.rb

As I was writing the code for the messages I caught myself cutting and pasting allot and decided these would be
better suited to be autogenerated.
