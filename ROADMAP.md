# v7cms Development Roadmap

**Last Updated:** 2025-11-22
**Total Pending Tasks:** 11 (9 fixes + 2 features)
**Estimated Effort:** ~14.75 hours

This roadmap provides a prioritized view of all pending work with clear next steps for developers and AI agents.

## Quick Start

**For Humans:** Scan the priority sections below to find work that matches your time and skills.

**For Claude:** Use this as your primary task selection guide. Each task includes status, priority, dependencies, and links to detailed implementation plans. When in doubt, start with Critical Priority items.

## Documentation Map

- **ROADMAP.md** (this file) - Prioritized task list with dependencies
- **PROJECT_STATUS.md** - Current project state and navigation guide
- **NEXT_STEPS.md** - Feature roadmap (7 priorities, 5 completed)
- **CLAUDE.md** - Comprehensive project documentation for development
- **README.md** - User-facing documentation and API reference
- **CHANGELOG.md** - History of completed work
- **docs/plans/** - Detailed implementation plans for specific tasks

---

## Critical Priority

**Status:** 0 pending tasks

All critical issues resolved. Monitor production for new critical bugs.

---

## High Priority

**Status:** 3 pending tasks | **Estimated Effort:** ~3.25 hours

### Task: Fix N+1 Query in Page#ancestors
**Priority:** High | **Status:** Pending | **Estimate:** 45min | **Dependencies:** None
**Plan:** [High Priority Fixes - Task 5](docs/plans/2025-11-17-high-priority-fixes.md#task-5)

**Problem:** Page model loads parents one-by-one causing N+1 database queries.

**Solution:** Use recursive CTE (Common Table Expression) for single-query ancestor loading.

**Impact:** Query reduction from O(n) to O(1) for hierarchy depth.

**⚠️ Decision:** Verify SQLite version supports recursive CTEs (3.8.3+) or use batch loading fallback.

---

### Task: Add Error Handling to Service Classes
**Priority:** High | **Status:** Pending | **Estimate:** 1.5 hours | **Dependencies:** None
**Plan:** [High Priority Fixes - Task 7](docs/plans/2025-11-17-high-priority-fixes.md#task-7)

**Problem:** PostRenderer, PageRenderer, FeedGenerator have no error handling for file I/O operations.

**Solution:** Add try/catch blocks, logging with Logger, return boolean success/failure.

**Impact:** Better debugging, prevents silent failures in production.

---

### Task: Fix Hierarchical Page File Path Collisions
**Priority:** High | **Status:** Pending | **Estimate:** 1 hour | **Dependencies:** None
**Plan:** [High Priority Fixes - Task 8](docs/plans/2025-11-17-high-priority-fixes.md#task-8)

**Problem:** Pages with same slug but different parents overwrite each other's static files.

**Solution:** Use full hierarchical path (e.g., `public/pages/grandparent/parent/child.html`).

**Impact:** Prevents file collisions, proper nested directory structure.

---

## Medium Priority

**Status:** 5 pending tasks | **Estimated Effort:** ~5.75 hours

### Task: Add Form Validation to Admin UI
**Priority:** Medium | **Status:** Pending | **Estimate:** 1.5 hours | **Dependencies:** None
**Plan:** [Medium Priority Improvements - Task 9](docs/plans/2025-11-17-medium-priority-fixes.md#task-9)

**Problem:** Admin forms submit without client-side validation, causing server errors.

**Solution:** Alpine.js validation with real-time feedback for posts, pages, settings.

**Impact:** Better UX, fewer API errors, prevents invalid data submission.

---

### Task: Add Confirmation Dialogs for Destructive Actions
**Priority:** Medium | **Status:** Pending | **Estimate:** 30min | **Dependencies:** None
**Plan:** [Medium Priority Improvements - Task 10](docs/plans/2025-11-17-medium-priority-fixes.md#task-10)

**Problem:** Delete buttons immediately delete without confirmation.

**Solution:** Confirmation dialogs with item title, special warnings for parent pages with children.

**Impact:** Prevents accidental data loss.

---

### Task: Cache Setting.instance Results
**Priority:** Medium | **Status:** Pending | **Estimate:** 45min | **Dependencies:** None
**Plan:** [Medium Priority Improvements - Task 11](docs/plans/2025-11-17-medium-priority-fixes.md#task-11)

**Problem:** Setting.instance hits database on every call despite rare changes.

**Solution:** In-memory cache with Mutex for thread safety, auto-clear on updates.

**Impact:** Query reduction from O(n) to O(1) for setting access.

---

### Task: Add API Documentation with OpenAPI
**Priority:** Medium | **Status:** Pending | **Estimate:** 2 hours | **Dependencies:** None
**Plan:** [Medium Priority Improvements - Task 12](docs/plans/2025-11-17-medium-priority-fixes.md#task-12)

**Problem:** API endpoints lack formal documentation for developers.

**Solution:** OpenAPI 3.0 spec + Swagger UI at `/api/docs` with interactive testing.

**Impact:** Better developer experience, reduces support questions.

---

### Task: Add Rate Limiting Middleware
**Priority:** Medium | **Status:** Pending | **Estimate:** 1 hour | **Dependencies:** None
**Plan:** [Medium Priority Improvements - Task 13](docs/plans/2025-11-17-medium-priority-fixes.md#task-13)

**Problem:** API endpoints vulnerable to abuse and DoS attacks.

**Solution:** Rack::Attack middleware with IP-based limits (100 general, 20 writes, 5 logins per minute).

**Impact:** Security hardening against automated attacks.

---

## Feature Development

**Status:** 2 pending features | **Estimated Effort:** ~5+ hours

### Feature: Commenting System (Priority 5)
**Priority:** Medium | **Status:** Design Phase | **Estimate:** 5-8 hours | **Dependencies:** None
**Plan:** [NEXT_STEPS.md - Priority 5](NEXT_STEPS.md#priority-5-commenting-system)

**⚠️ Decision Required:** Choose between self-hosted (custom Rails-style, Isso, Commento) vs third-party (utterances, giscus, Disqus). See investigation phase in NEXT_STEPS.md.

---

### Feature: Static Asset Management (Priority 7)
**Priority:** Low | **Status:** Planning | **Estimate:** 6-10 hours | **Dependencies:** None
**Plan:** [NEXT_STEPS.md - Priority 7](NEXT_STEPS.md#priority-7-static-asset-management--recovery)

**Scope:** Image uploads, file management UI, storage strategy, .htaccess routing for assets.

---

## Recently Completed

### ✅ Theme Customization (Priority 6)
**Completed:** 2025-11-22 | **Effort:** ~8 hours
40+ configurable fields across 8 semantic categories, Tailwind v4 CDN integration, auto-generated theme.css.

### ✅ API Pagination
**Completed:** 2025-11-21 | **Effort:** 1 hour
Added limit/offset pagination to Posts and Pages endpoints with metadata responses.

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

**See [DEPLOYMENT.txt](DEPLOYMENT.txt) for maintenance procedures.**
