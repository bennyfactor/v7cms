# Contributing to v7cms

Thank you for considering contributing to v7cms. This document outlines the process and guidelines for contributing to the project.

## Code of Conduct

This project follows standard open source community guidelines. Be respectful, constructive, and professional in all interactions.

## How to Contribute

### Reporting Bugs

Before creating a bug report:
- Check the [existing issues](https://github.com/your-repo/v7cms/issues) to avoid duplicates
- Test with the latest version from the `main` branch
- Verify the issue occurs in a clean environment (fresh database, no custom modifications)

When creating a bug report, include:
- Clear, descriptive title
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- Environment details (Ruby version, OS, deployment method)
- Relevant log output or error messages
- Screenshots if applicable

### Suggesting Enhancements

Enhancement suggestions are welcome. Before submitting:
- Check existing issues and pull requests for similar suggestions
- Consider if the feature fits the project's scope (minimal, maintainable CMS)
- Think about backward compatibility

When suggesting an enhancement:
- Use a clear, descriptive title
- Provide detailed explanation of the feature
- Explain why this enhancement would be useful
- Include examples of how it would work
- Consider implementation complexity

### Pull Requests

#### Development Workflow

1. **Fork the repository** and create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Set up development environment**:
   ```bash
   bundle install
   bundle exec rake db:migrate
   RACK_ENV=test bundle exec rake db:migrate
   ```

3. **Write tests** for your changes:
   - Model changes: Add tests to `spec/models/`
   - API changes: Add tests to `spec/routes/`
   - Service changes: Add tests to `spec/services/`
   - Run tests: `bundle exec rspec`

4. **Make your changes**:
   - Follow existing code style (2 spaces, Ruby community style guide)
   - Write clear commit messages
   - Keep commits focused and atomic
   - Update documentation if needed

5. **Ensure all tests pass**:
   ```bash
   bundle exec rspec
   ```
   All tests must pass before submitting a PR.

6. **Push to your fork** and create a pull request

#### Pull Request Guidelines

- **Title**: Clear, descriptive summary of changes
- **Description**:
  - What problem does this solve?
  - How does it solve it?
  - Any breaking changes?
  - Related issues (use "Fixes #123" syntax)
- **Tests**: All new code should have tests
- **Documentation**: Update relevant documentation files
- **Commits**: Clean commit history (squash if needed)

#### Code Review Process

1. Maintainer will review your PR
2. Address any requested changes
3. Once approved, maintainer will merge
4. Your contribution will be credited in CHANGELOG.md

## Development Guidelines

### Code Style

- **Indentation**: 2 spaces (no tabs)
- **Line length**: 100 characters max (soft limit)
- **String literals**: Single quotes for non-interpolated strings
- **Method names**: snake_case
- **Class names**: CamelCase
- **Constants**: SCREAMING_SNAKE_CASE

### Ruby Style Guide

Follow the [Ruby Style Guide](https://rubystyle.guide/) with these project-specific conventions:
- Use `def method_name` (not `def method_name()`)
- Prefer `&&` and `||` over `and` and `or`
- Use `fail` for exceptions, `raise` for re-raising
- Prefer `each` over `for`

### Testing Guidelines

- **Write tests first** (TDD preferred)
- **Test coverage**: Aim for 90%+ coverage of new code
- **Test types**:
  - **Model tests**: Validations, associations, scopes, methods
  - **Route tests**: API endpoints, authentication, error handling
  - **Service tests**: File operations, error scenarios
  - **Integration tests**: Complete workflows

### Testing Best Practices

```ruby
# Good: Descriptive test names
it "generates unique slug from title" do
  post = Post.create(title: "Hello World")
  expect(post.slug).to eq("hello-world")
end

# Good: Test one thing per test
it "validates presence of title" do
  post = Post.new(title: nil)
  expect(post).not_to be_valid
  expect(post.errors[:title]).to include("can't be blank")
end

# Good: Use let for test data
let(:user) { User.create(email: "test@example.com") }
let(:post) { Post.create(title: "Test", author: user) }

# Good: Clean up after tests (DatabaseCleaner handles this)
```

### Documentation Standards

Update documentation when:
- Adding new features
- Changing API endpoints
- Modifying configuration options
- Updating dependencies
- Changing deployment procedures

Documentation files to update:
- **README.md**: User-facing features and API changes
- **CLAUDE.md**: Architecture and development details
- **docs/DEPLOYMENT.md**: Deployment-related changes
- **CHANGELOG.md**: All changes (added by maintainer during merge)

### Commit Message Format

Use clear, descriptive commit messages:

```
Short summary (50 chars or less)

Detailed explanation if needed. Wrap at 72 characters.
Explain what changed and why, not how.

- Bullet points are fine
- Use present tense ("Add feature" not "Added feature")
- Reference issues: Fixes #123
```

Examples:
```
Add pagination to Posts API

Implements limit/offset pagination for GET /api/posts to handle
large post collections efficiently. Default limit is 20, max is 100.

Fixes #45
```

```
Fix N+1 query in Page#ancestors

Replaces recursive queries with a single CTE query, reducing
database load for hierarchical page structures.
```

### Feature Branch Naming

Use descriptive branch names:
- `feature/name` - New features
- `fix/name` - Bug fixes
- `refactor/name` - Code refactoring
- `docs/name` - Documentation updates
- `test/name` - Test improvements

Examples:
- `feature/comment-pagination`
- `fix/slug-generation-unicode`
- `refactor/theme-service`
- `docs/update-api-reference`

## Project Structure

Understanding the codebase:

```
app/
  cms.rb                  # Main Sinatra application
  models/                 # ActiveRecord models
  services/               # Business logic (renderers, generators)
  config/                 # Configuration modules
  helpers/                # Helper modules
  views/                  # ERB templates

spec/                     # RSpec tests
  models/                 # Model tests
  routes/                 # API/route tests
  services/               # Service tests
  helpers/                # Helper tests
  spec_helper.rb          # Test configuration

db/
  migrate/                # Database migrations
  seed.rb                 # Sample data

public/                   # Static assets
  posts/                  # Generated post HTML
  pages/                  # Generated page HTML
  css/                    # Stylesheets
  js/                     # JavaScript

admin/                    # Admin SPA
  index.html              # Admin interface
```

## Testing Your Changes

### Run All Tests

```bash
bundle exec rspec
```

### Run Specific Tests

```bash
# Single file
bundle exec rspec spec/models/post_spec.rb

# Single test (by line number)
bundle exec rspec spec/models/post_spec.rb:25

# With documentation format
bundle exec rspec --format documentation
```

### Test in Browser

```bash
# Start development server
bundle exec rackup -p 9292

# Visit:
# - Public site: http://localhost:9292
# - Admin: http://localhost:9292/admin/
```

### Test with Docker

```bash
# Run tests in Docker
docker-compose run --rm web bundle exec rspec

# Start development environment
docker-compose up -d
```

## First-Time Contributors

Good first issues:
- Documentation improvements
- Test coverage improvements
- Bug fixes with existing test cases
- UI/UX enhancements to admin interface

Look for issues labeled `good-first-issue` or `help-wanted`.

## Questions?

- Check [CLAUDE.md](CLAUDE.md) for architecture details
- Check [README.md](README.md) for usage information
- Check existing issues and pull requests
- Open a new issue for questions

## License

By contributing to v7cms, you agree that your contributions will be licensed under the European Union Public License (EUPL).

---

Thank you for contributing to v7cms!
