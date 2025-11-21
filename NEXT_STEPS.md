# v7cms - Next Steps & Future Features

This document outlines future development tasks organized by priority. The current implementation is complete through Phase 8 of IMPLEMENTATION_PLAN.md.

## Core Architecture Goal

**Static-First Design**: Generate static HTML/CSS/JS files that Apache serves directly. If the Ruby application breaks, the website remains accessible (read-only). Only admin editing, dynamic features, and comments would stop working.

---

## Priority 1: Site Settings Management

**Status**: ✅ **COMPLETED** (2025-11-14)

**Goal**: Allow customization of boilerplate text via admin interface instead of editing code.

### Implementation Tasks:
- [x] Create `settings` table in database
  - ✅ Chose structured columns approach (Option B)
  - ✅ 14 fields across 6 categories (Site Identity, Homepage, Footer, SEO, Contact/Social, Display)
- [x] Create Settings model with validations
  - ✅ Singleton pattern implemented
  - ✅ Email format validation
  - ✅ URL format validation
  - ✅ Numeric range validation (posts_per_page: 1-100)
- [x] Add Settings API endpoints:
  - ✅ `GET /api/settings` - retrieve all settings (public)
  - ✅ `PUT /api/settings` - bulk update settings (auth required)
  - ✅ `POST /api/settings/reset` - reset to defaults (auth required)
- [x] Add "Settings" section to admin interface (new tab/view)
  - ✅ 6-section form with all fields
  - ✅ Save and Reset buttons
  - ✅ Success/error feedback
- [x] Create settings form with fields:
  - ✅ **Site title** (header logo)
  - ✅ **Site tagline**
  - ✅ **Site author**
  - ✅ **Homepage welcome title**
  - ✅ **Homepage subtitle**
  - ✅ **Footer copyright text**
  - ✅ **Footer year** (boolean toggle)
  - ✅ **Meta description** (SEO)
  - ✅ **Meta keywords** (SEO)
  - ✅ **Contact email**
  - ✅ **GitHub URL**
  - ✅ **Social URL** (generic, not Twitter-specific)
  - ✅ **Posts per page** (numeric, 1-100)
  - ✅ **Date format** (strftime pattern)
- [x] Update ERB templates to use settings:
  - ✅ `app/views/layout.erb` - header title, tagline, footer text, meta tags
  - ✅ `app/views/index.erb` - welcome title and subtitle
  - ✅ `app/views/post.erb` - date formatting
- [x] Create database migration for settings table
  - ✅ Migration: 20251114001749_create_settings.rb
- [x] Add seed data with sensible defaults
  - ✅ Updated db/seed.rb to initialize Setting.instance
- [x] Write RSpec tests for Settings CRUD
  - ✅ 35 model tests (validations, defaults, singleton, reset)
  - ✅ 12 route tests (GET, PUT, POST reset, auth, validation)
  - ✅ Total: 47 new tests, 108 tests overall
- [x] Update static HTML generation to use settings (when implemented)
  - ✅ Prepared with JavaScript-based admin links
  - ⏸️ Full static generation is Priority 2

### Additional Improvements
- ✅ Database consolidation: All environments use single cms.db file
- ✅ Production environment fix: config.ru defaults to production
- ✅ JavaScript-based admin link injection (preparing for static site generation)

### Files to Modify:
- `db/migrate/XXXXXX_create_settings.rb` (new)
- `app/models/setting.rb` (new)
- `app/cms.rb` - add API routes
- `app/views/layout.erb` - use `@settings` or `Setting.get(key)`
- `app/views/index.erb` - use settings for titles
- `admin/index.html` - add settings UI
- `public/js/admin.js` - add settings management logic

---

## Priority 2: Static HTML Generation for Posts

**Status**: ✅ **COMPLETED** (2025-11-14)

**Goal**: Generate static `.html` files for each published post that Apache can serve directly, independent of the Ruby app.

### Implementation Summary:
- ✅ Created PostRenderer service with ERB-based template
- ✅ Automatic generation via ActiveRecord callbacks (after_commit)
- ✅ Files written to `public/posts/{slug}.html`
- ✅ Static-first Apache routing (already existed in .htaccess)
- ✅ Optimized cache headers (1-hour cache for static posts)
- ✅ Rake tasks: `posts:regenerate_all`, `posts:verify`, `posts:clean_orphans`
- ✅ 28 comprehensive tests (22 service + 6 model callback tests)
- ✅ Production tested and verified

### Files Created/Modified:
- `app/services/post_renderer.rb` (160 lines) - NEW
- `app/models/post.rb` (+21 lines for callbacks)
- `.htaccess` (cache optimization)
- `lib/tasks/posts.rake` (78 lines) - NEW
- `spec/services/post_renderer_spec.rb` (199 lines) - NEW
- `spec/models/post_spec.rb` (+98 lines for callback tests)
- `Rakefile` (environment task + task loader)
- `public/posts/.gitkeep` - NEW

### Results:
- **Performance**: Static files served directly by Apache (bypass Ruby entirely)
- **Resilience**: Site content remains accessible if Ruby app fails
- **Foundation**: Ready for RSS feeds and full static export
- **7 atomic commits** merged to main

---

## Priority 3: RSS Feed Generation

**Status**: ✅ **COMPLETED** (2025-11-15)

**Goal**: Provide RSS 2.0 and Atom feeds, dynamically generated and updated when content changes.

### Implementation Summary:
- ✅ Created FeedGenerator service (111 lines)
- ✅ RSS 2.0 feed at `/feed/rss` with proper XML structure
- ✅ Atom feed at `/feed/atom` with proper XML structure
- ✅ Includes 20 most recent published posts (configurable via FEED_LIMIT)
- ✅ Automatic regeneration via ActiveRecord callbacks on Post and Setting models
- ✅ Feed discovery links in layout.erb `<head>` section
- ✅ Rake task: `feeds:regenerate` for manual generation
- ✅ 41 comprehensive tests (feed structure, metadata, filtering, file operations)
- ✅ Uses Builder gem for clean XML generation
- ✅ Full post content in feeds (not excerpts)
- ✅ Proper date formatting (RFC 822 for RSS, ISO 8601 for Atom)

### Files Created/Modified:
- `app/services/feed_generator.rb` (111 lines) - NEW
- `app/models/post.rb` (+7 lines for feed regeneration callback)
- `app/models/setting.rb` (+9 lines for feed regeneration callback)
- `app/views/layout.erb` (+4 lines for feed discovery links)
- `app/cms.rb` (+20 lines for feed routes at /feed/rss and /feed/atom)
- `lib/tasks/feeds.rake` (14 lines) - NEW
- `spec/services/feed_generator_spec.rb` (368 lines) - NEW
- `spec/routes/feeds_spec.rb` (87 lines) - NEW
- `Gemfile` (+2 lines for builder and nokogiri gems)
- `.gitignore` (+4 lines to exclude generated feeds)

### Technical Decisions Made:
- **Dynamic generation**: Feeds generated on-demand via Sinatra routes (not static files)
- **URL structure**: `/feed/rss` and `/feed/atom` (avoiding .xml extension routing issues)
- **Full content**: Complete post HTML included in feeds
- **GUID**: Post URL used as stable identifier
- **SITE_URL**: Configurable via ENV var for correct URLs in production

### Results:
- **Deployed**: Working on production at https://dev.iaatb.net/feed/rss and /feed/atom
- **Performance**: Lightweight dynamic generation (Builder gem is fast)
- **Standards compliant**: RSS 2.0 and Atom 1.0 specifications
- **Auto-updating**: Feeds refresh whenever posts or settings change

---

## Priority 4: Pages & Hierarchical Content

**Status**: ✅ **COMPLETED** (2025-11-16) - **MERGED TO MAIN**

**Goal**: Support static pages (About, Contact, etc.) with parent-child relationships, separate from blog posts.

### Implementation Summary:
- ✅ Created pages table with hierarchical support (parent_id, position, page_type)
- ✅ Page model with self-referential associations and helper methods
- ✅ Pages API endpoints (GET, POST, PUT, DELETE with hierarchical support)
- ✅ Admin UI for creating/editing pages with parent selection
- ✅ Public routes at /pages/* with hierarchical URL support
- ✅ PageRenderer service for automatic static HTML generation
- ✅ Page view template with breadcrumbs and child page listings
- ✅ 37 Page model tests (all passing)
- ✅ Auto-update .ruby-version in setup.php for compatible patch versions

### Files Created:
- `db/migrate/20251116021317_create_pages.rb` - Database schema
- `app/models/page.rb` - Page model with hierarchical methods (84 lines)
- `app/services/page_renderer.rb` - Static HTML generator (205 lines)
- `app/views/page.erb` - Public page view template
- `spec/models/page_spec.rb` - Page model tests (37 tests)

### Files Modified:
- `app/cms.rb` - Added Pages API endpoints and public routes
- `admin/index.html` - Added Pages admin UI section
- `public/js/admin.js` - Added Pages JavaScript functionality
- `setup.php` - Auto-update .ruby-version for compatible patch versions

### Design Decisions Made:
- **URL structure**: All pages at `/pages/*` (simpler, no conflicts with posts)
- **Hierarchical URLs**: Supports both `/pages/parent/child` and `/pages/child`
- **Slug conflicts**: Separate namespace prevents conflicts with posts
- **Static generation**: Automatic via ActiveRecord callbacks

### Deployment Status:
- ✅ Merged to main branch (2025-11-16)
- ✅ All tests passing (264 total tests)
- ✅ Migration included in codebase
- Production deployment: Ready for deployment when desired

### Implementation Tasks:
- [x] Create `pages` table migration
- [x] Create Page model with self-referential associations
- [x] Define page types (standard, landing, contact)
- [x] Add Pages API endpoints (GET, POST, PUT, DELETE)
- [x] Create pages management UI in admin
- [x] Add public routes (/pages/*)
- [x] Generate static HTML for pages
- [x] Write tests for page hierarchy and CRUD operations

### Future Enhancements (Optional):
- [ ] Navigation menu builder (which pages appear in nav)
- [ ] Drag-and-drop page reordering in admin
- [ ] Custom URL paths for top-level pages (/:slug instead of /pages/:slug)

---

## API Pagination Enhancement

**Status**: ✅ **COMPLETED** (2025-11-21)

**Goal**: Add pagination support to Posts and Pages API endpoints to handle large content collections efficiently.

### Implementation Summary:
- ✅ Added pagination to GET /api/posts endpoint
- ✅ Added pagination to GET /api/pages endpoint
- ✅ Query parameters: limit (default 20, max 100), offset (default 0)
- ✅ Pagination metadata in responses: total, limit, offset, count
- ✅ Helper methods: pagination_params (validation), pagination_metadata (response)
- ✅ Compatible with existing filters (include_drafts, top_level, parent_id)
- ✅ Admin UI updated to handle paginated responses
- ✅ All pagination tests passing

### Files Modified:
- `app/cms.rb` - Added pagination_params and pagination_metadata helper methods
- `public/js/admin.js` - Updated loadPosts and loadPages to handle pagination
- Previous commits added pagination to API endpoints

### Technical Details:
- Default limit: 20 items per page
- Maximum limit: 100 items per page
- Minimum offset: 0
- Invalid values default to safe defaults (20/0)
- Pagination works seamlessly with all existing filters

---

## Priority 5: Commenting System

**Goal**: Enable comments on posts with moderation and spam prevention.

### Investigation Phase (Do First):
- [ ] Research commenting solutions:
  - **Self-hosted options**:
    - Custom Rails-style implementation (full control, more work)
    - Isso (Python, lightweight, privacy-focused)
    - Commento (Go, open-source, paid hosted option)
  - **Third-party services**:
    - Disqus (popular, privacy concerns, ads)
    - utterances (GitHub Issues, requires GitHub account)
    - giscus (GitHub Discussions, requires GitHub account)
  - **Static-friendly**:
    - Staticman (commits to git repo, complex setup)
    - Webmentions (IndieWeb standard)
- [ ] Evaluate criteria:
  - Privacy (GDPR compliance, data ownership)
  - Spam filtering (Akismet, challenge/response, moderation queue)
  - User experience (login required? anonymous comments?)
  - Static compatibility (can comments be in static HTML or need JS?)
  - Cost (free, one-time, subscription)
  - Maintenance burden

### Implementation (Custom, if chosen):
- [ ] Create `comments` table:
  ```ruby
  t.references :post, null: false, index: true
  t.string :author_name, null: false
  t.string :author_email, null: false
  t.string :author_url
  t.text :content, null: false
  t.string :ip_address
  t.boolean :approved, default: false, index: true
  t.boolean :spam, default: false
  t.timestamps
  ```
- [ ] Create Comment model with:
  - `belongs_to :post`
  - Validations: author_name, author_email, content
  - Email format validation
  - Spam detection integration (Akismet gem?)
  - Scopes: `approved`, `pending`, `spam`
- [ ] Add comments API endpoints:
  - `POST /api/posts/:id/comments` - submit comment (public, moderated)
  - `GET /api/posts/:id/comments` - list approved comments
  - `GET /api/comments` - all comments (admin, includes unapproved)
  - `PUT /api/comments/:id/approve` - approve comment (admin)
  - `DELETE /api/comments/:id` - delete comment (admin)
- [ ] Add comment form to public post view:
  - Name, email, website (optional), comment text
  - Submit button
  - "Your comment is awaiting moderation" message
- [ ] Add comment moderation to admin interface:
  - List pending comments
  - Approve/reject buttons
  - Mark as spam
  - Bulk actions
- [ ] Render approved comments:
  - Option A: Include in static HTML (regenerate post when comment approved)
  - Option B: Load via JavaScript (more dynamic, works without regeneration)
  - **Recommendation**: Start with JS, optimize to static later
- [ ] Add spam protection:
  - Akismet integration (gem: `akismet`)
  - Honeypot field (hidden field that bots fill)
  - Rate limiting (same IP can't comment too frequently)
  - Email verification (optional)
- [ ] Write tests for comments

### Implementation (Third-Party, if chosen):
- [ ] Sign up for service (e.g., utterances, giscus, Disqus)
- [ ] Add JavaScript embed code to `app/views/post.erb`
- [ ] Configure service settings (site URL, moderation, etc.)
- [ ] Add admin link to service's moderation dashboard
- [ ] Test comment submission and display

### Files to Create/Modify (Custom):
- `db/migrate/XXXXXX_create_comments.rb` (new)
- `app/models/comment.rb` (new)
- `app/cms.rb` - add comments routes
- `app/views/post.erb` - add comment form and display
- `admin/index.html` - add comment moderation section
- `public/js/admin.js` - add comment moderation logic
- `spec/models/comment_spec.rb` (new)
- `spec/routes/comments_spec.rb` (new)

---

## Priority 6: Theme Customization

**Goal**: Allow visual customization via admin interface without editing code.

### Investigation Phase:
- [ ] Define scope of customization:
  - **Color scheme**: Primary, secondary, accent colors? Light/dark mode toggle?
  - **Typography**: Font families (Google Fonts integration?), sizes, line heights?
  - **Layout**: Sidebar, full-width, boxed container?
  - **Custom CSS**: Allow arbitrary CSS injection (advanced users)?
  - **Pre-built themes**: Gallery of complete themes vs granular controls?

### Implementation (Granular Controls):
- [ ] Extend Settings model with theme fields:
  - `primary_color`, `secondary_color`, `accent_color`
  - `font_heading`, `font_body`
  - `layout_style` (full-width, boxed, sidebar)
  - `custom_css` (text field for advanced users)
- [ ] Generate custom stylesheet from settings:
  - Create `app/services/theme_generator.rb`
  - Method: `generate_css` - outputs CSS with variables
  - Write to `public/css/theme.css`
  - Regenerate when settings saved
- [ ] Use CSS custom properties:
  ```css
  :root {
    --color-primary: <%= Setting.get('primary_color') || '#3b82f6' %>;
    --font-heading: <%= Setting.get('font_heading') || 'system-ui' %>;
  }
  ```
- [ ] Add theme customization UI to admin:
  - Color pickers for primary, secondary, accent
  - Font dropdown (list of safe web fonts + Google Fonts)
  - Layout radio buttons
  - Custom CSS textarea with syntax highlighting (optional)
  - Live preview pane (iframe showing homepage with theme applied)
- [ ] Update `layout.erb` to load `theme.css`:
  ```html
  <link rel="stylesheet" href="/css/output.css">
  <link rel="stylesheet" href="/css/theme.css">
  ```
- [ ] Add theme export/import:
  - Export: Download theme as JSON file
  - Import: Upload JSON to apply theme

### Implementation (Pre-built Themes):
- [ ] Create theme directory: `public/themes/`
- [ ] Create default themes:
  - `default.css` - current design
  - `minimal.css` - ultra-minimal design
  - `dark.css` - dark mode theme
  - `serif.css` - serif fonts, classic blog style
- [ ] Add theme selector to settings:
  - Dropdown list of available themes
  - Preview thumbnails
- [ ] Load selected theme CSS dynamically

### Files to Create/Modify:
- `app/models/setting.rb` - add theme fields
- `app/services/theme_generator.rb` (new)
- `app/views/layout.erb` - load theme.css
- `admin/index.html` - add theme customization UI
- `public/css/theme.css` (generated, gitignored)
- `public/themes/*.css` (new, if using pre-built themes)
- `spec/services/theme_generator_spec.rb` (new)

---

## Priority 7: Static Asset Management & Recovery

**Goal**: Ensure static files are organized and the site remains functional if Ruby app breaks.

### File Structure:
```
public/
  posts/           # Static post HTML files
  pages/           # Static page HTML files
  feed.xml         # RSS feed
  atom.xml         # Atom feed
  sitemap.xml      # Sitemap (future)
  css/
    output.css     # Tailwind compiled CSS
    theme.css      # Custom theme CSS (generated)
  js/
    (client-side JS if needed)
  images/          # User-uploaded images (future)
admin/
  index.html       # Admin SPA
  (admin assets)
```

### Implementation Tasks:
- [ ] Update `.htaccess` for static-first routing:
  ```apache
  # Serve static files first if they exist
  RewriteCond %{REQUEST_FILENAME} -f
  RewriteRule ^ - [L]

  # Fallback to dynamic routing
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule ^(.*)$ /index.fcgi/$1 [QSA,L]
  ```
- [ ] Create rake task: `rake static:verify`
  - Check that all published posts have static files
  - Check that all published pages have static files
  - Check that feeds exist
  - Report missing files
- [ ] Create rake task: `rake static:regenerate_all`
  - Regenerate all static posts
  - Regenerate all static pages
  - Regenerate feeds
  - Regenerate sitemap
- [ ] Create rake task: `rake static:export`
  - Create ZIP archive of all static files
  - Include database dump (SQLite file)
  - Include README with recovery instructions
- [ ] Document manual recovery process (in CLAUDE.md or README):
  - If Ruby app breaks, static files continue to serve
  - How to restore from backup
  - How to regenerate all static files from database
- [ ] Add backup automation (optional):
  - Cron job to export static files + database nightly
  - Upload to cloud storage (S3, Backblaze, etc.)

### Files to Create/Modify:
- `.htaccess` - static file priority routing
- `lib/tasks/static.rake` (new)
- `CLAUDE.md` or `RECOVERY.md` - recovery documentation

---

## Future Enhancements (Lower Priority)

### Image Upload & Media Library
- [ ] Add file upload to admin interface (Uppy.js or native input)
- [ ] Store images in `public/images/` or `public/uploads/`
- [ ] Create media library interface (grid view, search, delete)
- [ ] Image optimization (resize, compress, WebP conversion)
- [ ] Insert images into Quill editor via media library
- [ ] Track image usage (which posts use which images)

### SEO Enhancements
- [ ] Add meta description field to posts/pages
- [ ] Generate OpenGraph tags (og:title, og:description, og:image)
- [ ] Generate Twitter Card tags
- [ ] Create sitemap.xml (list of all posts/pages)
- [ ] Add canonical URLs to prevent duplicate content
- [ ] Schema.org markup (Article, BlogPosting)

### Search Functionality
- [ ] Client-side search with lunr.js (indexes static content)
- [ ] Generate search index JSON file
- [ ] Add search bar to public site
- [ ] Highlight search results
- [ ] Search by title, content, tags (if tags implemented)

### Analytics Integration
- [ ] Google Analytics (via settings - paste tracking ID)
- [ ] Privacy-friendly alternatives (Plausible, Fathom)
- [ ] Display analytics in admin dashboard (via API)

### Multi-User & Roles
- [ ] Add `role` field to User model (admin, editor, viewer)
- [ ] Role-based permissions (editors can create drafts, admins can publish)
- [ ] Author attribution for posts/pages
- [ ] User management interface in admin

### Tags & Categories
- [ ] Create `tags` table (many-to-many with posts)
- [ ] Add tag input to post editor (tag picker or autocomplete)
- [ ] Display tags on posts
- [ ] Tag archive pages (`/tags/:tag`)
- [ ] Generate static tag pages

### Scheduled Publishing
- [ ] Add `publish_at` datetime field to posts/pages
- [ ] Rake task or background job to publish scheduled posts: `rake posts:publish_scheduled`
- [ ] Cron job to run task periodically
- [ ] Display schedule status in admin ("Scheduled for Nov 12, 2025")

### Webhooks & Notifications
- [ ] Webhook on post published (notify external service)
- [ ] Email notification when comment submitted (to admin)
- [ ] Slack/Discord integration (post published, comment awaiting moderation)

### Import/Export
- [ ] Export posts to Markdown files (one file per post)
- [ ] Import Markdown files (bulk create posts)
- [ ] Export entire site as JSON (posts, pages, settings, comments)
- [ ] Import from WordPress XML export
- [ ] Export to static site generator format (Jekyll, Hugo)

### Revision History
- [ ] Create `revisions` table (post_id, content, title, created_at)
- [ ] Save revision on every post update
- [ ] Display revision history in admin
- [ ] Restore from revision (copy content back to post)
- [ ] Diff view (compare two revisions)

### Draft Previews
- [ ] Generate preview URL for unpublished posts (`/preview/:token`)
- [ ] Temporary token expires after 24 hours
- [ ] Share preview link with reviewers before publishing

---

## Testing Strategy

For each feature:
1. **Unit tests** for models and services (RSpec)
2. **Integration tests** for API endpoints (Rack::Test)
3. **Manual testing** of admin UI (browser)
4. **Manual testing** of public site (browser)
5. **Verify static file generation** (if applicable)
6. **Test on production environment** (shared hosting)

---

## Development Workflow

1. **Pick a feature** from this document (start with Priority 1-3)
2. **Create a git branch**: `git checkout -b feature/settings-management`
3. **Implement tasks** one by one, committing frequently
4. **Write tests** as you go (TDD preferred)
5. **Run full test suite** before merging: `bundle exec rspec`
6. **Manual testing** in browser (both dev and production)
7. **Merge to main**: `git checkout main && git merge feature/settings-management`
8. **Deploy to production** and verify

---

## Current Status

✅ **Completed** (Phase 1-8 from IMPLEMENTATION_PLAN.md):
- Project foundation and setup
- Database with User and Post models
- OAuth authentication (Google, GitHub)
- Posts API (CRUD with authentication)
- Admin interface (Alpine.js + Quill.js)
- Public site (ERB templates)
- Tailwind CSS integration (CDN fallback due to memory constraints)
- FastCGI deployment on shared hosting
- Comprehensive test suite (57 tests)
- Production deployment working
- Security hardening (.htaccess rules, session config, ModSecurity workarounds)
- Cache control headers to prevent browser caching issues

🎯 **Next Recommended Steps**:
1. ✅ ~~Implement **Settings Management** (Priority 1)~~ - COMPLETED 2025-11-14
2. ✅ ~~Implement **Static HTML Generation** (Priority 2)~~ - COMPLETED 2025-11-14
3. ✅ ~~Implement **RSS Feeds** (Priority 3)~~ - COMPLETED 2025-11-15
4. ✅ ~~Implement **Pages & Hierarchy** (Priority 4)~~ - COMPLETED 2025-11-16
5. ✅ ~~Implement **API Pagination**~~ - COMPLETED 2025-11-21
6. Investigate **Commenting System** options (Priority 5)
7. Plan **Theme Customization** approach (Priority 6)

---

## Questions to Resolve Before Starting

### RSS Feeds:
- Content: full post HTML or plain text excerpt?
- Item limit: 10, 20, 50 posts in feed?

### Commenting:
- **Most important**: self-hosted or third-party?
- If self-hosted: anonymous comments or login required?
- Spam prevention: Akismet, honeypot, manual moderation only?

### Pages:
- URL structure: `/pages/:slug` or `/:slug` for top-level?
- Nested URLs: `/parent/child` or keep flat?

---

## Completed Features

### ✅ Settings Management (Priority 1) - 2025-11-14
- Structured columns approach with 14 fields
- Singleton pattern with comprehensive validation
- Admin UI with 6-section form
- 47 tests added (35 model + 12 routes)

### ✅ Static HTML Generation (Priority 2) - 2025-11-14
- ERB template approach with Tailwind CDN
- Automatic regeneration via ActiveRecord callbacks
- Apache static-first routing with optimized caching
- 28 tests added (22 service + 6 model)

---

*Last updated: 2025-11-21*
