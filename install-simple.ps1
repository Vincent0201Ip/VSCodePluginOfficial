# Simple Install Script
Write-Host "=== Installing VSCode Plugin ===" -ForegroundColor Cyan

$sourceDir = ".\Community.PowerToys.Run.Plugin.VSCodePluginOfficial\bin\x64\Release\net9.0-windows"
$targetDir = "$env:LOCALAPPDATA\Microsoft\PowerToys\PowerToys Run\Plugins\VSCode"

Write-Host "`nStopping PowerToys..." -ForegroundColor Yellow
Get-Process | Where-Object { $_.Name -like '*PowerToys*' } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

Write-Host "Creating target directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

Write-Host "Copying files..." -ForegroundColor Yellow
Copy-Item -Recurse -Force "$sourceDir\*" $targetDir

$files = Get-ChildItem $targetDir
Write-Host "`nCopied $($files.Count) files to:" -ForegroundColor Green
Write-Host "  $targetDir" -ForegroundColor Cyan

Write-Host "`nKey files:" -ForegroundColor Yellow
Get-ChildItem $targetDir -File | ForEach-Object { Write-Host "  + $($_.Name) ($([math]::Round($_.Length/1KB, 2)) KB)" -ForegroundColor Gray }

Write-Host "`n=== Installation Complete ===" -ForegroundColor Green
Write-Host "`nPlease start PowerToys Run manually from Start Menu" -ForegroundColor Yellow
Write-Host "Then press Alt+Space and type:" -ForegroundColor Cyan
Write-Host "  - vscode (to search VS Code projects)" -ForegroundColor Gray
Write-Host "  - ssh (to search SSH connections)" -ForegroundColor Gray
