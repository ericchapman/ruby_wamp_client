require 'wamp/client/version'
require 'wamp/client/message'
require 'wamp/client/serializer'
require 'wamp/client/connection'
require 'wamp/client/session'
require 'wamp/client/auth'
require 'wamp/client/response'
require 'logger'

module Wamp
  module Client

    # Returns the logger object
    #
    def self.logger
      unless defined?(@logger)
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::INFO
      end
      @logger
    end

    # Sets the log level
    #
    # @param log_level [Symbol] - the desired log level
    def self.log_level=(log_level)
      level =
          case log_level
          when :error
            Logger::ERROR
          when :debug
            Logger::DEBUG
          when :fatal
            Logger::FATAL
          when :warn
            Logger::WARN
          else
            Logger::INFO
          end
      self.logger.level = level
    end

  end
end