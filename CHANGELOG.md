# Changelog

All notable changes to v7cms will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.5] - 2026-04-08

### Fixed
- **Duplicate Cache-Control headers**: Unset `mod_expires` headers before setting no-cache on FCGI responses — DreamHost was adding `max-age=600` alongside our `no-cache`, creating conflicting headers

---

## [0.2.4] - 2026-04-08

### Fixed
- **FCGI no-cache headers**: Use `REDIRECT_` prefix for env var set by `RewriteRule` — Apache renames `E=VAR` to `REDIRECT_VAR` after internal redirect, so dynamic routes were missing no-cache headers

---

## [0.2.3] - 2026-04-08

### Fixed
- **Static file performance**: Apache rewrite rules for `/js/`, `/css/`, `/patterns/`, `/posts/`, `/pages/` to serve from `public/` directly, bypassing FCGI/Rack (1,000ms+ TTFB → <50ms)
- **Cache headers**: Replaced blanket no-cache on all JS/CSS/HTML with tiered caching — 30-day for static assets, 1-hour for theme.css and HTML, no-cache only for FCGI responses
- **Root path caching**: Explicit rewrite for `/` so homepage gets proper no-cache headers via FCGI env var
- **Conflicting headers**: Set Sinatra `static_cache_control` to 1-hour to avoid Apache/Sinatra header conflicts
- **Phantom script**: Removed `/js/recaptcha.js` reference from post and comment templates (file never existed, caused 404)

### Added
- Gzip compression via `mod_deflate` for JS, CSS, WASM, JSON, SVG, and fonts
- Template content specs verifying rewrite rules, cache headers, and compression config

---

## [0.2.2] - 2026-04-05

### Fixed
- `rake v7cms:assets` no longer clobbers client-owned files in `public/js/` and `public/css/` — now uses file-level symlinks for gem assets while preserving client files in the same directories
- Old directory symlinks from previous versions are auto-migrated

---

## [0.2.1] - 2026-04-04

### Added
- **Template Hook Partials**: Convention-based `_head_custom.erb` and `_body_scripts_custom.erb` for client customization without modifying gem layout
- Tests for hook rendering and multi-path view override behavior

### Fixed
- Sinatra template resolution for hook partials (underscore prefix, `layout: false`)
- Hook partials added to gem-level views for proper template lookup

### Security
- Updated `json` gem to 2.19.3 (CVE-2026-33210: format string injection)
- Aligned gemspec json constraint with Gemfile to protect gem consumers

---

## [0.2.0] - 2026-03-23

### Added
- **Form Builder**: Custom forms with 9 field types, public rendering, reCAPTCHA v3 spam prevention, email notifications, submission management with CSV export
- `[form:slug]` shortcodes for embedding forms in page/post content
- 3 new models (Form, FormField, FormSubmission), 2 services (FormRenderer, FormMailer)

---

## [0.1.51] - 2026-03-21

### Fixed
- `css_class` lost when editing menu items — `flattenMenuItems` was not including it in flattened objects

---

## [0.1.50] - 2026-03-18

### Added
- **Menu Builder**: Admin UI for managing navigation menus with polymorphic page/post/custom links
- Two-level nesting with CSS-only dropdowns (no JS on public side)
- Menus baked into static HTML output via PostRenderer/PageRenderer
- 10 REST API endpoints for menu and item CRUD, reordering, public render
- Security: HTML escaping, URL allowlist, linkable_type validation

---

## [0.1.48] - 2026-03-14

### Added
- **Hierarchical Pages**: `nested=true` parameter on `GET /api/pages` returns tree structure with depth and nested children
- Admin UI tree view with expand/collapse, replacing flat table

### Fixed
- RuboCop lint issues and widened CDN rake task regex to match unpinned versions

---

## [0.1.47] - 2026-03-14

### Fixed
- Quill.js toolbar duplication on navigation — added proper cleanup on view change
- Comment pagination offset increment moved after successful fetch
- **CDN Version Management**: Centralized versions in `cdn_versions.rb`, pinned Alpine.js 3.14.9, Swagger UI 5.18.2, Tailwind 4.1.0
- Updated omniauth-google-oauth2 and omniauth-oauth2

---

## [0.1.46] - 2026-03-13

### Changed
- Upgraded minimum Ruby from 3.0 to 3.4 across gemspec, CI, and Dockerfiles
- Updated rack, nokogiri, and faraday for security fixes

---

## [0.1.45] - 2026-03-12

### Added
- **Editorial Workflow**: Three-state system (draft → ready → published) replacing boolean `published` flag. Published versions are frozen ContentVersion snapshots; editing auto-flips to draft while published version stays live.
- **Post Tags**: Managed tagging system with Tag model, PostTag join table, CRUD API, admin tag management, and page-level tag filtering
- **Gem Packaging**: Namespaced all models/services/helpers under `V7CMS::`, moved code to `lib/v7cms/`, added FileResolver for user-first path resolution, rake setup tasks

### Fixed
- Restored admin UI files accidentally deleted during workflow merge
- Post/page status not showing in admin UI (`workflow_state` → `status` field mismatch)

---

## [0.1.43] - 2026-01-05

### Changed
- Simplified blog post layouts to standard and minimal options (Phase 1)
- Removed unused magazine and full_width layout templates
- Updated admin UI layout picker to 2-column grid

### Fixed
- Prerelease versioning now uses next version (0.1.43.pre.X instead of 0.1.42.pre.X)

---

## [0.1.42] - 2025-12-30

### Added
- **CI/CD Enhancements**: Prerelease gem builds on PRs, MegaLinter integration
- Prerelease gems published to GitHub Packages for testing before merge
- RuboCop and ESLint linting in CI pipeline

---

## [0.1.41] - 2025-12-30

### Added
- **Content History**: Hybrid versioning system for posts and pages
  - Versionable concern with auto-versioning on save
  - ContentVersion model with validations and scopes
  - Version list, restore, and compare API endpoints
  - Admin UI version history panel with diff viewer
  - Cleanup rake task for expired auto-versions

---

## [0.1.38-0.1.40] - 2025-12-26

### Added
- **Image/Asset Uploads** (PR #60)
  - Upload API with file serving and optional transformations
  - Media Library modal for editor image insertion
  - Assets tab in admin UI with upload/browse/delete
  - Upload settings section with size limit and processing status
  - Rake task for importing existing uploads
  - Image processing gems (mini_magick, ruby-vips)

---

## [0.1.36-0.1.37] - 2025-12-08

### Added
- **Blog Post Layouts**: Selectable post layout templates (standard, minimal)
- **Admin Load More**: Pagination for posts and pages lists
- **Page Hero Images**: Optional hero_image_url field for pages

---

## 2025-11-29 - User Management UI

### Added (PR #39 - User Management UI)
- **Users Admin Tab**: New tab in admin interface for viewing and managing user accounts
  - User list displays avatar, name, email, provider badge, admin status, last login
  - Relative time formatting ("2 days ago", "Just now")
  - Search and filter capabilities
- **Admin Privilege Management**: Toggle switches to grant/revoke admin access
  - Safety guard: Cannot revoke your own admin access
  - Safety guard: Must maintain at least one admin at all times
- **Last Login Tracking**: New `last_login_at` column tracks user login timestamps
  - Updated on each OAuth callback
  - Displayed in admin user list
- **Users API**: 2 new endpoints
  - `GET /api/users` - List all users (admin only)
  - `PUT /api/users/:id` - Update user admin status (admin only)
- **Tests**: 11 new route tests for user management

### Changed (PR #39)
- Modified 5 files (+411 lines):
  - Migration: Add `last_login_at` to users table
  - app/cms.rb: User API endpoints with safety validations
  - admin/index.html: Users tab and user table UI
  - public/js/admin.js: fetchUsers, toggleUserAdmin, formatRelativeTime
  - spec/routes/users_spec.rb: New test file
- Test results: **500 examples, 0 failures** ✅

---

## 2025-11-28 - API Documentation and Theme Enhancements

### Added (PR #38 - OpenAPI/Swagger API Documentation)
- **Swagger UI**: Interactive API documentation at `/api/docs`
- **OpenAPI 3.0 Spec**: Dynamic specification at `/api-spec.json`
- **Documentation Coverage**: All 25+ API endpoints across 7 categories
  - Posts, Pages, Comments, Settings, Theme, Auth, Feeds
- **Schema Definitions**: Complete request/response schemas for all endpoints
- **New Files**: 20 files added
  - `app/docs/swagger_root.rb` - API metadata
  - `app/docs/schemas/*.rb` - Schema definitions (7 files)
  - `app/docs/paths/*.rb` - Path definitions (7 files)
  - `app/docs/api_docs.rb` - Main assembler module
  - `public/api-docs.html` - Swagger UI interface

### Changed (PR #38)
- Added swagger-blocks gem (~> 3.0) to Gemfile
- Added `/api/docs` and `/api-spec.json` routes to cms.rb
- Total: +1978 lines across 20 files
- Test results: **489 examples, 0 failures** ✅

### Added (PR #36 - Header and Footer Style Customization)
- **Header Styles**: 3 options (default, minimal, prominent)
  - `default`: Standard header with subtle shadow
  - `minimal`: Compact header with border, hides tagline
  - `prominent`: Larger header with emphasized shadow
- **Footer Styles**: 3 options (default, minimal, centered)
- **Database**: New columns `header_style` and `footer_style` in themes table
- **Live Preview**: Styles update in real-time via theme preview

### Changed (PR #36)
- Added fields to ThemeConfig with enum validation
- Updated layout.erb to apply dynamic classes
- Total: +67 lines, -6 lines

### Fixed (PR #37 - Header/Footer Style Fallback)
- Added fallback for missing `header_style`/`footer_style` columns
- Prevents errors when database hasn't been migrated yet

### Fixed (PR #35 - Theme Preview Rendering)
- Theme preview endpoint now renders actual HTML page
- Preview iframe displays correctly in admin interface

### Fixed (PR #34 - API Response Parsing)
- Fixed nested data extraction from API responses in admin.js
- Properly handles wrapped response objects

---

## 2025-11-27 - Admin Security and Error Handling

### Added (PR #31 - Admin Email Whitelist Security)
- **Email Whitelist**: `ADMIN_EMAILS` environment variable controls admin access
  - Comma-separated list of authorized email addresses
  - Validated at OAuth login (not just authorization)
- **Admin Field**: Boolean `admin` column on users table
  - Stored in database for fast authorization checks
  - Backfill migration sets existing users based on whitelist
- **Fail-Closed Security**: Application rejects all logins if `ADMIN_EMAILS` not configured
- **Access Denied Screen**: Clear UI for unauthorized login attempts
- **Startup Warning**: Console warning if `ADMIN_EMAILS` not set
- **Setup Validation**: setup.php displays configured admin emails

### Changed (PR #31)
- OAuth callback validates email against whitelist before creating session
- `require_login` helper checks admin field
- Updated .env.example to mark `ADMIN_EMAILS` as REQUIRED
- Total: +194 lines, -69 lines across 15 files
- Test results: **443 examples, 0 failures** ✅

### Fixed (PR #33 - Auth API User Object Extraction)
- Correctly extracts user object from nested auth API response
- Prevents undefined errors in admin.js

### Fixed (PR #32 - Admin API Error Handling)
- Added comprehensive error handling to all admin API calls
- Prevents Alpine.js crashes on API failures
- Graceful error messages for users

---

## 2025-11-27 - Commenting System

### Added (PR #30 - Commenting System + Comment Disabling)
- **Comment Model**: Self-hosted anonymous commenting with moderation queue
  - Database: comments table with post_id FK, author fields, content, IP, reCAPTCHA score
  - Validations: author_name/email required, email format, content max 5000 chars
  - Scopes: approved, pending, spam
- **reCAPTCHA v3 Integration**: Invisible bot protection
  - Score threshold: 0.5 (rejects likely bots)
  - Environment variables: RECAPTCHA_SITE_KEY, RECAPTCHA_SECRET_KEY
- **Public Comments API**:
  - `GET /api/posts/:id/comments` - List approved comments with pagination
  - `POST /api/posts/:id/comments` - Submit comment with reCAPTCHA verification
- **Admin Comments API**:
  - `GET /api/comments` - List all comments with status filter
  - `GET /api/comments/pending_count` - Pending count for badge
  - `PUT /api/comments/:id/approve` - Approve comment
  - `PUT /api/comments/:id/spam` - Mark as spam
  - `DELETE /api/comments/:id` - Delete permanently
- **Frontend Comment Display**:
  - Lazy loading: 20 comments per batch with "Load More"
  - Comment form with name, email, optional website
  - Success/error messaging
- **Admin Moderation Interface**:
  - Comments tab with pending count badge
  - Filter buttons: Pending, Approved, Spam
  - Actions: Approve, Mark as Spam, Delete
  - Shows metadata: author, email, website, reCAPTCHA score
- **Comment Disabling Controls**:
  - Global toggle: `settings.allow_comments` (site-wide)
  - Per-post toggle: `posts.comments_enabled`
  - AND logic: both must be true for comments to display
  - "Comments are closed" message when disabled
  - Existing approved comments remain visible

### Changed (PR #30)
- Total: +2108 lines, -927 lines
- New files: comment.rb, comments.js, comment specs
- Test results: **477 examples, 0 failures** ✅

---

## 2025-11-25 - Rate Limiting and Security Hardening

### Added (PR #29 - Rate Limiting Middleware)
- **Rack::Attack Middleware**: Rate limiting with FastCGI multi-process compatibility
  - rack-attack gem (~> 6.7)
  - FileStore cache for shared state across processes
  - Cache directory: ./tmp/rack-attack-cache
- **Rate Limits**:
  - General traffic: 100 requests/minute per IP (excludes /admin)
  - API writes: 20 requests/minute per IP for POST/PUT/DELETE
  - Login: 5 requests/minute per IP for /auth/* endpoints
- **IP Blocklist**: Configurable via BLOCKED_IPS environment variable
- **Custom 429 Response**: JSON format with Retry-After header
- **Rate Limiting Tests**: 11 comprehensive tests

### Changed (PR #29)
- Modified 6 files
- Dockerfile.apache: Fixed FastCGI compatibility issues
- Test results: **425 examples, 0 failures** ✅

---

## 2025-11-24 - Performance Optimization and Testing Improvements

### Added (PR #28 - Setting.instance Caching)
- **Thread-Safe In-Memory Caching**: Caching for Setting.instance
  - Double-checked locking pattern
  - `Setting.clear_cache!` method
  - `after_save` callback for automatic invalidation
- **Caching Tests**: 3 tests for caching behavior

### Changed (PR #28)
- Modified 3 files
- Test results: **414 examples, 0 failures** ✅

---

## 2025-11-24 - Admin Form Enhancements, Bug Fixes, and Complete Test Suite Fix

### Fixed (PR #27 - Remaining Test Failures)
- **custom_css Field Integration**: Added to ThemeConfig::FIELDS
- **Test Suite Completion**: Fixed all 17 remaining test failures
- Test results: **411 examples, 0 failures** ✅ (100% pass rate achieved)

### Fixed (PR #26 - Theme Test Updates)
- Updated field names: `line_height` → `line_height_base`, etc.
- Updated validation ranges and CSS variable names
- 51 test failures fixed (down from 67)

### Fixed (PR #25 - Quill Content Validation)
- Added Quill 'text-change' event listeners
- "Content is required" error no longer persists after adding content

### Added (PR #24 - Confirmation Dialogs)
- Enhanced multi-line confirmation dialogs for deletions
- Child page count warning for cascade deletes

### Added (PR #23 - Admin Form Validation)
- Client-side validation for all admin forms
- Debounced slug uniqueness checking
- Real-time validation feedback

---

## 2025-11-23 - Service Error Handling

### Added
- **Error Handling**: Comprehensive try/catch in all 4 service classes
- **Logger Integration**: Structured error logging with stack traces
- **Boolean Return Values**: Success/failure instead of exceptions
- **31 Error Scenario Tests**

---

## 2025-11-22 - Theme Customization Complete

### Added
- **Theme Model**: Singleton with 40+ configurable fields
- **ThemeConfig Module**: Centralized field definitions (382 lines)
- **ThemeGenerator Service**: CSS generation with custom properties
- **Theme API**: GET, PUT, POST reset, GET preview endpoints
- **Admin UI**: Theme tab with color pickers
- **Tailwind v4 Integration**: CDN with @theme directive

### Changed
- Switched from Tailwind CLI to v4 CDN
- Test count: 252 → 396 examples

---

## 2025-11-18 - Critical Fixes

### Fixed
- Feed route tests updated for dynamic generation
- Legacy feed URL redirect tests

### Added
- Foreign key constraint on `pages.parent_id`
- Circular reference validation in Page model
- N+1 query optimization for `Page#ancestors` using recursive CTE

### Changed
- Test count: 246 → 252 examples
