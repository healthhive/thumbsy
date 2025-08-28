# Release Guide

This guide explains how to use the automated release system for Thumbsy.

## Overview

The release process is fully automated and follows semantic versioning principles. When you push a git tag, the CI/CD pipeline automatically:

1. ✅ Runs all tests and linting
2. 🔄 Updates version files
3. 📦 Builds the gem package
4. 🚀 Publishes to RubyGems
5. 🏷️ Creates a GitHub release

## Prerequisites

Before you can release, you need to set up:

### 1. RubyGems API Key

1. Go to [RubyGems.org](https://rubygems.org) and sign in
2. Navigate to your profile → API Keys
3. Create a new API key
4. Add it to your GitHub repository secrets as `RUBYGEMS_API_KEY`

### 2. GitHub Permissions

The workflow needs these permissions (already configured):
- `contents: write` - to update version files
- `packages: write` - to publish to RubyGems

## Release Process

### Option 1: Automatic Version Bumping (Recommended)

Use the version bump script to automatically determine the next version based on your commit messages:

```bash
# Automatically determine bump type from commits
ruby script/bump_version.rb

# Or manually specify bump type
ruby script/bump_version.rb patch    # 1.0.0 → 1.0.1
ruby script/bump_version.rb minor    # 1.0.0 → 1.1.0
ruby script/bump_version.rb major    # 1.0.0 → 2.0.0
```

The script will:
1. Analyze commits since the last tag
2. Determine the appropriate version bump
3. Update version files
4. Create a git commit
5. Create a git tag
6. Prompt you to push the tag

### Option 2: Manual Version Management

1. **Update version files manually:**
   ```bash
   # Edit lib/thumbsy/version.rb
   VERSION = "1.0.1"

   # Edit thumbsy.gemspec
   spec.version = "1.0.1"
   ```

2. **Commit and tag:**
   ```bash
   git add lib/thumbsy/version.rb thumbsy.gemspec
   git commit -m "chore: bump version to 1.0.1"
   git tag -a v1.0.1 -m "Release 1.0.1"
   ```

3. **Push the tag:**
   ```bash
   git push origin v1.0.1
   ```

## Version Bumping Rules

The automatic version bumper follows [Conventional Commits](https://www.conventionalcommits.org/) standards:

### Patch (1.0.0 → 1.0.1)
- Bug fixes
- Documentation updates
- Performance improvements
- Any commit that doesn't add features or breaking changes

### Minor (1.0.0 → 1.1.0)
- New features
- Commits starting with `feat:` or `feature:`
- Backward-compatible enhancements

### Major (1.0.0 → 2.0.0)
- Breaking changes
- Commits with `!` in the message
- Commits containing "breaking change"
- Incompatible API changes

## Commit Message Examples

```bash
# Patch releases
git commit -m "fix: resolve memory leak in vote counting"
git commit -m "docs: update API documentation"
git commit -m "perf: optimize database queries"

# Minor releases
git commit -m "feat: add support for custom vote types"
git commit -m "feature: implement vote analytics dashboard"

# Major releases
git commit -m "feat!: change vote model to use UUIDs"
git commit -m "feat: breaking change: rename thumbsy_votes table"
```

## What Happens During Release

When you push a tag (e.g., `v1.0.1`):

1. **CI Pipeline Triggers:**
   - Runs RuboCop linting
   - Runs tests across Ruby 3.3, 3.4 and Rails 7.1, 7.2, 8.0
   - All tests must pass before release

2. **Release Job:**
   - Extracts version from tag (`1.0.1`)
   - Updates `lib/thumbsy/version.rb` and `thumbsy.gemspec`
   - Builds the gem package
   - Publishes to RubyGems
   - Creates a GitHub release with changelog

3. **GitHub Release:**
   - Automatic release notes
   - Installation instructions
   - Links to documentation
   - Technical details

## Troubleshooting

### Release Failed
- Check that all tests pass in the CI pipeline
- Verify your RubyGems API key is correct
- Ensure you have write permissions to the repository

### Version Mismatch
- The CI automatically updates version files
- If there's a mismatch, check that your tag format is correct (`v1.0.1`)
- Verify the version files are committed before tagging

### RubyGems Publishing Issues
- Check that the gem name is available on RubyGems
- Verify your API key has publishing permissions
- Ensure the gem builds successfully before publishing

## Best Practices

1. **Always use conventional commits** for automatic version bumping
2. **Test locally** before pushing tags
3. **Review the release** after it's created
4. **Keep a changelog** in your commits for better release notes
5. **Use semantic versioning** consistently

## Quick Release Checklist

- [ ] All tests pass locally
- [ ] Code is linted with RuboCop
- [ ] Version files are updated
- [ ] Changes are committed
- [ ] Git tag is created
- [ ] Tag is pushed to GitHub
- [ ] CI pipeline completes successfully
- [ ] Gem is published to RubyGems
- [ ] GitHub release is created

## Support

If you encounter issues with the release process:

1. Check the GitHub Actions logs for detailed error messages
2. Verify your repository secrets are configured correctly
3. Ensure you have the necessary permissions
4. Open an issue in the repository for complex problems

---

**Happy releasing! 🚀**
