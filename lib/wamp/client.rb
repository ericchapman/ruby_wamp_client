require 'wamp/client/version'
require 'wamp/client/message'
require 'wamp/client/serializer'
require 'wamp/client/connection'
require 'wamp/client/session'
require 'wamp/client/auth'
require 'wamp/client/response'
require 'wamp/client/logging'

module Wamp
  module Client

    # Returns the logger object
    #
    def self.logger
      Logging.logger
    end

    # Sets the log level
    #
    # @param log_level [Symbol] - the desired log level
    def self.log_level=(log_level)
      Logging.log_level = log_level
    end

  end
end