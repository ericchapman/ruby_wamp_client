require 'openssl'
require 'base64'

module Wamp
  module Client
    module Auth
      module Cra

        # Generates the signature from the challenge
        # @param key [String]
        # @param challenge [String]
        def self.sign(key, challenge)
          hash  = OpenSSL::HMAC.digest('sha256', key, challenge)
          Base64.encode64(hash).gsub(/\n/,'')
        end

      end
    end
  end
end