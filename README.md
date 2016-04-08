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

### Topic Subscriptions and Publications

#### Subscribe
This method subscribes to a topic.  The prototype for the method is

```ruby
subscribe(topic, handler, options={}, callback=nil)
```

where the parameters are defined as

 - topic [String] - The topic to subscribe to
 - handler [lambda] - The handler(args, kwargs, details) when an event is received
 - options [Hash] - The options for the subscription
 - callback [lambda] - The callback(subscription, error, details) called to signal if the subscription was a success or not

To subscribe, do the following

```ruby
handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.subscribe('com.example.topic', handler)
```

If you would like confirmation of the success of the subscription, do the following

```ruby
callback = lambda do |subscription, error, details|
  # TODO: Do something
end

handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.subscribe('com.example.topic', handler, {}, callback)
```

#### Unsubscribe
This method unsubscribes from a topic.  The prototype for the method is as follows

```ruby
def unsubscribe(subscription, callback=nil)
```

where the parameters are defined as

 - subscription [Subscription] - The subscription object from when the subscription was created
 - callback [lambda] - The callback(subscription, error, details) called to signal if the unsubscription was a success or not

To unsubscribe, do the following

```ruby
callback = lambda do |subscription, error, details|
  @subscription = subscription
end

handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.subscribe('com.example.topic', handler, {}, callback)

# At some later time...

session.unsubscribe(@subscription)

# or ...

@subscription.unsubscribe

```

#### Publish
This method publishes an event to all of the subscribers.  The prototype for the method is

```ruby
publish(topic, args=nil, kwargs=nil, options={}, callback=nil)
```

where the parameters are defined as

 - topic [String] - The topic to publish the event to
 - args [Array] - The arguments
 - kwargs [Hash] - The keyword arguments
 - options [Hash] - The options for the subscription
 - callback [lambda] - The callback(publish, error, details) is called to signal if the publish was a success or not

To publish, do the following

```ruby
session.publish('com.example.topic', [15], {param: value})
```

If you would like confirmation, do the following

```ruby
callback = lambda do |publish, error, details|
  # TODO: Do something
end

session.publish('com.example.topic', [15], {param: value}, {acknowledge: true}, callback)
```

Options are

 - acknowledge - set to "true" if you want the Broker to acknowledge if the Publish was successful or not

### Procedure Registrations and Calls

#### Register
This method registers to a procedure.  The prototype for the method is

```ruby
register(procedure, handler, options={}, callback=nil)
```

where the parameters are defined as

 - procedure [String] - The procedure to register for
 - handler [lambda] - The handler(args, kwargs, details) when a invocation is received
 - options [Hash] - The options for the registration
 - callback [lambda] - The callback(registration, error, details) called to signal if the registration was a success or not

To register, do the following

```ruby
handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.register('com.example.procedure', handler)
```

If you would like confirmation of the success of the registration, do the following

```ruby
callback = lambda do |registration, error, details|
  # TODO: Do something
end

handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.register('com.example.procedure', handler, {}, callback)
```

#### Unregister
This method unregisters from a procedure.  The prototype for the method is as follows

```ruby
def unregister(registration, callback=nil)
```

where the parameters are defined as

 - registration [Registration] - The registration object from when the registration was created
 - callback [lambda] - The callback(registration, error, details) called to signal if the unregistration was a success
   or not

To unregister, do the following

```ruby
callback = lambda do |registration, error, details|
  @registration = registration
end

handler = lambda do |args, kwargs, details|
  # TODO: Do something
end

session.register('com.example.procedure', handler, {}, callback)

# At some later time...

session.unregister(@registration)

# or ...

@registration.unregister

```

#### Call
This method calls a procedure.  The prototype for the method is

```ruby
call(procedure, args=nil, kwargs=nil, options={}, callback=nil)
```

where the parameters are defined as

 - procedure [String] - The procedure to invoke
 - args [Array] - The arguments
 - kwargs [Hash] - The keyword arguments
 - options [Hash] - The options for the call
 - callback [lambda] - The callback(result, error, details) called to signal if the call was a success or not

To call, do the following

```ruby
callback = lambda do |result, error, details|
  # TODO: Do something
end

session.call('com.example.procedure', [15], {param: value}, {}, callback)
```

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
    $ mv message.rb.tmp ../lib/wamp_client/message.rb
    $ mv message_spec.rb.tmp ../spec/message_spec.rb

As I was writing the code for the messages I caught myself cutting and pasting allot and decided these would be
better suited to be autogenerated.
