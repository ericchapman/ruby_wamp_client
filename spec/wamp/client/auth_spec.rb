require 'spec_helper'

describe Wamp::Client::Auth do

  describe 'cra' do

    it 'generates the signature' do

      challenge = "{ \"nonce\": \"LHRTC9zeOIrt_9U3\", \"authprovider\": \"userdb\", \"authid\": \"peter\", \"timestamp\": \"2014-06-22T16:36:25.448Z\", \"authrole\": \"user\", \"authmethod\": \"wampcra\", \"session\": 3251278072152162}"
      secret = 'secret'
      signature = Wamp::Client::Auth::Cra.sign(secret, challenge)
      expect(signature).to eq('Pji30JC9tb/T9tbEwxw5i0RyRa5UVBxuoIVTgT7hnkE=')

    end

  end

end