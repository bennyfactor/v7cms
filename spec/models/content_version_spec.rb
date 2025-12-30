require 'spec_helper'

RSpec.describe ContentVersion, type: :model do
  let(:post) { Post.create!(title: 'Test Post', slug: 'test-post', content: 'Content') }
  let(:user) { User.create!(email: 'test@example.com', provider: 'google', uid: '123') }

  describe 'validations' do
    it 'requires version_number' do
      version = ContentVersion.new(
        versionable: post,
        version_type: 'auto',
        title: 'Test'
      )
      expect(version).not_to be_valid
      expect(version.errors[:version_number]).to include("can't be blank")
    end

    it 'requires version_number > 0' do
      version = ContentVersion.new(
        versionable: post,
        version_number: 0,
        version_type: 'auto',
        title: 'Test'
      )
      expect(version).not_to be_valid
      expect(version.errors[:version_number]).to include('must be greater than 0')
    end

    it 'requires valid version_type' do
      version = ContentVersion.new(
        versionable: post,
        version_number: 1,
        version_type: 'invalid',
        title: 'Test'
      )
      expect(version).not_to be_valid
      expect(version.errors[:version_type]).to include('is not included in the list')
    end

    it 'accepts valid version_types' do
      %w[auto workflow manual].each do |type|
        version = ContentVersion.new(
          versionable: post,
          version_number: 1,
          version_type: type,
          title: 'Test'
        )
        version.valid?
        expect(version.errors[:version_type]).to be_empty
      end
    end

    it 'requires title' do
      version = ContentVersion.new(
        versionable: post,
        version_number: 1,
        version_type: 'auto'
      )
      expect(version).not_to be_valid
      expect(version.errors[:title]).to include("can't be blank")
    end

    it 'allows nil workflow_state' do
      version = ContentVersion.new(
        versionable: post,
        version_number: 1,
        version_type: 'auto',
        title: 'Test',
        workflow_state: nil
      )
      version.valid?
      expect(version.errors[:workflow_state]).to be_empty
    end

    it 'validates workflow_state when present' do
      version = ContentVersion.new(
        versionable: post,
        version_number: 1,
        version_type: 'workflow',
        title: 'Test',
        workflow_state: 'invalid'
      )
      expect(version).not_to be_valid
      expect(version.errors[:workflow_state]).to include('is not included in the list')
    end
  end

  describe '#permanent?' do
    it 'returns true when expires_at is nil' do
      version = ContentVersion.new(expires_at: nil)
      expect(version.permanent?).to be true
    end

    it 'returns false when expires_at is set' do
      version = ContentVersion.new(expires_at: 1.day.from_now)
      expect(version.permanent?).to be false
    end
  end

  describe '#temporary?' do
    it 'returns false when expires_at is nil' do
      version = ContentVersion.new(expires_at: nil)
      expect(version.temporary?).to be false
    end

    it 'returns true when expires_at is set' do
      version = ContentVersion.new(expires_at: 1.day.from_now)
      expect(version.temporary?).to be true
    end
  end

  describe '#mark_permanent!' do
    it 'sets version_type to manual and clears expires_at' do
      version = ContentVersion.create!(
        versionable: post,
        version_number: 1,
        version_type: 'auto',
        title: 'Test',
        expires_at: 1.day.from_now
      )

      version.mark_permanent!
      version.reload

      expect(version.version_type).to eq('manual')
      expect(version.expires_at).to be_nil
    end
  end

  describe '#metadata_hash' do
    it 'returns empty hash for nil metadata' do
      version = ContentVersion.new(metadata: nil)
      expect(version.metadata_hash).to eq({})
    end

    it 'returns empty hash for blank metadata' do
      version = ContentVersion.new(metadata: '')
      expect(version.metadata_hash).to eq({})
    end

    it 'parses valid JSON' do
      version = ContentVersion.new(metadata: '{"slug":"test","page_type":"standard"}')
      expect(version.metadata_hash).to eq({ 'slug' => 'test', 'page_type' => 'standard' })
    end

    it 'returns empty hash for invalid JSON' do
      version = ContentVersion.new(metadata: 'not json')
      expect(version.metadata_hash).to eq({})
    end
  end

  describe '#restore_to_parent!' do
    it 'restores title and content to parent' do
      post.update!(title: 'Updated Title', content: 'Updated Content')

      # Use next version number after auto-created version
      next_version = (post.content_versions.maximum(:version_number) || 0) + 1
      version = ContentVersion.create!(
        versionable: post,
        version_number: next_version,
        version_type: 'workflow',
        title: 'Original Title',
        content: 'Original Content',
        metadata: '{"slug":"test-post"}'
      )

      version.restore_to_parent!
      post.reload

      expect(post.title).to eq('Original Title')
      expect(post.content).to eq('Original Content')
    end

    it 'restores metadata fields' do
      next_version = (post.content_versions.maximum(:version_number) || 0) + 1
      version = ContentVersion.create!(
        versionable: post,
        version_number: next_version,
        version_type: 'workflow',
        title: 'Test',
        content: 'Content',
        metadata: '{"slug":"restored-slug"}'
      )

      version.restore_to_parent!
      post.reload

      expect(post.slug).to eq('restored-slug')
    end
  end

  describe 'scopes' do
    before do
      ContentVersion.create!(
        versionable: post,
        version_number: 1,
        version_type: 'workflow',
        title: 'V1',
        expires_at: nil
      )
      ContentVersion.create!(
        versionable: post,
        version_number: 2,
        version_type: 'auto',
        title: 'V2',
        expires_at: 1.day.from_now
      )
      ContentVersion.create!(
        versionable: post,
        version_number: 3,
        version_type: 'auto',
        title: 'V3',
        expires_at: 1.day.ago
      )
    end

    it 'permanent scope returns only permanent versions' do
      expect(ContentVersion.permanent.count).to eq(1)
      expect(ContentVersion.permanent.first.version_number).to eq(1)
    end

    it 'temporary scope returns only temporary versions' do
      expect(ContentVersion.temporary.count).to eq(2)
    end

    it 'expired scope returns only expired versions' do
      expect(ContentVersion.expired.count).to eq(1)
      expect(ContentVersion.expired.first.version_number).to eq(3)
    end

    it 'by_version orders by version_number desc' do
      versions = ContentVersion.by_version
      expect(versions.map(&:version_number)).to eq([3, 2, 1])
    end
  end

  describe '.cleanup_expired!' do
    it 'deletes only expired versions' do
      ContentVersion.create!(
        versionable: post,
        version_number: 1,
        version_type: 'workflow',
        title: 'Permanent',
        expires_at: nil
      )
      ContentVersion.create!(
        versionable: post,
        version_number: 2,
        version_type: 'auto',
        title: 'Not expired',
        expires_at: 1.day.from_now
      )
      ContentVersion.create!(
        versionable: post,
        version_number: 3,
        version_type: 'auto',
        title: 'Expired',
        expires_at: 1.day.ago
      )

      deleted = ContentVersion.cleanup_expired!

      expect(deleted).to eq(1)
      expect(ContentVersion.count).to eq(2)
      expect(ContentVersion.pluck(:version_number)).to contain_exactly(1, 2)
    end
  end

  describe 'associations' do
    it 'belongs to versionable (polymorphic)' do
      version = ContentVersion.create!(
        versionable: post,
        version_number: 1,
        version_type: 'auto',
        title: 'Test'
      )
      expect(version.versionable).to eq(post)
    end

    it 'belongs to created_by (optional)' do
      version = ContentVersion.create!(
        versionable: post,
        version_number: 1,
        version_type: 'auto',
        title: 'Test',
        created_by: user
      )
      expect(version.created_by).to eq(user)
    end

    it 'allows nil created_by' do
      version = ContentVersion.create!(
        versionable: post,
        version_number: 1,
        version_type: 'auto',
        title: 'Test',
        created_by: nil
      )
      expect(version.created_by).to be_nil
    end
  end
end
