# Code Review Bug Fixes Design

**Date:** 2026-04-17
**Issues:** v7cms-75c, v7cms-c8u, v7cms-ap6, v7cms-ca9, v7cms-igu, v7cms-vyg

## Overview

Six issues identified during code review. All fixes ship in a single branch in priority order.

## 1. Vanity Page Routes (v7cms-75c)

**Problem:** `MenuItem#href` generates `/full_slug_path` (e.g., `/about`) but pages are only served at `/pages/*`. Menu links 404.

**Solution:** Keep `MenuItem#href` as-is. Add a catch-all route at the bottom of the Sinatra route stack:

```ruby
get '/*' do
  slug_path = params[:splat].first
  @page = V7CMS::Page.published.find_by(full_slug_path: slug_path)
  # render page or pass to 404
end
```

Sinatra matches routes top-down, so existing routes (`/posts`, `/api/*`, `/admin/*`, etc.) naturally take priority. The existing `/pages/*` route remains for backward compatibility.

## 2. Hierarchical Routing with Cached full_slug_path (v7cms-c8u)

**Problem:** Route resolution uses bare `slug` column. For hierarchical pages, the last-segment fallback is ambiguous when multiple pages share a leaf slug (e.g., `about/team` and `services/team`).

**Solution:** Add `full_slug_path` as a persisted database column.

### Database changes
- Add `full_slug_path` string column to pages table
- Add index on `full_slug_path` for fast lookups
- Backfill existing pages via migration data step

### Model changes
- Remove the computed `def full_slug_path` method (ActiveRecord column reader replaces it)
- Add `before_save` callback to compute `full_slug_path` from `breadcrumb_trail.map(&:slug).join('/')`

### Cascade updates
When a page's `slug` or `parent_id` changes, all descendants must have their `full_slug_path` recomputed. Add an `after_save` callback:

```ruby
after_save :cascade_full_slug_path, if: -> { saved_change_to_slug? || saved_change_to_parent_id? }

def cascade_full_slug_path
  children.each do |child|
    child.update_columns(full_slug_path: child.breadcrumb_trail.map(&:slug).join('/'))
    child.send(:cascade_full_slug_path)
  end
end
```

Use `update_columns` to skip callbacks on descendants (avoiding infinite loops) while still recursing to recompute the path from `breadcrumb_trail`.

### Route resolution
Both `/pages/*` and the catch-all use the same resolution logic via a shared helper:

```ruby
def resolve_page(slug_path)
  # Try exact full_slug_path match
  page = V7CMS::Page.published.find_by(full_slug_path: slug_path)
  return page if page

  # Only allow leaf-slug fallback for single-segment paths
  # Multi-segment paths must match full_slug_path exactly
  return nil if slug_path.include?('/')

  candidates = V7CMS::Page.published.where(slug: slug_path)
  candidates.size == 1 ? candidates.first : nil
end
```

## 3. Gitignore Patterns (v7cms-ca9)

**Problem:** `public/posts/*.html` doesn't match the current `slug/index.html` directory structure.

**Solution:** Change `public/posts/*.html` to `public/posts/**/*.html`.

## 4. reCAPTCHA Nil Fallback (v7cms-ap6)

**Problem:** The if/elsif in `verify_recaptcha_v3` can theoretically return nil if neither branch matches. Callers do `< 0.5` on the result, which would raise `NoMethodError`.

**Solution:** Add `else 0.0` after the `elsif`:

```ruby
if ENV['RECAPTCHA_PROJECT_ID'] && ENV['RECAPTCHA_API_KEY']
  verify_recaptcha_enterprise(token, remote_ip, action: action)
elsif ENV['RECAPTCHA_SECRET_KEY']
  verify_recaptcha_standard(token, remote_ip)
else
  0.0
end
```

## 5. Replace puts with Logger (v7cms-vyg)

**Problem:** 5 `puts` calls in `verify_recaptcha_v3`, `verify_recaptcha_enterprise`, and `verify_recaptcha_standard` bypass structured logging.

**Solution:** Add a `recaptcha_log` instance helper that uses Sinatra's built-in `logger` when available (during request handling) and falls back to `warn` when called outside request context (e.g., in tests via `CMS.new!`):

```ruby
def recaptcha_log(level, message)
  if respond_to?(:logger) && (log = begin; logger; rescue; nil; end)
    log.send(level, message)
  else
    warn "[#{level}] #{message}"
  end
end
```

Replace `puts` calls with appropriate log levels:
- `puts "reCAPTCHA not configured..."` -> `recaptcha_log(:info, ...)`
- `puts "reCAPTCHA Enterprise: invalid token..."` -> `recaptcha_log(:warn, ...)`
- `puts "reCAPTCHA Enterprise: action mismatch..."` -> `recaptcha_log(:warn, ...)`
- `puts "reCAPTCHA Enterprise verification error..."` -> `recaptcha_log(:error, ...)`
- `puts "reCAPTCHA verification error..."` -> `recaptcha_log(:error, ...)`

## 6. Integration Test for Blank reCAPTCHA Token (v7cms-igu)

**Problem:** Only unit tests exist for blank token handling (via `send(:verify_recaptcha_v3, ...)`). No integration test exercises the full request path.

**Solution:** Add integration test in `spec/routes/comments_spec.rb`:
- POST to `/api/posts/:id/comments` with `recaptcha_token: ""`
- Configure reCAPTCHA env vars (RECAPTCHA_SECRET_KEY) so the guard is active
- Assert 400 response with appropriate error message

## Testing Strategy

- Route resolution: test both `/pages/slug` and `/slug` vanity routes, including nested hierarchical paths and duplicate leaf slugs
- Cascade: test that renaming a parent page updates all descendants' `full_slug_path`
- Menu links: verify `MenuItem#href` resolves through vanity routes
- Existing test suite must remain green
