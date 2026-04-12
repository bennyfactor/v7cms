# API Reference

Interactive API documentation is also available at `/api/docs` (Swagger UI).

All authenticated endpoints require an active session (via OAuth login). Write endpoints also require the `X-Requested-With: XMLHttpRequest` header.

## System

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/health` | No | Health check with database status |
| `GET` | `/api/version` | No | Current v7cms version |
| `GET` | `/api/docs` | No | Swagger UI documentation |
| `GET` | `/api-spec.json` | No | OpenAPI spec (JSON) |

## Authentication

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/auth/google_oauth2` | No | Initiate Google OAuth flow |
| `GET` | `/auth/github` | No | Initiate GitHub OAuth flow |
| `GET` | `/auth/:provider/callback` | No | OAuth callback handler |
| `GET` | `/auth/failure` | No | OAuth failure handler |
| `GET` | `/api/auth/me` | No | Current user info (returns `logged_in: false` if unauthenticated) |
| `POST` | `/api/auth/logout` | Yes | Logout and clear session |

## Posts

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/posts` | No | List published posts (paginated) |
| `GET` | `/api/posts?include_drafts=true` | Yes | List all posts including drafts |
| `GET` | `/api/posts/:id` | No | Get post by ID or slug |
| `POST` | `/api/posts` | Yes | Create post |
| `PUT` | `/api/posts/:id` | Yes | Update post |
| `DELETE` | `/api/posts/:id` | Yes | Delete post |
| `PUT` | `/api/posts/:id/status` | Yes | Update post status (draft/ready) |
| `POST` | `/api/posts/:id/publish` | Yes | Publish a post (creates published version) |
| `POST` | `/api/posts/:id/unpublish` | Yes | Unpublish a post |

## Pages

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/pages` | No | List published pages (paginated) |
| `GET` | `/api/pages?include_drafts=true` | Yes | List all pages including drafts |
| `GET` | `/api/pages?nested=true` | No | List pages in hierarchical structure |
| `GET` | `/api/pages/types` | No | List available page types |
| `GET` | `/api/pages/:id` | No | Get page by ID or slug |
| `POST` | `/api/pages` | Yes | Create page |
| `PUT` | `/api/pages/:id` | Yes | Update page |
| `DELETE` | `/api/pages/:id` | Yes | Delete page |
| `PUT` | `/api/pages/:id/status` | Yes | Update page status |
| `POST` | `/api/pages/:id/publish` | Yes | Publish a page |
| `POST` | `/api/pages/:id/unpublish` | Yes | Unpublish a page |

## Comments

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/posts/:id/comments` | No | List approved comments for a post |
| `POST` | `/api/posts/:id/comments` | No | Submit comment (requires reCAPTCHA) |
| `GET` | `/api/comments` | Yes | List all comments with filters (`?status=pending\|approved\|spam`) |
| `GET` | `/api/comments/pending_count` | No | Count of pending comments |
| `PUT` | `/api/comments/:id/approve` | Yes | Approve comment |
| `PUT` | `/api/comments/:id/spam` | Yes | Mark comment as spam |
| `DELETE` | `/api/comments/:id` | Yes | Delete comment |

## Users

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/users` | Yes | List all users |
| `PUT` | `/api/users/:id` | Yes | Update user admin status |

## Settings

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/settings` | No | Get current settings |
| `PUT` | `/api/settings` | Yes | Update settings |
| `POST` | `/api/settings/reset` | Yes | Reset to defaults |
| `GET` | `/api/settings/layouts` | No | List available homepage layouts |
| `GET` | `/api/settings/post-layouts` | No | List available post layouts |

## Theme

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/theme` | No | Get current theme settings |
| `PUT` | `/api/theme` | Yes | Update theme (regenerates CSS) |
| `POST` | `/api/theme/reset` | Yes | Reset theme to defaults |
| `GET` | `/api/theme/preview` | No | Preview theme with query params |

## Tags

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/tags` | No | List all tags with post counts |
| `POST` | `/api/tags` | Yes | Create tag |
| `PUT` | `/api/tags/:id` | Yes | Rename tag |
| `DELETE` | `/api/tags/:id` | Yes | Delete tag (fails if posts attached) |

## Redirects

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/redirects` | Yes | List all redirects |
| `POST` | `/api/redirects` | Yes | Create redirect |
| `PUT` | `/api/redirects/:id` | Yes | Update redirect |
| `DELETE` | `/api/redirects/:id` | Yes | Delete redirect |

## Menus

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/menus` | Yes | List all menus |
| `GET` | `/api/menus/:id` | Yes | Get menu by ID or slug with nested items |
| `POST` | `/api/menus` | Yes | Create menu |
| `PUT` | `/api/menus/:id` | Yes | Update menu |
| `DELETE` | `/api/menus/:id` | Yes | Delete menu |
| `POST` | `/api/menus/:id/items` | Yes | Add item to menu |
| `PUT` | `/api/menu-items/:id` | Yes | Update menu item |
| `DELETE` | `/api/menu-items/:id` | Yes | Delete menu item |
| `PUT` | `/api/menus/:id/reorder` | Yes | Reorder menu items |

## Assets / Uploads

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/assets/capabilities` | No | Check image processing support and max upload size |
| `GET` | `/api/assets` | No | List assets (paginated, filterable by type/search) |
| `GET` | `/api/assets/:id` | No | Get single asset |
| `POST` | `/api/assets` | Yes | Upload new asset (multipart form) |
| `PUT` | `/api/assets/:id` | Yes | Update asset metadata (alt_text) |
| `DELETE` | `/api/assets/:id` | Yes | Delete asset and file |
| `GET` | `/upload/*` | No | Serve uploaded file (supports image transforms via query params) |

## Content Versions

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/posts/:id/versions` | Yes | List versions for a post (`?all=true` includes auto-versions) |
| `GET` | `/api/posts/:id/versions/:num` | Yes | Get specific post version with content |
| `POST` | `/api/posts/:id/versions/:num/restore` | Yes | Restore post to version |
| `POST` | `/api/posts/:id/versions/:num/keep` | Yes | Mark version as permanent |
| `GET` | `/api/pages/:id/versions` | Yes | List versions for a page |
| `GET` | `/api/pages/:id/versions/:num` | Yes | Get specific page version with content |
| `POST` | `/api/pages/:id/versions/:num/restore` | Yes | Restore page to version |
| `POST` | `/api/pages/:id/versions/:num/keep` | Yes | Mark version as permanent |

## Forms

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/forms` | Yes | List all forms |
| `GET` | `/api/forms/:id` | Yes | Get form with fields |
| `POST` | `/api/forms` | Yes | Create form |
| `PUT` | `/api/forms/:id` | Yes | Update form |
| `DELETE` | `/api/forms/:id` | Yes | Delete form |
| `POST` | `/api/forms/:id/fields` | Yes | Add field to form |
| `PUT` | `/api/form-fields/:id` | Yes | Update form field |
| `DELETE` | `/api/form-fields/:id` | Yes | Delete form field |
| `PUT` | `/api/forms/:id/reorder-fields` | Yes | Reorder form fields |

## Form Submissions

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/forms/:id/submissions` | Yes | List submissions (filterable: `?filter=spam\|not_spam`) |
| `GET` | `/api/forms/:id/submissions/export` | Yes | Export submissions as CSV |
| `GET` | `/api/forms/:id/submissions/:submission_id` | Yes | Get single submission |
| `DELETE` | `/api/forms/:id/submissions/:submission_id` | Yes | Delete submission |
| `GET` | `/forms/:slug` | No | Display public form page |
| `POST` | `/forms/:slug/submit` | No | Submit form data (reCAPTCHA optional per form config) |

## Feeds

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/feed/rss` | No | RSS 2.0 feed |
| `GET` | `/feed/atom` | No | Atom feed |
