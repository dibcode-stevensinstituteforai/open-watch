#!/usr/bin/env bash
# =============================================================================
# OpenWatch - Linux / WSL Ubuntu one-shot runner
# -----------------------------------------------------------------------------
# What this script does:
#   1. Runs scripts/doctor.sh to verify the environment.
#      - If something is missing, it offers to auto-install (sudo apt) before
#        continuing. Pass --yes to skip the prompt.
#   2. Configures CMake into build-linux/  (Ninja + clang++ + Release + C++20)
#   3. Compiles.
#   4. Runs the binary from inside build-linux/ so the source's relative
#      paths (../../models, ../../../videos/video1.mp4) resolve correctly.
#
# Usage (from anywhere):
#     bash scripts/run.sh
#     bash scripts/run.sh --yes        # don't prompt before auto-install
#     bash scripts/run.sh --build-only # configure + compile, don't run
#     bash scripts/run.sh --clean      # wipe build-linux/ before configuring
# =============================================================================

set -euo pipefail

# --- Locate repo root -------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# --- Args -------------------------------------------------------------------
ASSUME_YES=0
BUILD_ONLY=0
CLEAN=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)        ASSUME_YES=1 ;;
        --build-only)    BUILD_ONLY=1 ;;
        --clean)         CLEAN=1 ;;
        -h|--help)       grep '^#' "$0" | sed 's/^#\s\?//'; exit 0 ;;
        *) echo "Unknown flag: $arg" >&2; exit 2 ;;
    esac
done

# --- Pretty logging ---------------------------------------------------------
if [[ -t 1 ]]; then
    BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
    BLUE=''; GREEN=''; YELLOW=''; RED=''; NC=''
fi
log() { echo -e "${BLUE}[run]${NC} $*"; }
ok()  { echo -e "${GREEN}[ok]${NC}  $*"; }
die() { echo -e "${RED}[err]${NC} $*" >&2; exit 1; }

# =============================================================================
# 1. Run the doctor (and auto-install if needed)
# =============================================================================
log "Running environment doctor..."
if bash "${SCRIPT_DIR}/doctor.sh"; then
    ok "Environment looks good."
else
    log "${YELLOW}Doctor reported issues.${NC}"
    if (( ASSUME_YES )); then
        REPLY="y"
    else
        printf "Auto-install missing dependencies via apt now? [y/N] "
        read -r REPLY || REPLY=""
    fi
    if [[ "${REPLY,,}" == "y" || "${REPLY,,}" == "yes" ]]; then
        bash "${SCRIPT_DIR}/doctor.sh" --auto || die "Auto-install failed."
        # Re-verify after install
        bash "${SCRIPT_DIR}/doctor.sh" --quiet || die "Doctor still reports issues. Aborting."
        ok "Dependencies installed."
    else
        die "Aborted. Install the missing pieces and re-run."
    fi
fi

# =============================================================================
# 2. Configure CMake
# =============================================================================
BUILD_DIR="${REPO_ROOT}/build-linux"
if (( CLEAN )) && [[ -d "${BUILD_DIR}" ]]; then
    log "Cleaning ${BUILD_DIR}..."
    rm -rf "${BUILD_DIR}"
fi
mkdir -p "${BUILD_DIR}"

# Ensure clang++ resolves; prefer clang++-18 if present
if command -v clang++-18 >/dev/null 2>&1; then
    CXX_BIN="$(command -v clang++-18)"
elif command -v clang++ >/dev/null 2>&1; then
    CXX_BIN="$(command -v clang++)"
else
    die "clang++ not found even after doctor run."
fi

log "Configuring CMake (Ninja, Release, ${CXX_BIN})..."
cd "${BUILD_DIR}"
cmake .. \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER="${CXX_BIN}" \
    -DCMAKE_CXX_STANDARD=20

# =============================================================================
# 3. Build
# =============================================================================
log "Compiling..."
cmake --build . --config Release -j"$(nproc)"
ok "Build complete: ${BUILD_DIR}/person_detector_linux"

if (( BUILD_ONLY )); then
    log "Build-only mode. Skipping run."
    exit 0
fi

# =============================================================================
# 4. Run
# =============================================================================
log "Launching person tracker..."
log "Output (CSV + frame snapshots) -> ${BUILD_DIR}/output/"
echo
# Run from build-linux/ so the binary's relative paths resolve.
cd "${BUILD_DIR}"
./person_detector_linux

echo
ok "Done."
ok "Tracking CSV:    ${BUILD_DIR}/output/tracking_data.csv"
ok "Frame snapshots: ${BUILD_DIR}/output/track_frame_*.jpg"
