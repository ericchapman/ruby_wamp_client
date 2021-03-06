# Wamp::Client

[![Gem Version](https://badge.fury.io/rb/wamp_client.svg)](https://badge.fury.io/rb/wamp_client)
[![Circle CI](https://circleci.com/gh/ericchapman/ruby_wamp_client/tree/master.svg?&style=shield&circle-token=92813c17f9c9510c4c644e41683e7ba2572e0b2a)](https://circleci.com/gh/ericchapman/ruby_wamp_client/tree/master)
[![Codecov](https://img.shields.io/codecov/c/github/ericchapman/ruby_wamp_client/master.svg)](https://codecov.io/github/ericchapman/ruby_wamp_client)

Client for talking to a WAMP Router.  This is defined [here](https://tools.ietf.org/html/draft-oberstet-hybi-tavendo-wamp-02)

Note: [wamp_rails](https://github.com/ericchapman/ruby_wamp_rails) has been deprecated in favor of
[wamp-worker](https://github.com/ericchapman/ruby_wamp_worker) which allows this library to be run
in a RAILS worker.  It will also allow integration with Sidekiq to support allowing handlers to
execute in the background.

## Revision History

 - v0.2.2:
   - Fixed "time" issue with logging
 - v0.2.1:
   - Logging cleanup
 - v0.2.0:
   - Breaking changes to the API including
     - Moving CallResult, CallError, CallDefer, and ProgressiveCallDefer to common module called "Response"
     - Results to calls return a Hash object instead of a CallResult object
     - Catches "StandardError" instead of "Exception"
     - Session object has been split into *request* and *manager* objects
     - Callback subscriptions are now all "on(event)"
   - Lots of code cleanup and combining handling of methods
 - v0.1.4:
   - Wrapped defer logic inside of yield method for cleanliness
 - v0.1.3:
   - Improved logging
   - Minor code cleanup
   - Added including backtrace when unknown error occurs in "call"
 - v0.1.2:
   - Updated logging to use the standard Ruby logger
 - v0.1.1:
   - Added 'add_tick_loop' method to the transport to abstract the event machine
 - v0.1.0:
   - BREAKING CHANGE - Changed all of the namespaces to be "Wamp::Client"
 - v0.0.9:
   - Added support for transport override and 'faye-websocket' transport
   - Added "on(event)" callback (still support legacy methods)
   - Increased Test Coverage for 'Transport' and 'Connection' classes
 - v0.0.8:
   - Exposed 'yield' publicly to allow higher level libraries to not use the 'defer'
   - Removed library version dependency
 - v0.0.7:
   - Added 'session' to the 'details' in the callbacks and handlers
 - v0.0.6:
   - Added call cancelling
   - Added call timeout
 - v0.0.5:
   - Fixed issue where excluding the 'authmethods' and 'authid' was setting their values to none rather
     than excluding them.  This was being rejected by some routers
 - v0.0.4:
   - Added the ability to turn on logging by adding 'verbose' to the options
 - v0.0.3:
   - Fixed issue 1: Empty args will omit kwargs on some message types
 - v0.0.2:
   - Added defer call result support
   - Added progressive callee support
 - v0.0.1:
   - Initial Release

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

Note that once "connection.open" is called, the library will automatically attempt to reconnect if the connection
closes for any reason.  Calling "connection.close" will stop the reconnect logic as well as close the connection if it
is open

#### Creating a connection
A connection can be created as follows

```ruby
require 'wamp/client'

connection = Wamp::Client::Connection.new(uri: 'ws://127.0.0.1:8080/ws', realm: 'realm1')

connection.on(:join) do |session, details|
  puts "Session Open"

  # Register for something
  def add(args, kwargs, details)
    args[0] + args[1]
  end
  session.register('com.example.procedure', method(:add)) do |registration, error, details|

    # Call It
    session.call('com.example.procedure', [3,4]) do |result, error, details|
      if result
        puts result[:args][0] # => 7
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

Note that the connection will still call "on(:leave)" and "on(:disconnect)" as it closes the session and the transport

#### Callbacks
A connection has the following callbacks

**on(:connect)** - Called when the transport is opened
```ruby
connection.on(:connect) do

end
```

**on(:join)** - Called when the session is established
```ruby
connection.on(:join) do |session, details|

end
```

**on(:leave)** - Called when the session is terminated
```ruby
connection.on(:leave) do |reason, details|

end
```

**on(:disconnect)** - Called when the connection is terminated
```ruby
connection.on(:disconnect) do |reason|

end
```

**on(:challenge)** - Called when an authentication challenge is created
```ruby
connection.on(:challenge) do |authmethod, extra|

end
```

#### Event Tick
You can run a task on every event machine tick by using the transport class
method 'add_tick_loop'

```ruby
require 'wamp/client'

connection = Wamp::Client::Connection.new(uri: 'ws://127.0.0.1:8080/ws', realm: 'realm1')

connection.transport_class.add_tick_loop do
  # Do something periodic
end

``` 

#### Overriding Transport
By default, the library will use the "websocket-eventmachine-client" Gem as the websocket transport.
However the library also supports overriding this.

##### GEM: faye-websocket
To use this library, do the following

Install the "faye-websocket" Gem:

    $ gem install faye-websocket

Override the transport by doing the following:

```ruby
require 'wamp/client'

options = {
    uri: 'ws://127.0.0.1:8080/ws',
    realm: 'realm1',
    proxy: { # See faye-websocket documentation
      :origin  => 'http://username:password@proxy.example.com',
      :headers => {'User-Agent' => 'ruby'}
    },  
    transport: Wamp::Client::Transport::FayeWebSocket
}

connection = Wamp::Client::Connection.new(options)

# More code
``` 

Note that the "faye-wesbsocket" transport supports passing in a "proxy" as shown above.
 
##### Custom
You can also create your own transports by wrapping them in a "Transport" object
and including as shown above.  For more details on this, see the files in
"lib/wamp_client/transport"

### Authentication
The library supports authentication.  Here is how to perform the different methods

#### WAMPCRA
To perform WAMP CRA, do the following

```ruby
require 'wamp/client'

options = {
    uri: 'ws://127.0.0.1:8080/ws',
    realm: 'realm1',
    authid: 'joe',
    authmethods: ['wampcra']
}
connection = Wamp::Client::Connection.new(options)

connection.on(:challenge) do |authmethod, extra|
  puts 'Challenge'
  if authmethod == 'wampcra'
    Wamp::Client::Auth::Cra.sign('secret', extra[:challenge])
  else
    raise RuntimeError, "Unsupported auth method #{authmethod}"
  end
end

connection.on(:join) do |session, details|
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
 - details [Hash] - Hash containing some details about the call.  Details include
   - session [Wamp::Client::Session] - The session
   - etc.

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
 - details [Hash] - Hash containing some details about the call.  Details include
   - type [String] - The type of message
   - session [Wamp::Client::Session] - The session
   - etc.

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
def subscribe(topic, handler, options={}, &callback)
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
def publish(topic, args=nil, kwargs=nil, options={}, &callback)
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
def register(procedure, handler, options={}, &callback)
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
def call(procedure, args=nil, kwargs=nil, options={}, &callback)
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
  args = result[:args]
  kwargs = result[:kwargs]
end
```

Options are

 - receive_progress [Boolean] - "true" if you support results being able to be sent progressively
 - disclose_me [Boolean] - "true" if the caller would like the callee to know the identity
 - timeout [Integer] - specifies the number of milliseconds the caller should wait before cancelling the call

#### Errors
Errors can either be raised OR returned as shown below

```ruby
handler = lambda do |args, kwargs, details|
  raise RuntimeError,'error'
  # OR
  raise Wamp::Client::Response::CallError.new('wamp.error', ['some error'], {details: true})
  # OR
  Wamp::Client::Response::CallError.new('wamp.error', ['some error'], {details: true})
end
session.register('com.example.procedure', handler)
```

All 3 of the above examples will return a WAMP Error

#### Deferred Call
A deferred call refers to a call where the response needs to be asynchronously fetched before it can be returned to the
caller.  This is shown below

```ruby
def add(args, kwargs, details)
  defer = Wamp::Client::Response::CallDefer.new
  EM.add_timer(2) {  # Something Async
    defer.succeed(args[0]+args[1])
  }
  defer
end
session.register('com.example.procedure', method(:add))
```

Errors are returned as follows

```ruby
def add(args, kwargs, details)
  defer = Wamp::Client::Response::CallDefer.new
  EM.add_timer(2) {  # Something Async
    defer.fail(Wamp::Client::Response::CallError.new('test.error'))
  }
  defer
end
session.register('com.example.procedure', method(:add))
```

#### Progressive Calls
Progressive calls are ones that return the result in pieces rather than all at once.  They are invoked as follows

**Caller**

```ruby
results = []
session.call('com.example.procedure', [], {}, {receive_progress: true}) do |result, error, details|
  results = results + result[:args]
  unless details[:progress]
    puts results # => [1,2,3,4,5,6]
  end
end
```

**Callee**

```ruby
def add(args, kwargs, details)
  defer = Wamp::Client::Response::ProgressiveCallDefer.new
  EM.add_timer(2) {  # Something Async
    defer.progress(Wamp::Client::Response::CallResult.new([1,2,3]))
  }
  EM.add_timer(4) {  # Something Async
    defer.progress(Wamp::Client::Response::CallResult.new([4,5,6]))
  }
  EM.add_timer(6) {  # Something Async
    defer.succeed(Wamp::Client::Response::CallResult.new)
  }
  defer
end
session.register('com.example.procedure', method(:add))
```

#### Cancelled Call
A cancelled call will tell a callee who implements a progressive call to cancel it
 
**Caller**

```ruby
call = session.call('com.example.procedure', [15], {param: value}, {}) do |result, error, details|
  # TODO: Do something
  args = result[:args]
  kwargs = result[:kwargs]
end

# At some later time...

session.cancel(call, 'skip')  # Options are 'skip', 'kill', or 'killnowait'

# or ...

call.cancel('skip')
```

**Callee**

(There is probably a better way to do this.  This is a bad example)

```ruby
@interrupts = {}

def interrupt_handler(request, mode)
  @interrups[request] = mode
  
  # To trigger a custom error, either return something or raise a "CallError"
  # else the library will raise a standard error for you
end

def add(args, kwargs, details)
  defer = Wamp::Client::Response::ProgressiveCallDefer.new
  EM.add_timer(2) {  # Something Async
    if @interrupts[defer.request].nil?
      defer.progress(Wamp::Client::Response::CallResult.new([1,2,3]))
    end
  }
  EM.add_timer(4) {  # Something Async
    if @interrupts[defer.request].nil?
      defer.progress(Wamp::Client::Response::CallResult.new([4,5,6]))
    end
  }
  EM.add_timer(6) {  # Something Async
    if @interrupts[defer.request].nil?
      defer.succeed(Wamp::Client::Response::CallResult.new)
    end
    @interrupts.delete(request)
  }
  defer
end

session.register('com.example.procedure', method(:add), nil, method(:interrupt_handler))
```

Notes:

 - Once the response is cancelled, subsequent succeed, progress, or errors are ignored
   and not sent to the caller
 - Cancels are only processed by calls that had defers.  If the defer does not exist then
   the cancel is ignored

## Contributing

1. Fork it ( https://github.com/ericchapman/ruby_wamp_client )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### Testing

The unit tests are run as follows

    $ bundle exec rake spec

### Scripts

#### Message

The *lib/wamp_client/message.rb* file and the *spec/message_spec.rb* file are autogenerated using the script
*scripts/gen_message.rb*.  This is done as follows

    $ cd scripts
    $ ./gen_message.rb
    $ mv message.rb.tmp ../lib/wamp/client/message.rb
    $ mv message_spec.rb.tmp ../spec/wamp/client/message_spec.rb

As I was writing the code for the messages I caught myself cutting and pasting allot and decided these would be
better suited to be autogenerated.
