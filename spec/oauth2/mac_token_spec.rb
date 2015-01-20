require 'helper'

describe MACToken do
  let(:token) { 'monkey' }
  let(:client) do
    Client.new('abc', 'def', :site => 'https://api.example.com') do |builder|
      builder.request :url_encoded
      builder.adapter :test do |stub|
        VERBS.each do |verb|
          stub.send(verb, '/token/header') { |env| [200, {}, env[:request_headers]['Authorization']] }
        end
      end
    end
  end

  subject { MACToken.new(client, token, 'abc123') }

  describe '#initialize' do
    it 'assigns client and token' do
      expect(subject.client).to eq(client)
      expect(subject.token).to eq(token)
    end

    it 'assigns secret' do
      expect(subject.secret).to eq('abc123')
    end

    it 'defaults algorithm to hmac-sha-256' do
      expect(subject.algorithm).to be_instance_of(OpenSSL::Digest::SHA256)
    end

    it 'handles hmac-sha-256' do
      mac = MACToken.new(client, token, 'abc123', :algorithm => 'hmac-sha-256')
      expect(mac.algorithm).to be_instance_of(OpenSSL::Digest::SHA256)
    end

    it 'handles hmac-sha-1' do
      mac = MACToken.new(client, token, 'abc123', :algorithm => 'hmac-sha-1')
      expect(mac.algorithm).to be_instance_of(OpenSSL::Digest::SHA1)
    end

    it 'raises on improper algorithm' do
      expect { MACToken.new(client, token, 'abc123', :algorithm => 'invalid-sha') }.to raise_error(ArgumentError)
    end
  end

  describe '#request' do
    VERBS.each do |verb|
      it "sends the token in the Authorization header for a #{verb.to_s.upcase} request" do
        expect(subject.post('/token/header').body).to include("MAC id=\"#{token}\"")
      end
    end
  end

  describe '#header' do
    it 'does not generate the same header twice' do
      header = subject.header('get', 'https://www.example.com/hello')
      duplicate_header = subject.header('get', 'https://www.example.com/hello')

      expect(header).to_not eq(duplicate_header)
    end

    it 'generates the proper format' do
      header = subject.header('get', 'https://www.example.com/hello?a=1')
      expect(header).to match(/MAC id="#{token}", ts="[0-9]+", nonce="[^"]+", mac="[^"]+"/)
    end

    it 'passes ArgumentError with an invalid url' do
      expect { subject.header('get', 'this-is-not-valid') }.to raise_error(ArgumentError)
    end

    it 'passes URI::InvalidURIError through' do
      expect { subject.header('get', nil) }.to raise_error(URI::InvalidURIError)
    end
  end

  describe '#signature' do
    it 'generates properly' do
      signature = subject.signature(0, 'random-string', 'get', URI('https://www.google.com'))
      expect(signature).to eq('rMDjVA3VJj3v1OmxM29QQljKia6msl5rjN83x3bZmi8=')
    end
  end

  describe '#headers' do
    it 'is an empty hash' do
      expect(subject.headers).to eq({})
    end
  end

  describe '.from_access_token' do
    let(:one_second_later) { Time.now.to_i + 1 }

    let(:access_token) do
      AccessToken.new(
        client, token,
        :expires_at => one_second_later,
        :expires_in => 1,
        :refresh_token => 'abc',
        :random => 1
      )
    end

    subject { MACToken.from_access_token(access_token, 'hello') }

    it 'initializes client, token, and secret properly' do
      expect(subject.client).to eq(client)
      expect(subject.token).to eq(token)
      expect(subject.secret).to eq('hello')
    end

    it 'initializes configuration options' do
      expect(subject.expires_at).to eq(one_second_later)
      expect(subject.expires_in).to eq(1)
      expect(subject.refresh_token).to eq('abc')
    end

    it 'initializes params' do
      expect(subject.params).to eq(:random => 1)
    end
  end
end
