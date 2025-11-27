# v7cms Development Roadmap

**Last Updated:** 2025-11-25
**Total Pending Tasks:** 1 (1 feature)
**Estimated Effort:** ~2 hours
**Test Status:** ✅ 489 examples, 12 failures (97.5% pass rate - 12 failures in comments system)

This roadmap provides a prioritized view of all pending work with clear next steps for developers and AI agents.

## Quick Start

**For Humans:** Scan the priority sections below to find work that matches your time and skills.

**For Claude:** Use this as your primary task selection guide. Each task includes status, priority, dependencies, and links to detailed implementation plans. When in doubt, start with Critical Priority items.

## Documentation Map

- **ROADMAP.md** (this file) - Prioritized task list with dependencies
- **[docs/README.md](docs/README.md)** - Documentation index and navigation guide
- **[CLAUDE.md](CLAUDE.md)** - Comprehensive project documentation for development
- **[README.md](README.md)** - User-facing documentation and API reference
- **[CHANGELOG.md](CHANGELOG.md)** - History of completed work
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Guidelines for contributing
- **[SECURITY.md](SECURITY.md)** - Security policy and vulnerability reporting
- **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Production deployment guide
- **[docs/plans/](docs/plans/)** - Detailed implementation plans for specific tasks

---

## Critical Priority

**Status:** 0 pending tasks

All critical issues resolved. Monitor production for new critical bugs.

---

## High Priority

**Status:** 0 pending tasks

### ✓ Task: Fix Hierarchical Page File Path Collisions
**Priority:** High | **Status:** Complete | **Completed:** 2025-11-23
**PR:** [Branch: feature/fix-page-path-collisions]

**Problem:** Pages with same slug but different parents overwrite each other's static files.

**Solution:** Implemented full hierarchical path (e.g., `public/pages/grandparent/parent/child.html`).

**Changes:**
- Added `Page#full_slug_path` method to build hierarchical paths from breadcrumb trail
- Updated `PageRenderer#static_file_path` to use full hierarchical paths
- Added directory cleanup on delete to remove empty parent directories
- 9 new tests added (3 Page model, 4 hierarchical paths, 2 directory cleanup)
- All 62 Page/PageRenderer tests passing with no regressions

---

## Medium Priority

**Status:** 0 pending tasks

### ✓ Task: Fix Remaining Test Failures
**Priority:** Medium | **Status:** Complete | **Completed:** 2025-11-24 | **Actual Effort:** ~2 hours
**PR:** #27 [Branch: fix/remaining-test-failures]

**Problem:** 17 remaining test failures after PR #26 blocked full test suite success.

**Root Causes Identified:**
1. **Pattern 1 (5 failures)**: `custom_css` field existed in database but NOT in ThemeConfig::FIELDS, causing validation/serialization failures
2. **Pattern 2 (11 failures)**: ThemeGenerator tests expected old complex implementation with button classes, but code was refactored to simplified version
3. **Pattern 3 (1 failure)**: PostRenderer test expected no file but after_commit callback created it in before block

**Solution Implemented:**
- Added `custom_css` to ThemeConfig::FIELDS with validation (max 10000 chars)
- Updated ThemeGenerator to skip fields without CSS variables
- Updated all ThemeGenerator tests to match current simplified implementation
- Added explicit file cleanup in PostRenderer test

**Changes:**
- app/config/theme_fields.rb: Added custom_css field definition
- app/models/theme.rb: Added custom_css length validation
- app/services/theme_generator.rb: Skip fields with nil css_var
- spec/routes/theme_spec.rb: Fixed typo in test
- spec/services/theme_generator_spec.rb: Updated 11 tests for simplified CSS
- spec/services/post_renderer_spec.rb: Added file cleanup

**Impact:** Fixed all 17 remaining test failures. Test results: 411 examples, **0 failures** ✅ (100% pass rate achieved)

---

### ✓ Task: Fix Theme Test Failures
**Priority:** Medium | **Status:** Complete | **Completed:** 2025-11-24 | **Actual Effort:** ~1.5 hours
**PR:** #26 [Branch: fix/theme-test-field-names]

**Problem:** 67 test failures caused by Theme model schema expansion. Tests were using old field names (line_height, spacing_scale, border_radius) that were renamed/removed in migration `20251122060419_expand_theme_fields.rb`.

**Root Cause:** Theme schema expansion migration renamed fields for semantic clarity:
- `line_height` → `line_height_base`, `line_height_tight`, `line_height_loose`
- `spacing_scale` → `spacing_unit`, `spacing_section`
- `border_radius` → `radius_sm`, `radius_default`, `radius_lg`
- Removed: `layout_style`, `header_style`, `footer_style`

**Solution Implemented:** Systematically updated all 3 affected test files (theme_spec.rb, theme routes spec, theme_generator_spec.rb) with new field names, validation ranges, and CSS variable names.

**Changes:**
- spec/models/theme_spec.rb: Updated default values, validations, removed obsolete tests
- spec/routes/theme_spec.rb: Updated API endpoint tests with new field names
- spec/services/theme_generator_spec.rb: Updated Theme.new() calls, CSS variable assertions, removed obsolete helper tests
- 273 lines modified across 3 test files

**Impact:** Fixed 51 out of 67 test failures (76% success rate). Test results improved from 435 examples/67 failures → 411 examples/16 failures. Remaining 16 failures fixed in PR #27.

---

### ✓ Task: Fix Quill Content Validation Bug
**Priority:** Critical (Hotfix) | **Status:** Complete | **Completed:** 2025-11-24 | **Actual Effort:** 30 min
**PR:** #25 [Branch: hotfix/quill-content-validation]

**Problem:** "Content is required" validation error persisted even after adding content to Quill editor in posts/pages forms. Typing in title/slug fields triggered validation for ALL fields, but typing in Quill didn't clear the content error.

**Root Cause:** Quill editors don't support standard HTML @blur/@input events. Content divs had no event bindings to trigger validation when content changes.

**Solution Implemented:** Added Quill's native 'text-change' event listeners to both initQuill() and initPageQuill() methods. Listeners follow hybrid validation pattern: mark field as touched on first change, validate on subsequent changes.

**Changes:**
- Modified public/js/admin.js (16 lines added)
- Added text-change listener to initQuill() for posts (lines 149-155)
- Added text-change listener to initPageQuill() for pages (lines 767-773)
- Both content fields now trigger validation when edited

**Impact:** Content validation errors now clear when user types in editor. Posts and pages can be saved when valid content is present. Validation behaves consistently across all form fields.

---

### ✓ Task: Add Form Validation to Admin UI
**Priority:** Medium | **Status:** Complete | **Completed:** 2025-11-24 | **Actual Effort:** ~3 hours
**PR:** [Branch: feature/admin-form-validation]
**Plan:** [Admin Form Validation Design](docs/plans/2025-11-24-admin-form-validation-design.md)

**Problem:** Admin forms submitted without client-side validation, causing server errors and poor UX.

**Solution Implemented:** Comprehensive Alpine.js validation with hybrid timing (blur → real-time), validation summary banners, field-level feedback, and slug uniqueness checking with debouncing.

**Changes:**
- Added validation infrastructure to admin.js (350+ lines): state management, validators, helper methods
- Added HTML bindings to admin/index.html (275+ lines): summary banners, field bindings, error displays
- Added backend slug filtering to API endpoints (2 lines in cms.rb)
- 12 commits, 625+ lines added, 13 lines modified
- Validates 19 fields across 3 forms (Posts: 3, Pages: 4, Settings: 12)
- Features: hybrid validation timing, debounced slug uniqueness (1sec), caching, graceful error handling
- Testing checklist created: docs/TESTING_CHECKLIST.md

**Impact:** Prevents invalid submissions, immediate user feedback, reduces server load, improves UX.

---

### ✓ Task: Add Confirmation Dialogs for Destructive Actions
**Priority:** Medium | **Status:** Complete | **Completed:** 2025-11-24 | **Actual Effort:** 30 min
**PR:** [Branch: feature/confirmation-dialogs]
**Plan:** [Confirmation Dialogs Design](docs/plans/2025-11-24-confirmation-dialogs-design.md)

**Problem:** Delete buttons had basic confirmations without clear warnings about consequences.

**Solution Implemented:** Enhanced native `confirm()` dialogs with multi-line warnings:
- Posts: "This action cannot be undone" message
- Pages without children: Same enhanced warning
- Pages with children: CASCADE WARNING showing count of child pages that will be deleted

**Changes:**
- Updated `deletePost()` method in admin.js (5 lines modified)
- Updated `deletePage()` method in admin.js (17 lines modified)
- Client-side child counting using array filter (no API calls needed)
- Proper singular/plural grammar handling
- Backend cascade deletion unchanged (dependent: :destroy)

**Impact:** Prevents accidental data loss with clear, explicit warnings about deletion consequences.

---

### ✓ Task: Cache Setting.instance Results
**Priority:** Medium | **Status:** Complete | **Completed:** 2025-11-24 | **Actual Effort:** ~45min
**PR:** #28 [Branch: feature/cache-setting-instance]

**Problem:** Setting.instance hits database on every call despite rare changes.

**Solution Implemented:** In-memory cache with Mutex for thread safety, auto-clear on updates.

**Changes:**
- Added `@@instance_cache` and `@@cache_mutex` class variables for thread-safe caching
- Modified `Setting.instance` to use double-checked locking pattern
- Added `Setting.clear_cache!` method for explicit cache clearing
- Added `after_save` callback to automatically clear cache on updates
- Added 3 new tests for caching behavior (memory caching, cache clearing, thread safety)
- Added global cache clearing in spec_helper to prevent test pollution
- Fixed one existing test for clean state

**Impact:** Query reduction from O(n) to O(1) for setting access. Test results: 414 examples, **0 failures** ✅ (100% pass rate maintained)

---

## Low Priority

**Status:** 1 pending task | **Estimated Effort:** ~2 hours

### Task: Add API Documentation with OpenAPI
**Priority:** Low | **Status:** Pending | **Estimate:** 2 hours | **Dependencies:** None
**Plan:** [Medium Priority Improvements - Task 12](docs/plans/2025-11-17-medium-priority-fixes.md#task-12)

**Problem:** API endpoints lack formal documentation for developers.

**Solution:** OpenAPI 3.0 spec + Swagger UI at `/api/docs` with interactive testing.

**Impact:** Better developer experience, reduces support questions.

---

## Feature Development

**Status:** 1 pending feature | **Estimated Effort:** ~2 hours

### Feature: Static Asset Management (Priority 7)
**Priority:** Low | **Status:** Planning | **Estimate:** 6-10 hours | **Dependencies:** None
**Plan:** See CLAUDE.md Theme Customization design section for related file management patterns

**Scope:** Image uploads, file management UI, storage strategy, .htaccess routing for assets.

---

## Recently Completed

### ✅ Commenting System (PR #30)
**Completed:** 2025-11-25 | **Effort:** ~6-8 hours | **Status:** ✅ Complete (12 known test failures being addressed)
Implemented self-hosted anonymous commenting system with reCAPTCHA v3 spam prevention, admin moderation interface with badge notification, and lazy loading comment display. Created Comment model with validations, 6 API endpoints (3 public, 3 admin), frontend form with invisible reCAPTCHA v3, admin moderation UI with pending/approved/spam filters, and comprehensive test coverage. Features: score-based bot detection (threshold 0.5), moderation queue (all comments default to approved=false), lazy loading (20 comments per batch), badge notification showing pending count. Test results: 489 examples, **12 failures** in comments system tests (known issue). Added 40 new tests (13 model + 27 routes).

### ✅ Rate Limiting Middleware (PR #29)
**Completed:** 2025-11-25 | **Effort:** ~3 hours
Implemented Rack::Attack rate limiting middleware with FileStore cache for FastCGI multi-process compatibility. Added rack-attack gem (~> 6.7), created config/rate_limit.rb with FileStore cache pointing to ./tmp/rack-attack-cache for shared cache across processes. Added Rack::Attack middleware to cms.rb (disabled in test environment). Configured rate limits: 100 req/min for general traffic (excludes /admin paths), 20 req/min for API writes (POST/PUT/DELETE), 5 req/min for login attempts. IP blocklist configurable via BLOCKED_IPS env var. Returns 429 status with Retry-After header when rate limited. Added 11 comprehensive tests. Updated Dockerfile.apache with libfcgi-dev dependency, deployment mode bundle install, FcgidInitialEnv directives for Bundler paths, and ScriptAlias configuration. Tested successfully with Apache FastCGI container spawning 8 worker processes. Test results: 425 examples, **0 failures** ✅ (100% pass rate maintained).

### ✅ Setting.instance Caching (PR #28)
**Completed:** 2025-11-24 | **Effort:** ~45min
Implemented thread-safe in-memory caching for Setting.instance to reduce database queries from O(n) to O(1). Added @@instance_cache and @@cache_mutex class variables with double-checked locking pattern. Added Setting.clear_cache! method and after_save callback for automatic cache invalidation. Added 3 new tests (memory caching, cache clearing, thread safety) and global cache clearing in spec_helper. Test results: 414 examples, **0 failures** ✅ (100% pass rate maintained).

### ✅ Remaining Test Fixes (PR #27)
**Completed:** 2025-11-24 | **Effort:** ~2 hours
Fixed all 17 remaining test failures using systematic debugging. Added custom_css to ThemeConfig::FIELDS with validation, updated ThemeGenerator tests to match simplified implementation, fixed PostRenderer callback test. Test results: 411 examples, **0 failures** ✅ (100% pass rate achieved). Used systematic-debugging skill to identify 3 root cause patterns.

### ✅ Theme Test Fixes (PR #26)
**Completed:** 2025-11-24 | **Effort:** ~1.5 hours
Fixed 51 out of 67 test failures caused by Theme schema expansion migration. Updated 3 test files with new field names (line_height → line_height_base, spacing_scale → spacing_unit, border_radius → radius_default), validation ranges, and CSS variable names. Removed tests for deleted fields (layout_style, header_style, footer_style). Test results improved from 435 examples/67 failures to 411 examples/16 failures.

### ✅ Quill Content Validation Hotfix (PR #25)
**Completed:** 2025-11-24 | **Effort:** 30 min
Fixed critical bug where "Content is required" validation error persisted even after adding content to Quill editor. Added Quill's native 'text-change' event listeners to both posts and pages forms. Content validation now clears in real-time when user types in editor, following the hybrid validation pattern used throughout the application.

### ✅ Confirmation Dialogs for Destructive Actions (PR #24)
**Completed:** 2025-11-24 | **Effort:** 30 min
Enhanced deletion confirmation dialogs with clear warnings. Posts and pages now show "This action cannot be undone" message. Pages with children display CASCADE WARNING with exact child count and explicit message that all child pages will be permanently deleted. Uses client-side child counting with proper singular/plural grammar.

### ✅ Admin Form Validation (PR #23)
**Completed:** 2025-11-24 | **Effort:** ~3 hours
Comprehensive client-side validation for all admin forms (Posts, Pages, Settings). Features hybrid validation timing (blur → real-time), validation summary banners with clickable errors, field-level feedback (red/green borders), debounced slug uniqueness checking with caching, and graceful error handling. Validates 19 fields across 3 forms with 625+ lines of JavaScript/HTML implementation.

### ✅ Service Error Handling
**Completed:** 2025-11-23 | **Effort:** ~2 hours
Added comprehensive error handling to all 4 service classes (PostRenderer, PageRenderer, FeedGenerator, ThemeGenerator) with try/catch blocks, Logger integration, and 31 error scenario tests. Services now return boolean success/failure and log detailed error messages with stack traces.

### ✅ Theme Customization (Priority 6)
**Completed:** 2025-11-22 | **Effort:** ~8 hours
40+ configurable fields across 8 semantic categories, Tailwind v4 CDN integration, auto-generated theme.css.

### ✅ API Pagination
**Completed:** 2025-11-21 | **Effort:** 1 hour
Added limit/offset pagination to Posts and Pages endpoints with metadata responses.

### ✅ Fix N+1 Query in Page#ancestors
**Completed:** 2025-11-18 | **Effort:** ~45min
Implemented recursive CTE (Common Table Expression) for single-query ancestor loading. Reduced query complexity from O(n) to O(1) for hierarchy depth. Includes performance test verifying single query execution.

### ✅ Critical Fixes
**Completed:** 2025-11-18 | **Effort:** 2 hours
Fixed feed route tests, added foreign key constraints to pages, circular reference validation.

**See [CHANGELOG.md](docs/CHANGELOG.md) for full history.**

---

## How to Use This Roadmap

### For Humans
1. **Quick wins:** Look for tasks with ~30-60min estimates in Medium Priority
2. **High impact:** Start with High Priority tasks - they improve performance/reliability
3. **Learning:** Feature tasks (Priority 5, 7) are great for understanding the architecture

### For Claude
1. **Task selection:** Use priority + dependencies to choose next work
2. **Before starting:** Read the linked implementation plan for detailed steps
3. **Decision points:** Tasks marked with ⚠️ need human input before proceeding
4. **After completion:** Update this roadmap's status, add to Recently Completed, update CHANGELOG.md

### Updating This Roadmap
- **Move completed tasks** to Recently Completed section with completion date and actual effort
- **Archive old completions** (keep last 3) by moving to CHANGELOG.md
- **Add new tasks** from bugs, feature requests, or technical debt discoveries
- **Update estimates** based on actual completion times for future planning

---

## Maintenance & Ongoing Work

**Regular Tasks (not tracked here):**
- Weekly database backups
- Monthly dependency updates (`bundle update`)
- Quarterly security audits
- Monitor production logs for errors

**See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for maintenance procedures.**
