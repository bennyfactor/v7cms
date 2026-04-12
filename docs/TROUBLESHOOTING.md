# Troubleshooting

## FCGI Gem Won't Compile in Development

The `fcgi` gem is only needed for production FastCGI deployment on shared hosting. It is configured with `install_if` so it only installs on Linux. If you encounter compilation issues on macOS, you can safely ignore it — it won't be required.

## FCGI Cold-Start Issues

FastCGI processes may be terminated after periods of inactivity on shared hosting. The first request after a cold start can take several seconds while the Ruby process initializes. This is expected behavior. To mitigate:

- Use a monitoring service to send periodic requests and keep the process warm
- Ensure static HTML files are generated for published content (they bypass FastCGI entirely)

## OAuth Redirect Mismatches

If you receive "redirect_uri_mismatch" errors during OAuth login:

- Verify the redirect URI in your OAuth provider matches exactly:
  - Google: `https://yourdomain.com/auth/google_oauth2/callback`
  - GitHub: `https://yourdomain.com/auth/github/callback`
- Ensure you're using HTTPS in production (OAuth providers reject HTTP callbacks)
- Check that the domain in the callback URL matches where the app is actually served
- For local development, use `http://localhost:9292/auth/google_oauth2/callback`

## Static HTML Not Generating

Published posts are rendered to static HTML at `public/posts/<slug>/index.html`, and pages are rendered at `public/pages/<full_slug_path>/index.html`. If files aren't being created:

- Verify the `public/` directory is writable by the web server process
- Run `bundle exec rake v7cms:regenerate` to manually regenerate all static files
- Check that the post/page has been published (not just set to "ready" status)
- Review application logs for rendering errors

## reCAPTCHA 401 Errors

If comment submission or form submission returns 401 errors related to reCAPTCHA:

- **Standard reCAPTCHA v3**: Verify `RECAPTCHA_SITE_KEY` and `RECAPTCHA_SECRET_KEY` are correct in `.env`
- **reCAPTCHA Enterprise**: Ensure domain restrictions are set on the reCAPTCHA site key (in the reCAPTCHA console), not on the API key. HTTP referrer restrictions on the API key cause authentication failures.
- Verify your domain is added to the reCAPTCHA key's allowed domains list
- Check that you're using the correct environment variables for your setup (standard vs. Enterprise use different variables)

## Tailwind CSS Not Updating

If styles appear stale or new classes aren't taking effect:

```bash
# Rebuild CSS
bundle exec rake v7cms:tailwind
```

The generated `output.css` is gitignored and must be built locally or during deployment.

## Database Locked Errors

SQLite allows only one writer at a time. "database is locked" errors can occur under concurrent writes:

- This is uncommon for typical CMS usage but can happen during bulk operations
- Ensure only one process is writing to the database at a time
- For high-concurrency deployments, consider using a different database backend
- Check that no stale lock files exist in the `db/` directory

## Tests Failing "Table Not Found"

The test database needs its own migrations:

```bash
RACK_ENV=test bundle exec rake db:migrate
```

## OmniAuth "Uninitialized Constant"

Ensure `require 'omniauth'` runs before `use OmniAuth::Builder` in the application. This is handled automatically when using v7cms as a gem, but may need attention if you've customized the application loading order.

## Admin Panel Shows Blank Page

- Check the browser console for JavaScript errors
- Verify the admin assets are accessible at `/js/admin.js`
- Clear browser cache and try a hard refresh
- Ensure the session cookie is being set (check that `SESSION_SECRET` is configured)
