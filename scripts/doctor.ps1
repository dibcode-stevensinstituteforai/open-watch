# =============================================================================
# OpenWatch - Windows environment doctor
# -----------------------------------------------------------------------------
# Verifies that all required toolchain pieces are installed and at the right
# version. If something is missing, it prints the exact command needed to
# fix it, and (with -Auto) bootstraps vcpkg + installs deps for you.
#
# Required toolchain (Windows target uses MSVC; clang/LLVM is Linux-only):
#   - Windows 10
#   - Git for Windows
#   - CMake >= 3.20  (verified with CMake 4.3.x; any 3.20+ should work)
#   - Visual Studio 2022 with the "Desktop development with C++" workload
#     -> provides the MSVC v143 compiler that builds tracker_windows.exe
#   - vcpkg (default: C:\vcpkg)
#   - OpenCV 4 (with DNN module) and Eigen3, both via vcpkg (x64-windows)
# Optional:
#   - Ninja (informational only; the Windows build uses the VS generator)
#
# Usage (from anywhere, in PowerShell):
#     powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1
#     powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1 -Auto
#     powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1 -Quiet
# =============================================================================

[CmdletBinding()]
param(
    [string]$VcpkgRoot = "C:\vcpkg",
    [switch]$Auto,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# --- Locate repo root (script is in <repo>\scripts) -------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir "..")

# --- Pretty logging ---------------------------------------------------------
function Say($msg, $color = 'Gray')   { if (-not $Quiet) { Write-Host $msg -ForegroundColor $color } }
function Log($msg)                     { Say "[doctor] $msg" 'Cyan' }
function Ok($msg)                      { Say "  OK      $msg" 'Green' }
function Miss($msg)                    { Say "  MISSING $msg" 'Red' }
function Bad($msg)                     { Say "  WRONG   $msg" 'Yellow' }
function Hint($msg)                    { Say "          fix: $msg" 'DarkGray' }

# --- Track problems ---------------------------------------------------------
$script:HardErrors = 0
$script:Missing    = @()  # list of @{ Name; FixHint; Action }

function MarkMissing {
    param($Name, $FixHint, [scriptblock]$Action = $null)
    $script:Missing += @{ Name = $Name; FixHint = $FixHint; Action = $Action }
}

# =============================================================================
# 1. OS sanity
# =============================================================================
Log "Checking operating system..."
$os = (Get-CimInstance Win32_OperatingSystem).Caption
if ($os -match "Windows 10") {
    Ok $os
} else {
    Bad "Detected: $os (Windows 10 expected)"
}

# =============================================================================
# 2. Required toolchain
# =============================================================================
Log "Checking required toolchain..."

# Git
if (Get-Command git -ErrorAction SilentlyContinue) {
    Ok "git ($(git --version))"
} else {
    Miss "Git for Windows"
    Hint "Install: https://git-scm.com/download/win"
    MarkMissing -Name "git" -FixHint "Install Git for Windows manually"
    $script:HardErrors++
}

# CMake >= 3.20
if (Get-Command cmake -ErrorAction SilentlyContinue) {
    $cmakeFirst = (cmake --version | Select-Object -First 1)
    if ($cmakeFirst -match 'cmake version (\d+)\.(\d+)') {
        $maj = [int]$Matches[1]; $min = [int]$Matches[2]
        if ($maj -gt 3 -or ($maj -eq 3 -and $min -ge 20)) {
            Ok "$cmakeFirst"
        } else {
            Bad "$cmakeFirst (>= 3.20 required)"
            Hint "Update CMake: https://cmake.org/download/"
            MarkMissing -Name "cmake>=3.20" -FixHint "Update CMake manually"
            $script:HardErrors++
        }
    }
} else {
    Miss "cmake"
    Hint "Install CMake >= 3.20: https://cmake.org/download/"
    MarkMissing -Name "cmake" -FixHint "Install CMake manually"
    $script:HardErrors++
}

# Ninja (optional on Windows - the VS generator does not require it)
if (Get-Command ninja -ErrorAction SilentlyContinue) {
    Ok "ninja $((ninja --version)) (optional on Windows)"
} else {
    Say "  INFO    ninja not found (optional - the VS 2022 generator builds without it)" 'DarkGray'
}

# Visual Studio 2022 with C++ workload (provides the MSVC v143 compiler)
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsInstallPath = $null
if (Test-Path $vswhere) {
    $vsInstallPath = & $vswhere -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath 2>$null
}
if ($vsInstallPath) {
    Ok "Visual Studio 2022 with C++ workload (MSVC v143)  -> $vsInstallPath"
} else {
    Miss "Visual Studio 2022 with 'Desktop development with C++' workload"
    Hint "Install VS 2022 Community: https://visualstudio.microsoft.com/downloads/"
    Hint "On Windows we build with MSVC, NOT clang/LLVM (clang is Linux-only here)"
    MarkMissing -Name "VS2022+C++" -FixHint "Install VS 2022 manually"
    $script:HardErrors++
}

# vcpkg
$VcpkgExe = Join-Path $VcpkgRoot "vcpkg.exe"
if (Test-Path $VcpkgExe) {
    Ok "vcpkg at $VcpkgRoot"
} else {
    Miss "vcpkg at $VcpkgRoot"
    Hint "git clone https://github.com/microsoft/vcpkg.git $VcpkgRoot ; & $VcpkgRoot\bootstrap-vcpkg.bat"
    MarkMissing -Name "vcpkg" -FixHint "Bootstrap vcpkg" -Action {
        Log "Bootstrapping vcpkg into $VcpkgRoot ..."
        if (-not (Test-Path $VcpkgRoot)) {
            git clone https://github.com/microsoft/vcpkg.git $VcpkgRoot
        }
        Push-Location $VcpkgRoot
        & .\bootstrap-vcpkg.bat -disableMetrics
        Pop-Location
    }
}

# vcpkg packages (only if vcpkg is present)
$opencvInstalled = $false
$eigenInstalled  = $false
if (Test-Path $VcpkgExe) {
    $listed = & $VcpkgExe list 2>$null
    if ($listed -match 'opencv4(\[.*\])?:x64-windows') { $opencvInstalled = $true }
    if ($listed -match 'eigen3:x64-windows')          { $eigenInstalled  = $true }
}

if ($opencvInstalled) {
    Ok "OpenCV 4 (vcpkg, x64-windows)"
} else {
    Miss "OpenCV 4 (vcpkg, x64-windows)"
    Hint "$VcpkgRoot\vcpkg.exe install opencv4[core,dnn,jpeg,png,ffmpeg]:x64-windows"
    MarkMissing -Name "opencv4" -FixHint "vcpkg install opencv4" -Action {
        & $VcpkgExe install opencv4[core,dnn,jpeg,png,ffmpeg]:x64-windows
    }
}

if ($eigenInstalled) {
    Ok "Eigen3 (vcpkg, x64-windows)"
} else {
    Miss "Eigen3 (vcpkg, x64-windows)"
    Hint "$VcpkgRoot\vcpkg.exe install eigen3:x64-windows"
    MarkMissing -Name "eigen3" -FixHint "vcpkg install eigen3" -Action {
        & $VcpkgExe install eigen3:x64-windows
    }
}

# =============================================================================
# 3. Project assets
# =============================================================================
Log "Checking project assets..."
$prototxt   = Join-Path $RepoRoot "models\MobileNetSSD_deploy.prototxt"
$caffemodel = Join-Path $RepoRoot "models\MobileNetSSD_deploy.caffemodel"
if (Test-Path $prototxt)   { Ok  "models\MobileNetSSD_deploy.prototxt" }
else { Miss "models\MobileNetSSD_deploy.prototxt"; Hint "see models\DOWNLOAD-INSTRUCTIONS.txt"; $script:HardErrors++ }

if (Test-Path $caffemodel) { Ok  "models\MobileNetSSD_deploy.caffemodel" }
else { Miss "models\MobileNetSSD_deploy.caffemodel"; Hint "see models\DOWNLOAD-INSTRUCTIONS.txt"; $script:HardErrors++ }

# Test video lives inside the repo at videos\video1.mp4
$TestVideo = Join-Path $RepoRoot "videos\video1.mp4"
if (Test-Path $TestVideo) {
    Ok "test video found at $TestVideo"
} else {
    Bad "no test video at $TestVideo"
    Hint "drop your MP4 at videos\video1.mp4 (committed with the repo)"
}

# =============================================================================
# 4. Summary + (optional) auto-install
# =============================================================================
Say ""
if ($script:Missing.Count -eq 0 -and $script:HardErrors -eq 0) {
    Log "All checks passed. You are ready to build." 
    exit 0
}

if ($script:Missing.Count -gt 0) {
    Say ""
    Log "Missing components:" 'Yellow'
    foreach ($m in $script:Missing) { Say ("  - {0}  ({1})" -f $m.Name, $m.FixHint) 'Yellow' }

    if ($Auto) {
        Say ""
        Log "Running install (-Auto)..." 'Cyan'
        foreach ($m in $script:Missing) {
            if ($m.Action) {
                Log ("Installing {0}..." -f $m.Name)
                & $m.Action
            } else {
                Bad ("Cannot auto-install '{0}'. Manual step required: {1}" -f $m.Name, $m.FixHint)
            }
        }
        Log "Auto-install finished. Re-run doctor to verify." 'Green'
    } else {
        Say ""
        Log "Re-run with -Auto to install everything that can be auto-installed." 'Cyan'
    }
}

if ($script:HardErrors -gt 0) { exit 1 }
exit 1
