# Security Policy

## Supported Versions

Security updates are provided for:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| older   | :x:                |

We recommend always running the latest version from the `main` branch.

## Reporting a Vulnerability

**Please do not open public issues for security vulnerabilities.**

To report a security vulnerability:

1. **Email**: Send details to [your-security-email@example.com]
2. **Subject**: "v7cms Security Vulnerability Report"
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

You will receive a response within 48 hours acknowledging receipt of your report.

## Security Response Process

1. **Acknowledgment**: We'll confirm receipt within 48 hours
2. **Assessment**: We'll assess severity and impact within 5 business days
3. **Fix Development**: We'll develop and test a fix
4. **Disclosure**:
   - We'll notify you when the fix is ready
   - We'll coordinate public disclosure timing
   - We'll credit you in the security advisory (unless you prefer anonymity)

## Known Security Considerations

v7cms implements multiple security layers:

### Authentication & Authorization

- **OAuth 2.0**: No password storage, delegated authentication to Google/GitHub
- **Admin Whitelist**: `ADMIN_EMAILS` environment variable controls admin access
- **Session Security**: HttpOnly, Secure (HTTPS), SameSite cookies
- **Session Secret**: Strong random secret required (64+ characters)

### CSRF Protection

- **Rack::Protection**: Enabled for all state-changing operations
- **Authenticity Token**: Required for OAuth flows and admin actions
- **Safe Methods**: GET requests are read-only

### XSS Protection

- **Rack::Protection**: XSS filtering enabled
- **Content Security Policy**: Recommended for production deployments
- **HTML Escaping**: ERB templates auto-escape by default
- **Rich Text**: Quill editor content sanitized on display

### SQL Injection Prevention

- **ActiveRecord**: Parameterized queries throughout
- **No Raw SQL**: Except for optimized CTEs (safe, parameterized)
- **Input Validation**: All models have comprehensive validations

### Rate Limiting

- **Rack::Attack**: Configurable rate limits for API endpoints
- **IP-based**: General traffic, API writes, login attempts
- **Blocklist**: Support for blocking specific IPs via environment variable
- **Shared Cache**: FileStore cache compatible with FastCGI multi-process

### File Access Protection

- **Apache .htaccess**: Blocks direct access to:
  - Ruby source files (.rb)
  - Database files (.db, .sqlite3)
  - Environment files (.env)
  - Configuration directories (config/, app/, db/)
  - Log files
- **Static Files Only**: Public directory serves only whitelisted file types

### Spam Prevention

- **reCAPTCHA v3**: Invisible bot detection for comment submissions
- **Score-based**: Configurable threshold (default 0.5)
- **Comment Moderation**: All comments require approval by default
- **Admin Review**: Moderation queue with spam/approve/delete actions

### Database Security

- **SQLite**: File-based, controlled by file system permissions
- **Backup Strategy**: Regular backups recommended, stored securely
- **No Remote Access**: SQLite doesn't expose network ports
- **Migration Safety**: All migrations tested before production deployment

### Session Management

- **Session Expiry**: Configurable session timeout
- **Logout**: Clears session data completely
- **Single Sign-On**: OAuth re-authentication required after logout
- **Admin Flag**: Verified on every admin request

## Security Best Practices

### For Developers

1. **Never commit secrets**:
   - Use `.env` for credentials (gitignored)
   - Use `.env.example` for templates only
   - Rotate secrets regularly

2. **Validate all inputs**:
   - Model validations for all user data
   - API parameter validation
   - File upload validation (when implemented)

3. **Escape all outputs**:
   - ERB auto-escapes by default
   - Use `raw()` only for trusted content
   - Sanitize rich text content

4. **Test security features**:
   - Authentication tests
   - Authorization tests
   - CSRF protection tests
   - Input validation tests

5. **Review dependencies**:
   - Run `bundle audit` regularly
   - Update gems for security patches
   - Monitor security advisories

### For Deployers

1. **Use HTTPS in production**:
   - Required for OAuth callbacks
   - Required for secure session cookies
   - Use Let's Encrypt for free certificates

2. **Secure environment variables**:
   - Set via hosting panel or `.env` file
   - `.env` should have 600 permissions (owner read/write only)
   - Never expose via web server

3. **Strong session secret**:
   ```bash
   ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
   ```

4. **Configure admin whitelist**:
   - Set `ADMIN_EMAILS` environment variable
   - Use comma-separated list of trusted emails
   - Review and update quarterly

5. **Regular backups**:
   - Database backups daily
   - Full application backups weekly
   - Test restore procedure

6. **Monitor logs**:
   - Review error logs regularly
   - Watch for unusual activity patterns
   - Set up alerting for critical errors

7. **File permissions**:
   - Application files: 644
   - Directories: 755
   - Database file: 644 (writable by web server)
   - `.env` file: 600

8. **Update regularly**:
   - Apply security updates promptly
   - Test updates in staging first
   - Keep Ruby and dependencies current

## Security Checklist

Before deploying to production:

- [ ] HTTPS enforced
- [ ] Strong session secret generated
- [ ] `.env` file has 600 permissions
- [ ] `ADMIN_EMAILS` whitelist configured
- [ ] OAuth credentials configured with production URLs
- [ ] reCAPTCHA configured with production domain
- [ ] `.htaccess` blocks sensitive files
- [ ] Database file not web-accessible
- [ ] Rate limiting configured and tested
- [ ] Backup strategy implemented
- [ ] Monitoring and logging configured
- [ ] All tests passing
- [ ] Dependencies updated (`bundle audit`)

## Vulnerability Disclosure Policy

We follow responsible disclosure practices:

1. **Private Reporting**: Security issues reported privately
2. **Coordinated Disclosure**: Fix developed before public announcement
3. **Credit**: Reporters credited in security advisories (if desired)
4. **Transparency**: Security advisories published after fixes deployed

## Security Advisories

Security advisories will be published:
- In the GitHub repository (Security tab)
- In [CHANGELOG.md](CHANGELOG.md) with `[SECURITY]` prefix
- Via release notes

## Related Resources

- [OWASP Top Ten](https://owasp.org/www-project-top-ten/)
- [Ruby on Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [Rack::Protection Documentation](https://github.com/sinatra/sinatra/tree/master/rack-protection)
- [OAuth 2.0 Security Best Practices](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)

## Contact

For security concerns, contact: [your-security-email@example.com]

For general questions, open a GitHub issue.

---

Last updated: 2025-11-27
