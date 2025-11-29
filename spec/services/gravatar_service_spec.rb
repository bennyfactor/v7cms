require 'spec_helper'
require 'webmock/rspec'

RSpec.describe GravatarService do
  let(:email) { 'test@example.com' }
  let(:email_hash) { Digest::MD5.hexdigest(email.downcase) }
  let(:gravatar_json_url) { "https://www.gravatar.com/#{email_hash}.json" }
  let(:gravatar_avatar_url) { "https://www.gravatar.com/avatar/#{email_hash}?s=200&d=404" }

  describe '.fetch_profile' do
    context 'when Gravatar has profile data' do
      let(:gravatar_response) do
        {
          'entry' => [
            {
              'displayName' => 'Test User',
              'photos' => [{ 'value' => 'https://gravatar.com/avatar/123' }]
            }
          ]
        }
      end

      before do
        stub_request(:get, gravatar_json_url)
          .to_return(status: 200, body: gravatar_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns avatar_url and name' do
        result = described_class.fetch_profile(email)
        expect(result[:avatar_url]).to eq(gravatar_avatar_url)
        expect(result[:name]).to eq('Test User')
      end

      it 'handles uppercase email' do
        result = described_class.fetch_profile('TEST@EXAMPLE.COM')
        expect(result[:avatar_url]).to eq(gravatar_avatar_url)
      end

      it 'handles email with whitespace' do
        result = described_class.fetch_profile('  test@example.com  ')
        expect(result[:avatar_url]).to eq(gravatar_avatar_url)
      end
    end

    context 'when Gravatar has no displayName' do
      let(:gravatar_response) do
        {
          'entry' => [{}]
        }
      end

      before do
        stub_request(:get, gravatar_json_url)
          .to_return(status: 200, body: gravatar_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns only avatar_url' do
        result = described_class.fetch_profile(email)
        expect(result[:avatar_url]).to eq(gravatar_avatar_url)
        expect(result[:name]).to be_nil
      end
    end

    context 'when Gravatar returns 404' do
      before do
        stub_request(:get, gravatar_json_url)
          .to_return(status: 404)
      end

      it 'returns empty hash' do
        result = described_class.fetch_profile(email)
        expect(result).to eq({})
      end

      it 'logs warning' do
        expect_any_instance_of(Logger).not_to receive(:warn)
        described_class.fetch_profile(email)
      end
    end

    context 'when Gravatar times out' do
      before do
        stub_request(:get, gravatar_json_url).to_timeout
      end

      it 'returns empty hash' do
        result = described_class.fetch_profile(email)
        expect(result).to eq({})
      end

      it 'logs warning' do
        expect_any_instance_of(Logger).to receive(:warn).with(/Gravatar lookup failed/)
        described_class.fetch_profile(email)
      end
    end

    context 'when Gravatar returns invalid JSON' do
      before do
        stub_request(:get, gravatar_json_url)
          .to_return(status: 200, body: 'invalid json')
      end

      it 'returns empty hash' do
        result = described_class.fetch_profile(email)
        expect(result).to eq({})
      end

      it 'logs warning' do
        expect_any_instance_of(Logger).to receive(:warn).with(/Gravatar lookup failed/)
        described_class.fetch_profile(email)
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, gravatar_json_url).to_raise(SocketError)
      end

      it 'returns empty hash' do
        result = described_class.fetch_profile(email)
        expect(result).to eq({})
      end

      it 'logs warning' do
        expect_any_instance_of(Logger).to receive(:warn).with(/Gravatar lookup failed/)
        described_class.fetch_profile(email)
      end
    end
  end

  describe '#avatar_url' do
    it 'generates correct Gravatar avatar URL' do
      service = described_class.new(email)
      expect(service.send(:avatar_url)).to eq(gravatar_avatar_url)
    end
  end
end
