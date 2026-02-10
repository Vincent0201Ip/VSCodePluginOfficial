# Package Script for PowerToys Run VS Code Plugin
# Creates release packages for distribution

param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "1.0.0",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " PowerToys Run VS Code Plugin - Package" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$platforms = @("x64", "ARM64")
$releaseDir = "releases"
$pluginName = "VSCodePlugin"

# Create releases directory
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir | Out-Null
    Write-Host "Created releases directory" -ForegroundColor Green
}

# Build if not skipped
if (-not $SkipBuild) {
    Write-Host "Building all platforms..." -ForegroundColor Yellow
    & .\build.ps1 -Configuration Release
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed! Aborting package creation." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Package each platform
foreach ($platform in $platforms) {
    Write-Host "Packaging $platform..." -ForegroundColor Cyan
    
    $sourceDir = "Community.PowerToys.Run.Plugin.VSCodePluginOfficial\bin\$platform\Release\net9.0-windows"
    $zipName = "$pluginName-v$Version-$platform.zip"
    $zipPath = Join-Path $releaseDir $zipName
    
    if (-not (Test-Path $sourceDir)) {
        Write-Host "  ✗ Source directory not found: $sourceDir" -ForegroundColor Red
        Write-Host "    Run build.ps1 first or remove -SkipBuild flag" -ForegroundColor Yellow
        continue
    }
    
    # Remove old package if exists
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    
    try {
        # Create ZIP package (exclude .pdb files for release)
        $files = Get-ChildItem -Path $sourceDir -Recurse -File | Where-Object { 
            $_.Extension -ne '.pdb' -and $_.Name -ne '*.runtimeconfig.json' 
        }
        
        Compress-Archive -Path $sourceDir\* -DestinationPath $zipPath -Force
        
        $zipSize = (Get-Item $zipPath).Length / 1MB
        Write-Host "  ✓ Created: $zipName ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green
        
        # Calculate checksum
        $hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
        Write-Host "    SHA256: $hash" -ForegroundColor Gray
        
        # Save checksum to file
        $checksumFile = Join-Path $releaseDir "checksums.txt"
        "$hash  $zipName" | Out-File -Append -FilePath $checksumFile -Encoding UTF8
    }
    catch {
        Write-Host "  ✗ Failed to create package: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Create release notes template
$releaseNotesPath = Join-Path $releaseDir "RELEASE_NOTES.md"
$releaseNotes = @"
# PowerToys Run VS Code Plugin v$Version

## 🎉 Release Highlights

- Add your release highlights here

## ✨ Features

- 🔍 Quick access to VS Code projects
- 📡 SSH connection management
- 🌐 Remote development support
- 🚀 Smart caching (5 minutes)
- 📋 Context menu actions

## 📦 Installation

1. Download the appropriate package for your system:
   - **x64**: $pluginName-v$Version-x64.zip (Intel/AMD 64-bit)
   - **ARM64**: $pluginName-v$Version-ARM64.zip (ARM 64-bit)

2. Extract the ZIP file

3. Copy all files to:
   ``````
   %LOCALAPPDATA%\Microsoft\PowerToys\PowerToys Run\Plugins\VSCode\
   ``````

4. Restart PowerToys Run

## 📋 Requirements

- Windows 10/11
- PowerToys 0.97.0 or later
- .NET 9.0 Runtime
- VS Code (optional)

## 🔧 Usage

- Type ``vsc`` to search VS Code projects
- Type ``vsc ssh`` to search SSH connections

## 🐛 Known Issues

- None reported yet

## 📝 Checksums

See ``checksums.txt`` for SHA256 checksums of release packages.

## 🙏 Credits

Created by Vincent0201Ip
"@

$releaseNotes | Out-File -FilePath $releaseNotesPath -Encoding UTF8
Write-Host "Created release notes template: $releaseNotesPath" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Packaging completed! ✓" -ForegroundColor Green
Write-Host ""
Write-Host "Release packages created in: $releaseDir" -ForegroundColor Yellow
Write-Host ""
Write-Host "Files created:" -ForegroundColor Yellow
Get-ChildItem $releaseDir | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review and edit: $releaseNotesPath" -ForegroundColor Gray
Write-Host "  2. Upload packages to GitHub Releases" -ForegroundColor Gray
Write-Host "  3. Include checksums.txt for verification" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
