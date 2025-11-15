# v7cms - Project Status & Navigation Guide

**Last Updated**: 2025-11-15

This document provides a quick overview of project status and guides you to the right documentation.

---

## 🎯 Current Status: **Production-Ready Base Implementation**

The v7cms core is **complete and deployed** on shared hosting (DreamHost). The application is fully functional with OAuth authentication, blog post management, and a working admin interface.

---

## 📊 What's Complete

### ✅ Core Application (Phases 1-8)
- **Backend**: Ruby 3.2 + Sinatra framework with SQLite database
- **Models**: User (OAuth), Post (with auto-slugs), Setting (singleton)
- **Authentication**: OAuth 2.0 via OmniAuth (Google, GitHub)
- **API**: RESTful JSON API for posts and settings CRUD with authentication
- **Admin Interface**: Single-page app (Alpine.js + Quill.js WYSIWYG editor + Tailwind CSS)
- **Public Site**: ERB templates for homepage and individual post pages
- **Testing**: 177 RSpec tests (models, routes, helpers, services)
- **Deployment**: FastCGI on shared hosting with Apache .htaccess routing
- **Security**:
  - .htaccess rules blocking sensitive files (.rb, .db, .env, config/, etc.)
  - Session-based authentication
  - CSRF protection (Rack::Protection)
  - ModSecurity workarounds (email-only OAuth scope)
  - Cache control headers to prevent stale content
- **Settings Management**:
  - 14 configurable settings across 6 categories
  - Admin UI for editing all site text and display options
  - API endpoints for settings CRUD
  - Singleton pattern for single settings record
  - Comprehensive validation (email, URL, numeric ranges)
  - JavaScript-based admin link injection (static-site ready)
- **Static HTML Generation** (2025-11-14):
  - PostRenderer service generates standalone HTML files
  - Automatic generation via ActiveRecord callbacks
  - Files saved to public/posts/{slug}.html
  - Apache serves static files directly (bypass Ruby)
  - Rake tasks for bulk regeneration, verification, cleanup
  - 1-hour browser cache for static files
  - 28 new tests (22 service + 6 model callback tests)
- **RSS and Atom Feeds** (2025-11-15):
  - FeedGenerator service creates RSS 2.0 and Atom feeds
  - Dynamically generated at /feed/rss and /feed/atom
  - Includes 20 most recent published posts
  - Feed discovery links in HTML head
  - Automatic updates via ActiveRecord callbacks on Post and Setting
  - Rake task for manual regeneration
  - 41 new tests for feed generation service

### ✅ Production Deployment Features
- OAuth callback working in production
- Admin interface at `/admin/`
- Posts API fully functional
- Static assets served correctly
- Security hardening complete
- Cache control preventing browser caching issues

---

## 📁 Documentation Map

### For Understanding the Project
**→ `CLAUDE.md`** - Comprehensive project documentation
- Architecture overview
- Stack details (backend, frontend, request flow)
- File structure and key files
- Development commands (Docker & local)
- Testing instructions
- API documentation
- Configuration guide
- Deployment instructions
- Common issues and solutions
- Code style guidelines

### For Implementation History
**→ `IMPLEMENTATION_PLAN.md`** - Original 8-phase build plan
- **Status**: ✅ ALL PHASES COMPLETE (1-8)
- Foundation, database, OAuth, API, Tailwind, admin, public site, deployment
- This document is now **historical reference only**
- Shows how we got to current state
- Useful for understanding architecture decisions

### For Future Development
**→ `NEXT_STEPS.md`** - Roadmap for future features
- **Status**: 🎯 ACTIVE DEVELOPMENT ROADMAP
- 7 priority levels with detailed implementation plans
- Start here for new features:
  1. Settings Management (customize site text via admin)
  2. Static HTML Generation (posts as static files)
  3. RSS Feed Generation
  4. Pages & Hierarchical Content
  5. Commenting System
  6. Theme Customization
  7. Static Asset Management
- Each priority includes:
  - Clear goals
  - Design decisions to make
  - Task checklists
  - Files to create/modify
  - Technical considerations
- Also includes "Future Enhancements" (lower priority ideas)

### For Current Status
**→ `PROJECT_STATUS.md`** (this file)
- Quick overview of what's done and what's next
- Navigation guide to other documentation
- Git workflow reminders

---

## 🚀 Quick Start for New Claude Code Sessions

### "What should I work on next?"
1. Open **`NEXT_STEPS.md`**
2. Start with **Priority 2: Static HTML Generation**
3. Follow the task checklist in that section

### "How does this project work?"
1. Read **`CLAUDE.md`** - Project Overview and Architecture sections
2. Review **`app/cms.rb`** - Main application file
3. Check **`IMPLEMENTATION_PLAN.md`** to see how it was built

### "How do I test/deploy/develop?"
- **`CLAUDE.md`** has all commands under:
  - "Development Commands" section
  - "Testing" section
  - "Deployment" section

### "What's the tech stack?"
- **Backend**: Ruby 3.2, Sinatra 3.0, SQLite, ActiveRecord, OmniAuth
- **Frontend**: Alpine.js, Quill.js, Tailwind CSS (CDN)
- **Deployment**: FastCGI on Apache (shared hosting)
- **Testing**: RSpec with Rack::Test and DatabaseCleaner

---

## 🌳 Git Workflow

### Current Branch
- **Main branch**: `main`
- **Current working branch**: `base-implementation`

### Recommended Workflow for New Features
```bash
# Start new feature
git checkout main
git pull origin main
git checkout -b feature/settings-management

# Work on feature (commit often)
git add .
git commit -m "Add settings table and model"

# When complete and tested
bundle exec rspec  # All tests must pass
git checkout main
git merge feature/settings-management
git push origin main

# Deploy to production
# (git push triggers deployment or manual FTP/rsync)
```

### Commit Message Style
Follow existing pattern (see recent commits):
- Clear, descriptive subject line
- Explain "why" not just "what"

---

## 📂 Key Directories & Files

### Application Code
```
app/
  cms.rb                    # Main Sinatra application (routes, config)
  models/
    user.rb                 # OAuth user model
    post.rb                 # Blog post model
  helpers/
    auth_helper.rb          # Authentication helpers
  views/
    layout.erb              # Site layout template
    index.erb               # Homepage (post list)
    post.erb                # Single post view
    404.erb                 # Not found page
```

### Configuration
```
config.ru                   # Rack configuration
Rakefile                    # Database tasks
config/
  database.yml              # Database config (dev/test/prod)
.env                        # Environment variables (gitignored)
.env.example                # Template for .env
```

### Frontend
```
admin/
  index.html                # Admin SPA
public/
  js/
    admin.js                # Admin app logic (Alpine.js)
  css/
    input.css               # Tailwind input
    output.css              # Generated CSS (gitignored)
```

### Database
```
db/
  migrate/                  # ActiveRecord migrations
  seed.rb                   # Seed data script
  cms.db                    # SQLite database (gitignored)
```

### Testing
```
spec/
  models/                   # Model tests
  routes/                   # Route/integration tests
  helpers/                  # Helper tests
  spec_helper.rb            # RSpec configuration
```

### Deployment
```
index.fcgi                  # FastCGI entry point
.htaccess                   # Apache routing and security
setup.php                   # Production setup script (shebang fix)
bin/
  add_admin                 # Script to manually add admin user
```

---

## 🎯 Immediate Next Steps (Recommended)

### Step 1: Pages & Hierarchical Content ⬅️ **NEXT**
**File**: `NEXT_STEPS.md` → Priority 4

Support static pages (About, Contact, etc.) with parent-child relationships, separate from blog posts.

**Why this second?**
- Builds on static generation patterns
- Common CMS feature
- Enables full site management

**Estimated effort**: 4-6 hours

### Step 2: Commenting System
**File**: `NEXT_STEPS.md` → Priority 5

Enable user engagement through comments (needs decision: self-hosted vs third-party).

**Estimated effort**: 1-8 hours (depending on approach)

---

## 🔍 Common Tasks

### Add a new model
1. Create migration: `bundle exec rake db:create_migration NAME=create_things`
2. Edit migration file in `db/migrate/`
3. Run migration: `bundle exec rake db:migrate`
4. Create model: `app/models/thing.rb`
5. Write tests: `spec/models/thing_spec.rb`
6. Run tests: `bundle exec rspec spec/models/thing_spec.rb`

### Add a new API endpoint
1. Add route in `app/cms.rb`
2. Write test in `spec/routes/things_spec.rb`
3. Run tests: `bundle exec rspec spec/routes/things_spec.rb`
4. Manual test with curl or browser

### Add a new admin UI section
1. Update `admin/index.html` - add HTML structure
2. Update `public/js/admin.js` - add Alpine.js logic
3. Test in browser at `http://localhost:9292/admin/`

### Deploy to production
1. Commit and push changes to git
2. SSH/FTP to server
3. Pull latest code: `git pull origin main`
4. Run migrations: `RACK_ENV=production bundle exec rake db:migrate`
5. Restart FastCGI (varies by host, often automatic)
6. Test in browser at production URL

---

## ⚠️ Important Notes

### OAuth Configuration
- Credentials in `.env` (gitignored)
- Production callback URLs must be registered in Google/GitHub OAuth apps
- Google OAuth uses `email` scope only (not `profile`) to avoid ModSecurity blocking

### Database
- SQLite in `db/cms.db` (gitignored)
- All environments (dev/test/prod) use the same cms.db file
- Migrations in `db/migrate/`
- Always run migrations in test env: `RACK_ENV=test bundle exec rake db:migrate`

### Tailwind CSS
- Currently using **CDN** (not CLI) due to memory limits on shared hosting
- For local dev: Use CLI with `--watch` flag
- For production: CDN link in templates (already configured)

### Security
- `.htaccess` blocks access to `.rb`, `.db`, `.env`, `config/`, `app/`, etc.
- Session secret must be strong in production
- CSRF protection enabled (except for OAuth routes)
- Never commit secrets to git

### Testing
- Run all tests before deploying: `bundle exec rspec`
- Current count: 177 tests
- Test coverage: models, routes, helpers, services
- Always write tests for new features

### Static Files
- Static HTML files auto-generated for published posts
- Located in `public/posts/{slug}.html`
- Use `rake posts:regenerate_all` after deployment to rebuild all files
- Use `rake posts:verify` to check for missing files

---

## 🐛 Troubleshooting

### "Where do I start?"
→ Read this file, then `NEXT_STEPS.md` Priority 1

### "How does [feature] work?"
→ Check `CLAUDE.md` for architecture details

### "What's the original implementation plan?"
→ See `IMPLEMENTATION_PLAN.md` (historical reference)

### "Tests are failing"
→ Make sure test database is migrated: `RACK_ENV=test bundle exec rake db:migrate`

### "OAuth isn't working"
→ Check `.env` has correct credentials and callback URLs match OAuth app settings

### "Can't see my changes in production"
→ Browser cache issue - headers in `.htaccess` should prevent this now

### "Static files not being served"
→ Check `.htaccess` routing rules and file permissions

---

## 📞 Getting Help

- **GitHub Issues**: Report bugs at project repo
- **Documentation**: `CLAUDE.md` has troubleshooting section
- **Common Issues**: See `CLAUDE.md` → "Common Issues" section

---

**Quick Links:**
- 📖 Project Docs: `CLAUDE.md`
- 🏗️ Implementation History: `IMPLEMENTATION_PLAN.md`
- 🎯 Future Roadmap: `NEXT_STEPS.md`
- 📍 You Are Here: `PROJECT_STATUS.md`
