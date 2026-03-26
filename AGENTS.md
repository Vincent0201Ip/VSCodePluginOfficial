# Agent Development Guide

This document provides essential information for coding agents working on the PowerToys Run VS Code Plugin.

## Project Overview

A PowerToys Run plugin (C# .NET 9.0) for quickly opening VS Code projects and managing SSH connections.
- **Target Framework**: .NET 9.0-windows
- **Platforms**: x64, ARM64
- **Testing Framework**: MSTest
- **Key Dependencies**: Community.PowerToys.Run.Plugin.Dependencies (0.97.0), Newtonsoft.Json (13.0.3)

## Build Commands

### Build All Platforms
```powershell
.\build.ps1                          # Build both x64 and ARM64 in Release mode
.\build.ps1 -Configuration Debug     # Build in Debug mode
.\build.ps1 -Clean                   # Clean before building
.\build.ps1 -ShowDetails             # Verbose output
```

### Build Specific Platform
```bash
dotnet build -c Release -p:Platform=x64
dotnet build -c Release -p:Platform=ARM64
```

### Build Main Plugin Project Only
```bash
dotnet build Community.PowerToys.Run.Plugin.VSCodePluginOfficial\Community.PowerToys.Run.Plugin.VSCodePluginOfficial.csproj -c Release -p:Platform=x64
```

## Test Commands

### Run All Tests
```bash
dotnet test -c Release -p:Platform=x64
dotnet test -c Release -p:Platform=ARM64
```

### Run Single Test
```bash
# Run specific test method
dotnet test --filter "FullyQualifiedName=Community.PowerToys.Run.Plugin.VSCodePluginOfficial.UnitTests.MainTests.Query_should_return_results"

# Run all tests in a class
dotnet test --filter "FullyQualifiedName~MainTests"

# Run tests by name pattern
dotnet test --filter "DisplayName~Query"
```

### Run Tests with Detailed Output
```bash
dotnet test -c Release -p:Platform=x64 -v detailed --logger:"console;verbosity=detailed"
```

## Lint/Code Analysis

This project does not currently have explicit linting configured. Follow standard C# conventions and Visual Studio Code Analysis warnings.

```bash
# Build with warnings as errors
dotnet build -c Release -p:Platform=x64 -p:TreatWarningsAsErrors=true
```

## Installation & Deployment

```powershell
.\install.ps1           # Universal installer (recommended)
.\install-simple.ps1    # Install plugin to PowerToys (requires pre-built)
.\package.ps1           # Create release packages
```

### Universal Installer (install.ps1)

The universal installer is the recommended installation method. It works on any Windows system and handles all dependencies automatically:

- **Auto-detects architecture** (x64/ARM64)
- **Checks/installs PowerToys** (with user prompt)
- **Hybrid approach**: Downloads pre-built release → falls back to build
- **Auto-installs .NET 9.0 SDK** when building from source
- **Installs plugin and restarts PowerToys**

**Usage:**
```powershell
# Basic installation
.\install.ps1

# Force build from source
.\install.ps1 -ForceBuild

# Skip PowerToys check (useful for CI/CD)
.\install.ps1 -SkipPowerToysCheck

# Skip PowerToys restart
.\install.ps1 -SkipRestart
```

### Quick Install (install-simple.ps1)

For quick installation when you have pre-built files:

```powershell
.\install-simple.ps1
```

This script assumes you've already built the plugin and copies the x64 release to PowerToys.

## Code Style Guidelines

### Namespace & File Organization
- **Namespace**: Use file-scoped namespaces (`namespace X;` not `namespace X { }`)
- **Organization**: One class per file, file name matches class name
- **Structure**: 
  - `Main.cs` - Plugin entry point (implements IPlugin, IContextMenu, IDisposable)
  - `Models/` - Data models (VSCodeProject, SSHConfigEntry)
  - `Services/` - Business logic (VSCodeProjectLoader, SSHConfigParser)

### Imports
- Use `using` directives at top of file, before namespace
- Order: System namespaces first, then third-party, then project namespaces
- Example:
```csharp
using ManagedCommon;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Wox.Plugin;
using Community.PowerToys.Run.Plugin.VSCodePluginOfficial.Models;
using Community.PowerToys.Run.Plugin.VSCodePluginOfficial.Services;
```

### Naming Conventions
- **Classes/Interfaces**: PascalCase (`VSCodeProjectLoader`, `IPlugin`)
- **Methods**: PascalCase (`LoadProjects()`, `ParseConfig()`)
- **Properties**: PascalCase (`Name`, `Description`, `LastOpened`)
- **Fields**: 
  - Private fields: _camelCase with underscore (`_projectLoader`, `_cachedProjects`)
  - Constants: PascalCase (`PluginID`, `CacheValidityMinutes`)
- **Parameters/Locals**: camelCase (`projectPath`, `entries`)

### Types & Properties
- Use **auto-properties** for simple getters/setters: `public string Name { get; set; }`
- Use **expression-bodied members** for computed properties: `public string Description => Path;`
- Use **private setters** for init-only properties: `private PluginInitContext Context { get; set; }`
- Use **readonly** for fields that don't change: `private readonly VSCodeProjectLoader _projectLoader;`
- Prefer **var** for obvious types, explicit types otherwise

### XML Documentation
- **Required** for all public classes, methods, and properties
- Use `<summary>`, `<param>`, `<returns>` tags
- Example:
```csharp
/// <summary>
/// Loads all VS Code projects from workspace storage.
/// Results are cached for 5 minutes to improve performance.
/// </summary>
/// <returns>A list of VS Code projects, sorted by last opened date (most recent first).</returns>
public List<VSCodeProject> LoadProjects()
```

### Error Handling
- Use try-catch blocks for I/O operations and external dependencies
- Log errors using `System.Diagnostics.Debug.WriteLine()` for PowerToys logs
- Fail gracefully - return empty collections rather than throwing exceptions
- Example:
```csharp
try
{
    projects.AddRange(LoadFromWorkspaceStorage());
}
catch (Exception ex)
{
    // Log and continue - don't break the plugin
    Debug.WriteLine($"Error loading projects: {ex.Message}");
}
```

### Performance Patterns
- **Caching**: Use 5-minute cache for expensive operations (file I/O, parsing)
- **LINQ**: Avoid multiple enumeration - use `.ToList()` when re-using results
- **Deduplication**: Use `.GroupBy()` with case-insensitive comparison
- **Sorting**: Sort by most recent first (`.OrderByDescending()`)

### Code Formatting
- **Indentation**: 4 spaces (no tabs)
- **Braces**: Opening brace on new line (Allman style)
- **Line Length**: No hard limit, but keep reasonable (~120 chars)
- **Blank Lines**: One blank line between methods, two between classes

## Common Patterns

### Result Creation
```csharp
new Result
{
    Title = project.Name,
    SubTitle = project.Path,
    IcoPath = IconPath,
    ContextData = project,
    Action = context => OpenProject(project)
}
```

### PowerToys Plugin Interface
- Implement `IPlugin` (required), `IContextMenu` (for right-click), `IDisposable` (for cleanup)
- `Query()` returns `List<Result>`
- `Init()` receives `PluginInitContext`
- `LoadContextMenus()` returns context menu items

## Testing Guidelines

- Use MSTest framework (`[TestClass]`, `[TestMethod]`, `[TestInitialize]`)
- Test file naming: `{ClassName}Tests.cs`
- Keep tests simple and focused on behavior
- Mock file system operations when possible

## Architecture Notes

- Plugin loads dynamically into PowerToys Run process
- Assembly resolution: Custom resolver for Newtonsoft.Json (see `Main.OnAssemblyResolve()`)
- VS Code projects loaded from: `%APPDATA%\Code\User\workspaceStorage\*.json`
- SSH config parsed from: `%USERPROFILE%\.ssh\config`
- Icon theming: Automatic light/dark mode support via PowerToys

## Key Files

- `Main.cs` (637 lines) - Plugin entry point, query handling
- `Services/VSCodeProjectLoader.cs` (465 lines) - Project discovery and caching
- `Services/SSHConfigParser.cs` (134 lines) - SSH config parsing
- `Models/VSCodeProject.cs` (38 lines) - Project data model
- `plugin.json` - Plugin metadata (name, keyword, icon path)

## Notes for Agents

1. Always test both x64 and ARM64 builds before committing
2. Maintain the 5-minute cache pattern for performance
3. Handle missing VS Code/SSH config gracefully
4. Add XML docs for all public APIs
5. Follow existing patterns for consistency
6. Test with PowerToys Run after changes (`.\install-simple.ps1` then restart PowerToys)
