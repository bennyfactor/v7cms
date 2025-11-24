# Changelog

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
