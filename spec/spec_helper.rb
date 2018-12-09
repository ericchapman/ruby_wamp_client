require 'simplecov'
SimpleCov.start

require 'wamp/client'

if ENV['CODECOV_TOKEN']
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

Dir[File.expand_path('spec/support/**/*.rb')].each { |f| require f }

require "rspec/em"

Wamp::Client.log_level = :error

