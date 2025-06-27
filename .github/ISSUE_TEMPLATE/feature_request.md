---
name: Feature request
about: Suggest an idea for Thumbsy
title: '[FEATURE] '
labels: ['enhancement', 'needs-triage']
assignees: ''

---

## Feature Description
**Is your feature request related to a problem? Please describe.**
A clear and concise description of what the problem is. Ex. I'm always frustrated when [...]

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

## Use Case
**What would you use this feature for?**
Describe the specific use case or scenario where this feature would be helpful.

**Who would benefit from this feature?**
- [ ] Users of core ActiveRecord functionality
- [ ] Users of the optional API
- [ ] Gem maintainers
- [ ] All users
- [ ] Specific use case: ___________

## Proposed Implementation
**How do you envision this feature working?**

### API Design (if applicable)
```ruby
# Show how you'd like the feature to be used
# For example:
@book.your_new_method(user, options: {})
```

### Configuration (if applicable)
```ruby
# If this requires configuration
Thumbsy.configure do |config|
  config.your_new_option = true
end
```

### Database Changes (if applicable)
- [ ] Requires new database columns
- [ ] Requires new database tables
- [ ] Requires new indexes
- [ ] No database changes needed

**Describe any database schema changes:**
```sql
-- If database changes are needed
ALTER TABLE thumbsy_votes ADD COLUMN your_new_column VARCHAR(255);
```

## Alternatives Considered
**Describe alternatives you've considered**
A clear and concise description of any alternative solutions or features you've considered.

## Compatibility Considerations
**Will this feature affect existing functionality?**
- [ ] This is a breaking change
- [ ] This is backward compatible
- [ ] This requires migration steps for existing users
- [ ] Not sure about compatibility impact

**Rails/Ruby version compatibility:**
- Should work with Rails: [e.g. 7.0+, 7.1+, 8.0+]
- Should work with Ruby: [e.g. 3.3+, 3.4+]

## Implementation Complexity
**How complex do you think this feature would be to implement?**
- [ ] Small (few lines of code)
- [ ] Medium (new methods/classes)
- [ ] Large (significant architectural changes)
- [ ] Not sure

## Additional Context
**Add any other context, screenshots, or examples about the feature request here.**

### Related Issues
- Links to related issues or discussions
- Similar features in other gems

### Example from Other Gems
```ruby
# If you've seen similar functionality elsewhere
# show how it works in other gems
```

### Mock-up or Wireframe
```
If this is a UI-related feature (like API responses),
provide examples of the expected output format
```

## Willingness to Contribute
**Would you be willing to implement this feature?**
- [ ] Yes, I can implement this feature
- [ ] Yes, but I might need guidance
- [ ] I can help with testing
- [ ] I can help with documentation
- [ ] I cannot contribute to implementation

---

### Checklist
- [ ] I have searched existing issues to ensure this is not a duplicate
- [ ] I have clearly described the use case and benefits
- [ ] I have considered backward compatibility implications
- [ ] I have provided examples of how the feature would be used
- [ ] I have considered alternative approaches
