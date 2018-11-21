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

module Wamp
  module Client
    module Check

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods

        def check_equal(name, expected, value)
          raise ArgumentError, "The '#{name}' argument must have the value '#{expected}'.  Instead the value was '#{value}'" unless value == expected
        end

        def check_gte(name, expected, value)
          raise ArgumentError, "The '#{name}' argument must be greater than or equal to '#{expected}'.  Instead the value was '#{value}'" unless value >= expected
        end

        def check_nil(name, param, nil_allowed)
          raise ArgumentError, "The '#{name}' argument cannot be nil" if param.nil? and not nil_allowed
        end

        def check_int(name, param, nil_allowed=false)
          check_nil(name, param, nil_allowed)
          raise ArgumentError, "The '#{name}' argument must be an integer" unless param.nil? or param.is_a? Integer
        end

        def check_string(name, param, nil_allowed=false)
          check_nil(name, param, nil_allowed)
          raise ArgumentError, "The '#{name}' argument must be a string" unless param.nil? or param.is_a? String
        end

        def check_bool(name, param, nil_allowed=false)
          check_nil(name, param, nil_allowed)
          raise ArgumentError, "The '#{name}' argument must be a boolean" unless param.nil? or !!param == param
        end

        def check_dict(name, param, nil_allowed=false)
          check_nil(name, param, nil_allowed)
          raise ArgumentError, "The '#{name}' argument must be a hash" unless param.nil? or param.is_a? Hash
        end

        def check_list(name, param, nil_allowed=false)
          check_nil(name, param, nil_allowed)
          raise ArgumentError, "The '#{name}' argument must be an array" unless param.nil? or param.is_a? Array
        end

        def check_uri(name, param, nil_allowed=false)
          check_string(name, param, nil_allowed)
        end

        def check_id(name, param, nil_allowed=false)
          check_int(name, param, nil_allowed)
        end
      end

    end
  end
end