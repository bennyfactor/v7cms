# Deployment Guide

This guide covers deploying v7cms to production environments, including Docker and shared hosting (DreamHost, Bluehost, etc.).

## Table of Contents

- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Environment Configuration](#environment-configuration)
- [Docker Deployment](#docker-deployment)
- [Shared Hosting Deployment](#shared-hosting-deployment)
- [Post-Deployment](#post-deployment)
- [Backup Strategy](#backup-strategy)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)
- [Maintenance](#maintenance)

---

## Pre-Deployment Checklist

Before deploying to production, ensure:

- [ ] All tests passing (`bundle exec rspec`)
- [ ] Environment variables configured
- [ ] OAuth credentials obtained (Google, GitHub)
- [ ] reCAPTCHA credentials obtained (for commenting system)
- [ ] Database migrations ready
- [ ] Production secrets generated
- [ ] ADMIN_EMAILS environment variable configured

---

## Environment Configuration

### Required Environment Variables

Create a `.env` file (or configure hosting environment variables):

```bash
# Application Environment
RACK_ENV=production

# Session Security
SESSION_SECRET=<generate-with-openssl-rand-hex-64>

# OAuth Authentication
GOOGLE_CLIENT_ID=<your-google-client-id>
GOOGLE_CLIENT_SECRET=<your-google-client-secret>
GITHUB_CLIENT_ID=<your-github-client-id>
GITHUB_CLIENT_SECRET=<your-github-client-secret>

# reCAPTCHA (for comment spam prevention)
RECAPTCHA_SITE_KEY=<your-recaptcha-site-key>
RECAPTCHA_SECRET_KEY=<your-recaptcha-secret-key>

# Admin Access Control
ADMIN_EMAILS=admin@example.com,editor@example.com

# Optional: Site URL (for feed generation)
SITE_URL=https://yourdomain.com

# Optional: IP blocklist for rate limiting
BLOCKED_IPS=192.168.1.100,10.0.0.50
```

### Generate Secure Session Secret

```bash
ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
```

### Configure OAuth Providers

See the [README.md OAuth Configuration section](../README.md#oauth-configuration) for detailed setup instructions for Google and GitHub OAuth.

### Configure reCAPTCHA

1. Visit Google reCAPTCHA Admin: https://www.google.com/recaptcha/admin/create
2. Select **reCAPTCHA v3**
3. Add your domains (localhost for dev, yourdomain.com for production)
4. Copy Site Key and Secret Key to `.env`

---

## Docker Deployment

### Production Docker Setup

1. **Build the production image:**

```bash
docker build -t v7cms:production .
```

2. **Run the container:**

```bash
docker run -d \
  -p 80:9292 \
  -v $(pwd)/db:/app/db \
  -v $(pwd)/public:/app/public \
  -e RACK_ENV=production \
  -e SESSION_SECRET=<your-secret> \
  -e GOOGLE_CLIENT_ID=<id> \
  -e GOOGLE_CLIENT_SECRET=<secret> \
  -e GITHUB_CLIENT_ID=<id> \
  -e GITHUB_CLIENT_SECRET=<secret> \
  -e RECAPTCHA_SITE_KEY=<key> \
  -e RECAPTCHA_SECRET_KEY=<secret> \
  -e ADMIN_EMAILS=<email-list> \
  --name v7cms \
  v7cms:production
```

3. **Run database migrations:**

```bash
docker exec v7cms bundle exec rake db:migrate
```

4. **Regenerate static files:**

```bash
docker exec v7cms bundle exec rake posts:regenerate_all
docker exec v7cms bundle exec rake pages:regenerate_all
```

### Docker Compose Production

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'
services:
  web:
    build: .
    ports:
      - "80:9292"
    volumes:
      - ./db:/app/db
      - ./public:/app/public
    environment:
      - RACK_ENV=production
      - SESSION_SECRET=${SESSION_SECRET}
      - GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
      - GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
      - GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID}
      - GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}
      - RECAPTCHA_SITE_KEY=${RECAPTCHA_SITE_KEY}
      - RECAPTCHA_SECRET_KEY=${RECAPTCHA_SECRET_KEY}
      - ADMIN_EMAILS=${ADMIN_EMAILS}
      - SITE_URL=${SITE_URL}
    restart: unless-stopped
```

Deploy:

```bash
docker-compose -f docker-compose.prod.yml up -d
docker-compose -f docker-compose.prod.yml exec web bundle exec rake db:migrate
docker-compose -f docker-compose.prod.yml exec web bundle exec rake posts:regenerate_all
docker-compose -f docker-compose.prod.yml exec web bundle exec rake pages:regenerate_all
```

---

## Shared Hosting Deployment

### Prerequisites

- SSH access to hosting account
- Ruby 3.x installed (or available via rbenv/rvm)
- Ability to run FastCGI applications
- Write access to web directory

### Deployment Steps

#### 1. Enable FastCGI Gem

Edit `Gemfile`, uncomment:

```ruby
gem 'fcgi', '~> 0.9'
```

#### 2. Upload Files

```bash
# Via git (recommended)
git clone <your-repo-url> ~/yourdomain.com
cd ~/yourdomain.com

# Or via FTP/SFTP - upload all files except:
# - .git
# - db/*.db (development databases)
# - public/css/theme.css (will regenerate)
# - bin/tailwindcss (platform-specific)
```

#### 3. Install Dependencies

```bash
bundle install --deployment --without development test
```

#### 4. Configure Environment Variables

```bash
# Create .env file
cat > .env << 'EOF'
RACK_ENV=production
SESSION_SECRET=<your-generated-secret>
GOOGLE_CLIENT_ID=<your-id>
GOOGLE_CLIENT_SECRET=<your-secret>
GITHUB_CLIENT_ID=<your-id>
GITHUB_CLIENT_SECRET=<your-secret>
RECAPTCHA_SITE_KEY=<your-key>
RECAPTCHA_SECRET_KEY=<your-secret>
ADMIN_EMAILS=<admin-email-list>
SITE_URL=https://yourdomain.com
EOF

chmod 600 .env
```

#### 5. Run Setup Script

Visit `https://yourdomain.com/setup.php` in your browser to:
- Auto-detect Ruby path
- Update shebang in `index.fcgi`
- Set correct permissions
- Self-delete for security

Or run manual setup (see [Manual Setup section](#manual-setup-alternative) below).

#### 6. Run Database Migrations

```bash
RACK_ENV=production bundle exec rake db:migrate
```

#### 7. Regenerate Static Files

```bash
RACK_ENV=production bundle exec rake posts:regenerate_all
RACK_ENV=production bundle exec rake pages:regenerate_all
```

#### 8. Configure OAuth Redirect URLs

Set OAuth callback URLs in your provider consoles:
- **Google**: `https://yourdomain.com/auth/google_oauth2/callback`
- **GitHub**: `https://yourdomain.com/auth/github/callback`

Note: Production URLs **must use HTTPS**.

#### 9. Verify Deployment

```bash
curl https://yourdomain.com/health
```

### Manual Setup (Alternative)

If `setup.php` doesn't work or you prefer manual configuration:

```bash
# SSH into your server
cd /path/to/v7cms

# 1. Find your Ruby path
which ruby

# 2. Update the shebang in index.fcgi (line 1)
# Change: #!/usr/bin/env ruby
# To:     #!/full/path/to/ruby

# 3. Make it executable
chmod +x index.fcgi

# 4. Remove setup.php for security
rm setup.php
```

### Apache .htaccess Configuration

The included `.htaccess` file provides:
- Static-first routing (serves static HTML files before FastCGI)
- Security rules (blocks access to .rb, .db, .env files)
- Gzip compression
- Cache headers for static assets
- Rate limiting support

Verify `.htaccess` is configured correctly:

```apache
RewriteEngine On
RewriteBase /

# Block sensitive files
<FilesMatch "\.(rb|db|env|sqlite3)$">
  Order allow,deny
  Deny from all
</FilesMatch>

# Serve static files first
RewriteCond %{REQUEST_FILENAME} -f
RewriteRule ^ - [L]

# Route to FastCGI
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ /index.fcgi/$1 [QSA,L]
```

---

## Post-Deployment

### 1. Verify Application

- [ ] Homepage loads: `https://yourdomain.com/`
- [ ] Admin panel accessible: `https://yourdomain.com/admin/`
- [ ] Health check passes: `https://yourdomain.com/health`
- [ ] OAuth login works (Google)
- [ ] OAuth login works (GitHub)
- [ ] Can create posts
- [ ] Can view posts on public site
- [ ] RSS/Atom feeds accessible
- [ ] Static HTML files generated in `public/posts/` and `public/pages/`

### 2. Create First Admin User

1. Navigate to `/admin/`
2. Sign in with Google or GitHub (email must be in ADMIN_EMAILS)
3. Verify admin panel access
4. Create your first post
5. Verify static HTML file generated

### 3. Security Hardening

- [ ] Ensure `.env` is not web-accessible (blocked by .htaccess)
- [ ] Verify OAuth credentials are correct
- [ ] Confirm HTTPS is enforced
- [ ] Review file permissions (644 for files, 755 for directories)
- [ ] Ensure `db/` directory is writable
- [ ] Verify `tmp/` directory exists and is writable (for rate limiting cache)
- [ ] Test that sensitive files (.rb, .db, .env) return 403 when accessed via web

### 4. Monitoring

Monitor application logs:

```bash
# Docker
docker-compose logs -f web

# Shared hosting
tail -f ~/logs/<domain>/http/error.log
```

Watch for:
- FastCGI process errors
- Database locking issues (SQLite)
- OAuth authentication failures
- Rate limiting triggers
- File permission errors

---

## Backup Strategy

### Database Backups

```bash
# Manual backup
cp db/cms.db db/backups/cms-$(date +%Y%m%d-%H%M%S).db

# Automated daily backup (add to crontab)
0 2 * * * cd /path/to/v7cms && cp db/cms.db db/backups/cms-$(date +\%Y\%m\%d).db

# Keep only last 30 days of backups
0 3 * * * find /path/to/v7cms/db/backups -name "cms-*.db" -mtime +30 -delete
```

### Full Application Backups

```bash
# Create full backup
tar -czf v7cms-backup-$(date +%Y%m%d).tar.gz \
  --exclude='*.log' \
  --exclude='tmp/*' \
  --exclude='.git' \
  /path/to/v7cms

# Upload to remote storage (example with rsync)
rsync -avz v7cms-backup-$(date +%Y%m%d).tar.gz \
  user@backup-server:/backups/v7cms/
```

### Restore from Backup

```bash
# Stop application (Docker)
docker-compose down

# Restore database
cp db/backups/cms-<timestamp>.db db/cms.db

# Restart application
docker-compose up -d

# Regenerate static files (if needed)
docker exec v7cms bundle exec rake posts:regenerate_all
docker exec v7cms bundle exec rake pages:regenerate_all
```

---

## Troubleshooting

### Issue: 500 Internal Server Error

**Symptoms:** White page or generic server error

**Check:**
- Application logs
- File permissions
- Environment variables set correctly
- Database file writable
- Ruby path in shebang correct (shared hosting)

**Solution:**

```bash
# Check logs
tail -f logs/production.log

# Verify permissions
chmod 644 app/cms.rb
chmod 755 db/
chmod 644 db/cms.db

# Verify environment
env | grep RACK_ENV
env | grep SESSION_SECRET

# Test FastCGI directly (shared hosting)
./index.fcgi
```

### Issue: OAuth Login Not Working

**Symptoms:** Redirect loop, "redirect_uri_mismatch" error, or blank page after OAuth

**Check:**
- OAuth credentials correct in `.env`
- Redirect URLs match OAuth app settings exactly
- HTTPS enabled (required for production)
- ModSecurity not blocking requests

**Solution:**

```bash
# Verify environment variables
env | grep GOOGLE
env | grep GITHUB

# Check OAuth app settings in provider console
# Ensure redirect URLs include correct domain and protocol

# For DreamHost ModSecurity issues: use 'email' scope only
# See CLAUDE.md Security Notes section
```

### Issue: Admin Access Denied

**Symptoms:** User can log in but sees "Admin access denied" message

**Check:**
- `ADMIN_EMAILS` environment variable is set
- User's email matches one in the whitelist (exact match, comma-separated)
- User logged out and back in after ADMIN_EMAILS was updated

**Solution:**

```bash
# Verify ADMIN_EMAILS is set
env | grep ADMIN_EMAILS

# Check user's email in database
sqlite3 db/cms.db "SELECT email, admin FROM users;"

# Update user's admin status manually if needed
sqlite3 db/cms.db "UPDATE users SET admin = 1 WHERE email = 'user@example.com';"

# Or add email to ADMIN_EMAILS and have user re-login
```

### Issue: Static HTML Files Not Generated

**Symptoms:** Posts/pages don't appear on public site, 404 errors

**Check:**
- `public/posts/` and `public/pages/` directories exist
- Directories are writable
- ActiveRecord callbacks are firing
- Service classes return true

**Solution:**

```bash
# Create directories if missing
mkdir -p public/posts public/pages
chmod 755 public/posts public/pages

# Manually regenerate all files
bundle exec rake posts:regenerate_all
bundle exec rake pages:regenerate_all

# Verify files created
ls -la public/posts/
ls -la public/pages/

# Check service logs for errors
grep -i "error" logs/production.log | grep -i "renderer"
```

### Issue: Comments Not Showing

**Symptoms:** Comment form visible but submissions fail or comments don't appear

**Check:**
- reCAPTCHA credentials configured
- Comment moderation queue (comments default to approved=false)
- JavaScript errors in browser console

**Solution:**

```bash
# Verify reCAPTCHA config
env | grep RECAPTCHA

# Check pending comments count
sqlite3 db/cms.db "SELECT COUNT(*) FROM comments WHERE approved = 0;"

# Approve all pending comments (testing only)
sqlite3 db/cms.db "UPDATE comments SET approved = 1;"

# Check browser console for reCAPTCHA errors
# Visit /admin/ and check moderation queue
```

### Issue: Rate Limiting Blocking Legitimate Users

**Symptoms:** Users getting 429 errors, "Rate limit exceeded" messages

**Check:**
- Rate limit thresholds in `config/rate_limit.rb`
- User behind proxy/NAT (same IP for many users)
- DDoS or bot attack

**Solution:**

```bash
# View rate limit cache
ls -la tmp/rack-attack-cache/

# Temporarily disable rate limiting (emergency only)
# Comment out Rack::Attack in app/cms.rb and restart

# Whitelist specific IPs in config/rate_limit.rb
# Add to safelist block:
# Rack::Attack.safelist_ip("1.2.3.4")

# Increase rate limits if needed
# Edit config/rate_limit.rb and restart application
```

### Issue: Database Locked

**Symptoms:** "SQLite3::BusyException: database is locked" errors

**Cause:** SQLite can't handle high concurrent writes

**Solution:**

- Reduce concurrent requests (not ideal)
- Consider PostgreSQL/MySQL for high traffic
- Add retry logic with exponential backoff (already implemented in app)
- Ensure only one write operation at a time

For high-traffic sites, migrate to PostgreSQL:

```bash
# See "Scaling to PostgreSQL" section below
```

---

## Performance Optimization

### Enable Gzip Compression

The included `.htaccess` already has gzip compression. Verify it's working:

```bash
curl -H "Accept-Encoding: gzip" -I https://yourdomain.com/
# Look for "Content-Encoding: gzip" in response headers
```

### Cache Static Assets

The `.htaccess` file includes cache headers for static assets:
- Static HTML files: 1 hour cache
- CSS/JS: 1 month cache
- Images: 1 year cache

### Database Optimization

```bash
# Optimize SQLite database (run monthly)
sqlite3 db/cms.db "VACUUM;"
sqlite3 db/cms.db "ANALYZE;"

# Check database size
ls -lh db/cms.db
```

### Static File Generation Performance

The CMS pre-renders all published posts and pages as static HTML. Apache serves these files directly, bypassing the Ruby application entirely for maximum performance.

Regenerate static files after:
- Theme changes
- Settings changes
- Bulk post/page imports
- Deployment

```bash
bundle exec rake posts:regenerate_all
bundle exec rake pages:regenerate_all
```

---

## Scaling

### Moving to PostgreSQL/MySQL

For high-traffic sites, migrate from SQLite to PostgreSQL:

1. **Update Gemfile:**

```ruby
# Replace sqlite3 with:
gem 'pg', '~> 1.5'  # PostgreSQL
# OR
gem 'mysql2', '~> 0.5'  # MySQL
```

2. **Update config/database.yml:**

```yaml
production:
  adapter: postgresql
  database: v7cms_production
  username: <%= ENV['DB_USER'] %>
  password: <%= ENV['DB_PASS'] %>
  host: <%= ENV['DB_HOST'] %>
  pool: 5
```

3. **Export data from SQLite:**

```bash
sqlite3 db/cms.db .dump > dump.sql
```

4. **Import to PostgreSQL:**

```bash
# Create database
createdb v7cms_production

# Import data
psql v7cms_production < dump.sql

# Run migrations to ensure schema is current
RACK_ENV=production bundle exec rake db:migrate
```

5. **Update environment variables:**

```bash
DB_USER=postgres
DB_PASS=<password>
DB_HOST=localhost
```

### Load Balancing (Docker)

For horizontal scaling, use multiple containers behind a load balancer:

```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  web:
    build: .
    deploy:
      replicas: 3
    environment:
      # ... same as above

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    depends_on:
      - web
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
```

Note: Shared database and file storage required for multi-instance deployment.

---

## Maintenance

### Regular Tasks

- [ ] **Weekly:** Database backups (automated via cron)
- [ ] **Monthly:** Review logs for errors and unusual activity
- [ ] **Monthly:** Database optimization (VACUUM, ANALYZE)
- [ ] **Quarterly:** Dependency updates (`bundle update`)
- [ ] **Quarterly:** Security audits
- [ ] **Annually:** Rotate OAuth credentials
- [ ] **Annually:** Review and update admin email whitelist

### Updating Dependencies

```bash
# Update gems
bundle update

# Run tests
bundle exec rspec

# Deploy update
git push production main

# Or for shared hosting:
ssh user@host
cd ~/yourdomain.com
git pull origin main
bundle install --deployment
RACK_ENV=production bundle exec rake db:migrate
# Touch index.fcgi to restart FastCGI
touch index.fcgi
```

### Monitoring Checklist

- [ ] Application responding to requests
- [ ] OAuth login working
- [ ] Database queries executing successfully
- [ ] Static files generating correctly
- [ ] Disk space adequate (logs, database, backups)
- [ ] Error rate within acceptable range
- [ ] Rate limiting not blocking legitimate users

---

## Production Checklist

Before going live:

- [ ] All tests passing (`bundle exec rspec`)
- [ ] Environment variables configured and secured
- [ ] OAuth apps registered with production URLs
- [ ] reCAPTCHA configured with production domain
- [ ] ADMIN_EMAILS whitelist configured
- [ ] HTTPS enforced
- [ ] Database migrations run
- [ ] Static files regenerated
- [ ] Backups configured and tested
- [ ] Monitoring in place
- [ ] Error logging configured
- [ ] `.env` file has 600 permissions
- [ ] Sensitive files blocked by `.htaccess`
- [ ] Session secret is strong (64+ characters)
- [ ] Rate limiting tested and tuned
- [ ] FastCGI/Docker deployment tested
- [ ] Rollback procedure documented and tested

---

## Support

For deployment issues:

1. Check logs for error messages
2. Review this troubleshooting section
3. Consult [CLAUDE.md](../CLAUDE.md) for architecture details
4. Check [README.md](../README.md) for configuration help
5. Open GitHub issue with details if problem persists
