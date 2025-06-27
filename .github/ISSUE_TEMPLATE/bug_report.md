---
name: Bug report
about: Create a report to help us improve Thumbsy
title: '[BUG] '
labels: ['bug', 'needs-triage']
assignees: ''

---

## Bug Description
**Describe the bug**
A clear and concise description of what the bug is.

## Steps to Reproduce
**Steps to reproduce the behavior:**
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Expected Behavior
**What you expected to happen**
A clear and concise description of what you expected to happen.

## Actual Behavior
**What actually happened**
A clear and concise description of what actually happened instead.

## Environment Information
**Please complete the following information:**
- Ruby version: [e.g. 3.3.0]
- Rails version: [e.g. 7.1.0]
- Thumbsy version: [e.g. 1.0.0]
- Database adapter: [e.g. postgresql, mysql2, sqlite3]
- Operating System: [e.g. macOS, Linux, Windows]

## Thumbsy Configuration
**Which Thumbsy features are you using?**
- [ ] Core ActiveRecord functionality only
- [ ] Optional API endpoints
- [ ] Custom authentication setup
- [ ] Custom authorization setup

**Relevant configuration:**
```ruby
# Paste your Thumbsy configuration here
# (Remove any sensitive information like API keys)
```

## Code Examples
**Minimal code example that reproduces the issue:**
```ruby
# Your code here
```

**Models involved:**
```ruby
# Your model definitions
class YourModel < ApplicationRecord
  votable # or voter
end
```

## Error Messages
**Full error message and stack trace:**
```
Paste the complete error message and stack trace here
```

## Additional Context
**Add any other context about the problem here.**
- Any relevant log entries
- Screenshots (if applicable)
- Links to related issues
- Workarounds you've tried

## Possible Solution
**If you have ideas on how to fix the issue, please describe them here.**

---

### Checklist
- [ ] I have searched existing issues to ensure this is not a duplicate
- [ ] I have included all relevant environment information
- [ ] I have provided a minimal code example that reproduces the issue
- [ ] I have included the complete error message and stack trace
- [ ] I am using a supported version of Ruby (3.3+) and Rails (7.0+)
