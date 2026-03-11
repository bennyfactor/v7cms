require_relative '../spec_helper'

RSpec.describe Page, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      page = Page.new(title: 'About Us', slug: 'about-us', content: 'Content here')
      expect(page).to be_valid
    end

    it 'requires a title' do
      page = Page.new(slug: 'test')
      expect(page).not_to be_valid
      expect(page.errors[:title]).to include("can't be blank")
    end

    it 'requires a slug' do
      page = Page.new(slug: 'test')
      page.title = nil  # Prevent auto-generation
      page.slug = nil   # Now clear the slug
      expect(page).not_to be_valid
      expect(page.errors[:slug]).to include("can't be blank")
    end

    it 'requires unique slug' do
      Page.create!(title: 'First', slug: 'about')
      page = Page.new(title: 'Second', slug: 'about')
      expect(page).not_to be_valid
      expect(page.errors[:slug]).to include('has already been taken')
    end

    it 'validates slug format (lowercase, numbers, hyphens only)' do
      page = Page.new(title: 'Test', slug: 'Invalid Slug!')
      expect(page).not_to be_valid
      expect(page.errors[:slug]).to include('only allows lowercase letters, numbers, and hyphens')
    end

    it 'accepts valid slug formats' do
      expect(Page.new(title: 'Test', slug: 'valid-slug-123')).to be_valid
      expect(Page.new(title: 'Test 2', slug: 'test')).to be_valid
      expect(Page.new(title: 'Test 3', slug: 'test-123')).to be_valid
    end

    it 'validates page_type inclusion' do
      page = Page.new(title: 'Test', slug: 'test', page_type: 'invalid')
      expect(page).not_to be_valid
      expect(page.errors[:page_type]).to include('invalid is not a valid page type')
    end

    it 'accepts valid page types' do
      expect(Page.new(title: 'Test', slug: 'test-1', page_type: 'standard')).to be_valid
      expect(Page.new(title: 'Test', slug: 'test-2', page_type: 'landing')).to be_valid
      expect(Page.new(title: 'Test', slug: 'test-3', page_type: 'contact')).to be_valid
    end

    it 'accepts layout-based page types' do
      %w[blog_list blog_grid hero_grid magazine minimal portfolio landing].each do |type|
        expect(Page.new(title: 'Test', slug: "test-#{type.tr('_', '-')}", page_type: type)).to be_valid
      end
    end

    it 'validates content_source inclusion' do
      page = Page.new(title: 'Test', slug: 'test', content_source: 'invalid')
      expect(page).not_to be_valid
      expect(page.errors[:content_source]).to include('invalid is not a valid content source')
    end

    it 'accepts valid content_source values' do
      expect(Page.new(title: 'Test', slug: 'test-1', content_source: 'children')).to be_valid
      expect(Page.new(title: 'Test', slug: 'test-2', content_source: 'posts')).to be_valid
    end

    it 'validates items_limit is positive integer' do
      page = Page.new(title: 'Test', slug: 'test', items_limit: 0)
      expect(page).not_to be_valid
      expect(page.errors[:items_limit]).to include('must be greater than 0')
    end

    it 'validates items_limit maximum' do
      page = Page.new(title: 'Test', slug: 'test', items_limit: 101)
      expect(page).not_to be_valid
      expect(page.errors[:items_limit]).to include('must be less than or equal to 100')
    end

    it 'defaults content_source to children' do
      page = Page.new(title: 'Test', slug: 'test')
      expect(page.content_source).to eq('children')
    end

    it 'defaults items_limit to 10' do
      page = Page.new(title: 'Test', slug: 'test')
      expect(page.items_limit).to eq(10)
    end

    it 'validates position is non-negative integer' do
      page = Page.new(title: 'Test', slug: 'test', position: -1)
      expect(page).not_to be_valid
      expect(page.errors[:position]).to include('must be greater than or equal to 0')
    end

    it 'validates position is an integer' do
      page = Page.new(title: 'Test', slug: 'test', position: 1.5)
      expect(page).not_to be_valid
      expect(page.errors[:position]).to include('must be an integer')
    end

    describe 'hero_image_url' do
      it 'allows blank hero_image_url' do
        page = Page.new(title: 'Test', slug: 'test', hero_image_url: '')
        expect(page).to be_valid
      end

      it 'allows nil hero_image_url' do
        page = Page.new(title: 'Test', slug: 'test', hero_image_url: nil)
        expect(page).to be_valid
      end

      it 'allows valid http URL' do
        page = Page.new(title: 'Test', slug: 'test', hero_image_url: 'http://example.com/image.jpg')
        expect(page).to be_valid
      end

      it 'allows valid https URL' do
        page = Page.new(title: 'Test', slug: 'test', hero_image_url: 'https://example.com/image.jpg')
        expect(page).to be_valid
      end

      it 'rejects invalid URL format' do
        page = Page.new(title: 'Test', slug: 'test', hero_image_url: 'not a url')
        expect(page).not_to be_valid
        expect(page.errors[:hero_image_url]).to include('must be a valid URL')
      end
    end
  end

  describe 'circular reference prevention' do
    it 'prevents a page from being its own parent' do
      page = Page.create!(title: 'Page', slug: 'page')
      page.parent_id = page.id

      expect(page.valid?).to be false
      expect(page.errors[:parent_id]).to include('cannot be a circular reference')
    end

    it 'prevents a page from being a child of its own descendant' do
      grandparent = Page.create!(title: 'Grandparent', slug: 'grandparent')
      parent = Page.create!(title: 'Parent', slug: 'parent', parent: grandparent)
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)

      # Try to make grandparent a child of child (creates circular reference)
      grandparent.parent_id = child.id

      expect(grandparent.valid?).to be false
      expect(grandparent.errors[:parent_id]).to include('cannot be a circular reference')
    end

    it 'allows valid parent-child relationships' do
      parent = Page.create!(title: 'Parent', slug: 'parent')
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)

      expect(child.valid?).to be true
    end
  end

  describe 'slug generation' do
    it 'automatically generates slug from title' do
      page = Page.new(title: 'About Our Company')
      page.valid?
      expect(page.slug).to eq('about-our-company')
    end

    it 'does not overwrite existing slug' do
      page = Page.new(title: 'About Us', slug: 'custom-slug')
      page.valid?
      expect(page.slug).to eq('custom-slug')
    end

    it 'handles special characters in title' do
      page = Page.new(title: 'Contact Us! (2024)')
      page.valid?
      expect(page.slug).to eq('contact-us-2024')
    end

    it 'handles unicode characters' do
      page = Page.new(title: 'Café & Restaurant')
      page.valid?
      expect(page.slug).to eq('cafe-restaurant')
    end
  end

  describe 'associations' do
    it 'can have a parent page' do
      parent = Page.create!(title: 'Services', slug: 'services')
      child = Page.create!(title: 'Web Development', slug: 'web-development', parent: parent)

      expect(child.parent).to eq(parent)
    end

    it 'can have multiple children' do
      parent = Page.create!(title: 'Services', slug: 'services')
      child1 = Page.create!(title: 'Web Dev', slug: 'web-dev', parent: parent)
      child2 = Page.create!(title: 'Consulting', slug: 'consulting', parent: parent)

      expect(parent.children).to include(child1, child2)
      expect(parent.children.count).to eq(2)
    end

    it 'deletes children when parent is deleted' do
      parent = Page.create!(title: 'Services', slug: 'services')
      child = Page.create!(title: 'Web Dev', slug: 'web-dev', parent: parent)

      expect { parent.destroy }.to change { Page.count }.by(-2)
    end

    it 'allows parent to be nil (top-level page)' do
      page = Page.create!(title: 'About', slug: 'about', parent_id: nil)
      expect(page.parent).to be_nil
      expect(page).to be_valid
    end
  end

  describe 'scopes' do
    before do
      @published = Page.create!(title: 'Published', slug: 'published')
      @published.publish!
      @draft = Page.create!(title: 'Draft', slug: 'draft', status: 'draft')

      @parent = Page.create!(title: 'Parent', slug: 'parent')
      @child = Page.create!(title: 'Child', slug: 'child', parent: @parent)

      @page1 = Page.create!(title: 'Page 1', slug: 'page-1', position: 2)
      @page2 = Page.create!(title: 'Page 2', slug: 'page-2', position: 1)
    end

    it 'published scope returns only published pages' do
      pages = Page.published
      expect(pages).to include(@published)
      expect(pages).not_to include(@draft)
    end

    it 'top_level scope returns pages without parents' do
      pages = Page.top_level
      expect(pages).to include(@parent, @published, @draft, @page1, @page2)
      expect(pages).not_to include(@child)
    end

    it 'ordered scope sorts by position then title' do
      pages = Page.ordered.where(id: [@page1.id, @page2.id])
      expect(pages.first).to eq(@page2) # position 1
      expect(pages.last).to eq(@page1)  # position 2
    end
  end

  describe '#ancestors' do
    it 'returns empty array for top-level page' do
      page = Page.create!(title: 'Top', slug: 'top')
      expect(page.ancestors).to eq([])
    end

    it 'returns direct parent for child page' do
      parent = Page.create!(title: 'Parent', slug: 'parent')
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)

      expect(child.ancestors).to eq([parent])
    end

    it 'returns all ancestors in order (root to parent)' do
      grandparent = Page.create!(title: 'Grandparent', slug: 'grandparent')
      parent = Page.create!(title: 'Parent', slug: 'parent', parent: grandparent)
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)

      expect(child.ancestors).to eq([grandparent, parent])
    end
  end

  describe '#descendants' do
    it 'returns empty array for page without children' do
      page = Page.create!(title: 'Leaf', slug: 'leaf')
      expect(page.descendants).to eq([])
    end

    it 'returns direct children' do
      parent = Page.create!(title: 'Parent', slug: 'parent')
      child1 = Page.create!(title: 'Child 1', slug: 'child-1', parent: parent)
      child2 = Page.create!(title: 'Child 2', slug: 'child-2', parent: parent)

      expect(parent.descendants).to match_array([child1, child2])
    end

    it 'returns all descendants (children and grandchildren)' do
      parent = Page.create!(title: 'Parent', slug: 'parent')
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)
      grandchild = Page.create!(title: 'Grandchild', slug: 'grandchild', parent: child)

      expect(parent.descendants).to match_array([child, grandchild])
    end
  end

  describe '#breadcrumb_trail' do
    it 'returns just self for top-level page' do
      page = Page.create!(title: 'Top', slug: 'top')
      expect(page.breadcrumb_trail).to eq([page])
    end

    it 'returns path from root to self' do
      grandparent = Page.create!(title: 'Grandparent', slug: 'grandparent')
      parent = Page.create!(title: 'Parent', slug: 'parent', parent: grandparent)
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)

      expect(child.breadcrumb_trail).to eq([grandparent, parent, child])
    end
  end

  describe '#has_children?' do
    it 'returns false for page without children' do
      page = Page.create!(title: 'Leaf', slug: 'leaf')
      expect(page.has_children?).to be false
    end

    it 'returns true for page with children' do
      parent = Page.create!(title: 'Parent', slug: 'parent')
      Page.create!(title: 'Child', slug: 'child', parent: parent)

      expect(parent.has_children?).to be true
    end
  end

  describe '#depth' do
    it 'returns 0 for top-level page' do
      page = Page.create!(title: 'Top', slug: 'top')
      expect(page.depth).to eq(0)
    end

    it 'returns 1 for direct child' do
      parent = Page.create!(title: 'Parent', slug: 'parent')
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)

      expect(child.depth).to eq(1)
    end

    it 'returns correct depth for deeply nested page' do
      level1 = Page.create!(title: 'Level 1', slug: 'level-1')
      level2 = Page.create!(title: 'Level 2', slug: 'level-2', parent: level1)
      level3 = Page.create!(title: 'Level 3', slug: 'level-3', parent: level2)

      expect(level3.depth).to eq(2)
    end
  end

  describe 'defaults' do
    it 'defaults status to draft' do
      page = Page.new(title: 'Test', slug: 'test')
      expect(page.status).to eq('draft')
    end

    it 'defaults position to 0' do
      page = Page.new(title: 'Test', slug: 'test')
      expect(page.position).to eq(0)
    end

    it 'defaults page_type to standard' do
      page = Page.new(title: 'Test', slug: 'test')
      expect(page.page_type).to eq('standard')
    end
  end

  describe 'foreign key constraint' do
    it 'cascades delete to children when parent is deleted (due to dependent: :destroy)' do
      parent = Page.create!(title: 'Parent', slug: 'parent')
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)

      expect {
        parent.destroy
      }.to change(Page, :count).by(-2)  # Parent and child both deleted

      expect(Page.exists?(child.id)).to be false
    end

    it 'prevents invalid parent_id references' do
      expect {
        Page.create!(title: 'Orphan', slug: 'orphan', parent_id: 99999)
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'prevents manual deletion of parent when children exist (without using destroy)' do
      parent = Page.create!(title: 'Parent', slug: 'parent')
      child = Page.create!(title: 'Child', slug: 'child', parent: parent)

      # Direct SQL delete bypasses dependent: :destroy and triggers foreign key constraint
      expect {
        ActiveRecord::Base.connection.execute("DELETE FROM pages WHERE id = #{parent.id}")
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe 'query optimization' do
    it 'ancestors method executes only one query regardless of depth' do
      # Create 5-level hierarchy
      level1 = Page.create!(title: 'L1', slug: 'l1')
      level2 = Page.create!(title: 'L2', slug: 'l2', parent: level1)
      level3 = Page.create!(title: 'L3', slug: 'l3', parent: level2)
      level4 = Page.create!(title: 'L4', slug: 'l4', parent: level3)
      level5 = Page.create!(title: 'L5', slug: 'l5', parent: level4)

      # Reload to clear any associations
      level5.reload

      # Count SELECT queries when calling ancestors
      query_count = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        query_count += 1 if payload[:sql] =~ /SELECT.*FROM.*pages/i && payload[:name] != 'SCHEMA'
      end

      result = level5.ancestors

      ActiveSupport::Notifications.unsubscribe(subscriber)

      # Should execute only 1 query (not N queries where N is depth)
      expect(query_count).to eq(1)
      expect(result.length).to eq(4)  # L1, L2, L3, L4
    end
  end

  describe '#full_slug_path' do
    it 'returns just slug for top-level pages' do
      page = Page.create!(title: 'About', slug: 'about')
      expect(page.full_slug_path).to eq('about')
    end

    it 'returns parent/child for one level deep' do
      parent = Page.create!(title: 'Services', slug: 'services')
      child = Page.create!(title: 'Web Dev', slug: 'web-dev', parent: parent)
      expect(child.full_slug_path).to eq('services/web-dev')
    end

    it 'returns full path for deeply nested pages' do
      grandparent = Page.create!(title: 'GP', slug: 'gp')
      parent = Page.create!(title: 'P', slug: 'p', parent: grandparent)
      child = Page.create!(title: 'C', slug: 'c', parent: parent)
      expect(child.full_slug_path).to eq('gp/p/c')
    end
  end

  describe '#items_for_display' do
    let!(:parent_page) do
      page = Page.create!(title: 'Parent', slug: 'parent', page_type: 'blog_grid')
      page.publish!
      page
    end
    let!(:child1) do
      page = Page.create!(title: 'Child 1', slug: 'child-1', parent: parent_page, position: 1)
      page.publish!
      page
    end
    let!(:child2) { Page.create!(title: 'Child 2', slug: 'child-2', status: 'draft', parent: parent_page, position: 2) }
    let!(:child3) do
      page = Page.create!(title: 'Child 3', slug: 'child-3', parent: parent_page, position: 0)
      page.publish!
      page
    end

    it 'returns published children ordered by position when content_source is children' do
      parent_page.update!(content_source: 'children')
      items = parent_page.items_for_display
      expect(items.map(&:title)).to eq(['Child 3', 'Child 1'])
    end

    it 'respects items_limit for children' do
      parent_page.update!(content_source: 'children', items_limit: 1)
      expect(parent_page.items_for_display.count).to eq(1)
    end

    it 'returns published posts when content_source is posts' do
      post1 = V7CMS::Post.create!(title: 'Post 1', slug: 'post-1')
      post1.publish!
      post2 = V7CMS::Post.create!(title: 'Post 2', slug: 'post-2', status: 'draft')
      parent_page.update!(content_source: 'posts')
      items = parent_page.items_for_display
      expect(items.map(&:title)).to include('Post 1')
      expect(items.map(&:title)).not_to include('Post 2')
    end

    it 'respects items_limit for posts' do
      5.times do |i|
        post = V7CMS::Post.create!(title: "Post #{i}", slug: "post-#{i}")
        post.publish!
      end
      parent_page.update!(content_source: 'posts', items_limit: 3)
      expect(parent_page.items_for_display.count).to eq(3)
    end
  end

  describe '#uses_layout_template?' do
    it 'returns true for layout-based page types' do
      page = Page.new(page_type: 'blog_grid')
      expect(page.uses_layout_template?).to be true
    end

    it 'returns false for static page types' do
      page = Page.new(page_type: 'standard')
      expect(page.uses_layout_template?).to be false
    end
  end

  describe 'versioning' do
    it 'includes Versionable concern' do
      expect(Page.ancestors).to include(V7CMS::Versionable)
    end

    it 'creates auto version when title changes' do
      page = Page.create!(title: 'Original', slug: 'test', content: 'Content')
      page.update!(title: 'Updated')

      expect(page.content_versions.count).to eq(1)
    end

    it 'stores page-specific metadata' do
      page = Page.create!(
        title: 'Test',
        slug: 'test',
        content: 'Content',
        page_type: 'blog_grid',
        content_source: 'posts',
        items_limit: 10
      )
      page.update!(title: 'Updated')

      metadata = page.latest_version.metadata_hash
      expect(metadata['page_type']).to eq('blog_grid')
      expect(metadata['content_source']).to eq('posts')
      expect(metadata['items_limit']).to eq(10)
    end

    it 'creates workflow version on publish' do
      page = Page.create!(title: 'Test', slug: 'test', content: 'Content', status: 'draft')
      page.publish!

      workflow_versions = page.content_versions.where(version_type: 'workflow')
      expect(workflow_versions.count).to eq(1)
      expect(workflow_versions.first.workflow_state).to eq('published')
    end
  end

  describe 'editorial workflow' do
    describe 'status validation' do
      it 'requires a valid status' do
        page = Page.new(title: 'Test', slug: 'test', status: 'invalid')
        expect(page).not_to be_valid
        expect(page.errors[:status]).to include('is not included in the list')
      end

      it 'accepts draft status' do
        page = Page.new(title: 'Test', slug: 'test', status: 'draft')
        expect(page).to be_valid
      end

      it 'accepts ready status' do
        page = Page.new(title: 'Test', slug: 'test', status: 'ready')
        expect(page).to be_valid
      end

      it 'accepts published status' do
        page = Page.new(title: 'Test', slug: 'test', status: 'published')
        expect(page).to be_valid
      end
    end

    describe '#published?' do
      it 'returns false when published_version_id is nil' do
        page = Page.create!(title: 'Test', slug: 'test', status: 'draft')
        expect(page.published?).to be false
      end

      it 'returns true when published_version_id is present' do
        page = Page.create!(title: 'Test', slug: 'test', status: 'draft')
        page.publish!
        expect(page.published?).to be true
      end
    end

    describe '#publish!' do
      it 'creates a workflow version' do
        page = Page.create!(title: 'Test', slug: 'test', content: 'Content', status: 'draft')

        expect {
          page.publish!
        }.to change { page.content_versions.where(version_type: 'workflow').count }.by(1)
      end

      it 'sets status to published' do
        page = Page.create!(title: 'Test', slug: 'test', status: 'draft')
        page.publish!
        expect(page.status).to eq('published')
      end

      it 'sets published_version_id' do
        page = Page.create!(title: 'Test', slug: 'test', status: 'draft')
        page.publish!
        expect(page.published_version_id).not_to be_nil
      end

      it 'captures current title and content in version' do
        page = Page.create!(title: 'Original', slug: 'test', content: 'Original content', status: 'draft')
        page.publish!

        version = page.published_version
        expect(version.title).to eq('Original')
        expect(version.content).to eq('Original content')
      end
    end

    describe '#unpublish!' do
      it 'creates an unpublish workflow version' do
        page = Page.create!(title: 'Test', slug: 'test', status: 'draft')
        page.publish!

        expect {
          page.unpublish!
        }.to change { page.content_versions.where(version_type: 'workflow', workflow_state: 'unpublished').count }.by(1)
      end

      it 'sets status to draft' do
        page = Page.create!(title: 'Test', slug: 'test', status: 'draft')
        page.publish!
        page.unpublish!
        expect(page.status).to eq('draft')
      end

      it 'clears published_version_id' do
        page = Page.create!(title: 'Test', slug: 'test', status: 'draft')
        page.publish!
        page.unpublish!
        expect(page.published_version_id).to be_nil
      end
    end

    describe '#has_unpublished_changes?' do
      it 'returns false when not published' do
        page = Page.create!(title: 'Test', slug: 'test', status: 'draft')
        expect(page.has_unpublished_changes?).to be false
      end

      it 'returns false when published with no changes' do
        page = Page.create!(title: 'Test', slug: 'test', status: 'draft')
        page.publish!
        expect(page.has_unpublished_changes?).to be false
      end

      it 'returns true when title changed after publish' do
        page = Page.create!(title: 'Original', slug: 'test', status: 'draft')
        page.publish!
        page.title = 'Updated'
        page.save!
        expect(page.has_unpublished_changes?).to be true
      end

      it 'returns true when content changed after publish' do
        page = Page.create!(title: 'Test', slug: 'test', content: 'Original', status: 'draft')
        page.publish!
        page.content = 'Updated'
        page.save!
        expect(page.has_unpublished_changes?).to be true
      end
    end

    describe 'auto-flip to draft on content change' do
      it 'changes status from published to draft when title changes' do
        page = Page.create!(title: 'Original', slug: 'test', status: 'draft')
        page.publish!

        page.update!(title: 'Updated')
        expect(page.status).to eq('draft')
      end

      it 'changes status from published to draft when content changes' do
        page = Page.create!(title: 'Test', slug: 'test', content: 'Original', status: 'draft')
        page.publish!

        page.update!(content: 'Updated')
        expect(page.status).to eq('draft')
      end

      it 'does not flip to draft when other fields change' do
        page = Page.create!(title: 'Test', slug: 'test', position: 0, status: 'draft')
        page.publish!

        page.update!(position: 1)
        expect(page.status).to eq('published')
      end

      it 'does not flip to draft for non-published pages' do
        page = Page.create!(title: 'Test', slug: 'test', status: 'ready')
        page.update!(title: 'Updated')
        expect(page.status).to eq('ready')
      end
    end
  end

  describe 'content_filter_tag association' do
    it 'belongs to a content_filter_tag (optional)' do
      page = V7CMS::Page.create!(title: 'Blog', slug: 'blog', page_type: 'blog_grid', content_source: 'posts')
      expect(page.content_filter_tag).to be_nil
    end

    it 'can be assigned a tag' do
      tag = V7CMS::Tag.create!(name: 'Ruby')
      page = V7CMS::Page.create!(title: 'Ruby Posts', slug: 'ruby-posts', page_type: 'blog_grid', content_source: 'posts', content_filter_tag: tag)
      expect(page.content_filter_tag).to eq(tag)
    end
  end

  describe '#items_for_display with tag filtering' do
    let(:ruby_tag) { V7CMS::Tag.create!(name: 'Ruby') }
    let(:js_tag) { V7CMS::Tag.create!(name: 'JavaScript') }

    before do
      @ruby_post = V7CMS::Post.create!(title: 'Ruby Post')
      @ruby_post.tags << ruby_tag
      @ruby_post.publish!

      @js_post = V7CMS::Post.create!(title: 'JS Post')
      @js_post.tags << js_tag
      @js_post.publish!

      @both_post = V7CMS::Post.create!(title: 'Both Post')
      @both_post.tags << ruby_tag
      @both_post.tags << js_tag
      @both_post.publish!
    end

    it 'returns all published posts when no tag filter set' do
      page = V7CMS::Page.create!(title: 'All Posts', slug: 'all', page_type: 'blog_list', content_source: 'posts')
      expect(page.items_for_display.count).to eq(3)
    end

    it 'returns only posts with the filtered tag' do
      page = V7CMS::Page.create!(title: 'Ruby Posts', slug: 'ruby', page_type: 'blog_list', content_source: 'posts', content_filter_tag: ruby_tag)
      items = page.items_for_display
      expect(items.count).to eq(2)
      expect(items).to include(@ruby_post, @both_post)
      expect(items).not_to include(@js_post)
    end

    it 'does not filter when content_source is children' do
      parent = V7CMS::Page.create!(title: 'Parent', slug: 'parent', content_filter_tag: ruby_tag)
      child = V7CMS::Page.create!(title: 'Child', slug: 'child', parent: parent)
      child.publish!

      expect(parent.items_for_display).to include(child)
    end

    it 'respects items_limit with tag filter' do
      page = V7CMS::Page.create!(title: 'Ruby Posts', slug: 'ruby', page_type: 'blog_list', content_source: 'posts', content_filter_tag: ruby_tag, items_limit: 1)
      expect(page.items_for_display.count).to eq(1)
    end

    it 'does not return duplicate posts when post has multiple tags' do
      page = V7CMS::Page.create!(title: 'Ruby Posts', slug: 'ruby', page_type: 'blog_list', content_source: 'posts', content_filter_tag: ruby_tag)
      items = page.items_for_display
      expect(items.count).to eq(items.distinct.count)
    end
  end
end
