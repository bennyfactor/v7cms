require 'spec_helper'

RSpec.describe Post, type: :model do
  describe 'validations' do
    it 'requires title' do
      post = Post.new(content: 'Test content')
      expect(post).not_to be_valid
      expect(post.errors[:title]).to include("can't be blank")
    end

    it 'requires slug' do
      post = Post.new(title: 'Test Post', content: 'Test content')
      post.valid? # trigger callbacks
      expect(post.slug).not_to be_nil
    end

    it 'requires unique slug' do
      Post.create!(title: 'Test Post', slug: 'test-post', content: 'Content 1')
      post2 = Post.new(title: 'Test Post 2', slug: 'test-post', content: 'Content 2')

      expect(post2).not_to be_valid
      expect(post2.errors[:slug]).to include('has already been taken')
    end
  end

  describe 'slug generation' do
    it 'auto-generates slug from title if not provided' do
      post = Post.new(title: 'My Awesome Post', content: 'Content')
      post.valid?
      expect(post.slug).to eq('my-awesome-post')
    end

    it 'handles special characters in title' do
      post = Post.new(title: 'Hello, World! How are you?', content: 'Content')
      post.valid?
      expect(post.slug).to eq('hello-world-how-are-you')
    end

    it 'handles unicode characters' do
      post = Post.new(title: 'Café & Restaurant', content: 'Content')
      post.valid?
      expect(post.slug).to eq('caf-restaurant')
    end

    it 'preserves manually set slug' do
      post = Post.new(title: 'Test Post', slug: 'custom-slug', content: 'Content')
      post.valid?
      expect(post.slug).to eq('custom-slug')
    end
  end

  describe 'scopes' do
    before do
      Post.create!(title: 'Published 1', slug: 'pub1', content: 'Content', published: true)
      Post.create!(title: 'Draft 1', slug: 'draft1', content: 'Content', published: false)
      Post.create!(title: 'Published 2', slug: 'pub2', content: 'Content', published: true)
    end

    it 'has a published scope' do
      expect(Post.published.count).to eq(2)
      expect(Post.published.pluck(:title)).to contain_exactly('Published 1', 'Published 2')
    end

    it 'has a recent scope ordered by created_at desc' do
      posts = Post.recent
      expect(posts.first.title).to eq('Published 2')
      expect(posts.last.title).to eq('Published 1')
    end
  end

  describe 'default values' do
    it 'defaults published to false' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content')
      expect(post.published).to be false
    end
  end

  describe 'comments_enabled validation' do
    it 'accepts true' do
      post = Post.new(title: 'Test', comments_enabled: true)
      post.valid?
      expect(post.errors[:comments_enabled]).to be_empty
    end

    it 'accepts false' do
      post = Post.new(title: 'Test', comments_enabled: false)
      post.valid?
      expect(post.errors[:comments_enabled]).to be_empty
    end

    it 'rejects nil' do
      post = Post.new(title: 'Test', comments_enabled: nil)
      post.valid?
      expect(post.errors[:comments_enabled]).to include('is not included in the list')
    end
  end

  describe '#comments_allowed?' do
    let(:post) { Post.create!(title: 'Test', slug: 'test', comments_enabled: true) }

    context 'when both post and global setting allow comments' do
      it 'returns true' do
        Setting.instance.update!(allow_comments: true)
        expect(post.comments_allowed?).to be true
      end
    end

    context 'when post disables comments' do
      it 'returns false' do
        post.update!(comments_enabled: false)
        Setting.instance.update!(allow_comments: true)
        expect(post.comments_allowed?).to be false
      end
    end

    context 'when global setting disables comments' do
      it 'returns false' do
        post.update!(comments_enabled: true)
        Setting.instance.update!(allow_comments: false)
        expect(post.comments_allowed?).to be false
      end
    end

    context 'when both disable comments' do
      it 'returns false' do
        post.update!(comments_enabled: false)
        Setting.instance.update!(allow_comments: false)
        expect(post.comments_allowed?).to be false
      end
    end
  end

  describe 'static file generation' do
    let(:static_file_path) { File.join(PostRenderer::STATIC_DIR, 'test-post.html') }

    before do
      # Clean up any generated files from previous tests
      FileUtils.rm_rf(PostRenderer::STATIC_DIR) if Dir.exist?(PostRenderer::STATIC_DIR)
      # Ensure settings exist
      Setting.instance
    end

    after do
      # Clean up any generated files
      FileUtils.rm_rf(PostRenderer::STATIC_DIR) if Dir.exist?(PostRenderer::STATIC_DIR)
    end

    it 'generates static file when post is published' do
      post = Post.create!(
        title: 'Test Post',
        slug: 'test-post',
        content: '<p>Content</p>',
        published: true
      )

      expect(File.exist?(static_file_path)).to be true
    end

    it 'does not generate static file when post is draft' do
      post = Post.create!(
        title: 'Test Post',
        slug: 'test-post',
        content: '<p>Content</p>',
        published: false
      )

      expect(File.exist?(static_file_path)).to be false
    end

    it 'regenerates static file when published post is updated' do
      post = Post.create!(
        title: 'Test Post',
        slug: 'test-post',
        content: '<p>Original</p>',
        published: true
      )

      original_content = File.read(static_file_path)

      post.update!(content: '<p>Updated</p>')

      updated_content = File.read(static_file_path)
      expect(updated_content).not_to eq(original_content)
      expect(updated_content).to include('Updated')
    end

    it 'removes static file when post is unpublished' do
      post = Post.create!(
        title: 'Test Post',
        slug: 'test-post',
        content: '<p>Content</p>',
        published: true
      )

      expect(File.exist?(static_file_path)).to be true

      post.update!(published: false)

      expect(File.exist?(static_file_path)).to be false
    end

    it 'removes static file when post is destroyed' do
      post = Post.create!(
        title: 'Test Post',
        slug: 'test-post',
        content: '<p>Content</p>',
        published: true
      )

      expect(File.exist?(static_file_path)).to be true

      post.destroy

      expect(File.exist?(static_file_path)).to be false
    end

    it 'generates static file when draft becomes published' do
      post = Post.create!(
        title: 'Test Post',
        slug: 'test-post',
        content: '<p>Content</p>',
        published: false
      )

      expect(File.exist?(static_file_path)).to be false

      post.update!(published: true)

      expect(File.exist?(static_file_path)).to be true
    end
  end

  describe 'status' do
    it 'defaults status to draft' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content')
      expect(post.status).to eq('draft')
    end

    it 'validates status inclusion' do
      post = Post.new(title: 'Test', status: 'invalid')
      expect(post).not_to be_valid
      expect(post.errors[:status]).to include('is not included in the list')
    end

    it 'accepts valid statuses' do
      %w[draft ready published].each do |status|
        post = Post.new(title: 'Test', status: status)
        post.valid?
        expect(post.errors[:status]).to be_empty
      end
    end
  end

  describe 'versioning' do
    it 'includes Versionable concern' do
      expect(Post.ancestors).to include(V7CMS::Versionable)
    end

    it 'creates auto version when title changes' do
      post = Post.create!(title: 'Original', slug: 'test', content: 'Content')
      post.update!(title: 'Updated')

      expect(post.content_versions.count).to eq(1)
      expect(post.latest_version.title).to eq('Updated')
    end

    it 'creates auto version when content changes' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Original')
      post.update!(content: 'Updated')

      expect(post.content_versions.count).to eq(1)
    end

    it 'does not create version when only published changes' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content', published: false)
      post.update!(published: true)

      # Should only have workflow version, no auto version
      auto_versions = post.content_versions.where(version_type: 'auto')
      expect(auto_versions.count).to eq(0)
    end

    it 'stores comments_enabled in metadata' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content', comments_enabled: true)
      post.update!(title: 'Updated')

      expect(post.latest_version.metadata_hash['comments_enabled']).to eq(true)
    end

    it 'creates workflow version on publish' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content', published: false)
      post.update!(published: true)

      workflow_versions = post.content_versions.where(version_type: 'workflow')
      expect(workflow_versions.count).to eq(1)
      expect(workflow_versions.first.workflow_state).to eq('published')
    end

    it 'creates workflow version on unpublish' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content', published: true)
      post.update!(published: false)

      workflow_versions = post.content_versions.where(version_type: 'workflow')
      expect(workflow_versions.count).to eq(1)
      expect(workflow_versions.first.workflow_state).to eq('unpublished')
    end
  end

  describe '#published_version' do
    it 'returns nil when published_version_id is nil' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content')
      expect(post.published_version).to be_nil
    end

    it 'returns the content version when published_version_id is set' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content')
      version = post.content_versions.create!(
        version_number: 1,
        version_type: 'workflow',
        workflow_state: 'published',
        title: 'Published Title',
        content: 'Published Content'
      )
      post.update_column(:published_version_id, version.id)

      expect(post.published_version).to eq(version)
      expect(post.published_version.title).to eq('Published Title')
    end
  end

  describe '#has_unpublished_changes?' do
    it 'returns false when not published' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content', status: 'draft')
      expect(post.has_unpublished_changes?).to be false
    end

    it 'returns false when published and no changes' do
      post = Post.create!(title: 'Test', slug: 'test', content: 'Content', status: 'published')
      version = post.content_versions.create!(
        version_number: 1,
        version_type: 'workflow',
        workflow_state: 'published',
        title: 'Test',
        content: 'Content'
      )
      post.update_column(:published_version_id, version.id)

      expect(post.has_unpublished_changes?).to be false
    end

    it 'returns true when working draft differs from published version' do
      post = Post.create!(title: 'Updated Title', slug: 'test', content: 'Content', status: 'draft')
      version = post.content_versions.create!(
        version_number: 1,
        version_type: 'workflow',
        workflow_state: 'published',
        title: 'Original Title',
        content: 'Content'
      )
      post.update_column(:published_version_id, version.id)

      expect(post.has_unpublished_changes?).to be true
    end
  end
end
