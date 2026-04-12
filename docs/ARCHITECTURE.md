# Architecture

## Overview

v7cms is a Ruby/Sinatra CMS distributed as a gem. It uses ActiveRecord with SQLite, OmniAuth for authentication, and Alpine.js for the admin interface. Published content is rendered to static HTML files for performance.

## Project Structure

```
v7cms/
├── lib/
│   ├── v7cms.rb                    # Main gem entry point
│   └── v7cms/
│       ├── application.rb          # V7CMS::Application (Sinatra app, all routes)
│       ├── file_resolver.rb        # User-first path resolution
│       ├── version.rb              # Gem version
│       ├── config/
│       │   └── theme_fields.rb     # ThemeConfig module (field definitions)
│       ├── models/
│       │   ├── asset.rb            # File upload records
│       │   ├── comment.rb          # Post comments with moderation
│       │   ├── content_version.rb  # Version history (polymorphic)
│       │   ├── form.rb             # Form builder definitions
│       │   ├── form_field.rb       # Form field definitions
│       │   ├── form_submission.rb  # Form submission data
│       │   ├── menu.rb             # Navigation menus
│       │   ├── menu_item.rb        # Menu entries (nested)
│       │   ├── page.rb             # Static pages (hierarchical)
│       │   ├── post.rb             # Blog posts
│       │   ├── post_tag.rb         # Post-tag join table
│       │   ├── redirect.rb         # URL redirects
│       │   ├── setting.rb          # Site settings (singleton)
│       │   ├── tag.rb              # Content tags
│       │   ├── theme.rb            # Theme settings (singleton)
│       │   └── user.rb             # OAuth users
│       ├── helpers/
│       │   ├── auth_helper.rb      # Authentication (current_user, require_login)
│       │   ├── cdn_helper.rb       # CDN asset URL helpers
│       │   ├── form_helper.rb      # Form rendering helpers
│       │   └── menu_helper.rb      # Menu rendering helpers
│       ├── services/
│       │   ├── feed_generator.rb   # RSS/Atom feed generation
│       │   ├── form_mailer.rb      # Form submission email notifications
│       │   ├── form_renderer.rb    # Public form HTML rendering
│       │   ├── gravatar_service.rb # Gravatar URL generation
│       │   ├── htaccess_generator.rb # Apache .htaccess generation
│       │   ├── image_transformer.rb  # Image resize/crop (optional)
│       │   ├── page_renderer.rb    # Static HTML generation for pages
│       │   ├── post_renderer.rb    # Static HTML generation for posts
│       │   ├── storage/            # File storage adapters
│       │   └── theme_generator.rb  # CSS generation from theme settings
│       ├── views/                  # Default ERB templates
│       │   └── layouts/homepage/   # Homepage layout templates
│       ├── public/                 # Default static assets (admin UI, JS, CSS)
│       └── tasks/
│           ├── v7cms.rake          # Setup, migration, regeneration tasks
│           └── tailwind.rake       # Tailwind CSS CLI management
├── app/
│   ├── cms.rb                      # Backward compatibility aliases
│   └── docs/                       # OpenAPI/Swagger documentation
├── config/
│   └── database.yml                # Database configuration
├── db/
│   └── migrate/                    # ActiveRecord migrations
├── public/                         # Development static assets
├── spec/                           # Test suite (1213 tests)
├── v7cms.gemspec
├── Dockerfile
├── docker-compose.yml
├── Gemfile
└── config.ru
```

## File Resolver

When used as a gem, `V7CMS::FileResolver` provides user-first path resolution:

1. **Project files** (e.g., `./views/layout.erb`) take priority
2. **Gem files** (e.g., `lib/v7cms/views/layout.erb`) serve as fallback

This applies to views, public assets, and configuration files. You can override any single template without copying the entire views directory.

## Homepage Layouts

Built-in layout templates selectable via admin Settings:

| Layout | Description |
|--------|-------------|
| `blog_list` | Traditional blog format (default) |
| `blog_grid` | Grid layout with cards |
| `hero_grid` | Featured post hero + grid |
| `magazine` | Magazine-style layout |
| `minimal` | Clean, text-focused |
| `portfolio` | Visual portfolio grid |
| `landing` | Marketing landing page |

Custom layouts can be added at `views/layouts/homepage/_name.erb`.

## Request Flow

1. **Static assets** — served directly from `public/`
2. **Redirect check** — `before` filter checks non-reserved paths against redirect database
3. **Public routes** — `GET /`, `/posts/:slug`, `/pages/*`, `/feed/*`, `/forms/:slug`
4. **API routes** — `/api/*` JSON endpoints, session-authenticated
5. **Auth routes** — `/auth/*` OmniAuth OAuth flows
6. **Admin panel** — `/admin/` serves the Alpine.js SPA
7. **404 handler** — checks redirects again, then serves custom error page or ERB template

## Database Schema

### users

| Column | Type | Description |
|--------|------|-------------|
| email | string | OAuth email |
| name | string | Display name |
| provider | string | OAuth provider |
| uid | string | Provider user ID |
| avatar_url | string | Profile image URL |
| admin | boolean | Admin access flag |
| last_login_at | datetime | Last login timestamp |

### posts

| Column | Type | Description |
|--------|------|-------------|
| title | string | Post title |
| slug | string | URL identifier (unique) |
| content | text | HTML content |
| status | string | Editorial status (draft/ready) |
| published_version_id | integer | FK to published content_version |
| comments_enabled | boolean | Allow comments on this post |

### pages

| Column | Type | Description |
|--------|------|-------------|
| title | string | Page title |
| slug | string | URL identifier (unique) |
| content | text | HTML content |
| status | string | Editorial status |
| published_version_id | integer | FK to published content_version |
| page_type | string | Layout type (standard, portfolio, blog_grid, etc.) |
| content_source | string | Source for layout items (children, posts) |
| content_filter_tag_id | integer | FK to tag for filtering layout content |
| items_limit | integer | Max items to display |
| hero_image_url | string | Optional hero/thumbnail image URL |
| parent_id | integer | Parent page FK |
| position | integer | Sort order |

### comments

| Column | Type | Description |
|--------|------|-------------|
| post_id | integer | Parent post FK |
| author_name | string | Commenter name |
| author_email | string | Commenter email |
| author_url | string | Optional website |
| content | text | Comment text |
| ip_address | string | Submitter IP |
| recaptcha_score | float | reCAPTCHA score |
| approved | boolean | Moderation status |
| spam | boolean | Spam flag |

### settings (singleton)

Site configuration: title, tagline, author, welcome text, footer, SEO metadata, contact info, display options, comment settings, layout preferences, max upload size.

### themes (singleton)

40+ CSS properties organized by category: brand colors, neutrals, text hierarchy, interactive states, typography, layout/spacing, effects, and custom CSS. See [THEME.md](THEME.md) for full reference.

### tags

| Column | Type | Description |
|--------|------|-------------|
| name | string | Tag name (unique) |
| slug | string | URL-safe identifier |

### post_tags

Join table: `post_id`, `tag_id`.

### redirects

| Column | Type | Description |
|--------|------|-------------|
| short_path | string | URL path (unique) |
| target_path | string | Redirect destination |

### menus

| Column | Type | Description |
|--------|------|-------------|
| name | string | Menu name |
| slug | string | URL-safe identifier |
| location | string | Display location (header, footer, etc.) |
| menu_items_count | integer | Counter cache |

### menu_items

| Column | Type | Description |
|--------|------|-------------|
| menu_id | integer | Parent menu FK |
| label | string | Display text |
| link_type | string | Link type (custom, page, post) |
| linkable_type | string | Polymorphic type |
| linkable_id | integer | Polymorphic ID |
| url | string | Custom URL |
| target | string | Link target (_blank, etc.) |
| parent_id | integer | Parent item FK (nesting) |
| position | integer | Sort order |
| css_class | string | Optional CSS class |

### forms

| Column | Type | Description |
|--------|------|-------------|
| name | string | Form name |
| slug | string | URL-safe identifier (unique) |
| description | text | Form description |
| submit_button_text | string | Submit button label |
| success_message | string | Post-submission message |
| notification_email | string | Email for notifications |
| store_submissions | boolean | Store submissions in database |
| send_notifications | boolean | Send email notifications |
| require_recaptcha | boolean | Require reCAPTCHA verification |
| recaptcha_threshold | float | Minimum reCAPTCHA score |
| spam_behavior | string | What to do with spam (store/reject) |
| published | boolean | Publicly accessible |

### form_fields

| Column | Type | Description |
|--------|------|-------------|
| form_id | integer | Parent form FK |
| field_type | string | Input type (text, email, textarea, select, checkbox, etc.) |
| name | string | Field name |
| label | string | Display label |
| placeholder | string | Placeholder text |
| help_text | string | Help text |
| required | boolean | Required field |
| options | text | JSON options (for select/radio) |
| validation_rules | text | JSON validation rules |
| position | integer | Sort order |

### form_submissions

| Column | Type | Description |
|--------|------|-------------|
| form_id | integer | Parent form FK |
| data | text | JSON submission data |
| ip_address | string | Submitter IP |
| recaptcha_score | float | reCAPTCHA score |
| spam | boolean | Spam flag |

### assets

| Column | Type | Description |
|--------|------|-------------|
| filename | string | Stored filename |
| original_filename | string | Upload filename |
| content_type | string | MIME type |
| file_size | integer | Size in bytes |
| storage_key | string | Storage path |
| width | integer | Image width (if applicable) |
| height | integer | Image height (if applicable) |
| alt_text | string | Alt text |
| uploaded_by_id | integer | Uploader user FK |

### content_versions

| Column | Type | Description |
|--------|------|-------------|
| versionable_type | string | Polymorphic type (Post/Page) |
| versionable_id | integer | Polymorphic ID |
| version_number | integer | Sequential version number |
| title | string | Title at time of version |
| content | text | Content at time of version |
| created_by_id | integer | Author user FK |
| version_type | string | auto or manual |
| note | string | Optional version note |
