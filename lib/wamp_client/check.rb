module WampClient
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