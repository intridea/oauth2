require 'helper'
require 'zlib'

describe OAuth2::Response do
  describe '#initialize' do
    let(:status) { 200 }
    let(:headers) { {'foo' => 'bar'} }
    let(:body) { 'foo' }

    it 'returns the status, headers and body' do
      response = double('response', :headers => headers,
                                    :status  => status,
                                    :body    => body)
      subject = Response.new(response)
      expect(subject.headers).to eq(headers)
      expect(subject.status).to eq(status)
      expect(subject.body).to eq(body)
    end
  end

  describe '.register_parser' do
    let(:response) do
      double('response', :headers => {'Content-Type' => 'application/foo-bar'},
                         :status => 200,
                         :body => 'baz')
    end
    before do
      OAuth2::Response.register_parser(:foobar, 'application/foo-bar') do |body|
        "foobar #{body}"
      end
    end

    it 'adds to the content types and parsers' do
      expect(OAuth2::Response.send(:class_variable_get, :@@parsers).keys).to include(:foobar)
      expect(OAuth2::Response.send(:class_variable_get, :@@content_types).keys).to include('application/foo-bar')
    end

    it 'is able to parse that content type automatically' do
      expect(OAuth2::Response.new(response).parsed).to eq('foobar baz')
    end
  end

  describe '#parsed' do
    it 'parses application/x-www-form-urlencoded body' do
      headers = {'Content-Type' => 'application/x-www-form-urlencoded'}
      body = 'foo=bar&answer=42'
      response = double('response', :headers => headers, :body => body)
      subject = Response.new(response)
      expect(subject.parsed.keys.size).to eq(2)
      expect(subject.parsed['foo']).to eq('bar')
      expect(subject.parsed['answer']).to eq('42')
    end

    it 'parses application/json body' do
      headers = {'Content-Type' => 'application/json'}
      body = MultiJson.encode(:foo => 'bar', :answer => 42)
      response = double('response', :headers => headers, :body => body)
      subject = Response.new(response)
      expect(subject.parsed.keys.size).to eq(2)
      expect(subject.parsed['foo']).to eq('bar')
      expect(subject.parsed['answer']).to eq(42)
    end

    it "doesn't try to parse other content-types" do
      headers = {'Content-Type' => 'text/html'}
      body = '<!DOCTYPE html><html><head></head><body></body></html>'

      response = double('response', :headers => headers, :body => body)

      expect(MultiJson).not_to receive(:decode)
      expect(MultiJson).not_to receive(:load)
      expect(Rack::Utils).not_to receive(:parse_query)

      subject = Response.new(response)
      expect(subject.parsed).to be_nil
    end
  end

  context 'xml parser registration' do
    it 'tries to load multi_xml and use it' do
      expect(OAuth2::Response.send(:class_variable_get, :@@parsers)[:xml]).not_to be_nil
    end

    it 'is able to parse xml' do
      headers = {'Content-Type' => 'text/xml'}
      body = '<?xml version="1.0" standalone="yes" ?><foo><bar>baz</bar></foo>'

      response = double('response', :headers => headers, :body => body)
      expect(OAuth2::Response.new(response).parsed).to eq('foo' => {'bar' => 'baz'})
    end

    it 'is able to parse application/xml' do
      headers = {'Content-Type' => 'application/xml'}
      body = '<?xml version="1.0" standalone="yes" ?><foo><bar>baz</bar></foo>'

      response = double('response', :headers => headers, :body => body)
      expect(OAuth2::Response.new(response).parsed).to eq('foo' => {'bar' => 'baz'})
    end
  end

  context 'when gzip content-encoding' do
    let(:headers) do
      {'content-type' => 'application/json', 'content-encoding' => 'gzip'}
    end
    let(:original_data) do
      {'data' => 'some test data'}
    end
    let(:body) do
      str_io = StringIO.new('w')

      Zlib::GzipWriter.new(str_io).tap do |gz|
        gz.write(MultiJson.dump(original_data))
        gz.close
      end

      str_io.string
    end
    let(:response) do
      double('response', :status => 200, :headers => headers, :body => body)
    end

    it do
      expect(OAuth2::Response.new(response).parsed).to eq(original_data)
    end
  end
end
