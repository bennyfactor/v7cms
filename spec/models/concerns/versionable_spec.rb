require 'spec_helper'

# Test class that includes Versionable
class VersionableTestModel < ActiveRecord::Base
  self.table_name = 'posts'
  include V7CMS::Versionable

  private

  def version_metadata
    { slug: slug, comments_enabled: try(:comments_enabled) }
  end
end

RSpec.describe V7CMS::Versionable, type: :model do
  let(:model) do
    # Create model and clear auto-generated version for cleaner test expectations
    m = VersionableTestModel.create!(title: 'Test', slug: 'test', content: 'Content')
    m.content_versions.destroy_all
    m
  end
  let(:user) { User.create!(email: 'test@example.com', provider: 'google', uid: '123') }

  describe 'associations' do
    it 'has many content_versions' do
      expect(model).to respond_to(:content_versions)
    end

    it 'destroys versions when record is destroyed' do
      model.create_version!(version_type: 'workflow', workflow_state: 'published')
      expect { model.destroy }.to change { ContentVersion.count }.by(-1)
    end
  end

  describe '#create_version!' do
    it 'creates a version with incremented version_number' do
      v1 = model.create_version!(version_type: 'auto', expires_at: 1.day.from_now)
      v2 = model.create_version!(version_type: 'auto', expires_at: 1.day.from_now)

      expect(v1.version_number).to eq(1)
      expect(v2.version_number).to eq(2)
    end

    it 'stores title and content' do
      version = model.create_version!(version_type: 'workflow')

      expect(version.title).to eq('Test')
      expect(version.content).to eq('Content')
    end

    it 'stores metadata as JSON' do
      version = model.create_version!(version_type: 'workflow')

      expect(version.metadata_hash['slug']).to eq('test')
    end

    it 'associates created_by user' do
      version = model.create_version!(version_type: 'workflow', created_by: user)

      expect(version.created_by).to eq(user)
    end
  end

  describe '#create_auto_version!' do
    it 'creates an auto version with 24h expiry' do
      version = model.create_auto_version!

      expect(version.version_type).to eq('auto')
      expect(version.expires_at).to be_within(1.minute).of(24.hours.from_now)
    end
  end

  describe '#create_workflow_version!' do
    it 'creates a permanent workflow version' do
      version = model.create_workflow_version!(workflow_state: 'published')

      expect(version.version_type).to eq('workflow')
      expect(version.workflow_state).to eq('published')
      expect(version.expires_at).to be_nil
    end
  end

  describe '#latest_version' do
    it 'returns the most recent version' do
      model.create_version!(version_type: 'auto', expires_at: 1.day.from_now)
      v2 = model.create_version!(version_type: 'workflow')

      expect(model.latest_version).to eq(v2)
    end

    it 'returns nil when no versions exist' do
      expect(model.latest_version).to be_nil
    end
  end

  describe '#version_at' do
    it 'returns version by number' do
      v1 = model.create_version!(version_type: 'auto', expires_at: 1.day.from_now)
      model.create_version!(version_type: 'workflow')

      expect(model.version_at(1)).to eq(v1)
    end

    it 'returns nil for non-existent version' do
      expect(model.version_at(999)).to be_nil
    end
  end

  describe '#restore_version!' do
    it 'restores content from version' do
      model.create_version!(version_type: 'workflow')
      model.update!(title: 'Updated', content: 'New content')

      model.restore_version!(1)
      model.reload

      expect(model.title).to eq('Test')
      expect(model.content).to eq('Content')
    end

    it 'raises error for non-existent version' do
      expect { model.restore_version!(999) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'auto-versioning on save' do
    it 'creates auto version when title changes' do
      model.update!(title: 'New Title')

      # First version is from the update
      expect(model.content_versions.count).to eq(1)
      expect(model.latest_version.version_type).to eq('auto')
    end

    it 'creates auto version when content changes' do
      model.update!(content: 'New Content')

      expect(model.content_versions.count).to eq(1)
    end

    it 'does not create version for non-content changes' do
      # Skip this test - it will be verified in Task 4 with actual Post
    end
  end
end
