# PowerToys VSCode Plugin Deployment Script
# This script copies the built plugin to PowerToys Run plugins directory

Write-Host "=== PowerToys VSCode Plugin Deployment ===" -ForegroundColor Cyan
Write-Host ""

# Find the built DLL
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$builtDllPath = Get-ChildItem -Path $projectRoot -Recurse -Filter "Community.PowerToys.Run.Plugin.VSCodePluginOfficial.dll" | 
    Where-Object { $_.FullName -like "*\bin\*" } | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

if (-not $builtDllPath) {
    Write-Host "ERROR: Built DLL not found. Please run 'dotnet build' first." -ForegroundColor Red
    exit 1
}

Write-Host "Found built DLL: $($builtDllPath.FullName)" -ForegroundColor Green
Write-Host "Build time: $($builtDllPath.LastWriteTime)" -ForegroundColor Gray
Write-Host ""

# Find PowerToys installation
$possiblePaths = @(
    "$env:LOCALAPPDATA\Microsoft\PowerToys\PowerToys Run\Plugins",
    "C:\Program Files\PowerToys\modules\launcher\Plugins",
    "C:\Program Files\PowerToys\RunPlugins",
    "$env:ProgramFiles\PowerToys\modules\launcher\Plugins"
)

$powerToysPluginDir = $null
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $powerToysPluginDir = $path
        Write-Host "Found PowerToys plugins directory: $powerToysPluginDir" -ForegroundColor Green
        break
    }
}

if (-not $powerToysPluginDir) {
    Write-Host "ERROR: Could not find PowerToys plugins directory." -ForegroundColor Red
    Write-Host "Searched locations:" -ForegroundColor Yellow
    foreach ($path in $possiblePaths) {
        Write-Host "  - $path" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Please enter the PowerToys plugins directory path manually:" -ForegroundColor Yellow
    $manualPath = Read-Host "Path"
    if (Test-Path $manualPath) {
        $powerToysPluginDir = $manualPath
    } else {
        Write-Host "Invalid path. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Create plugin directory
$pluginName = "VSCodePluginOfficial"
$targetDir = Join-Path $powerToysPluginDir $pluginName

Write-Host ""
Write-Host "Creating plugin directory: $targetDir" -ForegroundColor Cyan

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "Created directory." -ForegroundColor Green
} else {
    Write-Host "Directory already exists." -ForegroundColor Yellow
}

# Copy all files from build output directory
$buildDir = $builtDllPath.DirectoryName
Write-Host ""
Write-Host "Copying files from: $buildDir" -ForegroundColor Cyan
Write-Host "Copying files to: $targetDir" -ForegroundColor Cyan

try {
    # Copy all DLLs and necessary files
    Get-ChildItem -Path $buildDir -Filter "*.dll" | ForEach-Object {
        Copy-Item $_.FullName -Destination $targetDir -Force
        Write-Host "  Copied: $($_.Name)" -ForegroundColor Gray
    }
    
    # Copy plugin.json if exists
    $pluginJson = Get-ChildItem -Path $projectRoot -Recurse -Filter "plugin.json" | Select-Object -First 1
    if ($pluginJson) {
        Copy-Item $pluginJson.FullName -Destination $targetDir -Force
        Write-Host "  Copied: plugin.json" -ForegroundColor Gray
    }
    
    # Copy Images folder if exists
    $imagesFolder = Get-ChildItem -Path $projectRoot -Recurse -Filter "Images" -Directory | Select-Object -First 1
    if ($imagesFolder) {
        $targetImagesDir = Join-Path $targetDir "Images"
        if (-not (Test-Path $targetImagesDir)) {
            New-Item -ItemType Directory -Path $targetImagesDir -Force | Out-Null
        }
        Copy-Item "$($imagesFolder.FullName)\*" -Destination $targetImagesDir -Force
        Write-Host "  Copied: Images folder" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "=== Deployment Successful! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Restart PowerToys (close from system tray and reopen)" -ForegroundColor White
    Write-Host "2. Open PowerToys Run (Alt+Space)" -ForegroundColor White
    Write-Host "3. Type 'vsc open' to test the new feature" -ForegroundColor White
    Write-Host ""
    
    # Check if PowerToys is running
    $powerToysProcess = Get-Process -Name "PowerToys*" -ErrorAction SilentlyContinue
    if ($powerToysProcess) {
        Write-Host "WARNING: PowerToys is currently running!" -ForegroundColor Yellow
        Write-Host "You need to restart PowerToys for changes to take effect." -ForegroundColor Yellow
        Write-Host ""
        $restart = Read-Host "Would you like to restart PowerToys now? (y/n)"
        if ($restart -eq 'y' -or $restart -eq 'Y') {
            Write-Host "Stopping PowerToys..." -ForegroundColor Cyan
            Stop-Process -Name "PowerToys*" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            
            # Try to start PowerToys
            $powerToysExe = Get-ChildItem "C:\Program Files\PowerToys" -Recurse -Filter "PowerToys.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($powerToysExe) {
                Write-Host "Starting PowerToys..." -ForegroundColor Cyan
                Start-Process $powerToysExe.FullName
                Write-Host "PowerToys restarted!" -ForegroundColor Green
            } else {
                Write-Host "Could not find PowerToys.exe to restart automatically." -ForegroundColor Yellow
                Write-Host "Please start PowerToys manually from the Start menu." -ForegroundColor White
            }
        }
    }
    
} catch {
    Write-Host ""
    Write-Host "ERROR during deployment: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
