# v7cms - Project Status & Navigation Guide

**Last Updated**: 2025-11-24

This document provides a quick overview of project status and guides you to the right documentation.

**🗺️ NEW:** See [ROADMAP.md](ROADMAP.md) for a prioritized view of all pending work.

---

## 🎯 Current Status: **All Tests Passing - 100% Test Success**

The v7cms core is **complete and deployed** on shared hosting (DreamHost). Recent completions include:
- ✅ Rate Limiting Middleware (PR #29) - FastCGI-compatible rate limiting with FileStore cache, tested with 8 concurrent worker processes
- ✅ Setting.instance Caching (PR #28) - Thread-safe in-memory caching reducing database queries from O(n) to O(1)
- ✅ Remaining Test Fixes (PR #27) - Fixed all 17 remaining test failures (custom_css, ThemeGenerator, PostRenderer)
- ✅ Theme Test Fixes (PR #26) - Fixed 51 test failures caused by Theme schema expansion
- ✅ Quill Content Validation Hotfix (PR #25) - Fixed critical bug preventing posts/pages from being saved
- ✅ Confirmation Dialogs (PR #24) - Enhanced delete confirmations with cascade warnings
- ✅ Admin Form Validation (PR #23) - Comprehensive client-side validation for all admin forms
- ✅ Service Error Handling (PR #21) - Comprehensive error handling for all 4 service classes with logging
- ✅ Theme Customization (Priority 6) - 40+ configurable fields across 8 categories
- ✅ API Pagination - Added to Posts and Pages endpoints
- ✅ Hierarchical Pages (Priority 4) - Full hierarchical page support

---

## 📊 What's Complete

### ✅ Core Application (Phases 1-8)
- **Backend**: Ruby 3.2 + Sinatra framework with SQLite database
- **Models**: User (OAuth), Post (with auto-slugs), Page (hierarchical), Setting (singleton), Theme (singleton)
- **Authentication**: OAuth 2.0 via OmniAuth (Google, GitHub)
- **API**: RESTful JSON API for posts, pages, settings, and theme CRUD with authentication
- **Admin Interface**: Single-page app (Alpine.js + Quill.js WYSIWYG editor + Tailwind CSS v4)
- **Public Site**: ERB templates for homepage, posts, and hierarchical pages
- **Testing**: 425 RSpec tests (models, routes, helpers, services, middleware) - **ALL PASSING** ✅
- **Setting.instance Caching** (2025-11-24) - PR #28:
  - Thread-safe in-memory caching with double-checked locking pattern
  - Added `@@instance_cache` and `@@cache_mutex` class variables
  - Added `Setting.clear_cache!` method and after_save callback
  - 3 new tests for caching behavior (memory, clearing, thread safety)
  - Global cache clearing in spec_helper for test isolation
  - Test results: 425 examples, 0 failures (100% pass rate maintained)
- **Remaining Test Fixes** (2025-11-24) - PR #27:
  - Fixed all 17 remaining test failures using systematic debugging
  - Added custom_css to ThemeConfig::FIELDS with validation
  - Updated ThemeGenerator tests to match simplified implementation
  - Fixed PostRenderer callback test
  - Test results: 411 examples, 0 failures (100% pass rate)
- **Theme Test Fixes** (2025-11-24) - PR #26:
  - Fixed 51 test failures caused by Theme schema expansion migration
  - Updated field names: line_height → line_height_base, spacing_scale → spacing_unit, border_radius → radius_default
  - Updated validation ranges to match new field semantics
  - Removed tests for deleted fields (layout_style, header_style, footer_style)
  - Updated CSS variable names in assertions
  - Test results: Reduced failures from 67 to 16
- **Admin Form Validation** (2025-11-24) - PR #23, #24, #25:
  - Client-side validation for Posts, Pages, and Settings forms (19 fields total)
  - Hybrid validation timing (blur → real-time after touched)
  - Validation summary banners with clickable error links
  - Red/green border feedback and field-level error messages
  - Debounced slug uniqueness checking with caching (1-second debounce)
  - Enhanced confirmation dialogs for destructive actions
  - Cascade warnings when deleting pages with children
  - Quill text-change event listeners for content validation
  - Testing checklist: docs/TESTING_CHECKLIST.md
- **Deployment**: FastCGI on shared hosting with Apache .htaccess routing
- **Security**:
  - .htaccess rules blocking sensitive files (.rb, .db, .env, config/, etc.)
  - Session-based authentication
  - CSRF protection (Rack::Protection)
  - ModSecurity workarounds (email-only OAuth scope)
  - Cache control headers to prevent stale content
- **Settings Management**:
  - 14 configurable settings across 6 categories
  - Admin UI for editing all site text and display options
  - API endpoints for settings CRUD
  - Singleton pattern for single settings record
  - Comprehensive validation (email, URL, numeric ranges)
  - JavaScript-based admin link injection (static-site ready)
  - Thread-safe in-memory caching (PR #28) - O(1) query performance
- **Static HTML Generation** (2025-11-14):
  - PostRenderer service generates standalone HTML files
  - Automatic generation via ActiveRecord callbacks
  - Files saved to public/posts/{slug}.html
  - Apache serves static files directly (bypass Ruby)
  - Rake tasks for bulk regeneration, verification, cleanup
  - 1-hour browser cache for static files
  - 28 new tests (22 service + 6 model callback tests)
- **RSS and Atom Feeds** (2025-11-15):
  - FeedGenerator service creates RSS 2.0 and Atom feeds
  - Dynamically generated at /feed/rss and /feed/atom
  - Includes 20 most recent published posts
  - Feed discovery links in HTML head
  - Automatic updates via ActiveRecord callbacks on Post and Setting
  - Rake task for manual regeneration
  - 41 new tests for feed generation service
- **Hierarchical Pages Feature** (2025-11-16) - MERGED:
  - Page model with self-referential associations (parent/children)
  - Hierarchical helper methods: ancestors, descendants, breadcrumb_trail, depth
  - Pages API endpoints (CRUD with hierarchical support)
  - Admin UI for creating/editing pages with parent selection
  - Public routes at /pages/* with hierarchical URL support
  - PageRenderer service for automatic static HTML generation
  - Page view template with breadcrumbs and child page listings
  - Comprehensive Page model tests
  - Auto-update .ruby-version in setup.php for compatible patch versions
- **API Pagination** (2025-11-21):
  - Pagination support for GET /api/posts and GET /api/pages
  - Query parameters: limit (default 20, max 100), offset (default 0)
  - Pagination metadata in responses (total, limit, offset, count)
  - Helper methods: pagination_params, pagination_metadata
  - Works with filters (include_drafts, top_level, parent_id)
- **Theme Customization** (2025-11-21 to 2025-11-22) - MERGED:
  - Theme model with 40+ configurable fields across 8 semantic categories
  - ThemeConfig module for centralized field definitions and metadata
  - ThemeGenerator service for CSS generation with custom properties
  - Theme API endpoints (GET, PUT, POST reset, GET preview)
  - Admin UI theme tab with color pickers and category organization
  - Tailwind CSS v4 via CDN with @theme directive integration
  - Auto-regeneration of theme.css and static HTML files on save
  - Comprehensive tests for model, routes, and service
- **Service Error Handling** (2025-11-23) - PR #21:
  - Comprehensive error handling for all 4 service classes
  - Try/catch blocks around all I/O operations (File.write, File.delete, FileUtils.mkdir_p)
  - Logger integration with STDOUT output for production visibility
  - Boolean return values (true/false) for success/failure
  - 31 new error scenario tests across PostRenderer, PageRenderer, FeedGenerator, ThemeGenerator
  - Detailed error messages with full stack traces
  - Split FeedGenerator into write_rss_feed and write_atom_feed methods

### ✅ Production Deployment Features
- OAuth callback working in production
- Admin interface at `/admin/`
- Posts API fully functional
- Static assets served correctly
- Security hardening complete
- Cache control preventing browser caching issues

---

## 📁 Documentation Map

### For Understanding the Project
**→ `CLAUDE.md`** - Comprehensive project documentation
- Architecture overview
- Stack details (backend, frontend, request flow)
- File structure and key files
- Development commands (Docker & local)
- Testing instructions
- API documentation
- Configuration guide
- Deployment instructions
- Common issues and solutions
- Code style guidelines

### For Implementation History
**→ `IMPLEMENTATION_PLAN.md`** - Original 8-phase build plan
- **Status**: ✅ ALL PHASES COMPLETE (1-8)
- Foundation, database, OAuth, API, Tailwind, admin, public site, deployment
- This document is now **historical reference only**
- Shows how we got to current state
- Useful for understanding architecture decisions

### For Future Development
**→ `NEXT_STEPS.md`** - Roadmap for future features
- **Status**: 🎯 ACTIVE DEVELOPMENT ROADMAP
- 7 priority levels with detailed implementation plans
- Completed priorities (1-4, 6):
  1. ✅ Settings Management (customize site text via admin)
  2. ✅ Static HTML Generation (posts as static files)
  3. ✅ RSS Feed Generation
  4. ✅ Pages & Hierarchical Content
  6. ✅ Theme Customization (40+ fields)
- Remaining priorities:
  5. Commenting System
  7. Static Asset Management
- Each priority includes:
  - Clear goals
  - Design decisions to make
  - Task checklists
  - Files to create/modify
  - Technical considerations
- Also includes "Future Enhancements" (lower priority ideas)

### For Current Status
**→ `PROJECT_STATUS.md`** (this file)
- Quick overview of what's done and what's next
- Navigation guide to other documentation
- Git workflow reminders

---

## 🚀 Quick Start for New Claude Code Sessions

### "What should I work on next?"
1. Open **`NEXT_STEPS.md`**
2. Start with **Priority 5: Commenting System** (next unimplemented feature)
3. Follow the task checklist in that section

### "How does this project work?"
1. Read **`CLAUDE.md`** - Project Overview and Architecture sections
2. Review **`app/cms.rb`** - Main application file
3. Check **`IMPLEMENTATION_PLAN.md`** to see how it was built

### "How do I test/deploy/develop?"
- **`CLAUDE.md`** has all commands under:
  - "Development Commands" section
  - "Testing" section
  - "Deployment" section

### "What's the tech stack?"
- **Backend**: Ruby 3.2, Sinatra 3.0, SQLite, ActiveRecord, OmniAuth
- **Frontend**: Alpine.js, Quill.js, Tailwind CSS v4 (CDN with @theme)
- **Deployment**: FastCGI on Apache (shared hosting)
- **Testing**: RSpec with Rack::Test and DatabaseCleaner (425 tests, 100% passing)

---

## 🌳 Git Workflow

### Current Branch
- **Main branch**: `main`
- **Current working branch**: `base-implementation`

### Recommended Workflow for New Features
```bash
# Start new feature
git checkout main
git pull origin main
git checkout -b feature/settings-management

# Work on feature (commit often)
git add .
git commit -m "Add settings table and model"

# When complete and tested
bundle exec rspec  # All tests must pass
git checkout main
git merge feature/settings-management
git push origin main

# Deploy to production
# (git push triggers deployment or manual FTP/rsync)
```

### Commit Message Style
Follow existing pattern (see recent commits):
- Clear, descriptive subject line
- Explain "why" not just "what"

---

## 📂 Key Directories & Files

### Application Code
```
app/
  cms.rb                    # Main Sinatra application (712 lines)
  models/
    user.rb                 # OAuth user model
    post.rb                 # Blog post model
    page.rb                 # Hierarchical page model
    setting.rb              # Site settings (singleton)
    theme.rb                # Theme customization (singleton)
  services/
    post_renderer.rb        # Static HTML generation for posts
    page_renderer.rb        # Static HTML generation for pages
    feed_generator.rb       # RSS/Atom feed generation
    theme_generator.rb      # CSS generation from theme
  config/
    theme_fields.rb         # Theme field metadata (ThemeConfig)
  helpers/
    auth_helper.rb          # Authentication helpers
  views/
    layout.erb              # Site layout with Tailwind v4 @theme
    index.erb               # Homepage (post list)
    post.erb                # Single post view
    page.erb                # Single page view
    404.erb                 # Not found page
```

### Configuration
```
config.ru                   # Rack configuration
Rakefile                    # Database tasks
config/
  database.yml              # Database config (dev/test/prod)
.env                        # Environment variables (gitignored)
.env.example                # Template for .env
```

### Frontend
```
admin/
  index.html                # Admin SPA (Posts, Pages, Settings, Theme)
public/
  js/
    admin.js                # Admin app logic (Alpine.js)
  css/
    theme.css               # Generated theme CSS (auto-generated, gitignored)
  posts/                    # Generated static post HTML files
  pages/                    # Generated static page HTML files
```

### Database
```
db/
  migrate/                  # ActiveRecord migrations
  seed.rb                   # Seed data script
  cms.db                    # SQLite database (gitignored)
```

### Testing
```
spec/
  models/                   # Model tests (User, Post, Page, Setting, Theme)
  routes/                   # Route/integration tests (Auth, Posts, Pages, Settings, Theme, Feeds)
  services/                 # Service tests (PostRenderer, PageRenderer, FeedGenerator, ThemeGenerator)
  helpers/                  # Helper tests
  spec_helper.rb            # RSpec configuration
```

### Deployment
```
index.fcgi                  # FastCGI entry point
.htaccess                   # Apache routing and security
setup.php                   # Production setup script (shebang fix)
bin/
  add_admin                 # Script to manually add admin user
```

---

## 🎯 Immediate Next Steps (Recommended)

### Step 1: Commenting System ⬅️ **NEXT**
**File**: `NEXT_STEPS.md` → Priority 5

Enable user engagement through comments on posts.

**Decision needed**: Self-hosted vs third-party service
- Self-hosted: Full control, requires spam prevention implementation
- Third-party: utterances, giscus (GitHub-based), Disqus, or others

**Estimated effort**: 2-8 hours (depending on approach)

### Step 2: Static Asset Management
**File**: `NEXT_STEPS.md` → Priority 7

Manage and serve uploaded media files (images, documents, etc.)

**Decision needed**: Storage strategy and admin UI approach

**Estimated effort**: 6-10 hours

---

## 🔍 Common Tasks

### Add a new model
1. Create migration: `bundle exec rake db:create_migration NAME=create_things`
2. Edit migration file in `db/migrate/`
3. Run migration: `bundle exec rake db:migrate`
4. Create model: `app/models/thing.rb`
5. Write tests: `spec/models/thing_spec.rb`
6. Run tests: `bundle exec rspec spec/models/thing_spec.rb`

### Add a new API endpoint
1. Add route in `app/cms.rb`
2. Write test in `spec/routes/things_spec.rb`
3. Run tests: `bundle exec rspec spec/routes/things_spec.rb`
4. Manual test with curl or browser

### Add a new admin UI section
1. Update `admin/index.html` - add HTML structure
2. Update `public/js/admin.js` - add Alpine.js logic
3. Test in browser at `http://localhost:9292/admin/`

### Deploy to production
1. Commit and push changes to git
2. SSH/FTP to server
3. Pull latest code: `git pull origin main`
4. Run migrations: `RACK_ENV=production bundle exec rake db:migrate`
5. Restart FastCGI (varies by host, often automatic)
6. Test in browser at production URL

---

## ⚠️ Important Notes

### OAuth Configuration
- Credentials in `.env` (gitignored)
- Production callback URLs must be registered in Google/GitHub OAuth apps
- Google OAuth uses `email` scope only (not `profile`) to avoid ModSecurity blocking

### Database
- SQLite in `db/cms.db` (gitignored)
- All environments (dev/test/prod) use the same cms.db file
- Migrations in `db/migrate/`
- Always run migrations in test env: `RACK_ENV=test bundle exec rake db:migrate`

### Tailwind CSS
- Using **Tailwind v4 CDN** with @theme directive (no build step required)
- Theme customization integrated via theme.css (auto-generated)
- For production: CDN link in templates (already configured)

### Security
- `.htaccess` blocks access to `.rb`, `.db`, `.env`, `config/`, `app/`, etc.
- Session secret must be strong in production
- CSRF protection enabled (except for OAuth routes)
- Never commit secrets to git

### Testing
- Run all tests before deploying: `bundle exec rspec`
- Current count: 425 tests
- Test status: **425 passing, 0 failures** ✅ (100% pass rate)
- Test coverage: models, routes, helpers, services, middleware
- Always write tests for new features
- ✅ All test failures resolved (PR #26 + PR #27)

### Static Files
- Static HTML files auto-generated for published posts and pages
- Posts located in `public/posts/{slug}.html`
- Pages located in `public/pages/{slug}.html`
- Use `rake posts:regenerate_all` and `rake pages:regenerate_all` after deployment
- Use `rake posts:verify` and `rake pages:verify` to check for missing files

### Theme Customization
- Theme CSS auto-generated at `public/css/theme.css`
- 40+ configurable fields across 8 categories
- Changes applied automatically when saved via admin UI
- To manually regenerate: `Theme.instance.send(:regenerate_theme_css)`

---

## 🐛 Troubleshooting

### "Where do I start?"
→ Read this file, then `NEXT_STEPS.md` Priority 1

### "How does [feature] work?"
→ Check `CLAUDE.md` for architecture details

### "What's the original implementation plan?"
→ See `IMPLEMENTATION_PLAN.md` (historical reference)

### "Tests are failing"
→ Make sure test database is migrated: `RACK_ENV=test bundle exec rake db:migrate`

### "OAuth isn't working"
→ Check `.env` has correct credentials and callback URLs match OAuth app settings

### "Can't see my changes in production"
→ Browser cache issue - headers in `.htaccess` should prevent this now

### "Static files not being served"
→ Check `.htaccess` routing rules and file permissions

---

## 📞 Getting Help

- **GitHub Issues**: Report bugs at project repo
- **Documentation**: `CLAUDE.md` has troubleshooting section
- **Common Issues**: See `CLAUDE.md` → "Common Issues" section

---

**Quick Links:**
- 📖 Project Docs: `CLAUDE.md`
- 🏗️ Implementation History: `IMPLEMENTATION_PLAN.md`
- 🎯 Future Roadmap: `NEXT_STEPS.md`
- 📍 You Are Here: `PROJECT_STATUS.md`
