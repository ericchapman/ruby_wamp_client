require 'time'
require 'logger'

module Wamp
  module Client
    module Logging

      LOG_LEVEL_LOOKUP = {
          error: Logger::ERROR,
          debug: Logger::DEBUG,
          info: Logger::INFO,
          warn: Logger::WARN,
      }

      class Pretty < Logger::Formatter
        def call(severity, time, program_name, message)
          "#{time.utc.iso8601(3)} #{::Process.pid} #{severity[0]}: #{message}\n"
        end
      end

      class WithoutTimestamp < Pretty
        def call(severity, time, program_name, message)
          "#{::Process.pid} #{severity[0]}: #{message}\n"
        end
      end

      # Returns the logger object
      #
      def self.logger
        unless defined?(@logger)
          $stdout.sync = true unless ENV['RAILS_ENV'] == "production"
          @logger = Logger.new $stdout
          @logger.level = Logger::INFO
          @logger.formatter = ENV['DYNO'] ? WithoutTimestamp.new : Pretty.new
        end
        @logger
      end

      # Sets the log level
      #
      # @param log_level [Symbol] - the desired log level
      def self.log_level=(log_level)
        self.logger.level = LOG_LEVEL_LOOKUP[log_level.to_sym] || :info
      end
    end
  end
end