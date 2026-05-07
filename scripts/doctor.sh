#!/usr/bin/env bash
# =============================================================================
# OpenWatch - Linux / WSL Ubuntu environment doctor
# -----------------------------------------------------------------------------
# Verifies that all required toolchain pieces are installed and at the right
# version. If something is missing or wrong, it prints the exact `apt`
# command needed to fix it, and (with --auto) installs missing pieces for
# you.
#
# Required toolchain:
#   - Ubuntu 24.04 LTS (native or WSL2)
#   - clang++ 18 (LLVM 18)
#   - cmake     >= 3.20
#   - ninja-build
#   - libopencv-dev      (>= 4.5, with DNN module)
#   - libeigen3-dev
#   - build-essential, pkg-config, git
#
# Usage (from anywhere):
#     bash scripts/doctor.sh           # diagnose only
#     bash scripts/doctor.sh --auto    # diagnose + auto-install missing deps
#     bash scripts/doctor.sh --quiet   # exit code only, no chatter
# =============================================================================

set -euo pipefail

# --- Locate repo root (this script is in <repo>/scripts) --------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Args -------------------------------------------------------------------
AUTO_INSTALL=0
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --auto)  AUTO_INSTALL=1 ;;
        --quiet) QUIET=1 ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^#\s\?//'
            exit 0
            ;;
        *) echo "Unknown flag: $arg" >&2; exit 2 ;;
    esac
done

# --- Pretty logging ---------------------------------------------------------
if [[ -t 1 ]]; then
    BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
else
    BLUE=''; GREEN=''; YELLOW=''; RED=''; BOLD=''; NC=''
fi
say()  { (( QUIET )) || echo -e "$*"; }
log()  { say "${BLUE}[doctor]${NC} $*"; }
ok()   { say "  ${GREEN}OK${NC}    $*"; }
miss() { say "  ${RED}MISSING${NC} $*"; }
bad()  { say "  ${YELLOW}WRONG${NC}   $*"; }
hint() { say "        ${BOLD}fix:${NC} $*"; }

# --- Track problems ---------------------------------------------------------
MISSING_PKGS=()
HARD_ERRORS=0

require_apt_pkg() {
    # require_apt_pkg <human-name> <command-to-test> <apt-package>
    local name="$1" probe="$2" pkg="$3"
    if command -v "$probe" >/dev/null 2>&1; then
        ok "$name (\`$probe\` -> $(command -v "$probe"))"
    else
        miss "$name"
        hint "sudo apt install -y $pkg"
        MISSING_PKGS+=("$pkg")
    fi
}

# =============================================================================
# 1. OS sanity
# =============================================================================
log "Checking operating system..."
if [[ ! -r /etc/os-release ]]; then
    miss "Cannot read /etc/os-release - this script targets Ubuntu Linux."
    HARD_ERRORS=$((HARD_ERRORS+1))
else
    . /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
        bad "Detected '${ID:-unknown}'. Officially supported: Ubuntu 24.04."
    elif [[ "${VERSION_ID:-}" != "24.04" ]]; then
        bad "Detected Ubuntu ${VERSION_ID:-unknown}. Officially supported: 24.04 LTS."
    else
        ok "Ubuntu 24.04 LTS"
    fi
fi

# =============================================================================
# 2. Required system packages
# =============================================================================
log "Checking required toolchain packages..."

# clang++ 18 specifically
if command -v clang++-18 >/dev/null 2>&1 || \
   { command -v clang++ >/dev/null 2>&1 && clang++ --version | grep -qE '\b(version )?1[89]\.'; }; then
    CXX_BIN="$(command -v clang++-18 || command -v clang++)"
    CXX_VER="$("${CXX_BIN}" --version | head -n1)"
    ok "clang++ 18 (${CXX_VER})"
else
    miss "clang++ 18 (LLVM 18 toolchain)"
    hint "sudo apt install -y clang-18 libc++-18-dev libc++abi-18-dev"
    MISSING_PKGS+=(clang-18 libc++-18-dev libc++abi-18-dev)
fi

# cmake >= 3.20
if command -v cmake >/dev/null 2>&1; then
    CMAKE_VER="$(cmake --version | head -n1 | awk '{print $3}')"
    CMAKE_MAJ="${CMAKE_VER%%.*}"; REST="${CMAKE_VER#*.}"; CMAKE_MIN="${REST%%.*}"
    if (( CMAKE_MAJ > 3 )) || { (( CMAKE_MAJ == 3 )) && (( CMAKE_MIN >= 20 )); }; then
        ok "cmake ${CMAKE_VER}"
    else
        bad "cmake ${CMAKE_VER} found, but >= 3.20 is required"
        hint "sudo apt install -y cmake     # 24.04 ships >= 3.28"
        MISSING_PKGS+=(cmake)
    fi
else
    miss "cmake"
    hint "sudo apt install -y cmake"
    MISSING_PKGS+=(cmake)
fi

# ninja
if command -v ninja >/dev/null 2>&1; then
    ok "ninja ($(ninja --version))"
else
    miss "ninja-build"
    hint "sudo apt install -y ninja-build"
    MISSING_PKGS+=(ninja-build)
fi

# pkg-config (used to detect OpenCV)
require_apt_pkg "pkg-config" pkg-config pkg-config

# git
require_apt_pkg "git" git git

# build-essential (provides make, dpkg-dev, etc.)
if dpkg -s build-essential >/dev/null 2>&1; then
    ok "build-essential"
else
    miss "build-essential"
    hint "sudo apt install -y build-essential"
    MISSING_PKGS+=(build-essential)
fi

# OpenCV (libopencv-dev) - probe via pkg-config
if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists opencv4; then
    OCV_VER="$(pkg-config --modversion opencv4)"
    ok "OpenCV ${OCV_VER} (libopencv-dev)"
else
    miss "OpenCV development headers (libopencv-dev, with DNN)"
    hint "sudo apt install -y libopencv-dev"
    MISSING_PKGS+=(libopencv-dev)
fi

# Eigen
if [[ -f /usr/include/eigen3/Eigen/Dense ]]; then
    ok "Eigen3 (/usr/include/eigen3)"
else
    miss "Eigen3 development headers"
    hint "sudo apt install -y libeigen3-dev"
    MISSING_PKGS+=(libeigen3-dev)
fi

# =============================================================================
# 3. Project assets
# =============================================================================
log "Checking project assets..."
if [[ -f "${REPO_ROOT}/models/MobileNetSSD_deploy.prototxt" ]]; then
    ok "models/MobileNetSSD_deploy.prototxt"
else
    miss "models/MobileNetSSD_deploy.prototxt"
    hint "see models/DOWNLOAD-INSTRUCTIONS.txt"
    HARD_ERRORS=$((HARD_ERRORS+1))
fi
if [[ -f "${REPO_ROOT}/models/MobileNetSSD_deploy.caffemodel" ]]; then
    ok "models/MobileNetSSD_deploy.caffemodel"
else
    miss "models/MobileNetSSD_deploy.caffemodel"
    hint "see models/DOWNLOAD-INSTRUCTIONS.txt"
    HARD_ERRORS=$((HARD_ERRORS+1))
fi

# Test video lives inside the repo at videos/video1.mp4
TEST_VIDEO="${REPO_ROOT}/videos/video1.mp4"
if [[ -f "${TEST_VIDEO}" ]]; then
    ok "test video found at ${TEST_VIDEO}"
else
    bad "no test video at ${TEST_VIDEO}"
    hint "drop your test MP4 at videos/video1.mp4 (gitignored, will not be committed)"
fi

# =============================================================================
# 4. Summary + (optional) auto-install
# =============================================================================
say
if (( ${#MISSING_PKGS[@]} == 0 )) && (( HARD_ERRORS == 0 )); then
    log "${GREEN}${BOLD}All checks passed. You are ready to build.${NC}"
    exit 0
fi

if (( ${#MISSING_PKGS[@]} > 0 )); then
    # Deduplicate
    UNIQUE_PKGS=$(printf "%s\n" "${MISSING_PKGS[@]}" | awk '!seen[$0]++' | tr '\n' ' ')
    say
    log "${YELLOW}Missing apt packages:${NC} ${UNIQUE_PKGS}"
    INSTALL_CMD="sudo apt update && sudo apt install -y ${UNIQUE_PKGS}"
    log "Install command:"
    say "    ${INSTALL_CMD}"

    if (( AUTO_INSTALL )); then
        say
        log "Running install (--auto)..."
        export DEBIAN_FRONTEND=noninteractive
        sudo apt update
        # shellcheck disable=SC2086
        sudo apt install -y --no-install-recommends ${UNIQUE_PKGS}

        # Make sure clang++ resolves to clang++-18 if that was just installed
        if [[ " ${UNIQUE_PKGS} " == *" clang-18 "* ]] && ! command -v clang++ >/dev/null 2>&1; then
            sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 100
            sudo update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-18   100
        fi
        log "${GREEN}Auto-install finished. Re-run doctor to verify.${NC}"
    fi
fi

if (( HARD_ERRORS > 0 )); then
    say
    log "${RED}Hard errors above must be fixed manually.${NC}"
    exit 1
fi

# Soft fail: missing deps but recoverable
exit 1
