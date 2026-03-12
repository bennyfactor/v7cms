# v7cms Future Features Roadmap

> **For Claude:** This document contains detailed specifications for future features. When implementing any feature, read the ENTIRE section for that feature before starting. Use superpowers:executing-plans or superpowers:subagent-driven-development as appropriate.

**Current Version:** 0.1.21
**Last Updated:** 2025-12-04

---

## Table of Contents

1. [Blog Post Layouts](#feature-1-blog-post-layouts) - Priority 1, Low complexity ✅
2. [Image/Asset Uploads](#feature-2-imageasset-uploads) - Priority 2, Medium complexity ✅
3. [Content History](#feature-3-content-history) - Priority 3, Medium complexity ✅
4. [Content Workflow States](#feature-4-content-workflow-states) - Priority 4, Medium complexity ✅
5. [Menu Builder](#feature-5-menu-builder) - Priority 5, Medium complexity
6. [Form Builder](#feature-6-form-builder) - Priority 6, Medium complexity
7. [Customizable Sidebars](#feature-7-customizable-sidebars) - Priority 7, High complexity
8. [Hierarchical Page Display in Admin](#feature-8-hierarchical-page-display-in-admin) - Medium complexity
9. [Bug Fixes & Code Quality](#bug-fixes--code-quality) - Ongoing

---

## Feature 1: Blog Post Layouts

**Goal:** Allow site-wide blog post layout selection (with future per-post override capability).

**Phase 1 (implement first):** Global setting for all posts
**Phase 2 (future):** Per-post layout override option

### Architecture

Add `layout_post` field to Settings model (similar to existing `layout_homepage`). Create post layout templates in `views/layouts/post/` directory. When rendering a single post, use the selected layout template instead of the default `post.erb`.

### Database Changes

**Migration:** `db/migrate/YYYYMMDDHHMMSS_add_layout_post_to_settings.rb`

```ruby
class AddLayoutPostToSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :settings, :layout_post, :string, default: 'standard'
  end
end
```

### Files to Modify

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/YYYYMMDDHHMMSS_add_layout_post_to_settings.rb` | Create | Add layout_post column |
| `lib/v7cms/models/setting.rb` | Modify | Add POST_LAYOUTS constant, validation, available_post_layouts method |
| `lib/v7cms/application.rb` | Modify | Update GET /posts/:slug route to use layout template |
| `lib/v7cms/views/layouts/post/_standard.erb` | Create | Default post layout (extract from current post.erb) |
| `lib/v7cms/views/layouts/post/_magazine.erb` | Create | Magazine-style single post layout |
| `lib/v7cms/views/layouts/post/_minimal.erb` | Create | Minimal single post layout |
| `lib/v7cms/views/layouts/post/_full_width.erb` | Create | Full-width post layout |
| `lib/v7cms/public/admin/index.html` | Modify | Add Post Layout dropdown in Settings tab |
| `lib/v7cms/public/js/admin.js` | Modify | Load and save layout_post setting |
| `spec/models/setting_spec.rb` | Modify | Add tests for layout_post validation |
| `spec/routes/posts_spec.rb` | Modify | Add tests for post layout rendering |

### Setting Model Changes

Add to `lib/v7cms/models/setting.rb`:

```ruby
# After HOMEPAGE_LAYOUTS constant (around line 46)
POST_LAYOUTS = %w[standard magazine minimal full_width].freeze

# Add validation (after layout_homepage validation)
validate :layout_post_must_be_available

# Add method (after available_layouts method)
def self.available_post_layouts
  layouts = POST_LAYOUTS.dup

  views_paths = V7CMS.file_resolver.resolve_all('views')
  views_paths.each do |views_path|
    layout_dir = File.join(views_path, 'layouts', 'post')
    next unless File.directory?(layout_dir)

    Dir.glob(File.join(layout_dir, '_*.erb')).each do |file|
      name = File.basename(file, '.erb').sub(/^_/, '')
      layouts << name unless layouts.include?(name)
    end
  end

  layouts.sort
end

# Add validation method (in private section)
def layout_post_must_be_available
  return if layout_post.blank?

  available = self.class.available_post_layouts
  unless available.include?(layout_post)
    errors.add(:layout_post, "must be a valid layout option (available: #{available.join(', ')})")
  end
end

# Update reset_to_defaults! to include:
layout_post: 'standard'
```

### Application Route Changes

Modify GET `/posts/:slug` route in `lib/v7cms/application.rb` to check for layout:

```ruby
# GET /posts/:slug - Single post page (public)
get '/posts/:slug' do
  @post = V7CMS::Post.published.find_by(slug: params[:slug])
  halt 404, erb(:'404', layout: :layout) unless @post

  @settings = V7CMS::Setting.instance
  @theme = V7CMS::Theme.instance

  layout_name = @settings.layout_post || 'standard'
  layout_path = "layouts/post/_#{layout_name}"

  # Check if layout template exists
  layout_exists = settings.views_paths.any? do |path|
    File.exist?(File.join(path, "#{layout_path}.erb"))
  end

  if layout_exists
    erb layout_path.to_sym, layout: :layout
  else
    erb :post, layout: :layout
  end
end
```

### Post Layout Templates

Create `lib/v7cms/views/layouts/post/_standard.erb`:
```erb
<!-- Standard post layout - extracted from current post.erb -->
<article class="max-w-4xl mx-auto">
  <header class="mb-8">
    <h1 class="text-4xl font-bold text-gray-900 mb-4"><%= @post.title %></h1>
    <div class="flex items-center text-gray-600">
      <time datetime="<%= @post.created_at.iso8601 %>">
        <%= @post.created_at.strftime(@settings.date_format) %>
      </time>
    </div>
  </header>

  <div class="prose prose-lg max-w-none">
    <%= @post.content %>
  </div>

  <% if @post.comments_allowed? %>
    <section class="mt-12 pt-8 border-t">
      <h2 class="text-2xl font-bold mb-6">Comments</h2>
      <div id="comments-section" data-post-id="<%= @post.id %>"></div>
    </section>
    <script src="/js/comments.js"></script>
  <% end %>
</article>
```

Create additional layouts following similar pattern with different styling.

### Admin UI Changes

Add to Settings form in `lib/v7cms/public/admin/index.html` (after Homepage Layout dropdown):

```html
<div class="mb-6">
  <label class="block text-sm font-medium text-gray-700 mb-2">Post Layout</label>
  <select x-model="settings.layout_post" class="w-full px-4 py-2 border border-gray-300 rounded-lg">
    <template x-for="layout in availablePostLayouts" :key="layout">
      <option :value="layout" x-text="layout.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')"></option>
    </template>
  </select>
  <p class="mt-1 text-sm text-gray-500">Layout template for individual blog posts</p>
</div>
```

Add to `lib/v7cms/public/js/admin.js`:
- Add `availablePostLayouts: []` to state
- Add `loadPostLayouts()` method similar to `loadLayouts()`
- Call `loadPostLayouts()` in init()
- Add API endpoint `GET /api/settings/post-layouts`

### API Endpoints

Add to `lib/v7cms/application.rb`:

```ruby
# GET /api/settings/post-layouts - List available post layouts
get '/api/settings/post-layouts' do
  json({ layouts: V7CMS::Setting.available_post_layouts })
end
```

### Tests Required

1. Setting model: layout_post validation
2. Setting model: available_post_layouts discovery
3. Route: GET /posts/:slug uses layout template
4. Route: GET /posts/:slug falls back to post.erb if layout missing
5. API: GET /api/settings/post-layouts returns layouts
6. API: PUT /api/settings accepts layout_post

### Phase 2: Per-Post Override (Future)

When implementing Phase 2, add:
- `layout` column to posts table (nullable, defaults to nil)
- Post rendering checks `@post.layout || @settings.layout_post`
- Admin UI shows layout dropdown on post edit form
- API accepts `layout` field in POST/PUT /api/posts

---

## Feature 2: Image/Asset Uploads

**Goal:** Allow uploading and managing images/assets with abstract storage layer.

### Architecture

- Abstract storage adapter pattern (start with local filesystem, can swap to S3)
- `Asset` model to track uploaded files with metadata
- Simple picker UI in admin for posts/pages (research media library options later)
- Serve uploaded files via dedicated route

### Database Changes

**Migration:** `db/migrate/YYYYMMDDHHMMSS_create_assets.rb`

```ruby
class CreateAssets < ActiveRecord::Migration[7.0]
  def change
    create_table :assets do |t|
      t.string :filename, null: false
      t.string :original_filename, null: false
      t.string :content_type, null: false
      t.integer :file_size, null: false
      t.string :storage_key, null: false  # path/key in storage
      t.string :storage_adapter, default: 'local'  # 'local' or 's3'
      t.integer :width   # for images
      t.integer :height  # for images
      t.string :alt_text
      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :assets, :storage_key, unique: true
    add_index :assets, :content_type
    add_index :assets, :created_at
  end
end
```

### Files to Create

| File | Description |
|------|-------------|
| `lib/v7cms/models/asset.rb` | Asset model with validations and storage methods |
| `lib/v7cms/services/storage/base.rb` | Abstract storage adapter interface |
| `lib/v7cms/services/storage/local_adapter.rb` | Local filesystem storage |
| `lib/v7cms/services/storage/s3_adapter.rb` | S3 storage (stub for future) |
| `lib/v7cms/services/asset_processor.rb` | Image processing (dimensions, thumbnails) |
| `spec/models/asset_spec.rb` | Asset model tests |
| `spec/services/storage/local_adapter_spec.rb` | Local storage tests |

### Files to Modify

| File | Action | Description |
|------|--------|-------------|
| `lib/v7cms/models.rb` | Modify | Require asset model |
| `lib/v7cms/services.rb` | Modify | Require storage adapters |
| `lib/v7cms/application.rb` | Modify | Add asset API routes |
| `lib/v7cms/public/admin/index.html` | Modify | Add Assets tab, image picker in editors |
| `lib/v7cms/public/js/admin.js` | Modify | Add asset management functions |

### Storage Adapter Interface

Create `lib/v7cms/services/storage/base.rb`:

```ruby
module V7CMS
  module Storage
    class Base
      def store(file, key)
        raise NotImplementedError
      end

      def retrieve(key)
        raise NotImplementedError
      end

      def delete(key)
        raise NotImplementedError
      end

      def url(key)
        raise NotImplementedError
      end

      def exists?(key)
        raise NotImplementedError
      end
    end
  end
end
```

Create `lib/v7cms/services/storage/local_adapter.rb`:

```ruby
module V7CMS
  module Storage
    class LocalAdapter < Base
      def initialize(base_path: nil)
        @base_path = base_path || File.join(V7CMS::Application.settings.public_folder, 'uploads')
        FileUtils.mkdir_p(@base_path)
      end

      def store(file, key)
        path = File.join(@base_path, key)
        FileUtils.mkdir_p(File.dirname(path))

        if file.respond_to?(:read)
          File.open(path, 'wb') { |f| f.write(file.read) }
          file.rewind if file.respond_to?(:rewind)
        else
          FileUtils.cp(file, path)
        end

        key
      end

      def retrieve(key)
        path = File.join(@base_path, key)
        File.exist?(path) ? File.open(path, 'rb') : nil
      end

      def delete(key)
        path = File.join(@base_path, key)
        FileUtils.rm_f(path)

        # Clean up empty directories
        dir = File.dirname(path)
        while dir != @base_path && Dir.empty?(dir)
          Dir.rmdir(dir)
          dir = File.dirname(dir)
        end
      end

      def url(key)
        "/uploads/#{key}"
      end

      def exists?(key)
        File.exist?(File.join(@base_path, key))
      end
    end
  end
end
```

### Asset Model

Create `lib/v7cms/models/asset.rb`:

```ruby
module V7CMS
  class Asset < ActiveRecord::Base
    belongs_to :uploaded_by, class_name: 'V7CMS::User', optional: true

    validates :filename, presence: true
    validates :original_filename, presence: true
    validates :content_type, presence: true
    validates :file_size, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 10.megabytes }
    validates :storage_key, presence: true, uniqueness: true

    ALLOWED_CONTENT_TYPES = %w[
      image/jpeg image/png image/gif image/webp image/svg+xml
      application/pdf
      text/plain text/csv
    ].freeze

    validates :content_type, inclusion: {
      in: ALLOWED_CONTENT_TYPES,
      message: 'is not an allowed file type'
    }

    before_destroy :delete_from_storage

    scope :images, -> { where("content_type LIKE 'image/%'") }
    scope :recent, -> { order(created_at: :desc) }

    def image?
      content_type.start_with?('image/')
    end

    def url
      storage_adapter_instance.url(storage_key)
    end

    def self.upload(file:, original_filename:, content_type:, uploaded_by: nil)
      # Generate unique storage key
      ext = File.extname(original_filename)
      timestamp = Time.now.strftime('%Y/%m/%d')
      unique_id = SecureRandom.hex(8)
      storage_key = "#{timestamp}/#{unique_id}#{ext}"

      # Store file
      adapter = storage_adapter_instance
      adapter.store(file, storage_key)

      # Get file size
      file_size = file.respond_to?(:size) ? file.size : File.size(file)

      # Get image dimensions if applicable
      width, height = nil, nil
      if content_type.start_with?('image/') && !content_type.include?('svg')
        width, height = AssetProcessor.dimensions(file)
      end

      create!(
        filename: File.basename(storage_key),
        original_filename: original_filename,
        content_type: content_type,
        file_size: file_size,
        storage_key: storage_key,
        storage_adapter: 'local',
        width: width,
        height: height,
        uploaded_by: uploaded_by
      )
    end

    private

    def storage_adapter_instance
      self.class.storage_adapter_instance
    end

    def self.storage_adapter_instance
      @storage_adapter ||= V7CMS::Storage::LocalAdapter.new
    end

    def delete_from_storage
      storage_adapter_instance.delete(storage_key)
    rescue => e
      Rails.logger.error "Failed to delete asset from storage: #{e.message}"
    end
  end
end
```

### Asset Processor

Create `lib/v7cms/services/asset_processor.rb`:

```ruby
module V7CMS
  class AssetProcessor
    # Get image dimensions without loading full image into memory
    def self.dimensions(file)
      return nil, nil unless defined?(MiniMagick)

      path = file.respond_to?(:path) ? file.path : file
      image = MiniMagick::Image.open(path)
      [image.width, image.height]
    rescue => e
      [nil, nil]
    end
  end
end
```

Note: MiniMagick is optional. If not present, dimensions will be nil.

### API Endpoints

Add to `lib/v7cms/application.rb`:

```ruby
# ==================== ASSETS API ====================

# GET /api/assets - List assets
get '/api/assets' do
  require_login

  assets = V7CMS::Asset.recent
  assets = assets.images if params[:images_only] == 'true'
  assets = assets.limit(params[:limit]&.to_i || 50)

  json({
    assets: assets.map { |a| asset_json(a) }
  })
end

# GET /api/assets/:id - Get single asset
get '/api/assets/:id' do
  require_login

  asset = V7CMS::Asset.find_by(id: params[:id])
  halt 404, json({ error: 'Asset not found' }) unless asset

  json({ asset: asset_json(asset) })
end

# POST /api/assets - Upload new asset
post '/api/assets' do
  require_ajax_header
  require_login

  unless params[:file] && params[:file][:tempfile]
    halt 400, json({ error: 'No file provided' })
  end

  file = params[:file][:tempfile]
  original_filename = params[:file][:filename]
  content_type = params[:file][:type] || 'application/octet-stream'

  asset = V7CMS::Asset.upload(
    file: file,
    original_filename: original_filename,
    content_type: content_type,
    uploaded_by: current_user
  )

  status 201
  json({ asset: asset_json(asset) })
rescue ActiveRecord::RecordInvalid => e
  halt 422, json({ error: e.message })
end

# DELETE /api/assets/:id - Delete asset
delete '/api/assets/:id' do
  require_ajax_header
  require_login

  asset = V7CMS::Asset.find_by(id: params[:id])
  halt 404, json({ error: 'Asset not found' }) unless asset

  asset.destroy
  json({ success: true })
end

# Helper
def asset_json(asset)
  {
    id: asset.id,
    filename: asset.filename,
    original_filename: asset.original_filename,
    content_type: asset.content_type,
    file_size: asset.file_size,
    url: asset.url,
    width: asset.width,
    height: asset.height,
    alt_text: asset.alt_text,
    created_at: asset.created_at.iso8601
  }
end
```

### Admin UI Changes

Add Assets tab to admin navigation and create asset picker modal for Quill editors.

The asset picker should:
1. Show grid of uploaded images
2. Allow drag-and-drop upload
3. Allow selecting image to insert into editor
4. Show upload progress

### .gitignore Update

Ensure uploads directory is in `.gitignore`:
```
/public/uploads/
```

### Tests Required

1. Asset model: validations (file size, content type)
2. Asset model: upload creates file and record
3. Asset model: destroy removes file
4. LocalAdapter: store, retrieve, delete, url
5. API: POST /api/assets uploads file
6. API: GET /api/assets lists assets
7. API: DELETE /api/assets/:id removes asset

### Future Enhancements

- S3 adapter implementation
- Image thumbnails/resizing
- Media library with folders and search
- Bulk upload
- Image optimization on upload

---

## Feature 3: Content History

**Goal:** Track milestone versions of posts and pages with author attribution.

### Architecture

Create `ContentVersion` model that stores snapshots at key workflow states (submitted, approved, published). Each version stores the full content, who made the change, and when.

### Database Changes

**Migration:** `db/migrate/YYYYMMDDHHMMSS_create_content_versions.rb`

```ruby
class CreateContentVersions < ActiveRecord::Migration[7.0]
  def change
    create_table :content_versions do |t|
      t.string :versionable_type, null: false  # 'Post' or 'Page'
      t.integer :versionable_id, null: false
      t.integer :version_number, null: false
      t.string :state, null: false  # 'submitted', 'approved', 'published'
      t.text :title
      t.text :content
      t.text :metadata  # JSON blob for other fields (slug, page_type, etc.)
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false
    end

    add_index :content_versions, [:versionable_type, :versionable_id, :version_number],
              unique: true, name: 'idx_content_versions_unique'
    add_index :content_versions, [:versionable_type, :versionable_id, :state]
  end
end
```

### Files to Create

| File | Description |
|------|-------------|
| `lib/v7cms/models/content_version.rb` | ContentVersion model |
| `lib/v7cms/models/concerns/versionable.rb` | Shared module for Post/Page |
| `spec/models/content_version_spec.rb` | Model tests |

### ContentVersion Model

Create `lib/v7cms/models/content_version.rb`:

```ruby
module V7CMS
  class ContentVersion < ActiveRecord::Base
    belongs_to :versionable, polymorphic: true
    belongs_to :created_by, class_name: 'V7CMS::User', optional: true

    STATES = %w[submitted approved published].freeze

    validates :version_number, presence: true, numericality: { greater_than: 0 }
    validates :state, inclusion: { in: STATES }
    validates :title, presence: true

    scope :for_record, ->(record) {
      where(versionable_type: record.class.name.demodulize, versionable_id: record.id)
    }
    scope :by_version, -> { order(version_number: :desc) }

    def metadata_hash
      return {} if metadata.blank?
      JSON.parse(metadata)
    rescue JSON::ParserError
      {}
    end

    def restore_to_parent!
      parent = versionable
      parent.title = title
      parent.content = content

      # Restore metadata fields
      metadata_hash.each do |key, value|
        parent.send("#{key}=", value) if parent.respond_to?("#{key}=")
      end

      parent.save!
    end
  end
end
```

### Versionable Concern

Create `lib/v7cms/models/concerns/versionable.rb`:

```ruby
module V7CMS
  module Versionable
    extend ActiveSupport::Concern

    included do
      has_many :content_versions,
               -> { order(version_number: :desc) },
               as: :versionable,
               class_name: 'V7CMS::ContentVersion',
               dependent: :destroy
    end

    def create_version!(state:, created_by: nil)
      next_version = (content_versions.maximum(:version_number) || 0) + 1

      content_versions.create!(
        version_number: next_version,
        state: state,
        title: title,
        content: content,
        metadata: version_metadata.to_json,
        created_by: created_by
      )
    end

    def latest_version
      content_versions.first
    end

    def version_at(number)
      content_versions.find_by(version_number: number)
    end

    def restore_version!(number)
      version = version_at(number)
      raise ActiveRecord::RecordNotFound, "Version #{number} not found" unless version
      version.restore_to_parent!
    end

    private

    # Override in models to specify which fields to store in metadata
    def version_metadata
      { slug: slug }
    end
  end
end
```

### Model Updates

Add to `lib/v7cms/models/post.rb`:

```ruby
include V7CMS::Versionable

private

def version_metadata
  {
    slug: slug,
    comments_enabled: comments_enabled
  }
end
```

Add to `lib/v7cms/models/page.rb`:

```ruby
include V7CMS::Versionable

private

def version_metadata
  {
    slug: slug,
    page_type: page_type,
    content_source: content_source,
    items_limit: items_limit,
    position: position,
    parent_id: parent_id
  }
end
```

### API Endpoints

Add to `lib/v7cms/application.rb`:

```ruby
# GET /api/posts/:id/versions - List versions for a post
get '/api/posts/:id/versions' do
  require_login

  post = V7CMS::Post.find_by(id: params[:id])
  halt 404, json({ error: 'Post not found' }) unless post

  json({
    versions: post.content_versions.map { |v| version_json(v) }
  })
end

# GET /api/posts/:id/versions/:version - Get specific version
get '/api/posts/:id/versions/:version' do
  require_login

  post = V7CMS::Post.find_by(id: params[:id])
  halt 404, json({ error: 'Post not found' }) unless post

  version = post.version_at(params[:version].to_i)
  halt 404, json({ error: 'Version not found' }) unless version

  json({ version: version_json(version, include_content: true) })
end

# POST /api/posts/:id/versions/:version/restore - Restore to version
post '/api/posts/:id/versions/:version/restore' do
  require_ajax_header
  require_login

  post = V7CMS::Post.find_by(id: params[:id])
  halt 404, json({ error: 'Post not found' }) unless post

  post.restore_version!(params[:version].to_i)
  json({ post: post_json(post) })
rescue ActiveRecord::RecordNotFound => e
  halt 404, json({ error: e.message })
end

# Similar endpoints for pages...

def version_json(version, include_content: false)
  result = {
    version_number: version.version_number,
    state: version.state,
    title: version.title,
    created_at: version.created_at.iso8601,
    created_by: version.created_by&.name || 'Unknown'
  }
  result[:content] = version.content if include_content
  result[:metadata] = version.metadata_hash if include_content
  result
end
```

### Admin UI Changes

Add version history panel to post/page editor:
- Show list of versions with state, author, date
- "View" button to see version content in modal
- "Restore" button to revert to that version

### Tests Required

1. ContentVersion model: validations
2. ContentVersion model: metadata parsing
3. ContentVersion model: restore_to_parent!
4. Versionable concern: create_version!
5. Versionable concern: version_at, restore_version!
6. Post/Page integration: versions are created
7. API: GET versions list
8. API: POST restore version

---

## Feature 4: Content Workflow States

**Goal:** Self-review workflow with save → submit → approve → publish states. Architecture supports future role-based permissions.

### Architecture

Add `workflow_state` field to posts and pages. States flow: `draft` → `submitted` → `approved` → `published`. Each state transition creates a content version (using Feature 3). "Undo" restores to last approved version.

### Prerequisites

- **Feature 3 (Content History)** must be implemented first - workflow transitions create versions

### Database Changes

**Migration:** `db/migrate/YYYYMMDDHHMMSS_add_workflow_state_to_content.rb`

```ruby
class AddWorkflowStateToContent < ActiveRecord::Migration[7.0]
  def change
    add_column :posts, :workflow_state, :string, default: 'draft'
    add_column :pages, :workflow_state, :string, default: 'draft'

    add_index :posts, :workflow_state
    add_index :pages, :workflow_state

    # Migrate existing published content
    reversible do |dir|
      dir.up do
        execute "UPDATE posts SET workflow_state = 'published' WHERE published = true"
        execute "UPDATE pages SET workflow_state = 'published' WHERE published = true"
      end
    end
  end
end
```

### Workflow States

| State | Description | Can Edit | Public Visible |
|-------|-------------|----------|----------------|
| `draft` | Initial state, work in progress | Yes | No |
| `submitted` | Ready for review | No (must undo first) | No |
| `approved` | Reviewed and approved | No (must undo first) | No |
| `published` | Live on site | Creates new draft | Yes |

### Files to Create

| File | Description |
|------|-------------|
| `lib/v7cms/models/concerns/workflowable.rb` | Shared workflow state machine |
| `spec/models/concerns/workflowable_spec.rb` | Workflow tests |

### Workflowable Concern

Create `lib/v7cms/models/concerns/workflowable.rb`:

```ruby
module V7CMS
  module Workflowable
    extend ActiveSupport::Concern

    WORKFLOW_STATES = %w[draft submitted approved published].freeze

    included do
      validates :workflow_state, inclusion: { in: WORKFLOW_STATES }

      scope :drafts, -> { where(workflow_state: 'draft') }
      scope :submitted, -> { where(workflow_state: 'submitted') }
      scope :approved, -> { where(workflow_state: 'approved') }
      # published scope already exists
    end

    def submit!(by: nil)
      raise InvalidTransition, "Cannot submit from #{workflow_state}" unless can_submit?

      create_version!(state: 'submitted', created_by: by)
      update!(workflow_state: 'submitted')
    end

    def approve!(by: nil)
      raise InvalidTransition, "Cannot approve from #{workflow_state}" unless can_approve?

      create_version!(state: 'approved', created_by: by)
      update!(workflow_state: 'approved')
    end

    def publish!(by: nil)
      raise InvalidTransition, "Cannot publish from #{workflow_state}" unless can_publish?

      create_version!(state: 'published', created_by: by)
      update!(workflow_state: 'published', published: true)
    end

    def undo!(by: nil)
      raise InvalidTransition, "Cannot undo from #{workflow_state}" unless can_undo?

      # Find last approved version and restore
      last_approved = content_versions.find_by(state: 'approved')
      if last_approved
        last_approved.restore_to_parent!
        update!(workflow_state: 'draft')
      else
        update!(workflow_state: 'draft')
      end
    end

    def unpublish!(by: nil)
      raise InvalidTransition, "Cannot unpublish" unless published?
      update!(workflow_state: 'draft', published: false)
    end

    # Transition guards
    def can_submit?
      workflow_state == 'draft'
    end

    def can_approve?
      workflow_state == 'submitted'
    end

    def can_publish?
      workflow_state == 'approved'
    end

    def can_undo?
      %w[submitted approved].include?(workflow_state)
    end

    def editable?
      workflow_state == 'draft'
    end

    class InvalidTransition < StandardError; end
  end
end
```

### Model Updates

Add to both `lib/v7cms/models/post.rb` and `lib/v7cms/models/page.rb`:

```ruby
include V7CMS::Workflowable
```

### API Endpoints

Add workflow action endpoints:

```ruby
# POST /api/posts/:id/submit
post '/api/posts/:id/submit' do
  require_ajax_header
  require_login

  post = V7CMS::Post.find_by(id: params[:id])
  halt 404, json({ error: 'Post not found' }) unless post

  post.submit!(by: current_user)
  json({ post: post_json(post) })
rescue V7CMS::Workflowable::InvalidTransition => e
  halt 422, json({ error: e.message })
end

# POST /api/posts/:id/approve
post '/api/posts/:id/approve' do
  require_ajax_header
  require_login

  post = V7CMS::Post.find_by(id: params[:id])
  halt 404, json({ error: 'Post not found' }) unless post

  post.approve!(by: current_user)
  json({ post: post_json(post) })
rescue V7CMS::Workflowable::InvalidTransition => e
  halt 422, json({ error: e.message })
end

# POST /api/posts/:id/publish
post '/api/posts/:id/publish' do
  require_ajax_header
  require_login

  post = V7CMS::Post.find_by(id: params[:id])
  halt 404, json({ error: 'Post not found' }) unless post

  post.publish!(by: current_user)
  json({ post: post_json(post) })
rescue V7CMS::Workflowable::InvalidTransition => e
  halt 422, json({ error: e.message })
end

# POST /api/posts/:id/undo
post '/api/posts/:id/undo' do
  require_ajax_header
  require_login

  post = V7CMS::Post.find_by(id: params[:id])
  halt 404, json({ error: 'Post not found' }) unless post

  post.undo!(by: current_user)
  json({ post: post_json(post) })
rescue V7CMS::Workflowable::InvalidTransition => e
  halt 422, json({ error: e.message })
end

# Similar endpoints for pages...
```

Update `post_json` and `page_json` helpers to include:
```ruby
workflow_state: record.workflow_state,
can_submit: record.can_submit?,
can_approve: record.can_approve?,
can_publish: record.can_publish?,
can_undo: record.can_undo?,
editable: record.editable?
```

### Admin UI Changes

Replace simple "Published" toggle with workflow buttons:

```html
<div class="workflow-actions flex gap-2">
  <template x-if="currentPost.workflow_state === 'draft'">
    <button @click="submitPost()" class="px-4 py-2 bg-blue-500 text-white rounded">
      Submit for Review
    </button>
  </template>

  <template x-if="currentPost.workflow_state === 'submitted'">
    <div class="flex gap-2">
      <button @click="approvePost()" class="px-4 py-2 bg-green-500 text-white rounded">
        Approve
      </button>
      <button @click="undoPost()" class="px-4 py-2 bg-gray-500 text-white rounded">
        Undo (Back to Draft)
      </button>
    </div>
  </template>

  <template x-if="currentPost.workflow_state === 'approved'">
    <div class="flex gap-2">
      <button @click="publishPost()" class="px-4 py-2 bg-green-600 text-white rounded">
        Publish
      </button>
      <button @click="undoPost()" class="px-4 py-2 bg-gray-500 text-white rounded">
        Undo (Back to Draft)
      </button>
    </div>
  </template>

  <template x-if="currentPost.workflow_state === 'published'">
    <button @click="unpublishPost()" class="px-4 py-2 bg-red-500 text-white rounded">
      Unpublish
    </button>
  </template>
</div>

<div class="workflow-state mt-2 text-sm text-gray-600">
  State: <span x-text="currentPost.workflow_state" class="font-semibold"></span>
</div>
```

Disable form fields when not editable:
```html
<input :disabled="!currentPost.editable" ...>
```

### Tests Required

1. Workflowable: state transitions
2. Workflowable: invalid transitions raise error
3. Workflowable: versions created on transitions
4. Workflowable: undo restores content
5. API: workflow action endpoints
6. Integration: full workflow cycle

### Future: Role-Based Permissions

When adding roles, modify transition guards:

```ruby
def can_approve?
  workflow_state == 'submitted' &&
    (current_user.admin? || current_user.role?(:editor))
end
```

Add roles migration:
```ruby
add_column :users, :role, :string, default: 'contributor'
# Roles: contributor (draft only), editor (can approve), admin (full access)
```

---

## Feature 5: Menu Builder

**Goal:** Create and manage multiple named menus with pages, posts, and custom links.

### Architecture

- `Menu` model for named menus (main, footer, sidebar, etc.)
- `MenuItem` model for menu entries with polymorphic links
- Nested structure for dropdown menus
- Template helpers to render menus

### Database Changes

**Migration:** `db/migrate/YYYYMMDDHHMMSS_create_menus.rb`

```ruby
class CreateMenus < ActiveRecord::Migration[7.0]
  def change
    create_table :menus do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :location  # 'header', 'footer', 'sidebar', etc.
      t.timestamps
    end

    add_index :menus, :slug, unique: true
    add_index :menus, :location

    create_table :menu_items do |t|
      t.references :menu, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :menu_items }
      t.string :label, null: false
      t.string :link_type, null: false  # 'page', 'post', 'custom'
      t.integer :linkable_id  # for page/post
      t.string :linkable_type  # 'Page' or 'Post'
      t.string :url  # for custom links
      t.string :target  # '_blank' for new tab
      t.string :css_class
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :menu_items, [:menu_id, :position]
    add_index :menu_items, [:linkable_type, :linkable_id]
  end
end
```

### Files to Create

| File | Description |
|------|-------------|
| `lib/v7cms/models/menu.rb` | Menu model |
| `lib/v7cms/models/menu_item.rb` | MenuItem model |
| `lib/v7cms/helpers/menu_helper.rb` | Template helpers |
| `spec/models/menu_spec.rb` | Menu tests |
| `spec/models/menu_item_spec.rb` | MenuItem tests |

### Menu Model

Create `lib/v7cms/models/menu.rb`:

```ruby
module V7CMS
  class Menu < ActiveRecord::Base
    has_many :menu_items, -> { order(:position) }, dependent: :destroy
    has_many :root_items, -> { where(parent_id: nil).order(:position) },
             class_name: 'V7CMS::MenuItem'

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true,
              format: { with: /\A[a-z0-9_-]+\z/, message: 'only allows lowercase letters, numbers, hyphens, and underscores' }

    LOCATIONS = %w[header footer sidebar].freeze
    validates :location, inclusion: { in: LOCATIONS }, allow_blank: true

    before_validation :generate_slug, if: -> { slug.blank? && name.present? }

    def self.at_location(location)
      find_by(location: location)
    end

    def self.by_slug(slug)
      find_by(slug: slug)
    end

    # Build nested structure for rendering
    def nested_items
      root_items.includes(:children).map(&:to_nested_hash)
    end

    private

    def generate_slug
      self.slug = name.parameterize
    end
  end
end
```

### MenuItem Model

Create `lib/v7cms/models/menu_item.rb`:

```ruby
module V7CMS
  class MenuItem < ActiveRecord::Base
    belongs_to :menu
    belongs_to :parent, class_name: 'V7CMS::MenuItem', optional: true
    has_many :children, -> { order(:position) }, class_name: 'V7CMS::MenuItem',
             foreign_key: :parent_id, dependent: :destroy

    belongs_to :linkable, polymorphic: true, optional: true

    LINK_TYPES = %w[page post custom].freeze

    validates :label, presence: true
    validates :link_type, inclusion: { in: LINK_TYPES }
    validates :url, presence: true, if: -> { link_type == 'custom' }
    validates :linkable, presence: true, if: -> { link_type.in?(%w[page post]) }
    validate :prevent_circular_reference

    def href
      case link_type
      when 'page'
        linkable ? "/#{linkable.full_slug_path}" : '#'
      when 'post'
        linkable ? "/posts/#{linkable.slug}" : '#'
      when 'custom'
        url
      else
        '#'
      end
    end

    def to_nested_hash
      {
        id: id,
        label: label,
        href: href,
        target: target,
        css_class: css_class,
        children: children.map(&:to_nested_hash)
      }
    end

    private

    def prevent_circular_reference
      return if parent_id.nil?

      if parent_id == id
        errors.add(:parent_id, 'cannot be self')
        return
      end

      # Check if parent is a descendant
      current = parent
      while current
        if current.id == id
          errors.add(:parent_id, 'cannot create circular reference')
          return
        end
        current = current.parent
      end
    end
  end
end
```

### Menu Helper

Create `lib/v7cms/helpers/menu_helper.rb`:

```ruby
module V7CMS
  module MenuHelper
    def render_menu(menu_or_slug, options = {})
      menu = menu_or_slug.is_a?(V7CMS::Menu) ? menu_or_slug : V7CMS::Menu.by_slug(menu_or_slug.to_s)
      return '' unless menu

      wrapper_class = options[:class] || 'menu'
      item_class = options[:item_class] || 'menu-item'
      link_class = options[:link_class] || 'menu-link'

      items_html = menu.root_items.map do |item|
        render_menu_item(item, item_class: item_class, link_class: link_class)
      end.join

      "<nav class=\"#{wrapper_class}\"><ul>#{items_html}</ul></nav>"
    end

    def render_menu_item(item, item_class:, link_class:)
      has_children = item.children.any?

      children_html = if has_children
        children = item.children.map do |child|
          render_menu_item(child, item_class: item_class, link_class: link_class)
        end.join
        "<ul class=\"submenu\">#{children}</ul>"
      else
        ''
      end

      target_attr = item.target.present? ? " target=\"#{item.target}\"" : ''
      css_class = [item_class, item.css_class, ('has-children' if has_children)].compact.join(' ')

      "<li class=\"#{css_class}\">" \
        "<a href=\"#{item.href}\" class=\"#{link_class}\"#{target_attr}>#{item.label}</a>" \
        "#{children_html}" \
      "</li>"
    end
  end
end
```

Register helper in application:
```ruby
helpers V7CMS::MenuHelper
```

### API Endpoints

```ruby
# ==================== MENUS API ====================

# GET /api/menus - List all menus
get '/api/menus' do
  require_login

  menus = V7CMS::Menu.includes(:menu_items).all
  json({ menus: menus.map { |m| menu_json(m) } })
end

# GET /api/menus/:id - Get menu with items
get '/api/menus/:id' do
  require_login

  menu = V7CMS::Menu.find_by(id: params[:id]) || V7CMS::Menu.find_by(slug: params[:id])
  halt 404, json({ error: 'Menu not found' }) unless menu

  json({ menu: menu_json(menu, include_items: true) })
end

# POST /api/menus - Create menu
post '/api/menus' do
  require_ajax_header
  require_login

  data = JSON.parse(request.body.read)
  menu = V7CMS::Menu.create!(
    name: data['name'],
    slug: data['slug'],
    location: data['location']
  )

  status 201
  json({ menu: menu_json(menu) })
rescue ActiveRecord::RecordInvalid => e
  halt 422, json({ error: e.message })
end

# PUT /api/menus/:id - Update menu
put '/api/menus/:id' do
  require_ajax_header
  require_login

  menu = V7CMS::Menu.find_by(id: params[:id])
  halt 404, json({ error: 'Menu not found' }) unless menu

  data = JSON.parse(request.body.read)
  menu.update!(
    name: data['name'],
    location: data['location']
  )

  json({ menu: menu_json(menu) })
rescue ActiveRecord::RecordInvalid => e
  halt 422, json({ error: e.message })
end

# DELETE /api/menus/:id - Delete menu
delete '/api/menus/:id' do
  require_ajax_header
  require_login

  menu = V7CMS::Menu.find_by(id: params[:id])
  halt 404, json({ error: 'Menu not found' }) unless menu

  menu.destroy
  json({ success: true })
end

# POST /api/menus/:id/items - Add item to menu
post '/api/menus/:id/items' do
  require_ajax_header
  require_login

  menu = V7CMS::Menu.find_by(id: params[:id])
  halt 404, json({ error: 'Menu not found' }) unless menu

  data = JSON.parse(request.body.read)

  item = menu.menu_items.create!(
    label: data['label'],
    link_type: data['link_type'],
    linkable_type: data['linkable_type'],
    linkable_id: data['linkable_id'],
    url: data['url'],
    target: data['target'],
    css_class: data['css_class'],
    parent_id: data['parent_id'],
    position: data['position'] || 0
  )

  status 201
  json({ item: menu_item_json(item) })
rescue ActiveRecord::RecordInvalid => e
  halt 422, json({ error: e.message })
end

# PUT /api/menu-items/:id - Update menu item
put '/api/menu-items/:id' do
  require_ajax_header
  require_login

  item = V7CMS::MenuItem.find_by(id: params[:id])
  halt 404, json({ error: 'Menu item not found' }) unless item

  data = JSON.parse(request.body.read)
  item.update!(
    label: data['label'],
    link_type: data['link_type'],
    linkable_type: data['linkable_type'],
    linkable_id: data['linkable_id'],
    url: data['url'],
    target: data['target'],
    css_class: data['css_class'],
    parent_id: data['parent_id'],
    position: data['position']
  )

  json({ item: menu_item_json(item) })
rescue ActiveRecord::RecordInvalid => e
  halt 422, json({ error: e.message })
end

# DELETE /api/menu-items/:id - Delete menu item
delete '/api/menu-items/:id' do
  require_ajax_header
  require_login

  item = V7CMS::MenuItem.find_by(id: params[:id])
  halt 404, json({ error: 'Menu item not found' }) unless item

  item.destroy
  json({ success: true })
end

# PUT /api/menus/:id/reorder - Reorder menu items
put '/api/menus/:id/reorder' do
  require_ajax_header
  require_login

  menu = V7CMS::Menu.find_by(id: params[:id])
  halt 404, json({ error: 'Menu not found' }) unless menu

  data = JSON.parse(request.body.read)
  # data['items'] = [{ id: 1, position: 0, parent_id: null }, ...]

  V7CMS::MenuItem.transaction do
    data['items'].each do |item_data|
      item = menu.menu_items.find(item_data['id'])
      item.update!(position: item_data['position'], parent_id: item_data['parent_id'])
    end
  end

  json({ menu: menu_json(menu.reload, include_items: true) })
end

def menu_json(menu, include_items: false)
  result = {
    id: menu.id,
    name: menu.name,
    slug: menu.slug,
    location: menu.location,
    created_at: menu.created_at.iso8601
  }
  result[:items] = menu.nested_items if include_items
  result
end

def menu_item_json(item)
  {
    id: item.id,
    label: item.label,
    link_type: item.link_type,
    linkable_type: item.linkable_type,
    linkable_id: item.linkable_id,
    url: item.url,
    href: item.href,
    target: item.target,
    css_class: item.css_class,
    parent_id: item.parent_id,
    position: item.position
  }
end
```

### Admin UI

Add Menus tab with:
- List of menus with edit/delete
- Create new menu form
- Menu editor with drag-and-drop item ordering
- Item form: type selector, page/post picker, custom URL field
- Nested item support (drag to indent)

### Template Usage

In layout templates:
```erb
<header>
  <%= render_menu('main', class: 'main-nav', link_class: 'nav-link') %>
</header>

<footer>
  <%= render_menu('footer', class: 'footer-nav') %>
</footer>
```

### Tests Required

1. Menu model: validations, slug generation
2. MenuItem model: validations, href generation
3. MenuItem model: circular reference prevention
4. MenuHelper: render_menu output
5. API: CRUD operations
6. API: reorder items
7. Integration: menu renders in template

---

## Feature 6: Form Builder

**Goal:** Create forms that can be embedded in pages with reCAPTCHA protection.

### Architecture

- `Form` model for form definitions
- `FormField` model for field configuration
- `FormSubmission` model for submitted data
- Embed forms in pages via shortcode or page type
- Email notifications on submission
- reCAPTCHA v3 protection (reuse existing infrastructure from comments)

### Database Changes

**Migration:** `db/migrate/YYYYMMDDHHMMSS_create_forms.rb`

```ruby
class CreateForms < ActiveRecord::Migration[7.0]
  def change
    create_table :forms do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :submit_button_text, default: 'Submit'
      t.string :success_message, default: 'Thank you for your submission!'
      t.string :notification_email  # where to send submissions
      t.boolean :store_submissions, default: true
      t.boolean :send_notifications, default: true
      t.boolean :require_recaptcha, default: true
      t.float :recaptcha_threshold, default: 0.5
      t.timestamps
    end

    add_index :forms, :slug, unique: true

    create_table :form_fields do |t|
      t.references :form, null: false, foreign_key: true
      t.string :field_type, null: false  # text, email, textarea, select, checkbox
      t.string :name, null: false  # field identifier
      t.string :label, null: false
      t.text :placeholder
      t.text :help_text
      t.boolean :required, default: false
      t.text :options  # JSON for select options
      t.text :validation_rules  # JSON for custom validation
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :form_fields, [:form_id, :position]
    add_index :form_fields, [:form_id, :name], unique: true

    create_table :form_submissions do |t|
      t.references :form, null: false, foreign_key: true
      t.text :data, null: false  # JSON of submitted values
      t.string :ip_address
      t.float :recaptcha_score
      t.boolean :spam, default: false
      t.datetime :created_at, null: false
    end

    add_index :form_submissions, :created_at
    add_index :form_submissions, [:form_id, :spam]
  end
end
```

### Files to Create

| File | Description |
|------|-------------|
| `lib/v7cms/models/form.rb` | Form model |
| `lib/v7cms/models/form_field.rb` | FormField model |
| `lib/v7cms/models/form_submission.rb` | FormSubmission model |
| `lib/v7cms/services/form_renderer.rb` | Render form HTML |
| `lib/v7cms/services/form_mailer.rb` | Email notifications |
| `lib/v7cms/helpers/form_helper.rb` | Template helpers |
| `lib/v7cms/public/js/forms.js` | Client-side validation and submission |
| `spec/models/form_spec.rb` | Form tests |
| `spec/models/form_field_spec.rb` | FormField tests |
| `spec/models/form_submission_spec.rb` | FormSubmission tests |

### Form Model

Create `lib/v7cms/models/form.rb`:

```ruby
module V7CMS
  class Form < ActiveRecord::Base
    has_many :form_fields, -> { order(:position) }, dependent: :destroy
    has_many :form_submissions, dependent: :destroy

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true,
              format: { with: /\A[a-z0-9_-]+\z/ }
    validates :notification_email, format: { with: URI::MailTo::EMAIL_REGEXP },
              allow_blank: true
    validates :recaptcha_threshold, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1
    }

    before_validation :generate_slug, if: -> { slug.blank? && name.present? }

    def self.by_slug(slug)
      find_by(slug: slug)
    end

    def process_submission(data:, ip_address: nil, recaptcha_score: nil)
      # Check reCAPTCHA if required
      if require_recaptcha && (recaptcha_score.nil? || recaptcha_score < recaptcha_threshold)
        return { success: false, error: 'reCAPTCHA verification failed', spam: true }
      end

      # Validate required fields
      errors = validate_submission(data)
      return { success: false, errors: errors } if errors.any?

      # Store submission if enabled
      submission = nil
      if store_submissions
        submission = form_submissions.create!(
          data: data.to_json,
          ip_address: ip_address,
          recaptcha_score: recaptcha_score,
          spam: false
        )
      end

      # Send notification if enabled
      if send_notifications && notification_email.present?
        FormMailer.send_notification(self, data, submission)
      end

      { success: true, submission: submission }
    end

    private

    def generate_slug
      self.slug = name.parameterize
    end

    def validate_submission(data)
      errors = {}

      form_fields.each do |field|
        value = data[field.name]

        if field.required? && value.blank?
          errors[field.name] = "#{field.label} is required"
        end

        if field.field_type == 'email' && value.present?
          unless value.match?(URI::MailTo::EMAIL_REGEXP)
            errors[field.name] = "#{field.label} must be a valid email"
          end
        end
      end

      errors
    end
  end
end
```

### FormField Model

Create `lib/v7cms/models/form_field.rb`:

```ruby
module V7CMS
  class FormField < ActiveRecord::Base
    belongs_to :form

    FIELD_TYPES = %w[text email textarea select checkbox].freeze

    validates :field_type, inclusion: { in: FIELD_TYPES }
    validates :name, presence: true, format: { with: /\A[a-z0-9_]+\z/ }
    validates :label, presence: true
    validate :options_required_for_select

    def options_array
      return [] if options.blank?
      JSON.parse(options)
    rescue JSON::ParserError
      options.split("\n").map(&:strip).reject(&:empty?)
    end

    def options_array=(arr)
      self.options = arr.to_json
    end

    private

    def options_required_for_select
      if field_type == 'select' && options_array.empty?
        errors.add(:options, 'are required for select fields')
      end
    end
  end
end
```

### FormSubmission Model

Create `lib/v7cms/models/form_submission.rb`:

```ruby
module V7CMS
  class FormSubmission < ActiveRecord::Base
    belongs_to :form

    scope :not_spam, -> { where(spam: false) }
    scope :recent, -> { order(created_at: :desc) }

    def data_hash
      return {} if data.blank?
      JSON.parse(data)
    rescue JSON::ParserError
      {}
    end
  end
end
```

### Form Renderer Service

Create `lib/v7cms/services/form_renderer.rb`:

```ruby
module V7CMS
  class FormRenderer
    def self.render(form, options = {})
      new(form, options).render
    end

    def initialize(form, options = {})
      @form = form
      @class = options[:class] || 'v7-form'
    end

    def render
      fields_html = @form.form_fields.map { |f| render_field(f) }.join

      recaptcha_html = if @form.require_recaptcha
        '<input type="hidden" name="recaptcha_token" class="recaptcha-token">'
      else
        ''
      end

      <<~HTML
        <form class="#{@class}" data-form-id="#{@form.id}" data-form-slug="#{@form.slug}">
          #{fields_html}
          #{recaptcha_html}
          <div class="form-actions">
            <button type="submit" class="form-submit">#{@form.submit_button_text}</button>
          </div>
          <div class="form-message" style="display:none;"></div>
        </form>
      HTML
    end

    private

    def render_field(field)
      case field.field_type
      when 'text', 'email'
        render_input(field)
      when 'textarea'
        render_textarea(field)
      when 'select'
        render_select(field)
      when 'checkbox'
        render_checkbox(field)
      end
    end

    def render_input(field)
      required = field.required? ? 'required' : ''
      <<~HTML
        <div class="form-field">
          <label for="#{field.name}">#{field.label}#{field.required? ? ' *' : ''}</label>
          <input type="#{field.field_type}" name="#{field.name}" id="#{field.name}"
                 placeholder="#{field.placeholder}" #{required}>
          #{"<p class=\"help-text\">#{field.help_text}</p>" if field.help_text.present?}
        </div>
      HTML
    end

    def render_textarea(field)
      required = field.required? ? 'required' : ''
      <<~HTML
        <div class="form-field">
          <label for="#{field.name}">#{field.label}#{field.required? ? ' *' : ''}</label>
          <textarea name="#{field.name}" id="#{field.name}"
                    placeholder="#{field.placeholder}" #{required}></textarea>
          #{"<p class=\"help-text\">#{field.help_text}</p>" if field.help_text.present?}
        </div>
      HTML
    end

    def render_select(field)
      required = field.required? ? 'required' : ''
      options_html = field.options_array.map { |opt| "<option value=\"#{opt}\">#{opt}</option>" }.join
      <<~HTML
        <div class="form-field">
          <label for="#{field.name}">#{field.label}#{field.required? ? ' *' : ''}</label>
          <select name="#{field.name}" id="#{field.name}" #{required}>
            <option value="">Select...</option>
            #{options_html}
          </select>
          #{"<p class=\"help-text\">#{field.help_text}</p>" if field.help_text.present?}
        </div>
      HTML
    end

    def render_checkbox(field)
      <<~HTML
        <div class="form-field form-field-checkbox">
          <label>
            <input type="checkbox" name="#{field.name}" value="1">
            #{field.label}
          </label>
          #{"<p class=\"help-text\">#{field.help_text}</p>" if field.help_text.present?}
        </div>
      HTML
    end
  end
end
```

### Form Mailer Service

Create `lib/v7cms/services/form_mailer.rb`:

```ruby
module V7CMS
  class FormMailer
    def self.send_notification(form, data, submission = nil)
      # Use Mail gem or ActionMailer if available
      return unless defined?(Mail)

      settings = V7CMS::Setting.instance

      body = build_email_body(form, data, submission)

      Mail.deliver do
        from    settings.contact_email.presence || 'noreply@example.com'
        to      form.notification_email
        subject "New submission: #{form.name}"
        body    body
      end
    rescue => e
      # Log error but don't fail submission
      warn "Failed to send form notification: #{e.message}"
    end

    def self.build_email_body(form, data, submission)
      lines = ["New submission for form: #{form.name}", ""]

      form.form_fields.each do |field|
        value = data[field.name]
        lines << "#{field.label}: #{value}"
      end

      if submission
        lines << ""
        lines << "Submission ID: #{submission.id}"
        lines << "Submitted at: #{submission.created_at}"
        lines << "IP Address: #{submission.ip_address}"
      end

      lines.join("\n")
    end
  end
end
```

### Form Helper

Create `lib/v7cms/helpers/form_helper.rb`:

```ruby
module V7CMS
  module FormHelper
    def render_form(form_or_slug, options = {})
      form = form_or_slug.is_a?(V7CMS::Form) ? form_or_slug : V7CMS::Form.by_slug(form_or_slug.to_s)
      return '' unless form

      FormRenderer.render(form, options)
    end
  end
end
```

### API Endpoints

```ruby
# ==================== FORMS API ====================

# GET /api/forms - List forms (admin)
get '/api/forms' do
  require_login

  forms = V7CMS::Form.includes(:form_fields).all
  json({ forms: forms.map { |f| form_json(f) } })
end

# GET /api/forms/:id - Get form with fields
get '/api/forms/:id' do
  form = V7CMS::Form.find_by(id: params[:id]) || V7CMS::Form.find_by(slug: params[:id])
  halt 404, json({ error: 'Form not found' }) unless form

  json({ form: form_json(form, include_fields: true) })
end

# POST /api/forms - Create form (admin)
post '/api/forms' do
  require_ajax_header
  require_login

  data = JSON.parse(request.body.read)
  form = V7CMS::Form.create!(
    name: data['name'],
    slug: data['slug'],
    description: data['description'],
    submit_button_text: data['submit_button_text'],
    success_message: data['success_message'],
    notification_email: data['notification_email'],
    store_submissions: data.fetch('store_submissions', true),
    send_notifications: data.fetch('send_notifications', true),
    require_recaptcha: data.fetch('require_recaptcha', true),
    recaptcha_threshold: data['recaptcha_threshold'] || 0.5
  )

  status 201
  json({ form: form_json(form) })
rescue ActiveRecord::RecordInvalid => e
  halt 422, json({ error: e.message })
end

# Similar PUT, DELETE for forms...

# POST /api/forms/:id/fields - Add field
post '/api/forms/:id/fields' do
  require_ajax_header
  require_login

  form = V7CMS::Form.find_by(id: params[:id])
  halt 404, json({ error: 'Form not found' }) unless form

  data = JSON.parse(request.body.read)
  field = form.form_fields.create!(
    field_type: data['field_type'],
    name: data['name'],
    label: data['label'],
    placeholder: data['placeholder'],
    help_text: data['help_text'],
    required: data['required'] || false,
    options: data['options'],
    position: data['position'] || 0
  )

  status 201
  json({ field: form_field_json(field) })
rescue ActiveRecord::RecordInvalid => e
  halt 422, json({ error: e.message })
end

# POST /api/forms/:slug/submit - Public form submission
post '/api/forms/:slug/submit' do
  form = V7CMS::Form.find_by(slug: params[:slug])
  halt 404, json({ error: 'Form not found' }) unless form

  data = JSON.parse(request.body.read)

  # Verify reCAPTCHA if required
  recaptcha_score = nil
  if form.require_recaptcha
    recaptcha_score = verify_recaptcha(data['recaptcha_token'])
  end

  result = form.process_submission(
    data: data['fields'],
    ip_address: request.ip,
    recaptcha_score: recaptcha_score
  )

  if result[:success]
    json({ success: true, message: form.success_message })
  else
    status result[:spam] ? 422 : 400
    json({ success: false, error: result[:error], errors: result[:errors] })
  end
end

# GET /api/forms/:id/submissions - List submissions (admin)
get '/api/forms/:id/submissions' do
  require_login

  form = V7CMS::Form.find_by(id: params[:id])
  halt 404, json({ error: 'Form not found' }) unless form

  submissions = form.form_submissions.not_spam.recent.limit(100)
  json({
    submissions: submissions.map { |s| submission_json(s) }
  })
end

def form_json(form, include_fields: false)
  result = {
    id: form.id,
    name: form.name,
    slug: form.slug,
    description: form.description,
    submit_button_text: form.submit_button_text,
    success_message: form.success_message,
    notification_email: form.notification_email,
    store_submissions: form.store_submissions,
    send_notifications: form.send_notifications,
    require_recaptcha: form.require_recaptcha,
    recaptcha_threshold: form.recaptcha_threshold,
    submissions_count: form.form_submissions.not_spam.count,
    created_at: form.created_at.iso8601
  }
  result[:fields] = form.form_fields.map { |f| form_field_json(f) } if include_fields
  result
end

def form_field_json(field)
  {
    id: field.id,
    field_type: field.field_type,
    name: field.name,
    label: field.label,
    placeholder: field.placeholder,
    help_text: field.help_text,
    required: field.required,
    options: field.options_array,
    position: field.position
  }
end

def submission_json(submission)
  {
    id: submission.id,
    data: submission.data_hash,
    ip_address: submission.ip_address,
    recaptcha_score: submission.recaptcha_score,
    created_at: submission.created_at.iso8601
  }
end
```

### Client-Side JavaScript

Create `lib/v7cms/public/js/forms.js`:

```javascript
document.addEventListener('DOMContentLoaded', function() {
  document.querySelectorAll('.v7-form').forEach(initForm);
});

function initForm(form) {
  const formSlug = form.dataset.formSlug;

  form.addEventListener('submit', async function(e) {
    e.preventDefault();

    const submitBtn = form.querySelector('.form-submit');
    const messageEl = form.querySelector('.form-message');

    submitBtn.disabled = true;
    submitBtn.textContent = 'Submitting...';
    messageEl.style.display = 'none';

    // Collect form data
    const fields = {};
    form.querySelectorAll('input, textarea, select').forEach(input => {
      if (input.name && !input.name.startsWith('recaptcha')) {
        if (input.type === 'checkbox') {
          fields[input.name] = input.checked ? '1' : '0';
        } else {
          fields[input.name] = input.value;
        }
      }
    });

    // Get reCAPTCHA token if required
    let recaptchaToken = null;
    const recaptchaInput = form.querySelector('.recaptcha-token');
    if (recaptchaInput && typeof grecaptcha !== 'undefined') {
      try {
        recaptchaToken = await grecaptcha.execute(window.RECAPTCHA_SITE_KEY, { action: 'form_submit' });
      } catch (err) {
        console.error('reCAPTCHA error:', err);
      }
    }

    try {
      const response = await fetch(`/api/forms/${formSlug}/submit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fields, recaptcha_token: recaptchaToken })
      });

      const result = await response.json();

      if (result.success) {
        messageEl.className = 'form-message success';
        messageEl.textContent = result.message;
        form.reset();
      } else {
        messageEl.className = 'form-message error';
        if (result.errors) {
          const errorList = Object.values(result.errors).join(', ');
          messageEl.textContent = errorList;
        } else {
          messageEl.textContent = result.error || 'Submission failed';
        }
      }
      messageEl.style.display = 'block';
    } catch (err) {
      messageEl.className = 'form-message error';
      messageEl.textContent = 'An error occurred. Please try again.';
      messageEl.style.display = 'block';
    } finally {
      submitBtn.disabled = false;
      submitBtn.textContent = form.dataset.submitText || 'Submit';
    }
  });
}
```

### Template Usage

In page templates:
```erb
<%= render_form('contact') %>
```

Or with custom class:
```erb
<%= render_form('newsletter', class: 'newsletter-form') %>
```

### Tests Required

1. Form model: validations, process_submission
2. FormField model: validations, options parsing
3. FormSubmission model: data_hash
4. FormRenderer: HTML output
5. API: CRUD operations
6. API: form submission with reCAPTCHA
7. Integration: form renders and submits

---

## Feature 7: Customizable Sidebars

**Goal:** Component-based sidebars with inherit-unless-override behavior.

### Architecture

- `Sidebar` model for sidebar definitions
- `SidebarComponent` model for component instances
- Components: text block, link list, image, menu, recent posts
- Pages can have assigned sidebar or inherit from parent

### Prerequisites

- **Feature 5 (Menu Builder)** should be implemented first (menu component type)
- **Feature 2 (Image Uploads)** helpful (image component type)

### Database Changes

**Migration:** `db/migrate/YYYYMMDDHHMMSS_create_sidebars.rb`

```ruby
class CreateSidebars < ActiveRecord::Migration[7.0]
  def change
    create_table :sidebars do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end

    add_index :sidebars, :slug, unique: true

    create_table :sidebar_components do |t|
      t.references :sidebar, null: false, foreign_key: true
      t.string :component_type, null: false
      t.string :title
      t.text :content  # JSON blob for component-specific data
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :sidebar_components, [:sidebar_id, :position]

    # Add sidebar reference to pages
    add_reference :pages, :sidebar, foreign_key: true
    add_column :pages, :inherit_sidebar, :boolean, default: true
  end
end
```

### Component Types

| Type | Description | Content JSON |
|------|-------------|--------------|
| `text` | Rich text/HTML block | `{ "html": "<p>...</p>" }` |
| `link_list` | List of links | `{ "links": [{ "label": "...", "url": "..." }] }` |
| `image` | Single image with optional link | `{ "asset_id": 1, "alt": "...", "link_url": "..." }` |
| `menu` | Embedded menu | `{ "menu_id": 1 }` |
| `recent_posts` | Latest N posts | `{ "count": 5, "show_date": true }` |

### Files to Create

| File | Description |
|------|-------------|
| `lib/v7cms/models/sidebar.rb` | Sidebar model |
| `lib/v7cms/models/sidebar_component.rb` | SidebarComponent model |
| `lib/v7cms/helpers/sidebar_helper.rb` | Template helpers |
| `lib/v7cms/views/components/_text.erb` | Text component partial |
| `lib/v7cms/views/components/_link_list.erb` | Link list partial |
| `lib/v7cms/views/components/_image.erb` | Image partial |
| `lib/v7cms/views/components/_menu.erb` | Menu partial |
| `lib/v7cms/views/components/_recent_posts.erb` | Recent posts partial |
| `spec/models/sidebar_spec.rb` | Sidebar tests |
| `spec/models/sidebar_component_spec.rb` | Component tests |

### Sidebar Model

Create `lib/v7cms/models/sidebar.rb`:

```ruby
module V7CMS
  class Sidebar < ActiveRecord::Base
    has_many :sidebar_components, -> { order(:position) }, dependent: :destroy
    has_many :pages

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true,
              format: { with: /\A[a-z0-9_-]+\z/ }

    before_validation :generate_slug, if: -> { slug.blank? && name.present? }

    def self.by_slug(slug)
      find_by(slug: slug)
    end

    private

    def generate_slug
      self.slug = name.parameterize
    end
  end
end
```

### SidebarComponent Model

Create `lib/v7cms/models/sidebar_component.rb`:

```ruby
module V7CMS
  class SidebarComponent < ActiveRecord::Base
    belongs_to :sidebar

    COMPONENT_TYPES = %w[text link_list image menu recent_posts].freeze

    validates :component_type, inclusion: { in: COMPONENT_TYPES }
    validate :content_valid_for_type

    def content_hash
      return {} if content.blank?
      JSON.parse(content)
    rescue JSON::ParserError
      {}
    end

    def content_hash=(hash)
      self.content = hash.to_json
    end

    # Component-specific accessors
    def html
      content_hash['html']
    end

    def links
      content_hash['links'] || []
    end

    def asset_id
      content_hash['asset_id']
    end

    def menu_id
      content_hash['menu_id']
    end

    def post_count
      content_hash['count'] || 5
    end

    private

    def content_valid_for_type
      case component_type
      when 'text'
        errors.add(:content, 'must include html') if content_hash['html'].blank?
      when 'menu'
        errors.add(:content, 'must include menu_id') if content_hash['menu_id'].blank?
      end
    end
  end
end
```

### Page Model Updates

Add to `lib/v7cms/models/page.rb`:

```ruby
belongs_to :sidebar, class_name: 'V7CMS::Sidebar', optional: true

# Get effective sidebar (own or inherited from parent)
def effective_sidebar
  return sidebar if sidebar.present?
  return nil unless inherit_sidebar

  # Walk up parent chain to find sidebar
  current = parent
  while current
    return current.sidebar if current.sidebar.present?
    break unless current.inherit_sidebar
    current = current.parent
  end

  nil
end
```

### Sidebar Helper

Create `lib/v7cms/helpers/sidebar_helper.rb`:

```ruby
module V7CMS
  module SidebarHelper
    def render_sidebar(sidebar_or_slug = nil, options = {})
      sidebar = resolve_sidebar(sidebar_or_slug)
      return '' unless sidebar

      wrapper_class = options[:class] || 'sidebar'

      components_html = sidebar.sidebar_components.map do |component|
        render_component(component)
      end.join

      "<aside class=\"#{wrapper_class}\">#{components_html}</aside>"
    end

    def render_page_sidebar(page = nil, options = {})
      page ||= @page
      return '' unless page

      sidebar = page.effective_sidebar
      return '' unless sidebar

      render_sidebar(sidebar, options)
    end

    private

    def resolve_sidebar(sidebar_or_slug)
      case sidebar_or_slug
      when V7CMS::Sidebar
        sidebar_or_slug
      when String, Symbol
        V7CMS::Sidebar.by_slug(sidebar_or_slug.to_s)
      when nil
        nil
      end
    end

    def render_component(component)
      partial_path = "components/_#{component.component_type}"

      # Check if partial exists in any view path
      partial_file = settings.views_paths.map do |path|
        File.join(path, "#{partial_path}.erb")
      end.find { |f| File.exist?(f) }

      if partial_file
        erb partial_path.to_sym, locals: { component: component }, layout: false
      else
        render_default_component(component)
      end
    end

    def render_default_component(component)
      title_html = component.title.present? ? "<h3>#{component.title}</h3>" : ''

      content_html = case component.component_type
      when 'text'
        component.html
      when 'link_list'
        links = component.links.map do |link|
          "<li><a href=\"#{link['url']}\">#{link['label']}</a></li>"
        end.join
        "<ul>#{links}</ul>"
      when 'recent_posts'
        posts = V7CMS::Post.published.recent.limit(component.post_count)
        items = posts.map do |post|
          "<li><a href=\"/posts/#{post.slug}\">#{post.title}</a></li>"
        end.join
        "<ul>#{items}</ul>"
      else
        ''
      end

      "<div class=\"sidebar-component sidebar-#{component.component_type}\">#{title_html}#{content_html}</div>"
    end
  end
end
```

### Component Partials

Create `lib/v7cms/views/components/_text.erb`:
```erb
<div class="sidebar-component sidebar-text">
  <% if component.title.present? %>
    <h3><%= component.title %></h3>
  <% end %>
  <%= component.html %>
</div>
```

Create `lib/v7cms/views/components/_link_list.erb`:
```erb
<div class="sidebar-component sidebar-link-list">
  <% if component.title.present? %>
    <h3><%= component.title %></h3>
  <% end %>
  <ul>
    <% component.links.each do |link| %>
      <li><a href="<%= link['url'] %>"><%= link['label'] %></a></li>
    <% end %>
  </ul>
</div>
```

Create `lib/v7cms/views/components/_recent_posts.erb`:
```erb
<% posts = V7CMS::Post.published.recent.limit(component.post_count) %>
<div class="sidebar-component sidebar-recent-posts">
  <% if component.title.present? %>
    <h3><%= component.title %></h3>
  <% end %>
  <ul>
    <% posts.each do |post| %>
      <li>
        <a href="/posts/<%= post.slug %>"><%= post.title %></a>
        <% if component.content_hash['show_date'] %>
          <span class="date"><%= post.created_at.strftime(@settings.date_format) %></span>
        <% end %>
      </li>
    <% end %>
  </ul>
</div>
```

Create `lib/v7cms/views/components/_menu.erb`:
```erb
<% menu = V7CMS::Menu.find_by(id: component.menu_id) %>
<% if menu %>
  <div class="sidebar-component sidebar-menu">
    <% if component.title.present? %>
      <h3><%= component.title %></h3>
    <% end %>
    <%= render_menu(menu, class: 'sidebar-nav') %>
  </div>
<% end %>
```

Create `lib/v7cms/views/components/_image.erb`:
```erb
<% asset = V7CMS::Asset.find_by(id: component.asset_id) if component.asset_id %>
<% if asset %>
  <div class="sidebar-component sidebar-image">
    <% if component.title.present? %>
      <h3><%= component.title %></h3>
    <% end %>
    <% link_url = component.content_hash['link_url'] %>
    <% if link_url.present? %>
      <a href="<%= link_url %>">
        <img src="<%= asset.url %>" alt="<%= component.content_hash['alt'] || asset.alt_text %>">
      </a>
    <% else %>
      <img src="<%= asset.url %>" alt="<%= component.content_hash['alt'] || asset.alt_text %>">
    <% end %>
  </div>
<% end %>
```

### API Endpoints

```ruby
# ==================== SIDEBARS API ====================

# GET /api/sidebars - List sidebars
get '/api/sidebars' do
  require_login

  sidebars = V7CMS::Sidebar.includes(:sidebar_components).all
  json({ sidebars: sidebars.map { |s| sidebar_json(s) } })
end

# GET /api/sidebars/:id - Get sidebar with components
get '/api/sidebars/:id' do
  require_login

  sidebar = V7CMS::Sidebar.find_by(id: params[:id]) || V7CMS::Sidebar.find_by(slug: params[:id])
  halt 404, json({ error: 'Sidebar not found' }) unless sidebar

  json({ sidebar: sidebar_json(sidebar, include_components: true) })
end

# POST /api/sidebars - Create sidebar
post '/api/sidebars' do
  require_ajax_header
  require_login

  data = JSON.parse(request.body.read)
  sidebar = V7CMS::Sidebar.create!(
    name: data['name'],
    slug: data['slug']
  )

  status 201
  json({ sidebar: sidebar_json(sidebar) })
rescue ActiveRecord::RecordInvalid => e
  halt 422, json({ error: e.message })
end

# Similar PUT, DELETE for sidebars...

# POST /api/sidebars/:id/components - Add component
post '/api/sidebars/:id/components' do
  require_ajax_header
  require_login

  sidebar = V7CMS::Sidebar.find_by(id: params[:id])
  halt 404, json({ error: 'Sidebar not found' }) unless sidebar

  data = JSON.parse(request.body.read)
  component = sidebar.sidebar_components.create!(
    component_type: data['component_type'],
    title: data['title'],
    content: data['content'].to_json,
    position: data['position'] || 0
  )

  status 201
  json({ component: component_json(component) })
rescue ActiveRecord::RecordInvalid => e
  halt 422, json({ error: e.message })
end

# PUT /api/sidebar-components/:id - Update component
put '/api/sidebar-components/:id' do
  require_ajax_header
  require_login

  component = V7CMS::SidebarComponent.find_by(id: params[:id])
  halt 404, json({ error: 'Component not found' }) unless component

  data = JSON.parse(request.body.read)
  component.update!(
    title: data['title'],
    content: data['content'].to_json,
    position: data['position']
  )

  json({ component: component_json(component) })
rescue ActiveRecord::RecordInvalid => e
  halt 422, json({ error: e.message })
end

# DELETE /api/sidebar-components/:id
delete '/api/sidebar-components/:id' do
  require_ajax_header
  require_login

  component = V7CMS::SidebarComponent.find_by(id: params[:id])
  halt 404, json({ error: 'Component not found' }) unless component

  component.destroy
  json({ success: true })
end

def sidebar_json(sidebar, include_components: false)
  result = {
    id: sidebar.id,
    name: sidebar.name,
    slug: sidebar.slug,
    created_at: sidebar.created_at.iso8601
  }
  result[:components] = sidebar.sidebar_components.map { |c| component_json(c) } if include_components
  result
end

def component_json(component)
  {
    id: component.id,
    component_type: component.component_type,
    title: component.title,
    content: component.content_hash,
    position: component.position
  }
end
```

### Admin UI Changes

Add Sidebars tab with:
- List of sidebars with edit/delete
- Create new sidebar form
- Sidebar editor with component list
- Add component: type dropdown, type-specific form
- Drag to reorder components
- Page editor: sidebar selector + inherit toggle

Update page API to include sidebar fields:
```ruby
sidebar_id: page.sidebar_id,
inherit_sidebar: page.inherit_sidebar,
effective_sidebar_id: page.effective_sidebar&.id
```

### Template Usage

In layout:
```erb
<div class="page-content">
  <main><%= yield %></main>
  <%= render_page_sidebar(@page, class: 'page-sidebar') %>
</div>
```

Or render specific sidebar:
```erb
<%= render_sidebar('blog-sidebar') %>
```

### Tests Required

1. Sidebar model: validations
2. SidebarComponent model: validations, content_hash
3. Page model: effective_sidebar inheritance
4. SidebarHelper: render_sidebar output
5. Component partials: each type renders correctly
6. API: CRUD operations
7. Integration: sidebar cascades to child pages

---

## Implementation Notes

### Shared Patterns

All features follow these patterns:

1. **Model structure:**
   - Validation with meaningful error messages
   - Scopes for common queries
   - Before/after callbacks for automation

2. **API structure:**
   - Consistent JSON response format
   - Proper HTTP status codes
   - require_login / require_ajax_header guards

3. **Testing:**
   - Model specs for validations and methods
   - Route specs for API endpoints
   - Integration specs for complex flows

4. **Admin UI:**
   - Alpine.js reactive data binding
   - Consistent form styling
   - Loading states and error handling

### Version Bumping

After completing each feature, bump gem version:
- Patch version for each feature (0.1.22, 0.1.23, etc.)
- Consider minor version for grouped releases (0.2.0)

### Migration Ordering

Run migrations in order:
1. Base tables (independent features)
2. Reference columns (features with dependencies)

### Backward Compatibility

- New columns should have sensible defaults
- Existing data should continue working
- Public API routes remain unchanged

---

## Quick Reference

| Feature | Priority | Depends On | Key Models |
|---------|----------|------------|------------|
| Blog Post Layouts | 1 | None | Setting |
| Image/Asset Uploads | 2 | None | Asset |
| Content History | 3 | None | ContentVersion |
| Content Workflow | 4 | Content History | Post, Page |
| Menu Builder | 5 | None | Menu, MenuItem |
| Form Builder | 6 | None | Form, FormField, FormSubmission |
| Customizable Sidebars | 7 | Menu Builder | Sidebar, SidebarComponent |
| Hierarchical Page Admin | 8 | None | Page (existing) |

---

## Feature 8: Hierarchical Page Display in Admin

**Goal:** Display pages in a tree structure in admin interface, showing parent-child relationships visually.

### Architecture

No database changes needed - Page model already has parent/children associations. This is purely an admin UI enhancement to display pages as a collapsible tree instead of a flat list.

### Current State

The admin currently shows pages as a flat table. Pages have:
- `parent_id` - foreign key to parent page
- `children` - has_many association
- `ancestors` - recursive method returning parent chain
- `depth` - returns nesting level (0 for top-level)

### API Changes

Modify `GET /api/pages` to optionally return nested structure:

```ruby
# GET /api/pages?nested=true - Return hierarchical structure
get '/api/pages' do
  if params[:nested] == 'true'
    pages = V7CMS::Page.top_level.ordered.includes(:children)
    json({ pages: pages.map { |p| page_json_nested(p) } })
  else
    # Existing flat list behavior
    pages = logged_in? && params[:include_drafts] == 'true' ?
      V7CMS::Page.ordered : V7CMS::Page.published.ordered
    json({ pages: pages.map { |p| page_json(p) } })
  end
end

def page_json_nested(page, depth = 0)
  base = page_json(page)
  base[:depth] = depth
  base[:children] = page.children.ordered.map { |c| page_json_nested(c, depth + 1) }
  base
end
```

### Files to Modify

| File | Action | Description |
|------|--------|-------------|
| `lib/v7cms/application.rb` | Modify | Add nested parameter to GET /api/pages |
| `lib/v7cms/public/admin/index.html` | Modify | Replace flat table with tree view |
| `lib/v7cms/public/js/admin.js` | Modify | Add tree rendering and expand/collapse logic |
| `spec/routes/pages_spec.rb` | Modify | Add tests for nested API response |

### Admin UI Implementation

Replace flat table with recursive tree component:

```html
<!-- Pages Tree View -->
<div class="pages-tree">
  <template x-for="page in nestedPages" :key="page.id">
    <div class="page-tree-item">
      <template x-if="true">
        <div x-data="{ expanded: true }">
          <!-- Page Row -->
          <div class="page-row flex items-center py-2 px-4 hover:bg-gray-50 border-b"
               :style="{ paddingLeft: (page.depth * 24 + 16) + 'px' }">

            <!-- Expand/Collapse Toggle -->
            <button x-show="page.children && page.children.length > 0"
                    @click="expanded = !expanded"
                    class="w-6 h-6 flex items-center justify-center text-gray-400 hover:text-gray-600 mr-2">
              <svg x-show="!expanded" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
              </svg>
              <svg x-show="expanded" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
              </svg>
            </button>

            <!-- Spacer when no children -->
            <span x-show="!page.children || page.children.length === 0" class="w-6 mr-2"></span>

            <!-- Page Icon -->
            <svg class="w-5 h-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>

            <!-- Title -->
            <span class="flex-1 font-medium text-gray-900" x-text="page.title"></span>

            <!-- Page Type Badge -->
            <span class="px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-600 mr-3"
                  x-text="page.page_type"></span>

            <!-- Status Badge -->
            <span x-show="page.published"
                  class="px-2 py-1 text-xs rounded-full bg-green-100 text-green-800 mr-3">
              Published
            </span>
            <span x-show="!page.published"
                  class="px-2 py-1 text-xs rounded-full bg-yellow-100 text-yellow-800 mr-3">
              Draft
            </span>

            <!-- Actions -->
            <button @click="editPage(page)" class="text-blue-600 hover:text-blue-800 mr-3">Edit</button>
            <button @click="deletePage(page)" class="text-red-600 hover:text-red-800">Delete</button>
          </div>

          <!-- Children (recursive) -->
          <div x-show="expanded && page.children && page.children.length > 0">
            <template x-for="child in page.children" :key="child.id">
              <div x-data="pageTreeItem(child)" x-html="renderPageTree(child)"></div>
            </template>
          </div>
        </div>
      </template>
    </div>
  </template>
</div>
```

### JavaScript Implementation

Add to `lib/v7cms/public/js/admin.js`:

```javascript
// State
nestedPages: [],
pagesViewMode: 'tree', // 'tree' or 'flat'

// Fetch nested pages
async fetchNestedPages() {
  try {
    const response = await fetch('/api/pages?nested=true&include_drafts=true', {
      credentials: 'include'
    });
    if (!response.ok) {
      console.error('Failed to fetch pages:', response.status);
      this.nestedPages = [];
      return;
    }
    const data = await response.json();
    this.nestedPages = data.pages || [];
  } catch (error) {
    console.error('Error fetching nested pages:', error);
    this.nestedPages = [];
  }
},

// Toggle between tree and flat view
togglePagesView() {
  this.pagesViewMode = this.pagesViewMode === 'tree' ? 'flat' : 'tree';
},

// Recursive function to flatten nested pages for operations
flattenPages(pages, result = []) {
  pages.forEach(page => {
    result.push(page);
    if (page.children && page.children.length > 0) {
      this.flattenPages(page.children, result);
    }
  });
  return result;
},

// Find page by ID in nested structure
findPageById(pages, id) {
  for (const page of pages) {
    if (page.id === id) return page;
    if (page.children && page.children.length > 0) {
      const found = this.findPageById(page.children, id);
      if (found) return found;
    }
  }
  return null;
}
```

Update `init()` to call `fetchNestedPages()`:

```javascript
async init() {
  await this.checkAuth();
  if (this.authenticated && this.user.admin) {
    await Promise.all([
      this.fetchPosts(),
      this.fetchPages(),
      this.fetchNestedPages(),  // Add this
      // ... rest of fetches
    ]);
  }
  this.loading = false;
}
```

### Visual Design

Tree structure with:
- Indentation: 24px per level
- Expand/collapse chevron icons for pages with children
- Document icon for each page
- Subtle connector lines (optional, CSS-based)
- Hover highlight on rows
- Same action buttons as current table

### Alternative: CSS Tree Lines

Optional enhancement - add visual connector lines:

```css
.page-tree-item {
  position: relative;
}

.page-tree-item::before {
  content: '';
  position: absolute;
  left: calc(var(--depth) * 24px + 8px);
  top: 0;
  bottom: 50%;
  width: 1px;
  background: #e5e7eb;
}

.page-tree-item::after {
  content: '';
  position: absolute;
  left: calc(var(--depth) * 24px + 8px);
  top: 50%;
  width: 12px;
  height: 1px;
  background: #e5e7eb;
}
```

### Drag-and-Drop Reordering (Future Enhancement)

Consider adding drag-and-drop to:
- Reorder siblings (change position)
- Reparent pages (change parent_id)

Libraries to consider:
- SortableJS (lightweight, no dependencies)
- @shopify/draggable

### Tests Required

1. API: GET /api/pages?nested=true returns tree structure
2. API: Nested response includes all levels
3. API: Children ordered by position
4. Integration: Tree renders correctly in admin

### Implementation Notes

- No database migration needed
- Backward compatible (flat view still available)
- Leverages existing Page model methods
- Pure frontend enhancement with minor API addition

---

## Bug Fixes & Code Quality

**Ongoing maintenance items tracked via GitHub Issues.**

### Admin UI Fixes — [Issue #67](https://github.com/bennyfactor/v7cms/issues/67)

**Priority:** High (editorial workflow controls broken)

1. **`workflow_state` vs `status` mismatch** — Admin UI binds to `workflow_state` but API returns `status`. Status badges and workflow action buttons never display. Affects post list, post editor, and page editor. Fix: replace all `workflow_state` references with `status` in `index.html` and `admin.js`.

2. **Unpinned CDN dependencies** — Alpine.js (`@3.x.x`) and Swagger UI (`@5`) loaded without pinned versions. Pin to specific versions and consider adding SRI hashes.

3. **Comment pagination offset bug** — `commentsOffset` incremented before fetch; stays advanced on failure. Move increment after successful response.
