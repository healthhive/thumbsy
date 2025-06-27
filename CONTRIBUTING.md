# Contributing to Thumbsy

Thank you for your interest in contributing to Thumbsy! We welcome contributions from everyone, whether you're fixing bugs, adding features, improving documentation, or helping with testing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Running Tests](#running-tests)
- [Code Style](#code-style)
- [Making Changes](#making-changes)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)
- [Documentation](#documentation)
- [Release Process](#release-process)

## Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow. Please be respectful and inclusive in all interactions.

## Getting Started

### Prerequisites

- Ruby 3.3+
- Rails 7.0+
- Git
- A GitHub account

### Quick Start

1. Fork the repository on GitHub
2. Clone your fork locally
3. Set up the development environment
4. Make your changes
5. Run tests
6. Submit a pull request

## Development Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/thumbsy.git
cd thumbsy
```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Set Up the Test Database

```bash
# The test suite will automatically set up the database
bundle exec rspec --help
```

### 4. Verify Installation

```bash
# Run a quick test to ensure everything works
bundle exec rspec spec/thumbsy_spec.rb
```

## Development Workflow

### Branch Naming

Use descriptive branch names:

- `feature/add-bulk-voting` - for new features
- `fix/duplicate-vote-bug` - for bug fixes
- `docs/api-examples` - for documentation updates
- `refactor/vote-model` - for refactoring

### Commit Messages

Write clear, descriptive commit messages:

```
Good examples:
- "Add bulk voting functionality"
- "Fix duplicate vote prevention bug"
- "Update API documentation with new examples"
- "Refactor vote model for better performance"

Avoid:
- "Fix bug"
- "Update code"
- "Changes"
```

## Running Tests

### Full Test Suite

```bash
# Run all tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec
```

### Specific Test Categories

```bash
# Run only core functionality tests
bundle exec rspec spec/basic_functionality_spec.rb

# Run only API tests (if API is loaded)
bundle exec rspec spec/api_functionality_spec.rb

# Run performance tests
bundle exec rspec spec/performance_spec.rb --tag performance

# Run database-specific tests
DATABASE_TESTS=true bundle exec rspec --tag database
```

### Testing Against Multiple Versions

```bash
# Test against Rails 7.0
RAILS_VERSION=7.0 bundle exec rspec

# Test against Rails 7.1
RAILS_VERSION=7.1 bundle exec rspec

# Test with PostgreSQL
# (Requires PostgreSQL running locally)
bundle exec rspec --tag database
```

### Writing Tests

- Write tests for all new functionality
- Update existing tests when modifying behavior
- Ensure tests are clear and well-documented
- Test both success and failure scenarios
- Include performance tests for significant changes

Example test structure:

```ruby
RSpec.describe "New Feature" do
  let(:user) { User.create!(name: "Test User") }
  let(:book) { Book.create!(title: "Test Book") }

  describe "#new_method" do
    it "handles the happy path" do
      result = book.new_method(user)
      expect(result).to be_truthy
    end

    it "handles edge cases" do
      expect { book.new_method(nil) }.to raise_error(ArgumentError)
    end
  end
end
```

## Code Style

We use RuboCop to enforce code style. Please ensure your code passes all style checks:

```bash
# Check code style
bundle exec rubocop

# Auto-fix simple issues
bundle exec rubocop -a

# Check specific files
bundle exec rubocop lib/thumbsy/votable.rb
```

### Key Style Guidelines

1. **Use double quotes** for strings
2. **Prefer explicit returns** in public methods
3. **Keep line length under 120 characters**
4. **Use meaningful variable names**
5. **Add comments for complex logic**
6. **Follow Rails conventions** for naming and structure

### Code Organization

- **Core functionality** goes in `lib/thumbsy/`
- **API functionality** goes in `lib/thumbsy/api/`
- **Tests** mirror the source structure in `spec/`
- **Documentation** goes in `docs/`

## Making Changes

### 1. Core Functionality Changes

If you're modifying core ActiveRecord functionality:

- Ensure backward compatibility
- Update relevant tests
- Consider performance implications
- Update documentation

### 2. API Changes

If you're modifying the optional API:

- Maintain RESTful conventions
- Ensure proper error handling
- Update API documentation
- Test with multiple authentication methods

### 3. Database Changes

If you need to modify the database schema:

- Create a new migration template
- Ensure it works with all supported databases
- Test upgrade and rollback scenarios
- Update the schema documentation

### 4. Documentation Changes

- Keep README.md focused on basic usage
- Put detailed information in `docs/`
- Update examples to use consistent model names (Book, User)
- Test all code examples

## Pull Request Process

### Before Submitting

1. **Rebase your branch** on the latest main
2. **Run the full test suite** and ensure it passes
3. **Check code style** with RuboCop
4. **Update documentation** if needed
5. **Add tests** for new functionality

### Pull Request Template

When you submit a PR, please include:

- **Description** of what the PR does
- **Motivation** for the change
- **Testing** performed
- **Breaking changes** (if any)
- **Documentation** updates needed

### Example PR Description

```markdown
## Description

Add bulk voting functionality to allow voting on multiple items at once.

## Motivation

Users requested the ability to vote on multiple books simultaneously for better UX in list views.

## Changes

- Add `vote_up_on_multiple` and `vote_down_on_multiple` methods
- Include proper transaction handling
- Add validation for bulk operations

## Testing

- Added comprehensive test suite
- Tested with 1000+ items
- Verified transaction rollback on failures

## Breaking Changes

None - this is purely additive functionality.

## Documentation Updated

- Updated README with bulk voting examples
- Added section to API guide
- Updated changelog
```

### Review Process

1. **Automated checks** must pass (CI, code style, tests)
2. **Code review** by maintainers
3. **Testing** on multiple Ruby/Rails versions
4. **Documentation review**
5. **Final approval** and merge

## Reporting Issues

### Before Reporting

1. **Search existing issues** to avoid duplicates
2. **Try the latest version** to see if it's already fixed
3. **Create a minimal reproduction** case

### Issue Types

Use the appropriate issue template:

- **Bug Report** - for functionality that doesn't work as expected
- **Feature Request** - for new functionality
- **Documentation** - for documentation improvements
- **Performance** - for performance-related issues

### Good Bug Reports Include

- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment information (Ruby, Rails, database versions)
- Minimal code example
- Complete error messages

## Documentation

### Types of Documentation

1. **README.md** - Basic usage and installation
2. **docs/api-guide.md** - Complete API documentation
3. **docs/architecture-guide.md** - Technical details
4. **docs/changelog.md** - Version history
5. **Code comments** - Explain complex logic

### Documentation Standards

- Use clear, concise language
- Include working code examples
- Test all code examples
- Keep examples consistent (use Book/User models)
- Update related documentation when making changes

### Testing Documentation

```bash
# Check for broken links
grep -r "](docs/" . --include="*.md"

# Verify code examples (manual process)
# Extract and test Ruby code blocks from documentation
```

## Release Process

For maintainers releasing new versions:

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., 1.2.3)
- **MAJOR** - Breaking changes
- **MINOR** - New features (backward compatible)
- **PATCH** - Bug fixes (backward compatible)

### Release Steps

1. **Update version** in `lib/thumbsy/version.rb`
2. **Update changelog** in `docs/changelog.md`
3. **Run full test suite** on all supported versions
4. **Build and test gem** locally
5. **Create release PR** with version bump
6. **Tag release** after PR merge
7. **Publish to RubyGems**
8. **Create GitHub release** with notes

### Release Checklist

- [ ] Version bumped in `lib/thumbsy/version.rb`
- [ ] Changelog updated with new version
- [ ] All tests passing on CI
- [ ] Documentation updated
- [ ] Gem builds successfully
- [ ] No security vulnerabilities
- [ ] Backward compatibility verified

## Getting Help

### Communication Channels

- **GitHub Issues** - for bugs and feature requests
- **GitHub Discussions** - for questions and general discussion
- **Pull Request Comments** - for code-specific discussions

### Development Questions

If you need help with development:

1. Check existing documentation
2. Look at similar implementations in the codebase
3. Ask questions in GitHub Discussions
4. Reference related issues or PRs

### Code Review Guidelines

When reviewing code:

- Be respectful and constructive
- Focus on the code, not the person
- Explain the reasoning behind suggestions
- Approve when ready, request changes when needed
- Test the changes locally when possible

## Recognition

We appreciate all contributions! Contributors will be:

- Listed in the GitHub contributors page
- Mentioned in release notes for significant contributions
- Recognized in the project documentation

Thank you for contributing to Thumbsy! 🎉
