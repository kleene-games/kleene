# Contributing to Kleene

Thanks for your interest in contributing to Kleene! This guide will help you get started.

## Ways to Contribute

- **Create Scenarios** - Share your interactive adventures
- **Improve Documentation** - Help make Kleene easier to learn
- **Report Bugs** - Found an issue? Let us know
- **Suggest Features** - Ideas for making Kleene better
- **Code Contributions** - Fix bugs or add features

## Contributing Scenarios

We love community-created scenarios! Here's how to contribute:

### Scenario Quality Guidelines

**Before submitting:**
1. **Playtest at multiple temperatures** (0, 5, 10)
2. **Run validation:** `/kleene analyze your_scenario`
3. **Check for dead ends** - Ensure all paths lead somewhere
4. **Add content warnings** if needed (violence, mature themes, etc.)
5. **Include metadata:**
   - Name and description
   - Estimated playtime
   - Difficulty level (beginner/intermediate/advanced)
   - Your name/credit

**Scenario checklist:**
- [ ] YAML syntax is valid
- [ ] All node references resolve
- [ ] At least one ending defined
- [ ] Preconditions/consequences work correctly
- [ ] No typos or formatting issues
- [ ] Tested at temp 0, 5, and 10
- [ ] Content warnings added (if applicable)

### How to Submit a Scenario

1. **Fork the repository**
2. **Add your scenario** to `scenarios/your_scenario.yaml`
3. **Update the registry** in `scenarios/registry.yaml`:
   ```yaml
   your_scenario:
     name: "Your Scenario Name"
     description: "Brief description (1-2 sentences)"
     path: "your_scenario.yaml"
     author: "Your Name"
     difficulty: "beginner"  # or intermediate, advanced
     estimated_playtime: 20-30
     content_warnings: []  # Add if needed
     tags: ["fantasy", "mystery"]  # Genre tags
     enabled: true
   ```
4. **Create a pull request** with description of your scenario
5. **Respond to feedback** from reviewers

### Scenario Best Practices

- **Start simple** - Test core loop before adding complexity
- **Work backward** - Design endings first, then paths to reach them
- **Use templates** - See `scenarios/TEMPLATES/` for examples
- **Improvisation-friendly** - Design for both scripted and free-form play
- **Test edge cases** - What if player does something unexpected?
- **Respect player agency** - Avoid railroading or false choices

## Code Contributions

### Development Setup

1. Clone the repository
2. Familiarize yourself with the codebase structure:
   ```
   .claude-plugin/     # Plugin manifest
   commands/           # Gateway command
   skills/             # Game skills (play, generate, analyze)
   lib/framework/      # Core documentation
   scenarios/          # Bundled scenarios
   hooks/              # Pre-tool hooks
   ```

3. Read the framework documentation in `lib/framework/`

### Code Standards

- **Markdown documentation** - Clear, concise, well-formatted
- **YAML scenarios** - Valid syntax, proper indentation
- **Follow conventions** - See `lib/framework/presentation.md`
- **Test thoroughly** - Playtest changes at multiple temperatures

### Pull Request Process

1. **Create a feature branch** - `git checkout -b feature/your-feature`
2. **Make your changes** - Follow code standards
3. **Test thoroughly** - Ensure nothing breaks
4. **Update documentation** - If you change behavior
5. **Commit with clear messages** - "Add feature X" or "Fix bug Y"
6. **Push and create PR** - Describe what and why
7. **Respond to review** - Address feedback constructively

### Commit Message Format

```
type: Brief description (50 chars or less)

Longer explanation if needed (wrap at 72 chars).

Fixes #123
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code restructuring
- `test:` Test additions/changes
- `chore:` Build/tool changes

## Reporting Bugs

Found a bug? Please include:

1. **Description** - What happened vs. what you expected
2. **Steps to reproduce** - How to trigger the bug
3. **Scenario** - Which scenario (if applicable)
4. **Temperature** - What temperature setting (if relevant)
5. **Error messages** - Copy/paste any errors
6. **Environment** - OS, Claude Code version

**Create an issue on GitHub** with this information.

## Suggesting Features

Have an idea? Great! Please include:

1. **Problem** - What problem does this solve?
2. **Solution** - How would this work?
3. **Alternatives** - What else did you consider?
4. **Examples** - How would users interact with it?

**Open a GitHub issue** with the "feature request" label.

## Testing Expectations

### For Scenarios
- Playtest at temperatures 0, 5, and 10
- Run `/kleene analyze` and address issues
- Test all ending paths
- Verify preconditions work correctly
- Check for typos and formatting

### For Code Changes
- Test affected skills/commands
- Verify backward compatibility
- Check edge cases
- Ensure documentation is current

## Code of Conduct

- **Be respectful** - Treat everyone with kindness
- **Be constructive** - Provide helpful feedback
- **Be patient** - We're all learning
- **Have fun!** - This is about creativity and games

## Questions?

- **GitHub Issues** - For bugs and features
- **Discussions** - For questions and ideas
- **Documentation** - Check `docs/` folder first

## License

By contributing, you agree your contributions will be licensed under the MIT License (same as the project).

---

Thank you for making Kleene better! 🎮✨
