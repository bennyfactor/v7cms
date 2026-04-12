# Installation

## Requirements

- Ruby 3.4+
- SQLite3
- Docker (optional, for development)

## As a Gem

Add v7cms to your Gemfile:

```ruby
source 'https://rubygems.pkg.github.com/bennyfactor' do
  gem 'v7cms', '~> 0.3'
end
```

Or install directly:

```bash
gem install v7cms --source "https://rubygems.pkg.github.com/bennyfactor"
```

Set up your project:

```bash
mkdir my-site && cd my-site

cat > Gemfile << 'EOF'
source "https://rubygems.org"

source "https://rubygems.pkg.github.com/bennyfactor" do
  gem "v7cms", "~> 0.3"
end
EOF

bundle install

# Bootstrap Rakefile (required for setup)
echo 'require "v7cms/tasks"' > Rakefile

# Run setup (creates config.ru, .env.example, Rakefile with db tasks, etc.)
bundle exec rake v7cms:setup

# Configure environment
cp .env.example .env
# Edit .env with your OAuth credentials and ADMIN_EMAILS

# Install and run migrations
bundle exec rake v7cms:install_migrations
bundle exec rake db:migrate

# Start the server
bundle exec rackup -p 9292
```

Your site is now running at http://localhost:9292.

## Cloning the Repository

### Docker (Recommended)

```bash
git clone https://github.com/bennyfactor/v7cms.git
cd v7cms
cp .env.example .env
# Edit .env with your credentials (see Configuration below)
docker-compose up -d
docker-compose run --rm web bundle exec rake db:migrate
```

### Local Development

```bash
git clone https://github.com/bennyfactor/v7cms.git
cd v7cms
bundle install
cp .env.example .env
# Edit .env with your credentials
bundle exec rake db:migrate
bundle exec rake v7cms:tailwind
bundle exec rackup -p 9292
```

## Configuration

### Environment Variables

```bash
SESSION_SECRET=<random-string>
ADMIN_EMAILS=admin@example.com,editor@example.com
GOOGLE_CLIENT_ID=<google-oauth-client-id>
GOOGLE_CLIENT_SECRET=<google-oauth-secret>
GITHUB_CLIENT_ID=<github-oauth-client-id>
GITHUB_CLIENT_SECRET=<github-oauth-secret>
RECAPTCHA_SITE_KEY=<recaptcha-site-key>
RECAPTCHA_SECRET_KEY=<recaptcha-secret-key>
RACK_ENV=development|test|production
```

### Admin Access Control

Set `ADMIN_EMAILS` with authorized admin email addresses (comma-separated). This variable controls who can log in to the admin panel:

- Only whitelisted emails can access the admin panel
- The application rejects all logins if `ADMIN_EMAILS` is not set (fail-closed security)
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

Required for comment spam prevention and form submissions. Supports both standard reCAPTCHA v3 and reCAPTCHA Enterprise.

#### Standard reCAPTCHA v3 (Recommended)

1. Visit [Google reCAPTCHA Admin](https://www.google.com/recaptcha/admin/create)
2. Select **reCAPTCHA v3**
3. Add your domain(s)
4. Add site key and secret key to `.env`:
   ```bash
   RECAPTCHA_SITE_KEY=<your-site-key>
   RECAPTCHA_SECRET_KEY=<your-secret-key>
   ```

#### reCAPTCHA Enterprise

If your Google account has been migrated to reCAPTCHA Enterprise:

1. Go to [Google Cloud reCAPTCHA](https://console.cloud.google.com/security/recaptcha)
2. Create or select your reCAPTCHA key
3. Configure domain restrictions on the reCAPTCHA site key (not the API key)
4. Create an API key at [Google Cloud Credentials](https://console.cloud.google.com/apis/credentials)
5. Add credentials to `.env`:
   ```bash
   RECAPTCHA_SITE_KEY=<your-site-key>
   RECAPTCHA_PROJECT_ID=<your-gcp-project-id>
   RECAPTCHA_API_KEY=<your-api-key>
   ```

**Important:** When using reCAPTCHA Enterprise, configure domain restrictions on the reCAPTCHA site key, not the API key. Adding HTTP referrer restrictions to the API key causes authentication failures. Leave the API key unrestricted or use API-level restrictions only.

## Rake Tasks

| Task | Description |
|------|-------------|
| `v7cms:setup` | Set up a new v7cms project (creates config files, copies templates) |
| `v7cms:install_migrations` | Install/update migrations from gem (`FORCE=true` to overwrite) |
| `v7cms:assets` | Copy static assets from gem to project |
| `v7cms:regenerate` | Regenerate all static HTML files (posts and pages) |
| `v7cms:htaccess` | Generate .htaccess for Apache/FastCGI |
| `v7cms:tailwind` | Build CSS using `tailwindcss-ruby` |
| `v7cms:version` | Show v7cms version |
| `db:migrate` | Run database migrations |
| `db:rollback` | Rollback last migration |

## Customization

v7cms supports multi-path view resolution. Add custom views without copying everything from the gem:

```bash
# Add a custom homepage layout
mkdir -p views/layouts/homepage
cat > views/layouts/homepage/_my_custom.erb << 'EOF'
<div class="my-homepage">
  <h1><%= @settings.welcome_title %></h1>
  <% @posts.each do |post| %>
    <article>
      <h2><a href="/posts/<%= post.slug %>"><%= post.title %></a></h2>
    </article>
  <% end %>
</div>
EOF
```

Then set `layout_homepage` to `my_custom` in admin Settings. Files in your project take priority over gem defaults.
