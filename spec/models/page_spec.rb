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
      @published = Page.create!(title: 'Published', slug: 'published', published: true)
      @draft = Page.create!(title: 'Draft', slug: 'draft', published: false)

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
    it 'defaults published to false' do
      page = Page.new(title: 'Test', slug: 'test')
      expect(page.published).to be false
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
      parent = Page.create!(title: 'Parent', slug: 'parent', published: true)
      child = Page.create!(title: 'Child', slug: 'child', parent: parent, published: true)

      expect {
        parent.destroy
      }.to change(Page, :count).by(-2)  # Parent and child both deleted

      expect(Page.exists?(child.id)).to be false
    end

    it 'prevents invalid parent_id references' do
      expect {
        Page.create!(title: 'Orphan', slug: 'orphan', parent_id: 99999, published: true)
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'prevents manual deletion of parent when children exist (without using destroy)' do
      parent = Page.create!(title: 'Parent', slug: 'parent', published: true)
      child = Page.create!(title: 'Child', slug: 'child', parent: parent, published: true)

      # Direct SQL delete bypasses dependent: :destroy and triggers foreign key constraint
      expect {
        ActiveRecord::Base.connection.execute("DELETE FROM pages WHERE id = #{parent.id}")
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
