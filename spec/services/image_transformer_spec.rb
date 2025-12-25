# frozen_string_literal: true

require 'spec_helper'

RSpec.describe V7CMS::ImageTransformer do
  describe '.available?' do
    it 'returns a boolean' do
      expect([true, false]).to include(described_class.available?)
    end

    it 'caches the result' do
      result1 = described_class.available?
      result2 = described_class.available?
      expect(result1).to eq(result2)
    end
  end

  describe '.parse_params' do
    it 'extracts width parameter' do
      params = described_class.parse_params('w' => '400')
      expect(params[:width]).to eq(400)
    end

    it 'extracts height parameter' do
      params = described_class.parse_params('h' => '300')
      expect(params[:height]).to eq(300)
    end

    it 'extracts fit parameter' do
      params = described_class.parse_params('fit' => 'crop')
      expect(params[:fit]).to eq('crop')
    end

    it 'extracts quality parameter' do
      params = described_class.parse_params('q' => '80')
      expect(params[:quality]).to eq(80)
    end

    it 'extracts format parameter' do
      params = described_class.parse_params('format' => 'webp')
      expect(params[:format]).to eq('webp')
    end

    it 'ignores invalid parameters' do
      params = described_class.parse_params('invalid' => 'value', 'w' => '400')
      expect(params.keys).to contain_exactly(:width)
    end

    it 'returns empty hash for empty params' do
      expect(described_class.parse_params({})).to eq({})
    end
  end

  describe '.cache_key' do
    it 'generates consistent cache key from params' do
      params = { width: 400, height: 300, fit: 'crop' }
      key = described_class.cache_key(params)
      expect(key).to eq('fit-crop_h300_w400')
    end

    it 'returns nil for empty params' do
      expect(described_class.cache_key({})).to be_nil
    end

    it 'sorts params for consistent ordering' do
      params1 = { height: 300, width: 400 }
      params2 = { width: 400, height: 300 }
      expect(described_class.cache_key(params1)).to eq(described_class.cache_key(params2))
    end
  end
end
