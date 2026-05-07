# =============================================================================
# OpenWatch - Windows one-shot runner
# -----------------------------------------------------------------------------
# What this script does:
#   1. Runs scripts/doctor.ps1 to verify the environment.
#      - If something is missing, it offers to auto-install (vcpkg + deps)
#        before continuing. Pass -Yes to skip the prompt.
#   2. Configures CMake into build-windows\  (VS 2022 + vcpkg toolchain + C++20)
#   3. Compiles (Release, x64).
#   4. Runs tracker_windows.exe from inside build-windows\Release\ so the
#      source's relative paths (..\..\models, ..\..\..\videos\video1.mp4)
#      resolve correctly. A live OpenCV window opens (press ESC to stop).
#
# Usage (from anywhere, in PowerShell):
#     powershell -ExecutionPolicy Bypass -File scripts\run.ps1
#     powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -Yes
#     powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -BuildOnly
#     powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -Clean
# =============================================================================

[CmdletBinding()]
param(
    [string]$VcpkgRoot = "C:\vcpkg",
    [switch]$Yes,
    [switch]$BuildOnly,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

# --- Locate repo root -------------------------------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $RepoRoot

# --- Pretty logging ---------------------------------------------------------
function Log($msg) { Write-Host "[run] $msg" -ForegroundColor Cyan }
function Ok($msg)  { Write-Host "[ok]  $msg" -ForegroundColor Green }
function Die($msg) { Write-Host "[err] $msg" -ForegroundColor Red; exit 1 }

# =============================================================================
# 1. Run the doctor (and auto-install if needed)
# =============================================================================
Log "Running environment doctor..."
$doctorOk = $true
try {
    & powershell -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $ScriptDir "doctor.ps1") -VcpkgRoot $VcpkgRoot
    if ($LASTEXITCODE -ne 0) { $doctorOk = $false }
} catch {
    $doctorOk = $false
}

if ($doctorOk) {
    Ok "Environment looks good."
} else {
    Log "Doctor reported issues."
    if ($Yes) {
        $reply = "y"
    } else {
        $reply = Read-Host "Auto-install missing dependencies (vcpkg + OpenCV + Eigen) now? [y/N]"
    }
    if ($reply -match '^(y|yes)$') {
        & powershell -NoProfile -ExecutionPolicy Bypass `
            -File (Join-Path $ScriptDir "doctor.ps1") -VcpkgRoot $VcpkgRoot -Auto
        if ($LASTEXITCODE -ne 0) { Die "Auto-install failed." }
        # Re-verify
        & powershell -NoProfile -ExecutionPolicy Bypass `
            -File (Join-Path $ScriptDir "doctor.ps1") -VcpkgRoot $VcpkgRoot -Quiet
        if ($LASTEXITCODE -ne 0) { Die "Doctor still reports issues. Aborting." }
        Ok "Dependencies installed."
    } else {
        Die "Aborted. Install the missing pieces and re-run."
    }
}

# =============================================================================
# 2. Configure CMake
# =============================================================================
$BuildDir = Join-Path $RepoRoot "build-windows"
if ($Clean -and (Test-Path $BuildDir)) {
    Log "Cleaning $BuildDir ..."
    Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$VcpkgInstalled = Join-Path $VcpkgRoot "installed\x64-windows"
$Toolchain      = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"

Log "Configuring CMake (VS 2022, x64, Release, vcpkg toolchain)..."
Push-Location $BuildDir
cmake .. -G "Visual Studio 17 2022" `
         -A x64 `
         -DCMAKE_BUILD_TYPE=Release `
         -DCMAKE_CXX_STANDARD=20 `
         -DCMAKE_PREFIX_PATH="$VcpkgInstalled" `
         -DCMAKE_TOOLCHAIN_FILE="$Toolchain"
if ($LASTEXITCODE -ne 0) { Pop-Location; Die "CMake configure failed." }

# =============================================================================
# 3. Build
# =============================================================================
Log "Compiling..."
cmake --build . --config Release
if ($LASTEXITCODE -ne 0) { Pop-Location; Die "Build failed." }
Pop-Location

$Exe = Join-Path $BuildDir "Release\tracker_windows.exe"
Ok "Build complete: $Exe"

if ($BuildOnly) {
    Log "Build-only mode. Skipping run."
    exit 0
}

# =============================================================================
# 4. Run
# =============================================================================
Log "Launching person tracker..."
Log "A live OpenCV window will open. Press ESC to stop."
Write-Host ""

$RunDir = Join-Path $BuildDir "Release"
Push-Location $RunDir
& $Exe
$rc = $LASTEXITCODE
Pop-Location

Write-Host ""
Ok "Done."
Ok "Tracking CSV: $(Join-Path $RunDir 'tracking_data.csv')"
exit $rc
