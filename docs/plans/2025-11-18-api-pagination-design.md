# API Pagination Design

**Date:** 2025-11-18
**Status:** Approved
**Priority:** High (Task 6)

## Overview

Add offset/limit pagination to `/api/posts` and `/api/pages` endpoints to follow REST best practices and future-proof the API as the content library grows.

## Goals

- Prevent API responses from becoming unwieldy as content grows
- Follow REST API best practices
- Provide clear pagination metadata to API consumers
- Maintain consistent behavior across all list endpoints

## Non-Goals

- Cursor-based pagination (offset/limit is sufficient for CMS use case)
- Backward compatibility (breaking change accepted)
- Pagination for single-item endpoints like `/api/posts/:id`

## Design Decisions

### Pagination Pattern: Offset/Limit

**Chosen approach:** Traditional offset/limit pagination (`?limit=20&offset=40`)

**Why:**
- Simple and familiar to API consumers
- Fits CMS use case (stable content, not real-time feed)
- Easier to implement page-based navigation
- Industry standard for REST APIs

**Rejected alternatives:**
- Cursor-based pagination: Too complex for relatively stable CMS content
- Page numbers (`?page=2`): Less flexible than offset, requires calculating offsets

### Default Values

- **Default limit:** 20 items
- **Maximum limit:** 100 items
- **Default offset:** 0

**Rationale:** 20 is a common API default (used by GitHub, GitLab) and works well for both mobile and desktop clients. 100 max prevents abuse while allowing bulk operations.

### Response Format

**Structure:**
```json
{
  "posts": [...],
  "pagination": {
    "total": 156,
    "limit": 20,
    "offset": 0,
    "count": 20
  }
}
```

**Fields:**
- `total`: Total items available (respects filters like `published`)
- `limit`: Limit applied to this request
- `offset`: Offset applied to this request
- `count`: Actual items returned (may be less than limit on last page)

**Why this format:**
- Self-documenting (all info in response body)
- Easier for consumers than HTTP headers
- Common pattern in modern REST APIs

### Breaking Change Strategy

**Decision:** Make pagination mandatory (breaking change)

**Why:**
- Forces API consumers to handle pagination properly from the start
- Simpler implementation (no conditional logic)
- Cleaner API design

**Impact:**
- Existing API consumers expecting all posts/pages will get only first 20
- Response structure changes (adds `pagination` wrapper)
- Admin UI needs updates

## Implementation Plan

### 1. Core API Changes

**Affected endpoints:**
- `GET /api/posts`
- `GET /api/pages`

**Parameters:**
- `limit` (optional, integer, default: 20, max: 100)
- `offset` (optional, integer, default: 0)

**Implementation:**
```ruby
# Parse and validate params
limit = [[params[:limit].to_i, 1].max, 100].min
limit = 20 if limit == 0  # default when not provided
offset = [params[:offset].to_i, 0].max

# Apply to query
posts = Post.published.recent.limit(limit).offset(offset)
total = Post.published.count

# Return with pagination metadata
json({
  posts: posts.map { |p| post_json(p) },
  pagination: {
    total: total,
    limit: limit,
    offset: offset,
    count: posts.length
  }
})
```

### 2. Filter Interaction

Pagination applies AFTER filtering:

- `GET /api/posts?include_drafts=true&limit=10` - First 10 of all posts (authenticated)
- `GET /api/posts?limit=10` - First 10 published posts (public)
- `GET /api/pages?top_level=true&limit=5` - First 5 top-level published pages

Total count reflects the filtered dataset, not all records.

### 3. Input Validation

**Strategy:** Fail gracefully, use sensible defaults

- Non-numeric values → Use defaults (limit: 20, offset: 0)
- `limit < 1` → Use default (20)
- `limit > 100` → Clamp to 100
- `offset < 0` → Treat as 0
- No HTTP errors for bad pagination params

**Edge cases:**
- Offset beyond total → Empty array, `count: 0`, but accurate `total`
- No items in database → `total: 0, count: 0, posts: []`

### 4. Admin UI Updates

**Current behavior:** Admin loads all posts/pages on startup

**New behavior:** Show first 20 items with "Load More" button

**Implementation approach:**
- Initial load: `GET /api/posts?limit=20`
- "Load More" button: Increment offset by 20, append results
- Disable button when `offset + count >= total`

**Why not load all:**
- Simpler implementation than infinite scroll
- Good enough for typical admin use (most blogs have < 100 posts)
- Can optimize later if needed

### 5. Testing

**New tests in `spec/routes/posts_spec.rb` and `spec/routes/pages_spec.rb`:**

Pagination behavior:
- Default pagination (no params) returns first 20 items with metadata
- Custom limit: `?limit=5` returns 5 items
- Custom offset: `?limit=5&offset=10` skips first 10
- Max limit enforced: `?limit=500` clamped to 100
- Invalid params use defaults: `?limit=-5`, `?offset=-10`
- Empty results: `?offset=999` returns `[]` with correct total
- Works with filters: `?include_drafts=true&limit=10`, `?top_level=true&limit=5`

Response structure:
- Response includes both data array and `pagination` object
- `pagination.count` matches actual array length
- `pagination.total` matches database count (after filters)

Edge cases:
- Offset beyond total
- Zero items in database
- Non-numeric parameter values

### 6. Documentation Updates

Update `CLAUDE.md` API documentation:

```markdown
### Pagination

All list endpoints support pagination via `limit` and `offset` query parameters.

**Parameters:**
- `limit` (optional, default: 20, max: 100) - Number of items to return
- `offset` (optional, default: 0) - Number of items to skip

**Response format:**
All paginated endpoints return:
{
  "posts": [...],  // or "pages"
  "pagination": {
    "total": 156,   // Total items available
    "limit": 20,    // Limit applied
    "offset": 0,    // Offset applied
    "count": 20     // Actual items returned
  }
}

**Examples:**
- `GET /api/posts` - First 20 published posts
- `GET /api/posts?limit=10` - First 10 published posts
- `GET /api/posts?limit=10&offset=20` - Posts 21-30
- `GET /api/posts?include_drafts=true&limit=50` - First 50 posts (all statuses, auth required)
- `GET /api/pages?top_level=true&limit=5` - First 5 top-level pages
```

## Testing Strategy

**Unit tests:** Verify parameter parsing and validation logic
**Integration tests:** Test full request/response cycle with database
**Edge case tests:** Invalid inputs, empty results, boundary conditions
**Regression tests:** Ensure existing filters (published, top_level, include_drafts) still work

**Target:** All existing tests pass + 15-20 new pagination tests

## Migration Notes

**Breaking changes:**
1. Response structure now includes `pagination` metadata
2. Endpoints return max 20 items by default (previously returned all)

**Migration steps:**
1. Update backend API routes
2. Update admin UI to handle pagination
3. Update tests
4. Update documentation
5. Deploy and verify in production

**Rollback plan:** Revert commit, no database changes required

## Success Criteria

- All list endpoints support `limit` and `offset` parameters
- Response includes accurate pagination metadata
- Admin UI can load and display paginated content
- All tests pass (existing + new pagination tests)
- Documentation updated
- No performance regression (pagination should improve response times for large datasets)

## Future Enhancements

**Not included in this design (can add later):**
- Pagination helpers in response (next_offset, prev_offset, has_more)
- Link headers (RFC 5988) for rel="next", rel="prev"
- Pagination for single-resource child collections (e.g., `/api/pages/:id/children`)
- Server-side caching of total counts for performance
- Cursor-based pagination if real-time consistency becomes important
