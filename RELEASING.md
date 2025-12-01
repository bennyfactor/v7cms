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
- `gem-release` is installed (`bundle install`)

## Release Process

### Using gem-release (Recommended)

The `gem-release` gem provides convenient commands for version bumping and tagging.

#### Quick Release (One Command)

```bash
# Bump version, commit, tag, and push in one command
gem bump --version minor --tag --push

# Or for a patch release
gem bump --version patch --tag --push
```

#### Step-by-Step Release

1. **Bump the version** (updates `lib/v7cms/version.rb` and commits):

   ```bash
   # For a patch release (0.1.0 → 0.1.1)
   gem bump --version patch

   # For a minor release (0.1.0 → 0.2.0)
   gem bump --version minor

   # For a major release (0.1.0 → 1.0.0)
   gem bump --version major

   # Or set a specific version
   gem bump --version 1.2.3
   ```

2. **Update CHANGELOG.md** (manual step):

   Edit `CHANGELOG.md`:
   - Change `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`
   - Add a new `[Unreleased]` section above it
   - Commit: `git commit -am "Update CHANGELOG for vX.Y.Z"`

3. **Create and push the tag**:

   ```bash
   gem tag --push
   ```

   This creates a git tag matching the version in `version.rb` and pushes it.

4. **Monitor the release** at:
   https://github.com/bennyfactor/v7cms/actions/workflows/publish-gem.yml

### Version Bump Options

| Command | Result |
|---------|--------|
| `gem bump --version patch` | 0.1.0 → 0.1.1 |
| `gem bump --version minor` | 0.1.0 → 0.2.0 |
| `gem bump --version major` | 0.1.0 → 1.0.0 |
| `gem bump --version 2.0.0` | Any → 2.0.0 |
| `gem bump --version pre` | 0.1.0 → 0.1.1.pre.1 |

Additional flags:
- `--tag` - Also create a git tag
- `--push` - Push commits and tags to remote
- `--skip-ci` - Add `[skip ci]` to commit message
- `--sign` - GPG sign the commit and tag

### Semantic Versioning

Follow [Semantic Versioning](https://semver.org/):

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Bug fixes, patches | PATCH | 0.1.0 → 0.1.1 |
| New features (backward compatible) | MINOR | 0.1.0 → 0.2.0 |
| Breaking changes | MAJOR | 0.1.0 → 1.0.0 |

## Manual Release Process

If you prefer not to use `gem-release`:

### 1. Update the Version

Edit `lib/v7cms/version.rb`:

```ruby
module V7CMS
  VERSION = 'X.Y.Z'
end
```

### 2. Update the Changelog

Edit `CHANGELOG.md`:

```markdown
## [Unreleased]

## [0.2.0] - 2024-12-15

### Added
- New feature description

[Unreleased]: https://github.com/bennyfactor/v7cms/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/bennyfactor/v7cms/compare/v0.1.0...v0.2.0
```

### 3. Commit and Tag

```bash
git add lib/v7cms/version.rb CHANGELOG.md
git commit -m "Bump version to X.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin main --tags
```

## Verify the Release

After the workflow completes:

1. Check [GitHub Packages](https://github.com/bennyfactor/v7cms/packages) for the published gem
2. Download the artifact from the workflow run
3. Optionally create a [GitHub Release](https://github.com/bennyfactor/v7cms/releases/new) with release notes

## Troubleshooting

### Version Mismatch Error

If the workflow fails with "Version mismatch", ensure:
- The tag is `vX.Y.Z` (with the `v` prefix)
- `lib/v7cms/version.rb` contains exactly `X.Y.Z` (without the `v`)

### Failed Tests

If tests fail during release:

1. Do not delete the tag yet
2. Fix the issue on `main`
3. Delete and recreate the tag:

   ```bash
   git tag -d vX.Y.Z
   git push origin :refs/tags/vX.Y.Z
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```

### Uncommitted Changes

`gem-release` will refuse to tag if you have uncommitted changes. Commit or stash them first:

```bash
git status
git stash  # or git commit
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

## gem-release Reference

Common commands:

```bash
# Show current version
gem bump --pretend

# Bump and see what would happen (dry run)
gem bump --version minor --pretend

# Full release workflow
gem bump --version minor --tag --push

# Just create a tag (no version bump)
gem tag

# Tag and push
gem tag --push
```

See [gem-release documentation](https://github.com/svenfuchs/gem-release) for more options.
