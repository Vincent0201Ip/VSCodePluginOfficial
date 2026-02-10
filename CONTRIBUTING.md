# Contributing to PowerToys Run VS Code Plugin

Thank you for your interest in contributing to this project! We welcome contributions from the community.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Guidelines](#coding-guidelines)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)

## 🤝 Code of Conduct

This project follows a simple code of conduct: be respectful, be constructive, and help make this project better for everyone.

## 💡 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title**: Describe the issue concisely
- **Steps to reproduce**: List the exact steps to reproduce the problem
- **Expected behavior**: What you expected to happen
- **Actual behavior**: What actually happened
- **Environment**: 
  - Windows version
  - PowerToys version
  - Plugin version
  - VS Code version (if applicable)
- **Screenshots**: If applicable

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- **Clear description**: Explain the enhancement in detail
- **Use case**: Why would this be useful?
- **Possible implementation**: If you have ideas on how to implement it
- **Examples**: Show examples of similar features in other tools

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes (see [Coding Guidelines](#coding-guidelines))
4. Test your changes thoroughly
5. Commit with clear messages: `git commit -m 'Add amazing feature'`
6. Push to your fork: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 🔧 Development Setup

### Prerequisites

- [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
- [PowerToys](https://github.com/microsoft/PowerToys/releases) (0.97.0 or later)
- [Git](https://git-scm.com/)
- Visual Studio 2022 or Visual Studio Code (optional)

### Setup Steps

1. **Clone your fork:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/PowerToys-VSCode-Plugin.git
   cd PowerToys-VSCode-Plugin
   ```

2. **Restore dependencies:**
   ```bash
   dotnet restore
   ```

3. **Build the project:**
   ```bash
   .\build.ps1
   ```

4. **Install for testing:**
   ```bash
   .\install-simple.ps1
   ```

5. **Restart PowerToys** and test your changes

### Project Structure

```
PowerToys-VSCode-Plugin/
├── Community.PowerToys.Run.Plugin.VSCodePluginOfficial/
│   ├── Main.cs                    # Main plugin class
│   ├── Services/
│   │   ├── VSCodeProjectLoader.cs # VS Code project loading
│   │   └── SSHConfigParser.cs     # SSH config parsing
│   ├── Models/
│   │   ├── VSCodeProject.cs       # Project model
│   │   └── SSHConfigEntry.cs      # SSH entry model
│   ├── Images/                    # Plugin icons
│   └── plugin.json                # Plugin metadata
├── Community.PowerToys.Run.Plugin.VSCodePluginOfficial.UnitTests/
│   └── MainTests.cs               # Unit tests
└── TestLoader/                    # Test loader project
```

## 📝 Coding Guidelines

### C# Code Style

- **Follow .NET conventions**: Use standard C# naming conventions
- **Use meaningful names**: Variables, methods, and classes should have descriptive names
- **Add XML documentation**: All public APIs should have XML doc comments
- **Handle errors gracefully**: Use try-catch blocks and provide user-friendly error messages
- **Keep methods focused**: Each method should do one thing well

### Example:

```csharp
/// <summary>
/// Searches for VS Code projects matching the search term.
/// </summary>
/// <param name="search">The search term to filter projects.</param>
/// <returns>A list of matching VS Code project results.</returns>
private List<Result> SearchVSCodeProjects(string search)
{
    try
    {
        var projects = _projectLoader.LoadProjects();
        // Implementation...
    }
    catch (Exception ex)
    {
        // Handle error gracefully
        return CreateErrorResult(ex);
    }
}
```

### Commit Messages

Write clear, descriptive commit messages:

- **Format**: `[Type] Brief description`
- **Types**: 
  - `[Feature]` - New feature
  - `[Fix]` - Bug fix
  - `[Refactor]` - Code refactoring
  - `[Docs]` - Documentation changes
  - `[Test]` - Test additions/changes
  - `[Chore]` - Maintenance tasks

**Examples:**
```
[Feature] Add support for VS Code Insiders
[Fix] Resolve SSH config parsing error with special characters
[Docs] Update installation instructions in README
[Refactor] Improve error handling in VSCodeProjectLoader
```

### Testing

- Test your changes with both x64 and ARM64 builds (if possible)
- Test with different VS Code configurations:
  - No VS Code installed
  - Local projects only
  - Remote SSH projects
  - Mixed local and remote
- Test SSH functionality:
  - With and without SSH config
  - Various SSH config formats
- Test edge cases and error scenarios

### Performance Considerations

- Use the existing caching mechanism (5-minute cache)
- Avoid blocking the UI thread
- Minimize file I/O operations
- Use LINQ efficiently (avoid multiple enumerations)

## 🚀 Submitting Changes

### Before Submitting

1. **Test thoroughly**: Ensure your changes work as expected
2. **Update documentation**: Update README.md if needed
3. **Add tests**: Include unit tests for new features (when applicable)
4. **Check code quality**: Review your code for potential improvements
5. **Build successfully**: Ensure `.\build.ps1` completes without errors

### Pull Request Guidelines

**Title Format:**
```
[Type] Brief description of changes
```

**Description Template:**
```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
Describe how you tested these changes.

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated (if needed)
- [ ] Tests added/updated (if applicable)
- [ ] Build passes without errors
- [ ] Tested with PowerToys Run
```

### Review Process

1. Maintainers will review your PR
2. Address any requested changes
3. Once approved, your PR will be merged
4. Your contribution will be credited in the next release

## 🐛 Reporting Bugs

### Bug Report Template

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '...'
3. Type '...'
4. See error

**Expected behavior**
What you expected to happen.

**Screenshots**
If applicable, add screenshots.

**Environment:**
- OS: Windows [version]
- PowerToys: [version]
- Plugin: [version]
- VS Code: [version]

**Additional context**
Any other relevant information.
```

## 💡 Suggesting Enhancements

### Enhancement Request Template

```markdown
**Is your feature request related to a problem?**
A clear description of the problem.

**Describe the solution you'd like**
A clear description of what you want to happen.

**Describe alternatives you've considered**
Any alternative solutions or features you've considered.

**Additional context**
Any other context or screenshots about the feature request.
```

## ❓ Questions?

If you have questions about contributing:

1. Check existing [issues](https://github.com/Vincent0201Ip/PowerToys-VSCode-Plugin/issues)
2. Open a new issue with the `question` label
3. Reach out to [@Vincent0201Ip](https://github.com/Vincent0201Ip)

## 🙏 Recognition

Contributors will be recognized in:
- The project README
- Release notes
- GitHub contributors page

Thank you for contributing to make this plugin better! 🎉
