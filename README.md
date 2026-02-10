# PowerToys Run - VS Code Plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![.NET](https://img.shields.io/badge/.NET-9.0-purple.svg)](https://dotnet.microsoft.com/download)
[![PowerToys](https://img.shields.io/badge/PowerToys-0.97.0+-blue.svg)](https://github.com/microsoft/PowerToys)

A powerful PowerToys Run plugin for quickly opening VS Code projects and managing SSH connections directly from your launcher.

## ✨ Features

- 🔍 **Quick Project Access**: Search and open all your VS Code projects from workspace storage
- 📡 **SSH Connection Manager**: Browse and connect to SSH hosts from your `~/.ssh/config`
- 🌐 **Remote Development Support**: Works with VS Code Remote SSH projects
- 🚀 **Smart Caching**: Projects and SSH configs are cached for 5 minutes for blazing-fast searches
- 📋 **Context Menu Actions**: 
  - Copy project paths
  - Open projects in File Explorer
  - Copy SSH commands
- 🎨 **Theme Support**: Automatic light/dark icon switching

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Building from Source](#building-from-source)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🔧 Prerequisites

- **Windows 10/11** (any recent version)
- **PowerToys** version 0.97.0 or later ([Download](https://github.com/microsoft/PowerToys/releases))
- **.NET 9.0 Runtime** (usually included with PowerToys)
- **Visual Studio Code** (optional, for opening projects)

## 📦 Installation

### Option 1: From Release (Recommended)

1. Download the latest release from the [Releases](https://github.com/Vincent0201Ip/PowerToys-VSCode-Plugin/releases) page
2. Extract the ZIP file
3. Copy all files to:
   ```
   %LOCALAPPDATA%\Microsoft\PowerToys\PowerToys Run\Plugins\VSCode\
   ```
4. Restart PowerToys Run (or PowerToys completely)

### Option 2: Build from Source

See [Building from Source](#building-from-source) section below.

### Quick Installation Script

Use the provided PowerShell script for automated installation:

```powershell
.\install-simple.ps1
```

This will:
- Stop PowerToys
- Copy plugin files to the correct location
- Provide instructions to restart PowerToys

## 🚀 Usage

### Search VS Code Projects

Open PowerToys Run (`Alt+Space`) and type:

```
vsc <project name>
```

**Examples:**
- `vsc` - Show all VS Code projects
- `vsc my-app` - Search for projects containing "my-app"
- `vsc project` - Filter by "project"

**Actions:**
- `Enter` - Open project in VS Code
- `Right-click` or `Shift+Enter` - Show context menu
  - Copy Path
  - Open in File Explorer

### Search SSH Connections

Type `vsc ssh` followed by your search:

```
vsc ssh <hostname>
```

**Examples:**
- `vsc ssh` - Show all SSH connections from `~/.ssh/config`
- `vsc ssh dev` - Search for SSH hosts containing "dev"
- `vsc ssh production` - Filter by "production"

**Actions:**
- `Enter` - Open SSH connection in new terminal
- `Right-click` or `Shift+Enter` - Copy SSH command

## ⚙️ Configuration

### VS Code Path Detection

The plugin automatically searches for VS Code in these locations (in order):

1. `%ProgramFiles%\Microsoft VS Code\Code.exe`
2. `%ProgramFiles(x86)%\Microsoft VS Code\Code.exe`
3. `%LocalAppData%\Programs\Microsoft VS Code\Code.exe`
4. `%UserProfile%\.vscode\bin\code.cmd`
5. `code` command (if in PATH)

If VS Code is not found, you'll see an error message with installation instructions.

### Workspace Detection

The plugin reads VS Code projects from:
- **Primary**: `%APPDATA%\Code\User\workspaceStorage\*.json`
- **Supports**: Both local and remote (SSH) projects

### SSH Configuration

SSH connections are read from:
- `%USERPROFILE%\.ssh\config`

**Supported SSH config options:**
- `Host` - Connection name (displayed in results)
- `HostName` - Actual server address
- `User` - SSH username
- `Port` - Custom SSH port
- `IdentityFile` - SSH key path

**Example SSH config:**
```ssh
Host dev-server
    HostName 192.168.1.100
    User developer
    Port 22
    IdentityFile ~/.ssh/id_rsa
```

## 🔨 Building from Source

### Requirements

- [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
- Visual Studio 2022 or Visual Studio Code (optional)
- PowerToys (for testing)

### Build Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Vincent0201Ip/PowerToys-VSCode-Plugin.git
   cd PowerToys-VSCode-Plugin
   ```

2. **Build the project:**
   
   **For x64:**
   ```bash
   dotnet build -c Release -p:Platform=x64
   ```
   
   **For ARM64:**
   ```bash
   dotnet build -c Release -p:Platform=ARM64
   ```
   
   **Build both architectures:**
   ```powershell
   .\build.ps1
   ```

3. **Install the plugin:**
   ```powershell
   .\install-simple.ps1
   ```

4. **Restart PowerToys**

### Output Location

Build outputs are located at:
```
Community.PowerToys.Run.Plugin.VSCodePluginOfficial\bin\{Platform}\Release\net9.0-windows\
```

## 🐛 Troubleshooting

### VS Code Not Opening

**Problem**: Projects appear in search but won't open

**Solutions:**
1. Verify VS Code is installed:
   ```powershell
   .\debug-vscode-path.ps1
   ```
2. Make sure VS Code is in your PATH:
   ```bash
   code --version
   ```
3. Reinstall VS Code and ensure "Add to PATH" is checked during installation

### Projects Not Found

**Problem**: No projects appear in search results

**Solutions:**
1. Open a folder in VS Code to create workspace entries
2. Check workspace storage exists:
   ```
   %APPDATA%\Code\User\workspaceStorage\
   ```
3. Verify you're using VS Code (not VS Code Insiders or other variants)

### SSH Connections Not Found

**Problem**: SSH hosts don't appear

**Solutions:**
1. Check SSH config file exists:
   ```
   %USERPROFILE%\.ssh\config
   ```
2. Verify config file format is correct (see [Configuration](#configuration) section)
3. Ensure at least one `Host` entry is defined

### Plugin Not Loading

**Problem**: Plugin doesn't appear in PowerToys Run

**Solutions:**
1. Verify installation path:
   ```
   %LOCALAPPDATA%\Microsoft\PowerToys\PowerToys Run\Plugins\VSCode\
   ```
2. Check all DLL files are present (including `Newtonsoft.Json.dll`)
3. Restart PowerToys completely (exit from system tray)
4. Check PowerToys Run settings - ensure plugin is enabled

### Performance Issues

**Problem**: Search is slow

**Solutions:**
- Plugin uses 5-minute caching by default
- First search after cache expiry may be slower
- Reduce number of workspace folders if you have many projects
- Consider archiving old projects

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Quick Start for Contributors

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Test thoroughly
5. Commit: `git commit -m 'Add amazing feature'`
6. Push: `git push origin feature/amazing-feature`
7. Open a Pull Request

### Code Style

- Follow standard C# conventions
- Add XML documentation comments for public APIs
- Write descriptive commit messages
- Include tests for new features (when applicable)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Microsoft PowerToys](https://github.com/microsoft/PowerToys) - For the amazing launcher framework
- [PowerToys Run Plugin Template](https://github.com/8LWXpg/PowerToysRun-PluginTemplate) - For the plugin template
- VS Code team - For creating an awesome editor

## 📧 Contact

Vincent0201Ip - [@Vincent0201Ip](https://github.com/Vincent0201Ip)

Project Link: [https://github.com/Vincent0201Ip/PowerToys-VSCode-Plugin](https://github.com/Vincent0201Ip/PowerToys-VSCode-Plugin)

---

**⭐ If you find this plugin useful, please consider giving it a star!**
