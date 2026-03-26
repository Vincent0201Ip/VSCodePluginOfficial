# Installation Test Checklist

## Quick Verification
```powershell
# Test script exists
Test-Path install.ps1

# Test script syntax
powershell -NoProfile -Command "try { $null = . .\install.ps1; exit 0 } catch { Write-Host \"Error: $_\"; exit 1 }"
```

## Installation Scenarios to Test

### Scenario 1: Fresh Windows (No Tools)
1. Start from fresh Windows installation
2. No PowerToys installed
3. No .NET SDK installed
4. Run: `.\install.ps1`
5. Expected: Prompt to install PowerToys → Install → Prompt for .NET SDK → Install → Build → Install plugin

### Scenario 2: Windows with PowerToys Only
1. PowerToys installed
2. No .NET SDK installed
3. Run: `.\install.ps1`
4. Expected: Try download release (fail if no releases) → Prompt for .NET SDK → Install → Build → Install plugin

### Scenario 3: Windows with Full Dev Tools
1. PowerToys installed
2. .NET 9.0 SDK installed
3. Run: `.\install.ps1`
4. Expected: Try download release (fail if no releases) → Build → Install plugin

### Scenario 4: Force Build
1. Run: `.\install.ps1 -ForceBuild`
2. Expected: Skip download, build directly

### Scenario 5: Skip PowerToys Check
1. Run: `.\install.ps1 -SkipPowerToysCheck`
2. Expected: Don't check/install PowerToys

### Scenario 6: Skip Restart
1. Run: `.\install.ps1 -SkipRestart`
2. Expected: Install but don't restart PowerToys

## Success Criteria

- ✅ Script runs without syntax errors
- ✅ Architecture detection works (x64/ARM64)
- ✅ PowerToys installation prompt appears when missing
- ✅ .NET SDK installation works when building from source
- ✅ Build succeeds with .NET 9.0 SDK
- ✅ Plugin installs to correct location
- ✅ PowerToys restarts after installation
- ✅ Backup of existing installation is created
- ✅ Temporary files are cleaned up

## Known Limitations

1. **No Pre-built Releases Yet**: The download step will fail until GitHub releases are created
2. **Winget Availability**: Fallback to direct download if winget is not available
3. **PowerToys Restart**: Manual restart may be needed in some cases
4. **ARM64 Testing**: Requires ARM64 Windows machine for full testing

## File Locations

### Script
- `install.ps1` - Universal installation script

### Target Installation Directory
- `%LOCALAPPDATA%\Microsoft\PowerToys\PowerToys Run\Plugins\VSCode\`

### Backup Location
- `%LOCALAPPDATA%\Microsoft\PowerToys\PowerToys Run\Plugins\VSCode.backup.{timestamp}\`

### Temporary Files
- `%TEMP%\VSCodePluginOfficial-{arch}\` - Extracted files
- `%TEMP%\dotnet-install.ps1` - .NET SDK installer (removed after use)

## Documentation Updates

- ✅ Created `install.ps1` with full implementation
- ✅ Updated `README.md` with installation instructions
- ✅ Updated `AGENTS.md` with installer reference
- ✅ Created `.opencode/plans/install-script-plan.md` with full plan

## Next Steps

1. Test script on fresh Windows environment
2. Create GitHub Releases with pre-built packages
3. Update version numbers in `plugin.json` and `install.ps1`
4. Test ARM64 build and installation
5. Consider adding CI/CD for automated releases
