# Universal Installer for PowerToys Run VS Code Plugin
# Works on fresh Windows installations with no prior configuration
# Supports: x64, ARM64, auto-detection, hybrid download/build approach

param(
    [Parameter(Mandatory=$false)]
    [string]$GitHubReleaseUrl = "https://github.com/Vincent0201Ip/PowerToys-VSCode-Plugin/releases/latest/download",
    
    [Parameter(Mandatory=$false)]
    [switch]$ForceBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPowerToysCheck,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipRestart
)

$ErrorActionPreference = "Stop"

# Script Information
$ScriptVersion = "1.0.0"
$PluginName = "VSCodePluginOfficial"
$PluginDisplayName = "VS Code Plugin"

# Color Scheme for Output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Header')]
        [string]$Level = 'Info'
    )
    
    $color = switch ($Level) {
        'Header' { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Info' { 'Gray' }
        default { 'White' }
    }
    
    $prefix = switch ($Level) {
        'Header' { '═══' }
        'Success' { '✓' }
        'Warning' { '⚠' }
        'Error' { '✗' }
        'Info' { 'ℹ' }
        default { '' }
    }
    
    if ($Level -eq 'Header') {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "$prefix $Message" -ForegroundColor $color
        Write-Host "========================================" -ForegroundColor Cyan
    }
    else {
        Write-Host "  $prefix $Message" -ForegroundColor $color
    }
}

# Detect System Architecture
function Get-SystemArchitecture {
    $architecture = [System.Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')
    
    if ($architecture -eq 'AMD64') {
        return 'x64'
    }
    elseif ($architecture -eq 'ARM64') {
        return 'ARM64'
    }
    else {
        # Check if running in WOW64 mode (32-bit process on 64-bit OS)
        $is64Bit = [System.Environment]::Is64BitOperatingSystem
        if ($is64Bit) {
            return 'x64'
        }
        else {
            Write-ColorOutput "Unsupported architecture: $architecture" -Level Error
            Write-ColorOutput "This plugin requires Windows x64 or ARM64" -Level Warning
            exit 1
        }
    }
}

# ============================================================================
# PowerToys Path Detection
# ============================================================================

# Get all possible PowerToys installation paths
function Get-PowerToysPaths {
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Microsoft\PowerToys",
        "$env:PROGRAMFILES\PowerToys",
        "$env:PROGRAMDATA\Microsoft\PowerToys"
    )
    
    # Add custom paths from registry
    $registryPaths = Get-PowerToysRegistryPaths
    $possiblePaths += $registryPaths
    
    # Filter to valid paths and remove duplicates
    $validPaths = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -Unique
    
    return $validPaths
}

# Get PowerToys paths from Windows Registry
function Get-PowerToysRegistryPaths {
    $paths = @()
    
    # Check for custom installation in registry
    $registryKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($keyPattern in $registryKeys) {
        try {
            Get-ItemProperty $keyPattern -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -like "*PowerToys*" -or $_.DisplayName -like "*Microsoft PowerToys*" } |
            ForEach-Object {
                if ($_.InstallLocation -and (Test-Path $_.InstallLocation)) {
                    $paths += $_.InstallLocation
                }
            }
        }
        catch {
            # Ignore registry errors
        }
    }
    
    return $paths
}

# Find PowerToys executable in given paths
function Find-PowerToysExe {
    param([string[]]$PowerToysPaths)
    
    foreach ($path in $PowerToysPaths) {
        $exePath = Join-Path $path "PowerToys.exe"
        if (Test-Path $exePath) {
            return $exePath
        }
    }
    
    return $null
}

# Check if PowerToys is installed (ENHANCED)
function Test-PowerToysInstalled {
    $powerToysPaths = Get-PowerToysPaths
    
    if ($powerToysPaths.Count -eq 0) {
        return $false
    }
    
    $powerToysPath = $powerToysPaths[0]
    $powerToysExe = Find-PowerToysExe -PowerToysPaths $powerToysPaths
    
    if ($powerToysExe -and (Test-Path $powerToysExe)) {
        try {
            $version = (Get-Item $powerToysExe).VersionInfo.FileVersion
            Write-ColorOutput "PowerToys found at: $powerToysExe" -Level Success
            Write-ColorOutput "Version: $version" -Level Info
            return $true
        }
        catch {
            Write-ColorOutput "PowerToys installed but version check failed" -Level Warning
            return $true
        }
    }
    
    return $false
}

# ============================================================================
# VS Code Path Detection
# ============================================================================

# Detect all VS Code installations and their workspace paths
function Get-VSCodeInstallations {
    $installations = @()
    
    # VS Code variants to check
    $variants = @(
        @{ Name = "VS Code"; AppData = "Code"; DisplayName = "VS Code Stable" },
        @{ Name = "Code - Insiders"; AppData = "Code - Insiders"; DisplayName = "VS Code Insiders" },
        @{ Name = "VSCodium"; AppData = "VSCodium"; DisplayName = "VSCodium" }
    )
    
    foreach ($variant in $variants) {
        $workspacePath = Join-Path $env:APPDATA $variant.AppData "User\workspaceStorage"
        
        if (Test-Path $workspacePath) {
            try {
                $workspaceCount = (Get-ChildItem $workspacePath -Directory -ErrorAction SilentlyContinue).Count
                
                $installations += [PSCustomObject]@{
                    Variant = $variant.DisplayName
                    AppDataName = $variant.AppData
                    WorkspacePath = $workspacePath
                    WorkspaceCount = $workspaceCount
                    IsPrimary = $false
                }
            }
            catch {
                # Skip if unable to access directory
            }
        }
    }
    
    # Mark first found as primary
    if ($installations.Count -gt 0) {
        $installations[0].IsPrimary = $true
        
        # Log additional installations
        if ($installations.Count -gt 1) {
            $additional = $installations | Select-Object -Skip 1 | ForEach-Object { 
                "$($_.Variant) ($($_.WorkspaceCount) workspaces)" 
            }
            Write-ColorOutput "Also detected: $($additional -join ', ')" -Level Info
        }
    }
    
    return $installations
}

# Get VS Code executable path
function Get-VSCodeExecutablePath {
    $possiblePaths = @(
        # VS Code Stable
        "$env:PROGRAMFILES\Microsoft VS Code\Code.exe",
        "$env:PROGRAMFILES(X86)\Microsoft VS Code\Code.exe",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        
        # VS Code Insiders
        "$env:PROGRAMFILES\Microsoft VS Code - Insiders\Code - Insiders.exe",
        "$env:PROGRAMFILES(X86)\Microsoft VS Code - Insiders\Code - Insiders.exe",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code - Insiders\Code - Insiders.exe",
        
        # VSCodium
        "$env:PROGRAMFILES\VSCodium\VSCodium.exe",
        "$env:PROGRAMFILES(X86)\VSCodium\VSCodium.exe",
        "$env:LOCALAPPDATA\Programs\VSCodium\VSCodium.exe"
    )
    
    # Check each path
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Search in PATH
    $pathDirs = $env:PATH -split ';'
    foreach ($dir in $pathDirs) {
        if ([string]::IsNullOrWhiteSpace($dir)) { continue }
        
        $codeExe = Join-Path $dir.Trim() "Code.exe"
        $codeInsidersExe = Join-Path $dir.Trim() "Code - Insiders.exe"
        $vscodiumExe = Join-Path $dir.Trim() "VSCodium.exe"
        
        if (Test-Path $codeExe) { return $codeExe }
        if (Test-Path $codeInsidersExe) { return $codeInsidersExe }
        if (Test-Path $vscodiumExe) { return $vscodiumExe }
    }
    
    return $null
}

# Install PowerToys
function Install-PowerToys {
    Write-ColorOutput "PowerToys is not installed" -Level Warning
    Write-ColorOutput "Would you like to install PowerToys?" -Level Info
    Write-Host ""
    Write-Host "  [Y] Yes - Install PowerToys (requires internet connection)" -ForegroundColor Gray
    Write-Host "  [N] No  - Exit installer" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "Your choice (Y/N)"
    
    if ($choice -eq 'Y' -or $choice -eq 'y') {
        Write-ColorOutput "Installing PowerToys..." -Level Header
        
        # Try using winget first
        $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
        
        if ($wingetAvailable) {
            Write-ColorOutput "Using winget to install PowerToys..." -Level Info
            try {
                winget install --id Microsoft.PowerToys --accept-package-agreements --accept-source-agreements
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "PowerToys installed successfully!" -Level Success
                    Write-ColorOutput "Please restart PowerToys manually before continuing" -Level Warning
                    Read-Host "Press Enter to continue after PowerToys is started"
                    return $true
                }
                else {
                    Write-ColorOutput "Winget installation failed. Trying direct download..." -Level Warning
                }
            }
            catch {
                Write-ColorOutput "Winget installation failed: $($_.Exception.Message)" -Level Warning
            }
        }
        
        # Fallback to direct download
        Write-ColorOutput "Downloading PowerToys installer..." -Level Info
        
        $downloadUrl = "https://github.com/microsoft/PowerToys/releases/latest/download/PowerToysUserSetup-x64.exe"
        $installerPath = "$env:TEMP\PowerToysSetup.exe"
        
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            Write-ColorOutput "Running PowerToys installer..." -Level Info
            Start-Process -FilePath $installerPath -Wait
            
            Write-ColorOutput "PowerToys installed successfully!" -Level Success
            Write-ColorOutput "Please restart PowerToys manually before continuing" -Level Warning
            Read-Host "Press Enter to continue after PowerToys is started"
            
            Remove-Item $installerPath -Force
            return $true
        }
        catch {
            Write-ColorOutput "Failed to install PowerToys: $($_.Exception.Message)" -Level Error
            Write-ColorOutput "Please install PowerToys manually from: https://github.com/microsoft/PowerToys/releases" -Level Info
            return $false
        }
    }
    else {
        Write-ColorOutput "Installation cancelled by user" -Level Warning
        exit 1
    }
}

# Check if .NET SDK is installed
function Test-DotNetSDK {
    $dotnetExe = Get-Command dotnet -ErrorAction SilentlyContinue
    
    if (-not $dotnetExe) {
        return $false
    }
    
    try {
        $sdks = dotnet --list-sdks 2>&1
        $hasNet90 = $sdks | Where-Object { $_ -match '^9\.0\.' }
        
        if ($hasNet90) {
            Write-ColorOutput ".NET 9.0 SDK found" -Level Success
            return $true
        }
        else {
            Write-ColorOutput ".NET found but version 9.0 SDK not installed" -Level Warning
            Write-ColorOutput "Installed SDKs:" -Level Info
            $sdks | ForEach-Object { Write-ColorOutput "  $_" -Level Info }
            return $false
        }
    }
    catch {
        Write-ColorOutput "Failed to check .NET SDK: $($_.Exception.Message)" -Level Warning
        return $false
    }
}

# Install .NET 9.0 SDK
function Install-DotNetSDK {
    Write-ColorOutput ".NET 9.0 SDK is required for building" -Level Warning
    Write-ColorOutput "Would you like to install .NET 9.0 SDK?" -Level Info
    Write-Host ""
    Write-Host "  [Y] Yes - Install .NET 9.0 SDK (requires internet connection)" -ForegroundColor Gray
    Write-Host "  [N] No  - Try download pre-built release instead" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "Your choice (Y/N)"
    
    if ($choice -eq 'Y' -or $choice -eq 'y') {
        Write-ColorOutput "Installing .NET 9.0 SDK..." -Level Header
        
        $downloadUrl = "https://dot.net/v1/dotnet-install.ps1"
        $installerPath = "$env:TEMP\dotnet-install.ps1"
        
        try {
            # Download dotnet-install script
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            
            # Run installer for SDK 9.0
            $installArgs = @(
                "-InstallDir", "$env:USERPROFILE\.dotnet",
                "-Channel", "9.0",
                "-Quality", "preview",
                "-Version", "latest"
            )
            
            & powershell -ExecutionPolicy Bypass -File $installerPath @installArgs
            
            # Add to PATH if not already there
            $dotnetPath = "$env:USERPROFILE\.dotnet"
            $env:PATH = "$dotnetPath;$env:PATH"
            
            # Persist to user PATH
            [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::User)
            
            Remove-Item $installerPath -Force
            
            Write-ColorOutput ".NET 9.0 SDK installed successfully!" -Level Success
            return $true
        }
        catch {
            Write-ColorOutput "Failed to install .NET 9.0 SDK: $($_.Exception.Message)" -Level Error
            Write-ColorOutput "Please install manually from: https://dotnet.microsoft.com/download/dotnet/9.0" -Level Info
            return $false
        }
    }
    else {
        return $false
    }
}

# Download pre-built release
function Get-PrebuiltRelease {
    param(
        [string]$Architecture
    )
    
    $platform = if ($Architecture -eq 'ARM64') { "ARM64" } else { "x64" }
    $packageName = "$PluginName-v$ScriptVersion-$platform.zip"
    $downloadUrl = "$GitHubReleaseUrl/$packageName"
    $downloadPath = "$env:TEMP\$packageName"
    
    Write-ColorOutput "Attempting to download pre-built release..." -Level Info
    Write-ColorOutput "URL: $downloadUrl" -Level Info
    
    try {
        # Check if URL exists (HEAD request)
        $response = Invoke-WebRequest -Uri $downloadUrl -Method Head -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-ColorOutput "Pre-built release found! Downloading..." -Level Success
            
            # Download the file
            Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
            
            $fileSize = (Get-Item $downloadPath).Length / 1MB
            Write-ColorOutput "Downloaded: $packageName ($([math]::Round($fileSize, 2)) MB)" -Level Success
            
            # Extract to temp directory
            $extractPath = "$env:TEMP\$PluginName-$platform"
            if (Test-Path $extractPath) {
                Remove-Item -Recurse -Force $extractPath
            }
            
            Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
            
            Write-ColorOutput "Extracted to: $extractPath" -Level Success
            
            # Clean up downloaded zip
            Remove-Item $downloadPath -Force
            
            return $extractPath
        }
        else {
            Write-ColorOutput "Pre-built release not found (Status: $($response.StatusCode))" -Level Warning
            return $null
        }
    }
    catch {
        Write-ColorOutput "Failed to download pre-built release: $($_.Exception.Message)" -Level Warning
        return $null
    }
}

# Build from source
function Build-Plugin {
    param(
        [string]$Architecture
    )
    
    Write-ColorOutput "Building plugin from source..." -Level Header
    
    # Check if we're in the project directory
    $csprojPath = "Community.PowerToys.Run.Plugin.VSCodePluginOfficial\Community.PowerToys.Run.Plugin.VSCodePluginOfficial.csproj"
    
    if (-not (Test-Path $csprojPath)) {
        Write-ColorOutput "Project file not found at: $csprojPath" -Level Error
        Write-ColorOutput "Make sure you're running this script from the project root directory" -Level Warning
        return $null
    }
    
    try {
        Write-ColorOutput "Building for $Architecture..." -Level Info
        
        $buildArgs = @(
            "build",
            $csprojPath,
            "-c", "Release",
            "-p:Platform=$Architecture",
            "-v:minimal"
        )
        
        & dotnet @buildArgs
        
        if ($LASTEXITCODE -eq 0) {
            $outputPath = "Community.PowerToys.Run.Plugin.VSCodePluginOfficial\bin\$Architecture\Release\net9.0-windows"
            
            if (Test-Path $outputPath) {
                Write-ColorOutput "Build completed successfully!" -Level Success
                Write-ColorOutput "Output: $outputPath" -Level Info
                return $outputPath
            }
        }
        else {
            Write-ColorOutput "Build failed with exit code: $LASTEXITCODE" -Level Error
        }
    }
    catch {
        Write-ColorOutput "Build failed: $($_.Exception.Message)" -Level Error
    }
    
    return $null
}

# Install plugin to PowerToys
function Install-Plugin {
    param(
        [string]$SourcePath,
        [string]$Architecture,
        [string]$PowerToysPath
    )
    
    # Use detected PowerToys path or default
    if (-not $PowerToysPath) {
        $powerToysPaths = Get-PowerToysPaths
        if ($powerToysPaths.Count -gt 0) {
            $PowerToysPath = $powerToysPaths[0]
        }
        else {
            $PowerToysPath = "$env:LOCALAPPDATA\Microsoft\PowerToys"
        }
    }
    
    $targetDir = Join-Path $PowerToysPath "PowerToys Run\Plugins\VSCode"
    
    Write-ColorOutput "Installing plugin to PowerToys..." -Level Header
    Write-ColorOutput "PowerToys location: $PowerToysPath" -Level Info
    
    # Stop PowerToys
    Write-ColorOutput "Stopping PowerToys..." -Level Info
    Get-Process | Where-Object { $_.Name -like '*PowerToys*' } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Create target directory
    Write-ColorOutput "Creating plugin directory..." -Level Info
    if (Test-Path $targetDir) {
        # Backup existing installation
        $backupPath = "$targetDir.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-ColorOutput "Backing up existing installation to: $backupPath" -Level Info
        Move-Item -Path $targetDir -Destination $backupPath
    }
    
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    
    # Copy plugin files
    Write-ColorOutput "Copying plugin files..." -Level Info
    Copy-Item -Recurse -Force "$SourcePath\*" $targetDir
    
    $files = Get-ChildItem $targetDir -File
    Write-ColorOutput "Copied $($files.Count) files" -Level Success
    
    # Verify plugin.json exists
    $pluginJson = Join-Path $targetDir "plugin.json"
    if (Test-Path $pluginJson) {
        Write-ColorOutput "plugin.json found" -Level Success
    }
    else {
        Write-ColorOutput "Warning: plugin.json not found!" -Level Warning
    }
    
    return $targetDir
}

# Restart PowerToys
function Restart-PowerToys {
    param([string]$PowerToysPath)
    
    # Use detected path or default
    if (-not $PowerToysPath) {
        $powerToysPaths = Get-PowerToysPaths
        if ($powerToysPaths.Count -gt 0) {
            $PowerToysPath = $powerToysPaths[0]
        }
        else {
            $PowerToysPath = "$env:LOCALAPPDATA\Microsoft\PowerToys"
        }
    }
    
    $powerToysExe = Join-Path $PowerToysPath "PowerToys.exe"
    
    if (Test-Path $powerToysExe) {
        Write-ColorOutput "Starting PowerToys..." -Level Info
        Start-Process -FilePath $powerToysExe
        Write-ColorOutput "PowerToys started successfully!" -Level Success
    }
    else {
        Write-ColorOutput "PowerToys.exe not found at: $powerToysExe" -Level Warning
        Write-ColorOutput "Please start PowerToys manually." -Level Warning
    }
}

# ============================================================================
# Main Execution
# ============================================================================

Write-ColorOutput "$PluginDisplayName Installer v$ScriptVersion" -Level Header

# 1. Detect Architecture
$architecture = Get-SystemArchitecture
Write-ColorOutput "Detected system architecture: $architecture" -Level Info

# 2. Check PowerToys
$powerToysPaths = Get-PowerToysPaths
$powerToysPath = $null

if (-not $SkipPowerToysCheck) {
    if ($powerToysPaths.Count -gt 0) {
        $powerToysPath = $powerToysPaths[0]
        Write-ColorOutput "PowerToys found at: $powerToysPath" -Level Success
    }
    
    if (-not (Test-PowerToysInstalled)) {
        Install-PowerToys
        # Re-check after installation
        $powerToysPaths = Get-PowerToysPaths
        $powerToysPath = $powerToysPaths[0]
    }
}

# 3. Detect VS Code Installations
Write-ColorOutput "Detecting VS Code installations..." -Level Header
$vsCodeInstallations = Get-VSCodeInstallations

if ($vsCodeInstallations.Count -gt 0) {
    $primaryVariant = $vsCodeInstallations | Where-Object { $_.IsPrimary }
    Write-ColorOutput "VS Code installation detected: $($primaryVariant.Variant)" -Level Success
    Write-ColorOutput "Workspaces: $($primaryVariant.WorkspaceCount) found" -Level Info
}
else {
    Write-ColorOutput "No VS Code installations detected" -Level Warning
    Write-ColorOutput "Plugin will install but may not find projects" -Level Warning
}

# 4. Get Plugin Files
$sourcePath = $null

if (-not $ForceBuild) {
    # Try pre-built release first
    $sourcePath = Get-PrebuiltRelease -Architecture $architecture
}

if (-not $sourcePath) {
    # Fallback to building from source
    Write-ColorOutput "Building from source..." -Level Header
    
    if (-not (Test-DotNetSDK)) {
        $sdkInstalled = Install-DotNetSDK
        if (-not $sdkInstalled) {
            Write-ColorOutput "Cannot build plugin without .NET 9.0 SDK" -Level Error
            exit 1
        }
    }
    
    $sourcePath = Build-Plugin -Architecture $architecture
}

if (-not $sourcePath) {
    Write-ColorOutput "Failed to obtain plugin files" -Level Error
    exit 1
}

# 5. Install Plugin
$installedPath = Install-Plugin -SourcePath $sourcePath -Architecture $architecture -PowerToysPath $powerToysPath

# 6. Restart PowerToys
if (-not $SkipRestart) {
    Restart-PowerToys -PowerToysPath $powerToysPath
}

# ============================================================================
# Summary
# ============================================================================

Write-ColorOutput "Installation Complete!" -Level Header
Write-ColorOutput "Plugin installed to: $installedPath" -Level Success
Write-ColorOutput "Architecture: $architecture" -Level Info
Write-Host ""
Write-ColorOutput "Usage:" -Level Info
Write-Host "  Press Alt+Space to open PowerToys Run" -ForegroundColor Gray
Write-Host "  Type 'vsc' to search VS Code projects" -ForegroundColor Gray
Write-Host "  Type 'vsc ssh' to search SSH connections" -ForegroundColor Gray
Write-Host ""
Write-ColorOutput "If the plugin doesn't appear:" -Level Warning
Write-Host "  1. Open PowerToys Settings" -ForegroundColor Gray
Write-Host "  2. Navigate to PowerToys Run" -ForegroundColor Gray
Write-Host "  3. Ensure '$PluginDisplayName' is enabled" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
