# Changelog

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

### Technical Details
- Migration `20251118030929_add_foreign_key_to_pages.rb` cleans up orphaned references before adding constraint
- Page model validation prevents circular hierarchies (self-parent or ancestor-as-child)
- Total test count increased from 246 to 252 examples (all passing)
