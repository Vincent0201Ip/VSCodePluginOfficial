# Build Script for PowerToys Run VS Code Plugin
# Builds both x64 and ARM64 architectures

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    
    [Parameter(Mandatory=$false)]
    [switch]$Clean,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowDetails
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " PowerToys Run VS Code Plugin - Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$projectPath = "Community.PowerToys.Run.Plugin.VSCodePluginOfficial\Community.PowerToys.Run.Plugin.VSCodePluginOfficial.csproj"
$platforms = @("x64", "ARM64")
$buildSuccess = $true

# Clean if requested
if ($Clean) {
    Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
    foreach ($platform in $platforms) {
        $binPath = "Community.PowerToys.Run.Plugin.VSCodePluginOfficial\bin\$platform"
        $objPath = "Community.PowerToys.Run.Plugin.VSCodePluginOfficial\obj\$platform"
        
        if (Test-Path $binPath) {
            Remove-Item -Recurse -Force $binPath
            Write-Host "  Cleaned: $binPath" -ForegroundColor Gray
        }
        if (Test-Path $objPath) {
            Remove-Item -Recurse -Force $objPath
            Write-Host "  Cleaned: $objPath" -ForegroundColor Gray
        }
    }
    Write-Host ""
}

# Check if project file exists
if (-not (Test-Path $projectPath)) {
    Write-Host "Error: Project file not found at: $projectPath" -ForegroundColor Red
    exit 1
}

# Build each platform
Write-Host "Building configuration: $Configuration" -ForegroundColor Yellow
Write-Host ""

foreach ($platform in $platforms) {
    Write-Host "Building for $platform..." -ForegroundColor Cyan
    
    $buildArgs = @(
        "build",
        $projectPath,
        "-c", $Configuration,
        "-p:Platform=$platform"
    )
    
    if ($ShowDetails) {
        $buildArgs += "-v:detailed"
    } else {
        $buildArgs += "-v:minimal"
    }
    
    try {
        & dotnet @buildArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ $platform build succeeded" -ForegroundColor Green
            
            # Verify output files
            $outputPath = "Community.PowerToys.Run.Plugin.VSCodePluginOfficial\bin\$platform\$Configuration\net9.0-windows"
            if (Test-Path $outputPath) {
                $dllPath = Join-Path $outputPath "Community.PowerToys.Run.Plugin.VSCodePluginOfficial.dll"
                if (Test-Path $dllPath) {
                    $fileSize = (Get-Item $dllPath).Length / 1KB
                    Write-Host "    Output: $outputPath" -ForegroundColor Gray
                    Write-Host "    DLL Size: $([math]::Round($fileSize, 2)) KB" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  ✗ $platform build failed (Exit code: $LASTEXITCODE)" -ForegroundColor Red
            $buildSuccess = $false
        }
    }
    catch {
        Write-Host "  ✗ $platform build failed: $($_.Exception.Message)" -ForegroundColor Red
        $buildSuccess = $false
    }
    
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
if ($buildSuccess) {
    Write-Host "Build completed successfully! ✓" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Run: .\install-simple.ps1" -ForegroundColor Gray
    Write-Host "  2. Or run: .\package.ps1 to create release packages" -ForegroundColor Gray
} else {
    Write-Host "Build completed with errors! ✗" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the error messages above and fix any issues." -ForegroundColor Yellow
    exit 1
}
Write-Host "========================================" -ForegroundColor Cyan
