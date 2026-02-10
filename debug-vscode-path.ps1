# VS Code Path Debug Script
Write-Host "=== VS Code Path Detection ===" -ForegroundColor Cyan

$possiblePaths = @(
    "${env:ProgramFiles}\Microsoft VS Code\Code.exe",
    "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe",
    "${env:LocalAppData}\Programs\Microsoft VS Code\Code.exe",
    "${env:UserProfile}\.vscode\bin\code.cmd",
    "code.cmd",
    "code.exe",
    "code"
)

Write-Host "`nChecking possible VS Code paths:" -ForegroundColor Yellow
$foundPath = $null

foreach ($path in $possiblePaths) {
    $expanded = [System.Environment]::ExpandEnvironmentVariables($path)
    if (Test-Path $expanded) {
        Write-Host "  [OK] $expanded" -ForegroundColor Green
        if (-not $foundPath) { $foundPath = $expanded }
    } else {
        Write-Host "  [  ] $expanded (not found)" -ForegroundColor Gray
    }
}

if ($foundPath) {
    Write-Host "`n==> Found VS Code at: $foundPath" -ForegroundColor Green
} else {
    Write-Host "`n==> VS Code not found! Please install VS Code or add 'code' to PATH" -ForegroundColor Red
}

Write-Host "`n=== Testing 'code' command ===" -ForegroundColor Yellow
try {
    $result = & code --version 2>&1
    Write-Host "`n[OK] 'code' command works!" -ForegroundColor Green
    Write-Host $result -ForegroundColor Gray
} catch {
    Write-Host "`n[  ] 'code' command not available" -ForegroundColor Red
}
