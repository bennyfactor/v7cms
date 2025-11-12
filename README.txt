# v7cms

A minimal content management system built with Ruby and Sinatra. This project provides a straightforward approach to managing and publishing content with modern authentication and a clean interface.

## Overview

v7cms is designed for developers who need a lightweight, maintainable CMS without the complexity of larger frameworks. It uses OAuth for authentication, provides a RESTful API for content management, and includes both an admin interface and a public-facing site.

The system runs on shared hosting environments via FastCGI or can be containerized with Docker for modern deployment workflows.

## Features

- OAuth authentication via Google and GitHub
- RESTful JSON API for programmatic access
- Rich text editing with Quill.js
- Draft and publish workflow
- Automatic URL slug generation
- Responsive design using Tailwind CSS
- Lightweight JavaScript framework (Alpine.js)
- Comprehensive test coverage

## Technology Stack

**Backend:**
- Ruby 3.2
- Sinatra 3.0 web framework
- SQLite database with ActiveRecord ORM
- OmniAuth 2.1 for OAuth authentication

**Frontend:**
- Alpine.js for reactive components
- Tailwind CSS for styling (standalone CLI, no Node.js required)
- Quill.js rich text editor
- ERB templates for server-side rendering

**Development:**
- RSpec for testing
- Docker for containerization
- Rake for task automation

## Requirements

### For Docker Development
- Docker and Docker Compose
- Git

### For Local Development
- Ruby 3.0 or higher
- Bundler gem
- SQLite3

### For Production Deployment
- Ruby 3.0+ environment
- Web server with FastCGI support (for shared hosting)
- Or Docker environment (for containerized deployment)

## Installation

### Docker Setup (Recommended)

1. Clone the repository:
```bash
git clone <repository-url>
cd v7cms
```

2. Create environment configuration:
```bash
cp .env.example .env
```

3. Edit `.env` and add your OAuth credentials:
```
SESSION_SECRET=<generate-random-string>
GOOGLE_CLIENT_ID=<your-google-client-id>
GOOGLE_CLIENT_SECRET=<your-google-client-secret>
GITHUB_CLIENT_ID=<your-github-client-id>
GITHUB_CLIENT_SECRET=<your-github-client-secret>
```

4. Start the application:
```bash
docker-compose up -d
```

5. Run database migrations:
```bash
docker-compose run --rm web bundle exec rake db:migrate
```

6. Optionally load sample data:
```bash
docker-compose run --rm web bundle exec ruby db/seed.rb
```

7. Access the application:
- Public site: http://localhost:9292/
- Admin panel: http://localhost:9292/admin.html

### Local Development Setup

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

## OAuth Configuration

### Google OAuth Setup

1. Visit the Google Cloud Console: https://console.cloud.google.com/
2. Create a new project or select an existing one
3. Enable the Google+ API
4. Navigate to Credentials and create OAuth 2.0 credentials
5. Add authorized redirect URI: `http://localhost:9292/auth/google_oauth2/callback`
6. Copy the Client ID and Client Secret to your `.env` file

For production, add your production domain's callback URL.

### GitHub OAuth Setup

1. Visit GitHub Developer Settings: https://github.com/settings/developers
2. Create a new OAuth App
3. Set the Authorization callback URL: `http://localhost:9292/auth/github/callback`
4. Copy the Client ID and Client Secret to your `.env` file

For production, add your production domain's callback URL.

## Usage

### Accessing the Admin Interface

1. Navigate to `http://localhost:9292/admin.html`
2. Click "Sign in with Google" or "Sign in with GitHub"
3. Complete the OAuth flow
4. You will be redirected to the admin dashboard

### Creating Posts

1. From the admin dashboard, click "New Post"
2. Enter a title (slug will be auto-generated)
3. Optionally customize the slug
4. Write content using the rich text editor
5. Toggle "Published" to make the post public
6. Click "Save Post"

### Managing Posts

- View all posts (including drafts) in the admin panel
- Click "Edit" to modify a post
- Click "Delete" to remove a post (with confirmation)
- Toggle the published status to control visibility

### Viewing Public Content

Navigate to `http://localhost:9292/` to see the public site with all published posts.

Individual posts are accessible at `http://localhost:9292/posts/<slug>`.

## API Documentation

The system provides a RESTful JSON API for programmatic access.

### Public Endpoints

**List published posts:**
```
GET /api/posts
```

**Get a single post:**
```
GET /api/posts/:id
```
Accepts either numeric ID or slug.

**Check authentication status:**
```
GET /api/auth/me
```

### Authenticated Endpoints

These endpoints require a valid session (OAuth login).

**List all posts (including drafts):**
```
GET /api/posts?include_drafts=true
```

**Create a new post:**
```
POST /api/posts
Content-Type: application/json

{
  "title": "Post Title",
  "slug": "optional-custom-slug",
  "content": "<p>HTML content</p>",
  "published": false
}
```

**Update a post:**
```
PUT /api/posts/:id
Content-Type: application/json

{
  "title": "Updated Title",
  "content": "<p>Updated content</p>",
  "published": true
}
```

**Delete a post:**
```
DELETE /api/posts/:id
```

**Logout:**
```
POST /api/auth/logout
```

## Development

### Running Tests

The project includes comprehensive test coverage using RSpec.

Run all tests:
```bash
docker-compose run --rm web bundle exec rspec
```

Run tests with detailed output:
```bash
docker-compose run --rm web bundle exec rspec --format documentation
```

Run a specific test file:
```bash
docker-compose run --rm web bundle exec rspec spec/routes/posts_spec.rb
```

### Database Management

Create a new migration:
```bash
docker-compose run --rm web bundle exec rake db:create_migration NAME=add_feature
```

Run migrations:
```bash
docker-compose run --rm web bundle exec rake db:migrate
```

Rollback last migration:
```bash
docker-compose run --rm web bundle exec rake db:rollback
```

Reset test database:
```bash
docker-compose run --rm -e RACK_ENV=test web bundle exec rake db:drop db:create db:migrate
```

### Working with CSS

The project uses Tailwind CSS via the standalone CLI. When modifying templates or adding new styles:

Rebuild CSS:
```bash
./bin/tailwindcss -i public/css/input.css -o public/css/output.css --minify
```

Watch for changes during development:
```bash
./bin/tailwindcss -i public/css/input.css -o public/css/output.css --watch
```

## Deployment

### Docker Production Deployment

1. Set environment variables for production
2. Build the production image:
```bash
docker build -t v7cms:production .
```

3. Run the container:
```bash
docker run -d \
  -p 80:9292 \
  -v $(pwd)/db:/app/db \
  -e RACK_ENV=production \
  -e SESSION_SECRET=<strong-secret> \
  -e GOOGLE_CLIENT_ID=<id> \
  -e GOOGLE_CLIENT_SECRET=<secret> \
  -e GITHUB_CLIENT_ID=<id> \
  -e GITHUB_CLIENT_SECRET=<secret> \
  --name v7cms \
  v7cms:production
```

4. Run migrations:
```bash
docker exec v7cms bundle exec rake db:migrate
```

See DEPLOYMENT.md for detailed production deployment instructions.

### Shared Hosting Deployment

The application supports deployment to shared hosting environments (DreamHost, Bluehost, etc.) via FastCGI:

1. Uncomment the `fcgi` gem in the Gemfile
2. Upload files to your web directory
3. Install dependencies: `bundle install --deployment`
4. Build CSS assets
5. Configure environment variables
6. Run migrations
7. Set up `.htaccess` for URL rewriting

See DEPLOYMENT.md for complete step-by-step instructions.

## Project Structure

```
v7cms/
├── app/
│   ├── cms.rb              Main Sinatra application
│   ├── models/             ActiveRecord models
│   │   ├── user.rb         OAuth user model
│   │   └── post.rb         Blog post model
│   ├── helpers/            Helper modules
│   │   └── auth_helper.rb  Authentication helpers
│   └── views/              ERB templates for public site
│       ├── layout.erb
│       ├── index.erb
│       ├── post.erb
│       └── 404.erb
├── config/
│   └── database.yml        Database configuration
├── db/
│   ├── migrate/            Database migrations
│   └── seed.rb             Sample data
├── public/
│   ├── admin.html          Admin single-page application
│   ├── js/
│   │   └── admin.js        Admin application logic
│   └── css/
│       ├── input.css       Tailwind source
│       └── output.css      Generated CSS (not in git)
├── spec/                   RSpec test suite
│   ├── models/
│   ├── routes/
│   └── helpers/
├── bin/
│   └── tailwindcss         Tailwind CLI binary (not in git)
├── Dockerfile
├── docker-compose.yml
├── Gemfile
├── Rakefile
├── config.ru               Rack configuration
└── tailwind.config.js      Tailwind configuration
```

## Database Schema

### Users Table
- `id` - Primary key
- `email` - User email from OAuth provider
- `name` - Display name
- `provider` - OAuth provider (google_oauth2, github)
- `uid` - Unique identifier from provider
- `avatar_url` - Profile image URL
- `created_at`, `updated_at` - Timestamps

### Posts Table
- `id` - Primary key
- `title` - Post title
- `slug` - URL-friendly identifier (unique)
- `content` - HTML content
- `published` - Boolean flag (default: false)
- `created_at`, `updated_at` - Timestamps

## Security Considerations

The application implements several security measures:

- CSRF protection via Rack::Protection
- SQL injection prevention through ActiveRecord parameterized queries
- XSS protection through Rack::Protection
- Secure session management with strong secrets
- OAuth authentication (no password storage)
- Environment variables for sensitive credentials

Production deployments should:
- Use HTTPS for all traffic
- Generate strong session secrets
- Regularly update dependencies
- Restrict file permissions appropriately
- Keep OAuth credentials secure

## Performance Notes

The application is designed for small to medium traffic sites:

- SQLite is suitable for most use cases
- For high-traffic sites, consider PostgreSQL or MySQL
- Tailwind CSS is pre-built (no runtime overhead)
- Alpine.js adds minimal JavaScript weight (7kB)
- FastCGI uses persistent processes for better performance than CGI

## Troubleshooting

### Common Issues

**Tests fail with "table not found":**
Run migrations in the test environment:
```bash
RACK_ENV=test bundle exec rake db:migrate
```

**Tailwind CSS not updating:**
Rebuild the CSS:
```bash
./bin/tailwindcss -i public/css/input.css -o public/css/output.css --minify
```

**OAuth authentication fails:**
- Verify credentials in `.env` match your OAuth app settings
- Check redirect URLs are correctly configured
- Ensure callback URLs match exactly (including protocol)

**FCGI gem won't compile:**
The FCGI gem is only needed for shared hosting deployment. For development, keep it commented out in the Gemfile.

## Contributing

Contributions are welcome. Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Follow existing code style
6. Submit a pull request with a clear description

## Testing

The project maintains comprehensive test coverage:

- Model tests for validations and business logic
- Route tests for all endpoints
- Helper tests for authentication logic
- Integration tests for complete workflows

Run the test suite before submitting changes.

## Documentation

Additional documentation is available:

- **DEPLOYMENT.txt** - Production deployment guide
- **IMPLEMENTATION_PLAN.txt** - Development roadmap
- **PROJECT_STATUS.txt** - Project completion summary

## License

This project is licensed under the European Union Public License (EUPL).

## Support

For bug reports and feature requests, please open an issue on GitHub.

For questions about deployment or usage, refer to the documentation files in this repository.
