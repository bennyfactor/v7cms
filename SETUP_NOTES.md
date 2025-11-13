# Production Setup Notes

## Quick Setup (Recommended)

After deploying to production for the first time:

1. **Run setup.php** - Visit `https://yourdomain.com/setup.php` in your browser
   - Detects your Ruby path
   - Updates the shebang in `index.fcgi`
   - Sets correct permissions
   - Deletes itself for security

2. **Build Tailwind CSS** - SSH into your server and run:
   ```bash
   cd /path/to/v7cms

   # Download Tailwind CLI (Linux x64)
   curl -sLO https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-linux-x64
   chmod +x tailwindcss-linux-x64
   mkdir -p bin
   mv tailwindcss-linux-x64 bin/tailwindcss

   # Build the CSS
   ./bin/tailwindcss -i public/css/input.css -o public/css/output.css --minify
   ```

3. Done! Your app should now work with full styling.

## Manual Setup (Alternative)

If you prefer manual setup or the PHP script doesn't work:

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

# 4. Download and build Tailwind CSS
curl -sLO https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-linux-x64
chmod +x tailwindcss-linux-x64
mkdir -p bin
mv tailwindcss-linux-x64 bin/tailwindcss
./bin/tailwindcss -i public/css/input.css -o public/css/output.css --minify

# 5. Remove setup.php for security
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

**No styling / unstyled page:**
- Tailwind CSS hasn't been built
- Run: `./bin/tailwindcss -i public/css/input.css -o public/css/output.css --minify`
- Check that `public/css/output.css` exists after building

**setup.php shows errors:**
- Check file permissions (files should be readable/writable by web server)
- Verify Ruby is installed and accessible
- SSH in and run setup commands manually

**bin/tailwindcss not found:**
- Download it: `curl -sLO https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-linux-x64`
- Make executable: `chmod +x tailwindcss-linux-x64`
- Create bin dir: `mkdir -p bin`
- Move to bin: `mv tailwindcss-linux-x64 bin/tailwindcss`

## Security Note

`setup.php` deletes itself after successful setup. If you need to re-run it,
you'll need to re-upload it or recreate it from git.
