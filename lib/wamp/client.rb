=begin

Copyright (c) 2018 Eric Chapman

MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=end

require 'wamp/client/version'
require 'wamp/client/message'
require 'wamp/client/serializer'
require 'wamp/client/connection'
require 'wamp/client/session'
require 'wamp/client/auth'
require 'wamp/client/defer'
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