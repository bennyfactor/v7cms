# v7cms

[![Ruby](https://img.shields.io/badge/Ruby-3.2-red?logo=ruby)](https://www.ruby-lang.org/)
[![Sinatra](https://img.shields.io/badge/Sinatra-3.0-lightgrey?logo=ruby)](https://sinatrarb.com/)
[![License: EUPL-1.2](https://img.shields.io/badge/License-EUPL--1.2-blue.svg)](https://opensource.org/licenses/EUPL-1.2)
[![Tests](https://img.shields.io/badge/Tests-848%20passing-brightgreen)](spec/)
[![RSpec](https://img.shields.io/badge/Tested%20with-RSpec-red?logo=ruby)](https://rspec.info/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

A minimal, hierarchical content management system built with Ruby and Sinatra. Features static HTML generation for maximum performance and runs on shared hosting via FastCGI or containerized with Docker.

## Features

**Content Management**
- Blog posts with rich text editing (Quill.js)
- Hierarchical static pages with parent/child relationships
- Draft and publish workflow
- Automatic URL slug generation
- RSS and Atom feed generation
- Content version history with restore and compare
- Image/asset uploads with media library

**Admin Interface**
- Single-page application with Alpine.js
- OAuth authentication (Google, GitHub)
- Email whitelist access control
- User management with admin privileges
- Comment moderation with spam detection
- Site settings customization
- Theme customization (40+ CSS properties)
- Selectable blog post layouts (standard, minimal)
- URL redirect management with .htaccess generation
- Gravatar integration for user avatars
- Assets tab with media library

**Performance**
- Static HTML generation for posts and pages
- Pre-built Tailwind CSS (no runtime overhead)
- Lightweight JavaScript (Alpine.js ~7kB)
- FastCGI support for shared hosting

**Developer Experience**
- RESTful JSON API with OpenAPI documentation
- Comprehensive test suite (848 tests)
- Docker development environment
- Rake tasks for common operations

## Quick Start

```bash
# Clone and start with Docker
git clone https://github.com/bennyfactor/v7cms.git
cd v7cms
cp .env.example .env
# Edit .env with your OAuth credentials
docker-compose up -d
docker-compose run --rm web bundle exec rake db:migrate

# Access the application
# Public site: http://localhost:9292
# Admin panel: http://localhost:9292/admin/
```

## Requirements

- Ruby 3.0+
- SQLite3 (or PostgreSQL/MySQL)
- Docker (optional, for development)

## Installation

### As a Gem (Recommended for New Projects)

Add v7cms to your Gemfile:

```ruby
source 'https://rubygems.pkg.github.com/bennyfactor' do
  gem 'v7cms', '~> 0.1'
end
```

Or install directly:

```bash
gem install v7cms --source "https://rubygems.pkg.github.com/bennyfactor"
```

Then set up your project:

```bash
# Create project directory
mkdir my-site && cd my-site

# Create Gemfile
cat > Gemfile << 'EOF'
source "https://rubygems.org"

source "https://rubygems.pkg.github.com/bennyfactor" do
  gem "v7cms", "~> 0.1"
end
EOF

# Install dependencies
bundle install

# Create bootstrap Rakefile (required to run setup)
echo 'require "v7cms/tasks"' > Rakefile

# Run setup (creates config.ru, .env.example, updates Rakefile with db tasks, etc.)
bundle exec rake v7cms:setup

# Copy and configure environment
cp .env.example .env
# Edit .env with your OAuth credentials and ADMIN_EMAILS

# Install and run migrations
bundle exec rake v7cms:install_migrations
bundle exec rake db:migrate

# Start the server
bundle exec rackup -p 9292
```

Your site is now running at http://localhost:9292

**Customization:**

v7cms supports multi-path view resolution - add custom views without copying everything from the gem:

```bash
# Add a custom homepage layout (no need to copy other files!)
mkdir -p views/layouts/homepage
cat > views/layouts/homepage/_my_custom.erb << 'EOF'
<div class="my-homepage">
  <h1><%= @settings.welcome_title %></h1>
  <% @posts.each do |post| %>
    <article>
      <h2><a href="/posts/<%= post.slug %>"><%= post.title %></a></h2>
      <time><%= post.created_at.strftime(@settings.date_format) %></time>
    </article>
  <% end %>
</div>
EOF
```

Then set `layout_homepage` to `my_custom` in admin Settings.

**Available layout variables:**
- `@posts` - published posts collection
- `@settings` - site settings (site_title, welcome_title, date_format, etc.)

**Override any view or asset:**

```bash
# Override the main layout
mkdir -p views
cp $(bundle show v7cms)/lib/v7cms/views/layout.erb views/

# Override styles
mkdir -p public/css
# Add your custom CSS
```

Files in your project take priority over gem defaults.

### Cloning the Repository (For Development)

#### Docker Setup (Recommended)

1. Clone the repository:
   ```bash
   git clone https://github.com/bennyfactor/v7cms.git
   cd v7cms
   ```

2. Create environment configuration:
   ```bash
   cp .env.example .env
   ```

3. Edit `.env` with your credentials:
   ```
   SESSION_SECRET=<generate-random-string>
   ADMIN_EMAILS=your-email@example.com
   GOOGLE_CLIENT_ID=<your-google-client-id>
   GOOGLE_CLIENT_SECRET=<your-google-client-secret>
   GITHUB_CLIENT_ID=<your-github-client-id>
   GITHUB_CLIENT_SECRET=<your-github-client-secret>
   RECAPTCHA_SITE_KEY=<your-recaptcha-site-key>
   RECAPTCHA_SECRET_KEY=<your-recaptcha-secret-key>
   ```

4. Start the application:
   ```bash
   docker-compose up -d
   docker-compose run --rm web bundle exec rake db:migrate
   ```

5. Access the application:
   - Public site: http://localhost:9292
   - Admin panel: http://localhost:9292/admin/

#### Local Development Setup

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Create and configure `.env` file as described above.

3. Run database migrations:
   ```bash
   bundle exec rake db:migrate
   ```

4. Build CSS assets:
   ```bash
   ./bin/tailwindcss -i public/css/input.css -o public/css/output.css --minify
   ```

5. Start the server:
   ```bash
   bundle exec rackup -p 9292
   ```

## Configuration

### Admin Access Control

Set the `ADMIN_EMAILS` environment variable with authorized admin email addresses:

```
ADMIN_EMAILS=admin@example.com,editor@example.com
```

- Only whitelisted emails can access the admin panel
- Application rejects all logins if `ADMIN_EMAILS` is not set (fail-closed security)
- Admins can grant/revoke admin status to other users via the Users tab

### OAuth Setup

Configure at least one OAuth provider for admin access.

**Google OAuth:**
1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Create OAuth 2.0 credentials
3. Set redirect URI: `https://yourdomain.com/auth/google_oauth2/callback`
4. Add credentials to `.env`

**GitHub OAuth:**
1. Visit [GitHub Developer Settings](https://github.com/settings/developers)
2. Create a new OAuth App
3. Set callback URL: `https://yourdomain.com/auth/github/callback`
4. Add credentials to `.env`

### reCAPTCHA Setup

Required for comment spam prevention. v7cms supports both standard reCAPTCHA v3 and reCAPTCHA Enterprise.

#### Option 1: Standard reCAPTCHA v3 (Recommended for new setups)

1. Visit [Google reCAPTCHA Admin](https://www.google.com/recaptcha/admin/create)
2. Select **reCAPTCHA v3** (not v2 or Enterprise)
3. Add your domain(s)
4. Add site key and secret key to `.env`:
   ```bash
   RECAPTCHA_SITE_KEY=<your-site-key>
   RECAPTCHA_SECRET_KEY=<your-secret-key>
   ```

#### Option 2: reCAPTCHA Enterprise

If your Google account has been migrated to reCAPTCHA Enterprise, use these settings instead:

1. Go to [Google Cloud reCAPTCHA](https://console.cloud.google.com/security/recaptcha)
2. Create or select your reCAPTCHA key
3. **Configure domain restrictions here** - add your domains in the key's "Domain list" section
4. Create an API key at [Google Cloud Credentials](https://console.cloud.google.com/apis/credentials)
5. Add credentials to `.env`:
   ```bash
   RECAPTCHA_SITE_KEY=<your-site-key>
   RECAPTCHA_PROJECT_ID=<your-gcp-project-id>
   RECAPTCHA_API_KEY=<your-api-key>
   ```

**Important:** When using reCAPTCHA Enterprise, configure domain restrictions on the **reCAPTCHA site key** (in the reCAPTCHA console), not on the API key. The API key settings page allows adding HTTP referrer restrictions, but this will cause authentication failures with the reCAPTCHA service. Leave the API key unrestricted or use API-level restrictions only (e.g., restrict to "reCAPTCHA Enterprise API").

## Usage

### Admin Interface

1. Navigate to `http://localhost:9292/admin/`
2. Sign in with Google or GitHub
3. Manage content via the tabbed interface:
   - **Posts**: Create and edit blog posts
   - **Pages**: Create hierarchical static pages
   - **Comments**: Moderate user comments
   - **Users**: Manage admin privileges
   - **Redirects**: Manage URL redirects
   - **Settings**: Configure site metadata
   - **Theme**: Customize colors, typography, and layout

### Public Site

- Homepage: `http://localhost:9292/`
- Blog posts: `http://localhost:9292/posts/<slug>`
- Static pages: `http://localhost:9292/<slug>`
- RSS Feed: `http://localhost:9292/feed/rss`
- Atom Feed: `http://localhost:9292/feed/atom`

## API Documentation

Interactive API documentation is available at `/api/docs` (Swagger UI).

### Authentication
| Endpoint | Description |
|----------|-------------|
| `GET /auth/google_oauth2` | Google OAuth flow |
| `GET /auth/github` | GitHub OAuth flow |
| `GET /api/auth/me` | Current user info |
| `POST /api/auth/logout` | Logout |

### Posts
| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /api/posts` | No | List published posts |
| `GET /api/posts?include_drafts=true` | Yes | List all posts |
| `GET /api/posts/:id` | No | Get post by ID or slug |
| `POST /api/posts` | Yes | Create post |
| `PUT /api/posts/:id` | Yes | Update post |
| `DELETE /api/posts/:id` | Yes | Delete post |

### Pages
| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /api/pages` | No | List published pages |
| `GET /api/pages?include_drafts=true` | Yes | List all pages |
| `GET /api/pages/:id` | No | Get page by ID or slug |
| `POST /api/pages` | Yes | Create page |
| `PUT /api/pages/:id` | Yes | Update page |
| `DELETE /api/pages/:id` | Yes | Delete page |

### Comments
| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /api/posts/:id/comments` | No | List approved comments |
| `POST /api/posts/:id/comments` | No | Submit comment (requires reCAPTCHA) |
| `GET /api/comments` | Yes | List all comments with filters |
| `GET /api/comments/pending_count` | Yes | Count pending comments |
| `PUT /api/comments/:id/approve` | Yes | Approve comment |
| `PUT /api/comments/:id/spam` | Yes | Mark as spam |
| `DELETE /api/comments/:id` | Yes | Delete comment |

### Users
| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /api/users` | Yes | List all users |
| `PUT /api/users/:id` | Yes | Update admin status |

### Settings
| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /api/settings` | No | Get current settings |
| `PUT /api/settings` | Yes | Update settings |
| `POST /api/settings/reset` | Yes | Reset to defaults |

### Theme
| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /api/theme` | No | Get current theme |
| `PUT /api/theme` | Yes | Update theme |
| `POST /api/theme/reset` | Yes | Reset to defaults |
| `GET /api/theme/preview` | No | Preview with query params |

### Redirects
| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /api/redirects` | Yes | List all redirects |
| `POST /api/redirects` | Yes | Create redirect |
| `PUT /api/redirects/:id` | Yes | Update redirect |
| `DELETE /api/redirects/:id` | Yes | Delete redirect |

## Development

### Running Tests

```bash
# All tests
docker-compose run --rm web bundle exec rspec

# With detailed output
docker-compose run --rm web bundle exec rspec --format documentation

# Specific file
docker-compose run --rm web bundle exec rspec spec/routes/posts_spec.rb
```

### Database Management

```bash
# Create migration
docker-compose run --rm web bundle exec rake db:create_migration NAME=add_feature

# Run migrations
docker-compose run --rm web bundle exec rake db:migrate

# Rollback
docker-compose run --rm web bundle exec rake db:rollback
```

### Rake Tasks

```bash
# Set up a new v7cms project (creates config files, copies templates)
bundle exec rake v7cms:setup

# Install/update migrations from gem
bundle exec rake v7cms:install_migrations
bundle exec rake v7cms:install_migrations FORCE=true  # Overwrite changed migrations

# Regenerate all static HTML files (posts and pages)
bundle exec rake v7cms:regenerate

# Generate .htaccess for Apache/FastCGI
bundle exec rake v7cms:htaccess

# Show v7cms version
bundle exec rake v7cms:version

# Database migrations
bundle exec rake db:migrate
bundle exec rake db:rollback
```

### CSS Development

```bash
# Rebuild CSS
./bin/tailwindcss -i public/css/input.css -o public/css/output.css --minify

# Watch for changes
./bin/tailwindcss -i public/css/input.css -o public/css/output.css --watch
```

## Deployment

### Docker Production

```bash
docker build -t v7cms:production .
docker run -d \
  -p 80:9292 \
  -v $(pwd)/db:/app/db \
  -e RACK_ENV=production \
  -e SESSION_SECRET=<strong-secret> \
  -e ADMIN_EMAILS=<admin-emails> \
  --name v7cms \
  v7cms:production
```

### Shared Hosting (FastCGI)

The `v7cms:setup` task automatically configures your project for FastCGI deployment:

1. **Run setup** (if not already done):
   ```bash
   bundle exec rake v7cms:setup
   ```
   This creates:
   - `setup.php` - Auto-detects Ruby path for your hosting environment
   - `index.fcgi` - FastCGI entry point
   - Adds `fcgi` gem to Gemfile (Linux-only, via `install_if`)

2. **Upload and configure:**
   ```bash
   bundle install --deployment
   cp .env.example .env
   # Edit .env with your credentials
   ```

3. **Run migrations and generate .htaccess:**
   ```bash
   RACK_ENV=production bundle exec rake db:migrate
   bundle exec rake v7cms:htaccess
   ```

4. **Auto-configure Ruby path** (optional):
   Visit `https://yourdomain.com/setup.php` in your browser to auto-detect and configure the Ruby shebang in `index.fcgi`.

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed instructions.

## Project Structure

```
v7cms/
├── lib/
│   ├── v7cms.rb                  # Main gem entry point
│   └── v7cms/
│       ├── application.rb        # V7CMS::Application (Sinatra app)
│       ├── file_resolver.rb      # User-first path resolution
│       ├── version.rb            # Gem version
│       ├── models/               # V7CMS::User, Post, Page, etc.
│       ├── helpers/              # V7CMS::AuthHelper
│       ├── services/             # V7CMS::FeedGenerator, etc.
│       ├── views/                # Default ERB templates
│       ├── public/               # Default static assets
│       └── tasks/                # Rake tasks (v7cms:setup, etc.)
├── app/
│   ├── cms.rb                    # Backward compatibility aliases
│   └── docs/                     # OpenAPI documentation
├── config/
│   └── database.yml
├── db/
│   └── migrate/                  # ActiveRecord migrations
├── public/                       # Development static assets
├── spec/                         # Test suite (848 tests)
├── v7cms.gemspec                 # Gem specification
├── Dockerfile
├── docker-compose.yml
├── Gemfile
└── config.ru
```

### Gem Architecture

When using v7cms as a gem, the `V7CMS::FileResolver` provides user-first path resolution:

1. **Your project files** (e.g., `./views/layout.erb`) take priority
2. **Gem files** (e.g., `lib/v7cms/views/layout.erb`) are used as fallback

**Multi-path view resolution:** Unlike typical gems, v7cms searches multiple view directories. You can add a custom homepage layout in `views/layouts/homepage/_my_layout.erb` without needing to copy all other views. The gem's views remain accessible as fallback.

**Built-in homepage layouts:**
- `blog_list` (default) - Traditional blog format
- `blog_grid` - Grid layout with cards
- `hero_grid` - Featured post hero + grid
- `magazine` - Magazine-style layout
- `minimal` - Clean, text-focused
- `portfolio` - Visual portfolio grid
- `landing` - Marketing landing page

## Database Schema

### users
| Column | Type | Description |
|--------|------|-------------|
| id | integer | Primary key |
| email | string | OAuth email |
| name | string | Display name |
| provider | string | OAuth provider |
| uid | string | Provider user ID |
| avatar_url | string | Profile image |
| admin | boolean | Admin access flag |
| last_login_at | datetime | Last login timestamp |

### posts
| Column | Type | Description |
|--------|------|-------------|
| id | integer | Primary key |
| title | string | Post title |
| slug | string | URL identifier (unique) |
| content | text | HTML content |
| published | boolean | Visibility flag |
| comments_enabled | boolean | Allow comments |

### pages
| Column | Type | Description |
|--------|------|-------------|
| id | integer | Primary key |
| title | string | Page title |
| slug | string | URL identifier (unique) |
| content | text | HTML content |
| published | boolean | Visibility flag |
| page_type | string | Layout type (standard, portfolio, blog_grid, etc.) |
| content_source | string | Source for layout items (children, posts) |
| items_limit | integer | Max items to display in layouts |
| hero_image_url | string | Optional hero/thumbnail image URL |
| parent_id | integer | Parent page FK |
| position | integer | Sort order |

### comments
| Column | Type | Description |
|--------|------|-------------|
| id | integer | Primary key |
| post_id | integer | Parent post FK |
| author_name | string | Commenter name |
| author_email | string | Commenter email |
| author_url | string | Optional website |
| content | text | Comment text |
| approved | boolean | Moderation status |
| spam | boolean | Spam flag |
| recaptcha_score | float | reCAPTCHA score |

### settings (singleton)
Site configuration: title, tagline, author, welcome text, footer, SEO metadata, contact info, display options, comment settings.

### themes (singleton)
40+ CSS properties: colors, typography, spacing, shadows, border radius, custom CSS.

### redirects
| Column | Type | Description |
|--------|------|-------------|
| id | integer | Primary key |
| short_path | string | URL path (unique) |
| target_path | string | Redirect destination |
| created_at | datetime | Creation timestamp |
| updated_at | datetime | Last update timestamp |

## Security

- CSRF protection via Rack::Protection
- SQL injection prevention via ActiveRecord
- XSS protection via Rack::Protection
- OAuth authentication (no password storage)
- Admin email whitelist
- reCAPTCHA spam prevention
- Environment variables for secrets

See [SECURITY.md](SECURITY.md) for security policy and reporting vulnerabilities.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Documentation

- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) - Production deployment guide
- [RELEASING.md](RELEASING.md) - Gem release process (maintainers)
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [SECURITY.md](SECURITY.md) - Security policy

## License

[European Union Public License (EUPL-1.2)](LICENSE)

## Support

- [GitHub Issues](https://github.com/bennyfactor/v7cms/issues) - Bug reports and feature requests
- [API Documentation](/api/docs) - Interactive API reference
