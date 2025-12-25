# frozen_string_literal: true

require 'spec_helper'

RSpec.describe V7CMS::Asset, type: :model do
  let(:valid_attributes) do
    {
      filename: 'photo.jpg',
      original_filename: 'My Photo.jpg',
      content_type: 'image/jpeg',
      file_size: 1024,
      storage_key: '2025/12/photo.jpg'
    }
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      asset = described_class.new(valid_attributes)
      expect(asset).to be_valid
    end

    it 'requires filename' do
      asset = described_class.new(valid_attributes.merge(filename: nil))
      expect(asset).not_to be_valid
      expect(asset.errors[:filename]).to include("can't be blank")
    end

    it 'requires original_filename' do
      asset = described_class.new(valid_attributes.merge(original_filename: nil))
      expect(asset).not_to be_valid
      expect(asset.errors[:original_filename]).to include("can't be blank")
    end

    it 'requires content_type' do
      asset = described_class.new(valid_attributes.merge(content_type: nil))
      expect(asset).not_to be_valid
      expect(asset.errors[:content_type]).to include("can't be blank")
    end

    it 'requires file_size' do
      asset = described_class.new(valid_attributes.merge(file_size: nil))
      expect(asset).not_to be_valid
    end

    it 'requires storage_key' do
      asset = described_class.new(valid_attributes.merge(storage_key: nil))
      expect(asset).not_to be_valid
      expect(asset.errors[:storage_key]).to include("can't be blank")
    end

    it 'requires unique storage_key' do
      described_class.create!(valid_attributes)
      asset = described_class.new(valid_attributes)
      expect(asset).not_to be_valid
      expect(asset.errors[:storage_key]).to include('has already been taken')
    end

    it 'validates content_type is allowed' do
      asset = described_class.new(valid_attributes.merge(content_type: 'application/exe'))
      expect(asset).not_to be_valid
      expect(asset.errors[:content_type]).to include('is not an allowed file type')
    end

    it 'validates file_size is positive' do
      asset = described_class.new(valid_attributes.merge(file_size: 0))
      expect(asset).not_to be_valid
    end
  end

  describe 'content type validation' do
    %w[image/jpeg image/png image/gif image/webp image/svg+xml].each do |type|
      it "allows #{type}" do
        asset = described_class.new(valid_attributes.merge(content_type: type))
        expect(asset).to be_valid
      end
    end

    %w[application/pdf].each do |type|
      it "allows #{type}" do
        asset = described_class.new(valid_attributes.merge(content_type: type))
        expect(asset).to be_valid
      end
    end

    %w[audio/mpeg video/mp4 application/zip].each do |type|
      it "allows #{type}" do
        asset = described_class.new(valid_attributes.merge(content_type: type))
        expect(asset).to be_valid
      end
    end
  end

  describe '#image?' do
    it 'returns true for image content types' do
      asset = described_class.new(valid_attributes.merge(content_type: 'image/jpeg'))
      expect(asset.image?).to be true
    end

    it 'returns false for non-image content types' do
      asset = described_class.new(valid_attributes.merge(content_type: 'application/pdf'))
      expect(asset.image?).to be false
    end
  end

  describe '#url' do
    it 'returns the public URL' do
      asset = described_class.new(valid_attributes)
      expect(asset.url).to eq('/upload/2025/12/photo.jpg')
    end
  end

  describe 'scopes' do
    before do
      described_class.create!(valid_attributes.merge(storage_key: '2025/12/a.jpg', content_type: 'image/jpeg'))
      described_class.create!(valid_attributes.merge(storage_key: '2025/12/b.pdf', content_type: 'application/pdf', filename: 'doc.pdf'))
      described_class.create!(valid_attributes.merge(storage_key: '2025/12/c.mp3', content_type: 'audio/mpeg', filename: 'song.mp3'))
    end

    it 'filters images' do
      expect(described_class.images.count).to eq(1)
    end

    it 'orders by recent' do
      expect(described_class.recent.first.storage_key).to eq('2025/12/c.mp3')
    end
  end

  describe '#file_type_category' do
    it 'returns :image for image types' do
      asset = described_class.new(content_type: 'image/jpeg')
      expect(asset.file_type_category).to eq(:image)
    end

    it 'returns :document for PDF' do
      asset = described_class.new(content_type: 'application/pdf')
      expect(asset.file_type_category).to eq(:document)
    end

    it 'returns :audio for audio types' do
      asset = described_class.new(content_type: 'audio/mpeg')
      expect(asset.file_type_category).to eq(:audio)
    end

    it 'returns :video for video types' do
      asset = described_class.new(content_type: 'video/mp4')
      expect(asset.file_type_category).to eq(:video)
    end

    it 'returns :archive for zip' do
      asset = described_class.new(content_type: 'application/zip')
      expect(asset.file_type_category).to eq(:archive)
    end
  end
end
