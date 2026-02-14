# ============================================================
#  Error Fix Script — Run AFTER setup_ui.ps1
#  Fixes all compile errors from flutter analyze
# ============================================================
param([string]$root = (Get-Location).Path)
$front = "$root\frontend"
$src   = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Fixing Compile Errors...        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

function Put($file, $dest) {
    $dir = Split-Path $dest -Parent
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    Copy-Item "$src\$file" $dest -Force
    Write-Host "  ✓ $file" -ForegroundColor Green
}

# Fix 1: AppTheme — add backward-compat color aliases (error, background, textDark, textLight)
Write-Host "[1] AppTheme color aliases..." -ForegroundColor Yellow
Put "app_theme.dart" "$front\lib\core\theme\app_theme.dart"

# Fix 2: api_service — expose .dio getter (resume_service needs it)
Write-Host "[2] ApiService .dio getter..." -ForegroundColor Yellow
Put "api_service.dart" "$front\lib\services\api_service.dart"

# Fix 3: PrimaryButton — move to shared so both auth screens can import it
Write-Host "[3] Shared PrimaryButton widget..." -ForegroundColor Yellow
Put "primary_button.dart" "$front\lib\shared\widgets\primary_button.dart"

# Fix 4: LoginScreen — use shared PrimaryButton (no private _PrimaryBtn)
Write-Host "[4] LoginScreen (clean imports)..." -ForegroundColor Yellow
Put "login_screen.dart" "$front\lib\features\auth\screens\login_screen.dart"

# Fix 5: RegisterScreen — import PrimaryButton from shared (no show _PrimaryBtn)
Write-Host "[5] RegisterScreen (clean imports)..." -ForegroundColor Yellow
Put "register_screen.dart" "$front\lib\features\auth\screens\register_screen.dart"

# Fix 6: HomeScreen — _AppBar as SliverPersistentHeaderDelegate (not raw Widget in slivers)
Write-Host "[6] HomeScreen (SliverPersistentHeader fix)..." -ForegroundColor Yellow
Put "home_screen.dart" "$front\lib\features\home\screens\home_screen.dart"

# Verify
Write-Host ""
Write-Host "Re-analyzing fixed files..." -ForegroundColor Yellow
Set-Location $front
$errors = flutter analyze lib/core/theme/ lib/services/api_service.dart `
    lib/shared/widgets/primary_button.dart `
    lib/features/auth/ lib/features/home/ 2>&1 | Select-String " error "

if ($errors) {
    Write-Host "" 
    Write-Host "  Remaining errors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
} else {
    Write-Host "  No errors in fixed files! ✓" -ForegroundColor Green
}
Set-Location $root
Write-Host ""
Write-Host "Done! Run: cd frontend && flutter run -d chrome" -ForegroundColor Cyan