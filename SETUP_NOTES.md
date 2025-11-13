# Production Setup Notes

## Quick Setup (Recommended)

After deploying to production for the first time:

1. Visit `https://yourdomain.com/setup.php` in your browser
2. The script will:
   - Detect your Ruby path
   - Update the shebang in `index.fcgi`
   - Set correct permissions
   - Delete itself for security
3. Done! Your app should now work.

## Manual Setup (Alternative)

If you prefer manual setup or the PHP script doesn't work:

```bash
# SSH into your server
cd /path/to/v7cms

# Find your Ruby path
which ruby

# Update the shebang in index.fcgi (line 1)
# Change: #!/usr/bin/env ruby
# To:     #!/full/path/to/ruby

# Make it executable
chmod +x index.fcgi

# Remove setup.php for security
rm setup.php
```

## Why is this needed?

Apache/FastCGI runs with a minimal environment where `#!/usr/bin/env ruby`
cannot find rbenv's Ruby. The shebang needs the absolute path to work.

## Common Issues

**500 Error after deployment:**
- Run setup.php or manually update the shebang
- Check that .env file exists with OAuth credentials
- Verify bundle install ran successfully

**setup.php shows errors:**
- Check file permissions (files should be readable/writable by web server)
- Verify Ruby is installed and accessible
- SSH in and run setup commands manually

## Security Note

`setup.php` deletes itself after successful setup. If you need to re-run it,
you'll need to re-upload it or recreate it from git.
