require 'spec_helper'

RSpec.describe Redirect, type: :model do
  describe 'validations' do
    it 'requires short_path' do
      redirect = Redirect.new(target_path: '/posts/test')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:short_path]).to include("can't be blank")
    end

    it 'requires target_path' do
      redirect = Redirect.new(short_path: '/test')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:target_path]).to include("can't be blank")
    end

    it 'requires unique short_path' do
      Redirect.create!(short_path: '/test', target_path: '/posts/test')
      redirect = Redirect.new(short_path: '/test', target_path: '/posts/other')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:short_path]).to include('has already been taken')
    end
  end

  describe '#normalize_paths' do
    it 'adds leading slash to short_path if missing' do
      redirect = Redirect.create!(short_path: 'test', target_path: '/posts/test')
      expect(redirect.short_path).to eq('/test')
    end

    it 'adds leading slash to target_path if missing' do
      redirect = Redirect.create!(short_path: '/test', target_path: 'posts/test')
      expect(redirect.target_path).to eq('/posts/test')
    end

    it 'removes multiple leading slashes from short_path' do
      redirect = Redirect.create!(short_path: '///test', target_path: '/posts/test')
      expect(redirect.short_path).to eq('/test')
    end

    it 'does not modify paths that already start with /' do
      redirect = Redirect.create!(short_path: '/test', target_path: '/posts/test')
      expect(redirect.short_path).to eq('/test')
      expect(redirect.target_path).to eq('/posts/test')
    end
  end

  describe '#short_path_not_reserved' do
    it 'rejects root path' do
      redirect = Redirect.new(short_path: '/', target_path: '/posts/test')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:short_path]).to include('conflicts with reserved path')
    end

    it 'rejects /admin path' do
      redirect = Redirect.new(short_path: '/admin', target_path: '/posts/test')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:short_path]).to include('conflicts with reserved path')
    end

    it 'rejects /api path' do
      redirect = Redirect.new(short_path: '/api', target_path: '/posts/test')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:short_path]).to include('conflicts with reserved path')
    end

    it 'rejects /auth path' do
      redirect = Redirect.new(short_path: '/auth', target_path: '/posts/test')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:short_path]).to include('conflicts with reserved path')
    end

    it 'rejects /feed path' do
      redirect = Redirect.new(short_path: '/feed', target_path: '/posts/test')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:short_path]).to include('conflicts with reserved path')
    end

    it 'rejects /posts path' do
      redirect = Redirect.new(short_path: '/posts', target_path: '/pages/test')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:short_path]).to include('conflicts with reserved path')
    end

    it 'rejects /pages path' do
      redirect = Redirect.new(short_path: '/pages', target_path: '/posts/test')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:short_path]).to include('conflicts with reserved path')
    end

    it 'rejects paths starting with reserved paths' do
      redirect = Redirect.new(short_path: '/admin/test', target_path: '/posts/test')
      expect(redirect).not_to be_valid
      expect(redirect.errors[:short_path]).to include('conflicts with reserved path')
    end

    it 'allows non-reserved paths' do
      redirect = Redirect.new(short_path: '/pricing', target_path: '/posts/pricing-page')
      expect(redirect).to be_valid
    end
  end

  describe '#regenerate_htaccess callback' do
    before do
      # Allow HtaccessGenerator.generate to be called without errors
      allow(HtaccessGenerator).to receive(:generate).and_return(true)
    end

    it 'calls HtaccessGenerator.generate after save' do
      expect(HtaccessGenerator).to receive(:generate)
      Redirect.create!(short_path: '/test', target_path: '/posts/test')
    end

    it 'calls HtaccessGenerator.generate after destroy' do
      redirect = Redirect.create!(short_path: '/test', target_path: '/posts/test')
      expect(HtaccessGenerator).to receive(:generate)
      redirect.destroy
    end
  end
end
