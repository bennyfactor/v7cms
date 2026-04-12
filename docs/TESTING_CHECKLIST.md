# Release QA Checklist

## Automated Tests

- [ ] `bundle exec rspec` -- all 1,213 examples pass
- [ ] `bundle exec brakeman` -- no new warnings
- [ ] `bundle exec bundle-audit` -- no known vulnerabilities

## Manual Smoke Tests

- [ ] Start server (`bundle exec rackup -p 9292` or `docker-compose up`)
- [ ] Homepage loads with correct layout and theme
- [ ] Admin login via OAuth (Google or GitHub)
- [ ] Create a new post, verify it appears on homepage
- [ ] Edit a post, verify changes persist
- [ ] Delete a post, verify removal
- [ ] Static HTML generated at `public/posts/<slug>/index.html`
- [ ] Create/edit/delete a page, verify static HTML at `public/pages/<slug>/index.html`
- [ ] RSS feed (`/feed/rss`) and Atom feed (`/feed/atom`) render correctly
- [ ] Submit a comment, verify it appears in moderation queue
- [ ] Theme changes apply to public site
- [ ] Settings changes apply (site title, etc.)

## Deployment Verification

- [ ] Health check: `GET /health` returns 200
- [ ] Static files served directly by web server
- [ ] OAuth callback redirects work with production URLs
- [ ] `.htaccess` rules block access to `.env`, `.db`, `.rb` files
- [ ] Uploaded assets accessible via `/uploads/` path

## Pre-Release Checks

- [ ] Version bumped in `lib/v7cms/version.rb`
- [ ] CHANGELOG.md updated with new version entry
- [ ] CI green on all checks
- [ ] No uncommitted changes on release branch
