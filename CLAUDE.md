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

## Hidden Directories — Never Commit

**IMPORTANT**: Never commit directories or files starting with `.` (dot) to the repository. The `.gitignore` has a blanket `.*` rule for this. Hidden directories like `.claude/`, `.beads/`, `.dolt/`, `.superpowers/`, `.env`, etc. contain local tooling state, credentials, or agent configuration that must stay local. Treat them like private keys — if they accidentally get committed, they must be purged from history with `git filter-repo`.

## Feature Branch Workflow

**IMPORTANT**: When completing a feature branch, do NOT automatically merge to main. Instead:

1. Push the feature branch to GitHub: `git push origin feature/feature-name`
2. Offer to create a pull request on GitHub for the user to review and merge
3. Let the user decide when to merge to main
4. This allows for code review, CI checks, and controlled deployments

**Never** run `git merge` or `git checkout main && git merge` without explicit user instruction.

## Project Overview

v7cms is a modern, minimal content management system built with Ruby 3.4 and Sinatra. It features OAuth authentication, a RESTful API, a single-page admin interface built with Alpine.js and Tailwind CSS, and self-hosted commenting with reCAPTCHA v3 spam prevention. The application is designed to run on shared hosting (DreamHost) via FastCGI or containerized with Docker for development/deployment.

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
  config/                # Application configuration
    theme_fields.rb      # Theme field definitions (ThemeConfig module)
  docs/                  # OpenAPI/Swagger documentation
    api_docs.rb          # Main documentation entry point
    swagger_root.rb      # Swagger root configuration
    paths/               # API endpoint documentation
    schemas/             # JSON schema definitions
  helpers/               # Helper modules
    auth_helper.rb       # Authentication helpers (current_user, logged_in?, require_login)
  models/                # ActiveRecord models
    comment.rb           # Comment model with moderation/spam fields
    page.rb              # Static page model with slug generation
    post.rb              # Blog post model with slug generation
    setting.rb           # Singleton settings model
    theme.rb             # Singleton theme model for CSS customization
    user.rb              # OAuth user model with admin flag
  services/              # Business logic services
    feed_generator.rb    # RSS/Atom feed generation
    page_renderer.rb     # Static HTML generation for pages
    post_renderer.rb     # Static HTML generation for posts
    theme_generator.rb   # CSS generation from theme settings
  views/                 # ERB templates for public site
    layout.erb           # Site layout
    index.erb            # Homepage
    post.erb             # Single post view
    page.erb             # Static page view
    404.erb              # Not found page
config/
  database.yml           # Database configuration (dev/test/prod)
db/
  migrate/               # ActiveRecord migrations
  seed.rb                # Sample data generator
public/
  admin/index.html       # Admin SPA
  js/admin.js            # Admin application logic
  css/
    input.css            # Tailwind input
    output.css           # Generated CSS (gitignored)
    theme.css            # Generated theme CSS (gitignored)
spec/                    # RSpec test suite (1217 tests)
  models/                # Model tests
  routes/                # Route/integration tests
  services/              # Service tests
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
- OAuth user model (email, provider, uid, avatar_url, admin)
- `admin` boolean field controls admin panel access
- `from_omniauth` class method for OAuth callback
- Unique constraint on provider+uid
- Admin access validated against ADMIN_EMAILS environment variable at login

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

The application has comprehensive test coverage (1217 tests):

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
- **users**: id, email, name, provider, uid, avatar_url, admin (boolean), last_login_at, timestamps
- **posts**: id, title, slug (unique), content, published (boolean), comments_enabled (boolean), timestamps
- **pages**: id, title, slug (unique), content, published (boolean), page_type, content_source, items_limit, hero_image_url, parent_id (FK), position, timestamps
- **settings**: singleton with 16 fields (site_title, site_tagline, site_author, welcome_title, welcome_subtitle, footer_text, show_copyright_year, meta_description, meta_keywords, contact_email, github_url, social_url, posts_per_page, date_format, allow_comments, timestamps)
- **themes**: singleton with 40+ fields for colors, typography, spacing, shadows, and custom CSS
- **comments**: id, post_id (FK), author_name, author_email, author_url, content, ip_address, recaptcha_score, approved (boolean), spam (boolean), timestamps
- **content_versions**: id, versionable_type, versionable_id (polymorphic), version_number, title, content, created_by_id, version_type (auto/manual), note, timestamps
- **uploads**: id, filename, content_type, file_size, file_path, alt_text, timestamps

## API Documentation

Interactive API documentation available at `/api/docs` (Swagger UI).

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

### Pages API
- `GET /api/pages` - List published pages
- `GET /api/pages?include_drafts=true` - All pages (auth required)
- `GET /api/pages/:id` - Get page by ID or slug
- `POST /api/pages` - Create page (auth required)
- `PUT /api/pages/:id` - Update page (auth required)
- `DELETE /api/pages/:id` - Delete page (auth required)

### Comments API
- `GET /api/posts/:post_id/comments` - List approved comments for a post
- `GET /api/posts/:post_id/comments?include_pending=true` - All comments (auth required)
- `POST /api/posts/:post_id/comments` - Submit comment (public, requires reCAPTCHA)
- `PUT /api/comments/:id` - Moderate comment (auth required)
- `DELETE /api/comments/:id` - Delete comment (auth required)

### Users API
- `GET /api/users` - List all users (auth required)
- `PUT /api/users/:id` - Update user admin status (auth required)

### Settings API
- `GET /api/settings` - Get current settings (public)
- `PUT /api/settings` - Update settings (auth required)
- `POST /api/settings/reset` - Reset to defaults (auth required)

### Theme API
- `GET /api/theme` - Get current theme settings (public)
- `PUT /api/theme` - Update theme (auth required, regenerates CSS)
- `POST /api/theme/reset` - Reset to defaults (auth required)
- `GET /api/theme/preview` - Preview theme with query params (public)

### Feeds
- `GET /feed/rss` - RSS 2.0 feed
- `GET /feed/atom` - Atom feed

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

### Completed Features

The following major features have been implemented:

- **Theme Customization** (2025-11-21): 40+ configurable CSS properties via admin UI with live preview. Uses singleton Theme model and ThemeGenerator service.
- **User Management** (2025-11-28): Admin can view all users and toggle admin privileges. Includes last_login tracking and safety guards (cannot revoke own admin).
- **Page Hero Images** (2025-12-06): Optional hero_image_url field for pages. Displays as banner on page view and as thumbnails in grid layout cards (portfolio, blog_grid, hero_grid, magazine). Admin UI includes URL field with live preview.
- **Blog Post Layouts** (2025-12-08): Selectable post layout templates (standard, minimal). Admin UI includes layout picker in post editor and settings.
- **Image/Asset Uploads** (2025-12-26): Upload API with file serving and optional transformations. Media Library modal for editor image insertion. Assets tab in admin UI with upload/browse/delete.
- **Content History** (2025-12-30): Hybrid versioning system for posts and pages. Versionable concern with auto-versioning on save. Version list, restore, and compare API endpoints. Admin UI version history panel with diff viewer.
- **CI/CD Enhancements** (2025-12-30): Prerelease gem builds on PRs, MegaLinter integration. Prerelease gems published to GitHub Packages for testing before merge.
- **Static HTML Directory Index** (2026-04-12): Static HTML files now written as `slug/index.html` instead of `slug.html`. Apache serves published posts/pages directly via RewriteCond file-existence checks, bypassing FCGI cold-start. Pages support nested slugs.
- **Conditional reCAPTCHA** (2026-04-12): reCAPTCHA script and comment form only load when `comments_enabled` and `allow_comments` are both true. Eliminates 401 errors and badge on posts with comments disabled.
- **Documentation Reorganization** (2026-04-12): README rewritten to ~1KB. Detailed content moved to docs/: INSTALLATION.md, API.md, ARCHITECTURE.md, THEME.md, TROUBLESHOOTING.md. All docs updated for accuracy (correct rake tasks, gem version, static HTML paths).
- **reCAPTCHA Blank Token Guard** (2026-04-13): `verify_recaptcha_v3` short-circuits on blank token when reCAPTCHA is configured, returning 0.0 without making a wasteful HTTP call to Google. Closes #76.


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
