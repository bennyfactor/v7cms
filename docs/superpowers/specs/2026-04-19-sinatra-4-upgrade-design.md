# Sinatra 3.x → 4.x Upgrade Design

**Date:** 2026-04-19
**Issue:** v7cms-wcy

## Overview

Upgrade Sinatra from 3.2.0 to 4.x to fix the `URI::RFC3986_PARSER.unescape` deprecation warning on Ruby 3.4 and pick up Rack 3 support.

## 1. Gemfile Changes

- `sinatra '~> 3.0'` → `sinatra '~> 4.0'`
- Remove explicit `rack-protection '~> 3.0'` (bundled with Sinatra 4)
- `bundle update sinatra rack rack-protection`

All other Rack-dependent gems are already Rack 3 compatible (rack-attack 6.8.0, rack-test 2.2.0, omniauth 2.1.4, puma 6.6.1).

## 2. Fix Error Handler Response Access

**Problem:** `response['Content-Type']` and `response.body.join` in error handlers (lines 167, 182) use Rack 2 response API. Rack 3 changes response body from array to iterable.

**Fix:** Use Sinatra's `content_type` helper and handle body as either array or string:

```ruby
error 403 do
  if content_type&.include?('application/json')
    return response.body.is_a?(Array) ? response.body.join : response.body.to_s
  end
  # ... rest of handler
end
```

Same pattern for `error 500` handler.

## 3. Verify Multipart File Upload

`params[:file][:tempfile]` pattern (line 1630) needs testing with Rack 3's multipart handling. Existing file upload tests should catch breakage; add targeted test if none exists.

## 4. Verify find_template Override

Custom template lookup (lines 73-85) uses `super` with yield block. Full test suite covers template rendering. No preemptive changes — fix only if tests fail.

## 5. Host Authorization

Sinatra 4.1+ adds `host_authorization` security feature. Configure to match current permissive behavior:

```ruby
set :host_authorization, permitted_hosts: []
```

## 6. Testing

- Run full test suite after upgrade
- Specifically verify error handlers return correct responses for JSON and HTML
- Verify file upload still works
- Verify template rendering
- Confirm URI deprecation warning is gone
