# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commit Message Policy

**IMPORTANT**: Never mention Claude, Claude Code, AI assistance, or include any attribution to AI tools in commit messages. Commit messages should be written as if created directly by the human developer.

- Do NOT include "Generated with Claude Code" text
- Do NOT include "Co-Authored-By: Claude" attribution
- Do NOT use emojis like 🤖 to indicate AI assistance
- Write commit messages in first person from the developer's perspective
- Focus on what changed and why, without mentioning the tools used to make the change
- Keep commit messages professional and tool-agnostic

## Feature Branch Workflow

**IMPORTANT**: When completing a feature branch, do NOT automatically merge to main. Instead:

1. Push the feature branch to GitHub: `git push origin feature/feature-name`
2. Offer to create a pull request on GitHub for the user to review and merge
3. Let the user decide when to merge to main
4. This allows for code review, CI checks, and controlled deployments

**Never** run `git merge` or `git checkout main && git merge` without explicit user instruction.

## Project Overview

v7cms is a modern, minimal content management system built with Ruby 3.2 and Sinatra. It features OAuth authentication, a RESTful API, and a single-page admin interface built with Alpine.js and Tailwind CSS. The application is designed to run on shared hosting (DreamHost) via FastCGI or containerized with Docker for development/deployment.

## Architecture

### Backend Stack
- **Framework**: Sinatra 3.0 (lightweight Ruby web framework)
- **Database**: SQLite with ActiveRecord ORM
- **Authentication**: OmniAuth 2.1 (Google OAuth2, GitHub)
- **Testing**: RSpec with Rack::Test and DatabaseCleaner

### Frontend Stack
- **Admin Interface**: Alpine.js (7kB reactive framework) + Quill.js (WYSIWYG editor)
- **Styling**: Tailwind CSS v4 Standalone CLI (no Node.js required)
- **Public Site**: ERB templates with Tailwind styling

### Request Flow
1. **Public Routes** (`GET /`, `GET /posts/:slug`) - Render ERB templates
2. **API Routes** (`/api/*`) - JSON REST API for posts management
3. **Auth Routes** (`/auth/*`) - OmniAuth OAuth flows
4. **Static Assets** - Served from `/public` directory

## Project Structure

```
app/
  cms.rb                 # Main Sinatra application
  models/                # ActiveRecord models
    user.rb              # OAuth user model
    post.rb              # Blog post model with slug generation
    setting.rb           # Singleton settings model
  helpers/               # Helper modules
    auth_helper.rb       # Authentication helpers (current_user, logged_in?, require_login)
  views/                 # ERB templates for public site
    layout.erb           # Site layout
    index.erb            # Homepage
    post.erb             # Single post view
    404.erb              # Not found page
config/
  database.yml           # Database configuration (dev/test/prod)
db/
  migrate/               # ActiveRecord migrations
  seed.rb                # Sample data generator
public/
  admin.html             # Admin SPA
  js/admin.js            # Admin application logic
  css/
    input.css            # Tailwind input
    output.css           # Generated CSS (gitignored)
spec/                    # RSpec test suite (57 tests)
  models/                # Model tests
  routes/                # Route/integration tests
  helpers/               # Helper tests
bin/
  tailwindcss            # Tailwind CLI binary (gitignored)
```

## Key Files

### app/cms.rb (Main Application)
- **Lines 1-7**: Requires (Sinatra, ActiveRecord, OmniAuth, etc.)
- **Lines 9-30**: App configuration (database, sessions, static files)
- **Lines 32-57**: OmniAuth configuration (Google, GitHub)
- **Lines 59-86**: Public site routes (homepage, single post, 404)
- **Lines 88-127**: API routes (health, auth status, logout)
- **Lines 129-172**: Posts API (CRUD endpoints, authentication required)
- **Lines 220-237**: Helper methods (json, post_json)

### app/models/post.rb
- Auto-generates URL-friendly slugs from titles
- Validations: title, slug (unique)
- Scopes: `published`, `recent`
- Slug generation handles special characters and unicode

### app/models/setting.rb
- Singleton pattern (only one settings record exists)
- 14 configurable fields across 6 categories:
  - Site Identity: site_title, site_tagline, site_author
  - Homepage Content: welcome_title, welcome_subtitle
  - Footer: footer_text, show_copyright_year
  - SEO/Meta: meta_description, meta_keywords
  - Contact/Social: contact_email, github_url, social_url
  - Display Options: posts_per_page, date_format
- Comprehensive validations:
  - Email format (URI::MailTo::EMAIL_REGEXP)
  - URL format (regex validation)
  - String length limits
  - Numeric ranges (posts_per_page: 1-100)
- Methods:
  - `Setting.instance` - returns singleton record (creates if needed)
  - `Setting.get(key)` - convenience method for getting values
  - `reset_to_defaults!` - resets all fields to default values

### app/models/user.rb
- OAuth user model (email, provider, uid, avatar_url)
- `from_omniauth` class method for OAuth callback
- Unique constraint on provider+uid

### public/admin.html
- Single-page admin application
- Alpine.js reactive data binding
- Quill.js WYSIWYG editor integration
- OAuth login flow
- Posts CRUD interface
- Settings management tab with 6-section form

## Development Commands

### Docker (Recommended)

```bash
# Start development server
docker-compose up -d

# Run migrations
docker-compose run --rm web bundle exec rake db:migrate

# Run tests
docker-compose run --rm web bundle exec rspec

# Seed sample data
docker-compose run --rm web bundle exec ruby db/seed.rb

# View logs
docker-compose logs -f web

# Stop server
docker-compose down
```

### Local Development

```bash
# Install dependencies
bundle install

# Run migrations
bundle exec rake db:migrate

# Build Tailwind CSS
./bin/tailwindcss -i public/css/input.css -o public/css/output.css --minify

# Start server
bundle exec rackup -p 9292

# Run tests
bundle exec rspec

# Watch Tailwind for changes (development)
./bin/tailwindcss -i public/css/input.css -o public/css/output.css --watch
```

## Testing

The application has comprehensive test coverage (108 tests):

```bash
# All tests
bundle exec rspec

# Specific test file
bundle exec rspec spec/routes/posts_spec.rb

# With documentation format
bundle exec rspec --format documentation

# Test specific line
bundle exec rspec spec/routes/posts_spec.rb:25
```

Test organization:
- `spec/models/` - Model validations, associations, scopes (User, Post, Setting)
- `spec/routes/` - API endpoints, OAuth flows, public routes (Posts, Settings, Auth)
- `spec/helpers/` - Authentication helpers

## Database

### Migrations

```bash
# Create migration
bundle exec rake db:create_migration NAME=add_something

# Run migrations (development)
bundle exec rake db:migrate

# Run migrations (test)
RACK_ENV=test bundle exec rake db:migrate

# Rollback
bundle exec rake db:rollback
```

### Schema
- **users**: id, email, name, provider, uid, avatar_url, timestamps
- **posts**: id, title, slug (unique), content, published (boolean), timestamps
- **settings**: id, site_title, site_tagline, site_author, welcome_title, welcome_subtitle, footer_text, show_copyright_year, meta_description, meta_keywords, contact_email, github_url, social_url, posts_per_page, date_format, timestamps (singleton: only one record)

## API Documentation

### Authentication (OmniAuth)
- `GET /auth/google_oauth2` - Google OAuth flow
- `GET /auth/github` - GitHub OAuth flow
- `GET /auth/:provider/callback` - OAuth callback
- `POST /api/auth/logout` - Logout
- `GET /api/auth/me` - Current user info

### Posts API
- `GET /api/posts` - List published posts
- `GET /api/posts?include_drafts=true` - All posts (auth required)
- `GET /api/posts/:id` - Get post by ID or slug
- `POST /api/posts` - Create post (auth required)
- `PUT /api/posts/:id` - Update post (auth required)
- `DELETE /api/posts/:id` - Delete post (auth required)

### Settings API
- `GET /api/settings` - Get current settings (public)
- `PUT /api/settings` - Update settings (auth required)
- `POST /api/settings/reset` - Reset to defaults (auth required)

## Configuration

### Environment Variables (.env)
```bash
SESSION_SECRET=<random-string>
GOOGLE_CLIENT_ID=<google-oauth-client-id>
GOOGLE_CLIENT_SECRET=<google-oauth-secret>
GITHUB_CLIENT_ID=<github-oauth-client-id>
GITHUB_CLIENT_SECRET=<github-oauth-secret>
RACK_ENV=development|test|production
```

### OAuth Setup
- Google: https://console.cloud.google.com/ (OAuth 2.0 credentials)
- GitHub: https://github.com/settings/developers (OAuth Apps)

## Deployment

### Docker Deployment
The application is Docker-ready. Use `docker-compose.yml` for deployment with volume mounts for data persistence.

### Shared Hosting (FastCGI)
1. Uncomment `fcgi` gem in Gemfile
2. Upload files via FTP/git
3. Run `bundle install --deployment`
4. Configure `.htaccess` for URL rewriting
5. Set environment variables on hosting panel
6. Run `RACK_ENV=production bundle exec rake db:migrate`

## Security Notes
- CSRF protection enabled (Rack::Protection::AuthenticityToken)
- SQL injection prevention via ActiveRecord parameterized queries
- XSS protection via Rack::Protection
- Session secrets must be strong in production
- OAuth credentials never committed to git (.env in .gitignore)

## Common Issues

### Issue: FCGI gem won't compile in development
**Solution**: Comment out `fcgi` gem - only needed for production FastCGI deployment

### Issue: Tailwind CSS not updating
**Solution**: Rebuild CSS with `./bin/tailwindcss -i public/css/input.css -o public/css/output.css --minify`

### Issue: OmniAuth "uninitialized constant"
**Solution**: Ensure `require 'omniauth'` is before `use OmniAuth::Builder` in cms.rb

### Issue: Tests failing "table not found"
**Solution**: Run `RACK_ENV=test bundle exec rake db:migrate`

## Code Style
- Use 2 spaces for indentation
- Follow Ruby community style guide
- Write tests before implementation (TDD)
- Keep routes organized by function (public, auth, API)
- Use descriptive variable names
- Comment complex logic

## Performance Notes
- SQLite suitable for small-medium traffic sites
- For high traffic, consider PostgreSQL/MySQL
- Tailwind CSS is pre-built (no runtime overhead)
- Alpine.js is only 7kB minified
- FastCGI persistent processes reduce startup overhead

## Browser Support
- Modern browsers (Chrome, Firefox, Safari, Edge)
- Admin interface requires JavaScript
- Public site works without JavaScript (progressive enhancement)

## Design Documents and Planning

**IMPORTANT**: Never commit files in `docs/plans/` directory. Design documents created during brainstorming sessions should be preserved in this CLAUDE.md file for future reference, not committed as separate planning documents.

### Theme Customization Feature Design (Priority 6)

**Status**: Design Complete - Ready for Implementation
**Date**: 2025-11-21
**Estimated Effort**: 8-12 hours

**Overview**: Add comprehensive theme customization with 19 configurable fields (colors, typography, layout, spacing) via admin interface with live split-view preview.

**Key Decisions**:
- Separate Theme model (not extending Settings)
- Granular controls approach (not pre-built themes)
- Hybrid CSS generation (static theme.css + inline preview)
- Professional split-view UI (form 40%, preview iframe 60%)

**Database Schema** - New `themes` table (singleton pattern):
- 8 color fields (primary, secondary, background, text, heading, link, link_hover, border)
- 4 typography fields (font_heading, font_body, font_size_base, line_height)
- 4 layout fields (layout_width, layout_style, spacing_scale, border_radius)
- 3 advanced fields (custom_css, header_style, footer_style)

**Services**:
- ThemeGenerator (`app/services/theme_generator.rb`) - Generates CSS with custom properties, writes to `public/css/theme.css`

**API Endpoints**:
- GET /api/theme - Retrieve current theme (public)
- PUT /api/theme - Update theme (auth required, regenerates CSS and static files)
- POST /api/theme/reset - Reset to defaults (auth required)
- GET /api/theme/preview - Preview endpoint for iframe with query params (public, temporary)

**Admin UI**:
- Left panel (40%): Tabbed form (Colors, Typography, Layout, Advanced) with save/reset/export buttons
- Right panel (60%): Live preview iframe with page selector (home/post/page)
- Debounced updates (500ms) to prevent excessive iframe reloads
- Alpine.js reactive data binding

**Integration**:
- Theme model callbacks regenerate theme.css and all static HTML files on save
- Layout.erb includes theme.css after Tailwind
- Conditional Google Fonts loading when custom fonts selected
- PostRenderer and PageRenderer automatically pick up theme changes

**Implementation Phases**:
1. Backend (2-3h): Migration, Theme model, ThemeGenerator service, tests
2. API Endpoints (2-3h): 4 routes, validation, tests
3. Static Integration (1-2h): Update layout.erb, callbacks, verify regeneration
4. Admin UI Form (2-3h): Split-view layout, tabbed form, save/reset logic
5. Live Preview (1-2h): Iframe integration, debounced watching, page selector

**Testing**: 75+ new tests (40 model, 15 service, 20 route)

**Files to Create**: Migration, theme.rb, theme_generator.rb, 3 test files, public/css/theme.css (gitignored)

**Files to Modify**: cms.rb (+80 lines routes), layout.erb (+8 lines), admin/index.html (+200 lines), admin.js (+250 lines), .gitignore, seed.rb
