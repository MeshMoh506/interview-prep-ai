Write-Host "🔍 PRE-COMMIT SECURITY CHECK" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Check 1: .env not in git
$envInGit = git ls-files | Select-String "\.env$" | Where-Object { $_ -notmatch "\.env\.example" }
if ($envInGit) {
    Write-Host "❌ FAIL: .env file is tracked by git!" -ForegroundColor Red
    Write-Host "   Run: git rm --cached backend/.env" -ForegroundColor Yellow
} else {
    Write-Host "✅ PASS: .env not tracked" -ForegroundColor Green
}

# Check 2: No API keys in code
$apiKeys = Get-ChildItem -Recurse -Include *.py | Select-String -Pattern "(gsk_|hf_|sk-)" | Where-Object { $_.Line -notmatch "getenv" }
if ($apiKeys) {
    Write-Host "❌ FAIL: Possible API keys found in code!" -ForegroundColor Red
    $apiKeys | ForEach-Object { Write-Host "   $_" -ForegroundColor Yellow }
} else {
    Write-Host "✅ PASS: No hardcoded API keys" -ForegroundColor Green
}

# Check 3: Verify on main branch
$branch = git branch --show-current
if ($branch -eq "main") {
    Write-Host "✅ PASS: On main branch" -ForegroundColor Green
} else {
    Write-Host "⚠️  WARNING: On branch '$branch', not 'main'" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Ready to commit? (Y/N)" -ForegroundColor Cyan
