# WampClient

**UNDER DEVELOPMENT!**

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

TODO: Write usage instructions here

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
