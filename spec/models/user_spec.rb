require 'spec_helper'
require 'webmock/rspec'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'requires email' do
      user = User.new(provider: 'google', uid: '12345')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'requires provider' do
      user = User.new(email: 'test@example.com', uid: '12345')
      expect(user).not_to be_valid
      expect(user.errors[:provider]).to include("can't be blank")
    end

    it 'requires uid' do
      user = User.new(email: 'test@example.com', provider: 'google')
      expect(user).not_to be_valid
      expect(user.errors[:uid]).to include("can't be blank")
    end

    it 'requires unique provider+uid combination' do
      User.create!(email: 'test1@example.com', provider: 'google', uid: '12345', name: 'Test 1')
      user2 = User.new(email: 'test2@example.com', provider: 'google', uid: '12345')

      expect(user2).not_to be_valid
      expect(user2.errors[:uid]).to include('has already been taken')
    end

    it 'allows same uid for different providers' do
      User.create!(email: 'test1@example.com', provider: 'google', uid: '12345', name: 'Test 1')
      user2 = User.new(email: 'test2@example.com', provider: 'github', uid: '12345')

      expect(user2).to be_valid
    end
  end

  describe 'admin field' do
    it 'defaults to false for new users' do
      user = User.create!(
        email: 'test@example.com',
        provider: 'google_oauth2',
        uid: '12345'
      )
      expect(user.admin).to be false
    end

    it 'can be set to true' do
      user = User.create!(
        email: 'admin@example.com',
        provider: 'google_oauth2',
        uid: '12345',
        admin: true
      )
      expect(user.admin).to be true
    end

    it 'validates presence (not nil)' do
      user = User.new(email: 'test@example.com', provider: 'google', uid: '123')
      user.admin = nil
      expect(user).not_to be_valid
      expect(user.errors[:admin]).to include('is not included in the list')
    end
  end

  describe '.from_omniauth' do
    let(:auth_hash) do
      {
        'provider' => 'google',
        'uid' => '123456',
        'info' => {
          'email' => 'user@example.com',
          'name' => 'Test User',
          'image' => 'https://example.com/avatar.jpg'
        }
      }
    end

    it 'creates a new user from OAuth hash' do
      expect {
        User.from_omniauth(auth_hash)
      }.to change(User, :count).by(1)

      user = User.last
      expect(user.email).to eq('user@example.com')
      expect(user.name).to eq('Test User')
      expect(user.provider).to eq('google')
      expect(user.uid).to eq('123456')
      expect(user.avatar_url).to eq('https://example.com/avatar.jpg')
    end

    it 'finds existing user with same provider and uid' do
      existing = User.create!(
        email: 'user@example.com',
        name: 'Test User',
        provider: 'google',
        uid: '123456'
      )

      expect {
        user = User.from_omniauth(auth_hash)
        expect(user.id).to eq(existing.id)
      }.not_to change(User, :count)
    end
  end

  describe '#fetch_gravatar_if_missing' do
    let(:email) { 'test@example.com' }
    let(:email_hash) { Digest::MD5.hexdigest(email.downcase) }
    let(:gravatar_json_url) { "https://www.gravatar.com/#{email_hash}.json" }

    context 'when avatar_url and name are missing' do
      let(:gravatar_response) do
        {
          'entry' => [{ 'displayName' => 'Gravatar User' }]
        }
      end

      before do
        stub_request(:get, gravatar_json_url)
          .to_return(status: 200, body: gravatar_response.to_json)
      end

      it 'fetches both from Gravatar on create' do
        user = User.create!(
          email: email,
          provider: 'google',
          uid: '12345'
        )

        user.reload
        expect(user.avatar_url).to include('gravatar.com/avatar/')
        expect(user.name).to eq('Gravatar User')
      end
    end

    context 'when only avatar_url is missing' do
      let(:gravatar_response) do
        {
          'entry' => [{ 'displayName' => 'Gravatar User' }]
        }
      end

      before do
        stub_request(:get, gravatar_json_url)
          .to_return(status: 200, body: gravatar_response.to_json)
      end

      it 'fetches only avatar_url from Gravatar' do
        user = User.create!(
          email: email,
          provider: 'google',
          uid: '12345',
          name: 'Existing Name'
        )

        user.reload
        expect(user.avatar_url).to include('gravatar.com/avatar/')
        expect(user.name).to eq('Existing Name')
      end
    end

    context 'when only name is missing' do
      let(:gravatar_response) do
        {
          'entry' => [{ 'displayName' => 'Gravatar User' }]
        }
      end

      before do
        stub_request(:get, gravatar_json_url)
          .to_return(status: 200, body: gravatar_response.to_json)
      end

      it 'fetches only name from Gravatar' do
        user = User.create!(
          email: email,
          provider: 'google',
          uid: '12345',
          avatar_url: 'https://example.com/avatar.jpg'
        )

        user.reload
        expect(user.avatar_url).to eq('https://example.com/avatar.jpg')
        expect(user.name).to eq('Gravatar User')
      end
    end

    context 'when both avatar_url and name are present' do
      it 'does not call GravatarService' do
        expect(GravatarService).not_to receive(:fetch_profile)

        User.create!(
          email: email,
          provider: 'google',
          uid: '12345',
          name: 'Existing Name',
          avatar_url: 'https://example.com/avatar.jpg'
        )
      end
    end

    context 'when Gravatar has no profile' do
      before do
        stub_request(:get, gravatar_json_url)
          .to_return(status: 404)
      end

      it 'does not update user' do
        user = User.create!(
          email: email,
          provider: 'google',
          uid: '12345'
        )

        user.reload
        expect(user.avatar_url).to be_nil
        expect(user.name).to be_nil
      end
    end

    context 'when called manually on existing user' do
      let(:gravatar_response) do
        {
          'entry' => [{ 'displayName' => 'Gravatar User' }]
        }
      end

      before do
        stub_request(:get, gravatar_json_url)
          .to_return(status: 200, body: gravatar_response.to_json)
      end

      it 'can backfill missing data' do
        user = User.create!(
          email: email,
          provider: 'google',
          uid: '12345'
        )

        # Stub to prevent callback during create
        allow(GravatarService).to receive(:fetch_profile).and_return({})

        # Manually call to simulate rake task
        allow(GravatarService).to receive(:fetch_profile).and_call_original
        user.fetch_gravatar_if_missing

        user.reload
        expect(user.avatar_url).to include('gravatar.com/avatar/')
        expect(user.name).to eq('Gravatar User')
      end
    end
  end
end
