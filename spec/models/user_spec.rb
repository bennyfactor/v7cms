require 'spec_helper'

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
end
