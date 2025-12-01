# Releasing v7cms

This document describes the process for releasing new versions of the v7cms gem.

## Overview

Releases are automated via GitHub Actions. When you push a version tag (e.g., `v0.1.0`), the workflow will:

1. Verify the tag version matches `lib/v7cms/version.rb`
2. Run the full test suite
3. Build the gem
4. Publish to GitHub Packages
5. Upload the `.gem` file as a build artifact

## Prerequisites

- You have push access to the repository
- All changes are merged to `main`
- Tests are passing on `main`

## Release Process

### 1. Determine the Version Number

Follow [Semantic Versioning](https://semver.org/):

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Bug fixes, patches | PATCH | 0.1.0 → 0.1.1 |
| New features (backward compatible) | MINOR | 0.1.0 → 0.2.0 |
| Breaking changes | MAJOR | 0.1.0 → 1.0.0 |

### 2. Update the Version

Edit `lib/v7cms/version.rb`:

```ruby
module V7CMS
  VERSION = 'X.Y.Z'
end
```

### 3. Update the Changelog

Edit `CHANGELOG.md`:

1. Change `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`
2. Add a new `[Unreleased]` section above it
3. Update the comparison links at the bottom

Example:
```markdown
## [Unreleased]

## [0.2.0] - 2024-12-15

### Added
- New feature description

[Unreleased]: https://github.com/bennyfactor/v7cms/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/bennyfactor/v7cms/compare/v0.1.0...v0.2.0
```

### 4. Commit the Version Bump

```bash
git add lib/v7cms/version.rb CHANGELOG.md
git commit -m "Bump version to X.Y.Z"
git push origin main
```

### 5. Create and Push the Tag

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z - Brief description"
git push origin vX.Y.Z
```

**Important:** The tag must start with `v` and match the version in `version.rb` exactly.

### 6. Monitor the Release

Watch the GitHub Action at:
https://github.com/bennyfactor/v7cms/actions/workflows/publish-gem.yml

The workflow will:
- Fail fast if the tag doesn't match `version.rb`
- Run all tests
- Build and publish the gem

### 7. Verify the Release

After the workflow completes:

1. Check [GitHub Packages](https://github.com/bennyfactor/v7cms/packages) for the published gem
2. Download the artifact from the workflow run to verify the `.gem` file
3. Optionally create a [GitHub Release](https://github.com/bennyfactor/v7cms/releases/new) with release notes

## Quick Reference

For the current version `0.1.0`, run:

```bash
# Ensure you're on main with latest
git checkout main
git pull origin main

# Create and push the tag
git tag -a v0.1.0 -m "Release v0.1.0 - Initial gem release"
git push origin v0.1.0
```

## Troubleshooting

### Version Mismatch Error

If the workflow fails with "Version mismatch", ensure:
- The tag is `vX.Y.Z` (with the `v` prefix)
- `lib/v7cms/version.rb` contains exactly `X.Y.Z` (without the `v`)

### Failed Tests

If tests fail during release:
1. Do not delete the tag
2. Fix the issue on `main`
3. Delete and recreate the tag:
   ```bash
   git tag -d vX.Y.Z
   git push origin :refs/tags/vX.Y.Z
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```

### Manual Gem Build

To build the gem locally without publishing:

```bash
gem build v7cms.gemspec
# Creates v7cms-X.Y.Z.gem
```

## Installing from GitHub Packages

Users can install the gem by adding to their Gemfile:

```ruby
source 'https://rubygems.pkg.github.com/bennyfactor' do
  gem 'v7cms', '~> X.Y'
end
```

Or install directly:

```bash
gem install v7cms --source "https://rubygems.pkg.github.com/bennyfactor"
```
