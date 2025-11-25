# Changelog

## 2025-11-24 - Performance Optimization and Testing Improvements

### Added (PR #28 - Setting.instance Caching)
- **Thread-Safe In-Memory Caching**: Implemented caching for Setting.instance to reduce database queries
  - Added `@@instance_cache` and `@@cache_mutex` class variables
  - Double-checked locking pattern for thread safety
  - `Setting.clear_cache!` method for explicit cache clearing
  - `after_save` callback for automatic cache invalidation on updates
- **Caching Tests**: Added 3 comprehensive tests for caching behavior
  - Test 1: Verifies instance cached in memory after first load (no DB query on second call)
  - Test 2: Verifies cache clears when settings are updated (fresh object loaded)
  - Test 3: Verifies thread-safe cache access (10 concurrent threads get same instance)
- **Test Infrastructure**: Global cache clearing in spec_helper before each test

### Changed (PR #28)
- Modified 3 files:
  - app/models/setting.rb: Added caching implementation (17 lines)
  - spec/models/setting_spec.rb: Added caching tests and clean state handling (67 lines)
  - spec/spec_helper.rb: Added cache clearing to prevent test pollution (2 lines)
- Test results: **414 examples, 0 failures** ✅ (100% pass rate maintained)

### Fixed (PR #28)
- **Query Performance**: Setting.instance now O(1) instead of O(n) for repeated calls
- **Test Isolation**: Cache clearing prevents cached Setting from polluting other tests
- **Deadlock Prevention**: first_or_create! called outside mutex to avoid recursive locking

### Impact (PR #28)
- **Performance**: First call queries database, all subsequent calls use in-memory cache
- **Thread Safety**: Mutex protection ensures safe concurrent access
- **Auto-Invalidation**: Cache automatically cleared when settings updated
- Test count increased from 411 to 414 examples (3 new caching tests)

---

## 2025-11-24 - Admin Form Enhancements, Bug Fixes, and Complete Test Suite Fix

### Added (PR #27 - Remaining Test Fixes)
- **custom_css Field Integration**: Added custom_css to ThemeConfig::FIELDS with proper metadata
  - Added to app/config/theme_fields.rb with `css_var: nil`, `default: nil`, `type: :text`
  - Added validation in Theme model: `validates :custom_css, length: { maximum: 10000 }, allow_blank: true`
  - Updated ThemeGenerator to skip fields without CSS variables
- **Test Suite Completion**: Fixed all 17 remaining test failures using systematic debugging
  - Pattern 1 (5 failures): custom_css missing from ThemeConfig
  - Pattern 2 (11 failures): ThemeGenerator tests outdated
  - Pattern 3 (1 failure): PostRenderer callback side effect

### Changed (PR #27)
- Modified 6 test files:
  - app/config/theme_fields.rb: Added custom_css field
  - app/models/theme.rb: Added custom_css validation
  - app/services/theme_generator.rb: Skip nil css_var fields
  - spec/routes/theme_spec.rb: Fixed variable name typo
  - spec/services/theme_generator_spec.rb: Updated 11 tests for simplified CSS generation
  - spec/services/post_renderer_spec.rb: Added file cleanup for callback handling
- Test results: **411 examples, 0 failures** ✅ (100% pass rate achieved)

### Fixed (PR #27)
- **custom_css Serialization**: Now properly included in API responses via theme_json
- **custom_css Validation**: Length limit (10000 chars) now enforced
- **custom_css Reset**: Now properly reset to nil by reset_to_defaults!
- **ThemeGenerator Tests**: Aligned with current simplified implementation
- **PostRenderer Test**: Fixed callback side effect in test setup

### Impact (PR #27)
- **Test Stability**: 100% test pass rate achieved (was 96% after PR #26)
- **API Completeness**: custom_css now fully functional in theme API
- **Maintainability**: All tests aligned with current implementations
- Net code reduction: 24 insertions, 33 deletions (removed obsolete tests)

---

## 2025-11-24 - Admin Form Enhancements, Bug Fixes, and Test Fixes

### Added (PR #26 - Theme Test Fixes)
- **Test Suite Improvements**: Fixed 51 test failures caused by Theme schema expansion migration
- **Updated Field Names**: Changed all test references from old to new field names:
  - `line_height` → `line_height_base`
  - `spacing_scale` → `spacing_unit`
  - `border_radius` → `radius_default`
- **Updated Validation Ranges**: Aligned test assertions with new field semantics
  - `line_height_base`: 1.0-2.5 (was 1.4-2.0)
  - `font_size_base`: 12-24 (unchanged)
  - `spacing_unit`: 0.25-10.0 (new range)
- **Updated CSS Variable Names**: Changed test assertions to match generated CSS
  - `--line-height` → `--line-height-base`
  - `--spacing-scale` → `--spacing-unit`
  - `--border-radius` → `--radius-default`
  - `--container-width` → `--container-max`

### Changed (PR #26)
- Modified 3 test files (273 lines changed):
  - spec/models/theme_spec.rb: Default values, validations, removed obsolete field tests
  - spec/routes/theme_spec.rb: API endpoint tests with new field names
  - spec/services/theme_generator_spec.rb: Theme.new() calls, CSS assertions, removed obsolete helper tests
- Test results: 411 examples, 16 failures (down from 67)

### Removed (PR #26)
- Tests for deleted Theme fields: `layout_style`, `header_style`, `footer_style`
- Tests for obsolete helper methods: `container_width_px`, `border_radius_px`

### Impact (PR #26)
- **Test Stability**: 76% of failing tests now pass (51 out of 67 fixed)
- **Test Suite Health**: Improved from 368 passing to 395 passing tests
- **Remaining Work**: 16 failures fixed in PR #27

---

## 2025-11-24 - Admin Form Enhancements and Bug Fixes

### Added (PR #25 - Quill Content Validation Hotfix)
- **Quill Text-Change Event Listeners**: Added native 'text-change' event listeners to both Quill editors
  - initQuill() for posts content validation (public/js/admin.js lines 149-155)
  - initPageQuill() for pages content validation (public/js/admin.js lines 767-773)
- **Hybrid Validation Pattern**: Listeners mark field as touched on first change, then validate on subsequent changes
- 16 lines added to admin.js

### Fixed (PR #25)
- **Content Validation Bug**: "Content is required" error no longer persists after adding content to Quill editor
- Posts and pages can now be saved when valid content is present
- Validation behaves consistently across all form fields (title, slug, content)

### Added (PR #24 - Confirmation Dialogs)
- **Enhanced Confirmation Dialogs**: Multi-line native confirm() dialogs for destructive actions
  - Posts deletion: "This action cannot be undone" message
  - Pages deletion without children: Same enhanced warning
  - Pages deletion with children: CASCADE WARNING with child count
- **Client-Side Child Counting**: Uses array filter to count child pages before deletion
- **Proper Grammar Handling**: Singular/plural formatting for child page counts

### Changed (PR #24)
- Modified deletePost() method in admin.js (5 lines)
- Modified deletePage() method in admin.js (17 lines)
- Total: 22 lines modified in public/js/admin.js

### Added (PR #23 - Admin Form Validation)
- **Comprehensive Client-Side Validation**: Alpine.js validation for all admin forms
  - Posts form: 3 fields (title, slug, content)
  - Pages form: 4 fields (title, slug, content, parent_id)
  - Settings form: 12 fields (site_title, site_tagline, contact_email, etc.)
- **Validation Infrastructure** (public/js/admin.js - 350+ lines):
  - validationErrors reactive state (post, page, settings)
  - touchedFields tracking with JavaScript Sets
  - validatePost(), validatePage(), validateSettings() methods
  - markTouched() helper method
  - clearValidationErrors() helper method
  - validateField() for individual field validation
  - checkSlugUniqueness() with debouncing (1 second) and caching
- **HTML Validation Bindings** (admin/index.html - 275+ lines):
  - Validation summary banners with error counts and clickable error links
  - Field-level @blur and @input bindings for hybrid validation timing
  - Red/green border feedback using :class bindings
  - Error message displays below each field
  - Save button disabled state when validation errors exist
- **Backend Slug Filtering**: API endpoints filter out current record when checking slug uniqueness (cms.rb)
- **Hybrid Validation Timing**: No validation on fresh fields → validate on blur → real-time after touched
- **Debounced Slug Uniqueness**: 1-second debounce with caching to reduce API calls
- **Graceful Error Handling**: Network errors during slug checks don't block saving
- Testing checklist created: docs/TESTING_CHECKLIST.md

### Changed (PR #23)
- Total: 625+ lines added, 13 lines modified across 3 files
- 12 commits merged to main
- Test count: 427 → 435 examples

### Impact
- **PR #25**: Fixes critical blocker preventing posts/pages from being saved
- **PR #24**: Prevents accidental data loss with clear deletion warnings
- **PR #23**: Prevents invalid submissions, provides immediate user feedback, reduces server load, improves UX

---

## 2025-11-23 - Service Error Handling

### Added
- **Error Handling in Service Classes**: Comprehensive error handling for all 4 service classes
  - PostRenderer: try/catch for file write/delete operations
  - PageRenderer: try/catch for file write/delete operations
  - FeedGenerator: try/catch for RSS and Atom feed generation
  - ThemeGenerator: try/catch for CSS generation and file write
- **Logger Integration**: All services use Logger.new(STDOUT) for structured error logging
- **Error Logging**: Detailed error messages with full stack traces on failure
- **Boolean Return Values**: Services return true/false for success/failure instead of raising exceptions
- **31 Error Scenario Tests**: Comprehensive test coverage for all error paths
  - PostRenderer: 10 error handling tests
  - PageRenderer: 9 error handling tests (new test file created)
  - FeedGenerator: 7 error handling tests
  - ThemeGenerator: 5 error handling tests

### Changed
- FeedGenerator.write_feeds now attempts both RSS and Atom writes even if one fails
- Split FeedGenerator into write_rss_feed and write_atom_feed private methods
- All service methods now log success messages on completion
- ThemeGenerator.generate_and_write returns nil on error (was raising exception)

### Technical Details
- Error handling pattern: begin/rescue/end blocks with structured logging
- Logger outputs to STDOUT for visibility in production logs
- Tests use instance_double(Logger) for mock verification
- All error tests verify both return values and log messages
- Total test count: 396 → 427 examples (31 new tests, all passing)

---

## 2025-11-22 - Theme Customization Complete

### Added
- **Theme Model**: Singleton theme model with 40+ configurable fields across 8 semantic categories
- **ThemeConfig Module**: Centralized field definitions and metadata (382 lines)
- **ThemeGenerator Service**: CSS generation with custom properties
- **Theme API**: GET, PUT, POST reset, GET preview endpoints
- **Admin UI**: Theme tab with color pickers and category organization
- **Tailwind v4 Integration**: CDN with @theme directive support
- Theme CSS auto-generated at `public/css/theme.css`
- Two migrations for theme tables (create + expand fields)
- Comprehensive tests for theme model, routes, and service

### Changed
- **Tailwind CSS**: Switched from standalone CLI to v4 CDN with @theme directive
- No CSS build step required anymore
- Admin interface path: `/admin/index.html` → `/admin/`
- Total test count: 252 → 396 examples (all passing)

### Technical Details
- Theme system uses semantic color naming (primary, accent, etc.)
- CSS custom properties for browser-side theming
- Auto-regeneration of theme.css and static HTML on save
- Granular controls approach (not pre-built themes)

---

## 2025-11-18 - Critical Fixes

### Fixed
- Feed route tests updated for dynamic generation (was expecting static files)
- Test expectations now match dynamic routes `/feed/rss` and `/feed/atom`
- Legacy feed URLs (`/feed.xml`, `/atom.xml`) now correctly test for redirects instead of 404s

### Added
- Foreign key constraint on `pages.parent_id` → `pages.id`
- Circular reference validation in Page model
- Database-level orphan prevention for pages
- Tests for foreign key constraint behavior (3 tests)
- Tests for circular reference prevention (3 tests)

### Changed
- Pages table now enforces referential integrity at database level
- Parent pages with children cannot be deleted via direct SQL (on_delete: :restrict)
- ActiveRecord `dependent: :destroy` still cascades deletes through the model layer
- Feed tests restructured to test dynamic generation and legacy redirects separately

### Performance
- **N+1 Query Optimization**: `Page#ancestors` method now uses recursive CTE (Common Table Expression)
- Query complexity reduced from O(n) to O(1) for hierarchy depth
- Single database query loads all ancestors regardless of nesting level
- Performance test added verifying single-query execution (spec/models/page_spec.rb:328)
- SQLite 3.8.3+ required for recursive CTE support

### Technical Details
- Migration `20251118030929_add_foreign_key_to_pages.rb` cleans up orphaned references before adding constraint
- Page model validation prevents circular hierarchies (self-parent or ancestor-as-child)
- Total test count increased from 246 to 252 examples (all passing)
