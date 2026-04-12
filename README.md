# v7cms

[![Ruby](https://img.shields.io/badge/Ruby-3.4-red?logo=ruby)](https://www.ruby-lang.org/)
[![Sinatra](https://img.shields.io/badge/Sinatra-3.0-lightgrey?logo=ruby)](https://sinatrarb.com/)
[![License: EUPL-1.2](https://img.shields.io/badge/License-EUPL--1.2-blue.svg)](https://opensource.org/licenses/EUPL-1.2)
[![Tests](https://img.shields.io/badge/Tests-1213%20passing-brightgreen)](spec/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

A minimal content management system built with Ruby and Sinatra. SQLite storage, OAuth authentication, Alpine.js admin interface, static HTML generation for published content, and deployment via Docker or shared hosting with FastCGI.

## Quick Start

```bash
git clone https://github.com/bennyfactor/v7cms.git
cd v7cms
cp .env.example .env  # configure OAuth credentials
docker-compose up -d
docker-compose run --rm web bundle exec rake db:migrate
# Visit http://localhost:9292
```

## Documentation

- [Installation](docs/INSTALLATION.md) — gem install, local dev, configuration
- [API Reference](docs/API.md) — REST API endpoints
- [Architecture](docs/ARCHITECTURE.md) — project structure and design
- [Theme Customization](docs/THEME.md) — CSS properties reference
- [Deployment](docs/DEPLOYMENT.md) — production deployment guide
- [Troubleshooting](docs/TROUBLESHOOTING.md) — common issues
- [Contributing](CONTRIBUTING.md) — how to contribute
- [Changelog](CHANGELOG.md) — version history
- [Security](SECURITY.md) — security policy

## License

[European Union Public License (EUPL-1.2)](LICENSE)
