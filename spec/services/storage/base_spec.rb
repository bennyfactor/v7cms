# frozen_string_literal: true

require 'spec_helper'

RSpec.describe V7CMS::Storage::Base do
  subject(:adapter) { described_class.new }

  describe 'interface methods' do
    it 'raises NotImplementedError for #store' do
      expect { adapter.store(nil, 'key') }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for #retrieve' do
      expect { adapter.retrieve('key') }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for #delete' do
      expect { adapter.delete('key') }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for #url' do
      expect { adapter.url('key') }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for #exists?' do
      expect { adapter.exists?('key') }.to raise_error(NotImplementedError)
    end
  end
end
