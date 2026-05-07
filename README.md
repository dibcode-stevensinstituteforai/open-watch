<div align="center">

# OpenWatch

### Open-source person tracking and suspicious-activity detection for AI research and real-world security challenges

![C++20](https://img.shields.io/badge/C%2B%2B-20-blue.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20WSL-lightgrey.svg)
![CMake](https://img.shields.io/badge/build-CMake%20%E2%89%A5%203.20-064F8C.svg)
![OpenCV](https://img.shields.io/badge/OpenCV-%E2%89%A5%204.5-5C3EE8.svg)
![Status: Phase 1](https://img.shields.io/badge/status-Phase%201%20%7C%20tracking%20%2B%20CSV-orange.svg)

A collaboration between **[Dibcode](https://dibcode.com)** and the
**[Stevens Institute for Artificial Intelligence (SIAI)](https://www.stevens.edu/stevens-institute-for-artificial-intelligence)**
at Stevens Institute of Technology.

</div>

---

## Project description

> **OpenWatch is an open-source person tracking and suspicious-activity
> detection system built for AI research and real-world security challenges.
> It is designed to track individuals and detect behavioral patterns such as
> *loitering around microbusinesses*. A collaboration between Dibcode and the
> Stevens Institute for Artificial Intelligence (SIAI).**

OpenWatch is being developed in two phases:

| Phase | Goal | Status |
|---|---|---|
| **Phase 1 — Perception foundation** | Real-time multi-person detection + tracking with persistent IDs, exporting structured CSV (bounding box + timestamp + track ID) for downstream analysis | ✅ Implemented (this repo) |
| **Phase 2 — Suspicious-activity detection** | Loitering analysis (time-in-zone per track ID), zone definitions for microbusiness fronts, alerting + labeled dataset generation | 🔬 In design |
| **Phase 3 — Edge deployment** | Run the pipeline on Raspberry Pi / NVIDIA Jetson / Arduino-class devices for on-site security at small businesses | 🛣️ Roadmap |

Phase 1 produces the **CSV ground truth** (`x, y, width, height, time_in_seconds, track_id`) that Phase 2's loitering detector will consume.

---

## Table of contents

- [Why OpenWatch](#why-openwatch)
- [SIAI research alignment](#siai-research-alignment)
- [Features](#features)
- [Architecture](#architecture)
- [Supported platforms](#supported-platforms)
- [Quick start](#quick-start)
  - [The scripts at a glance](#the-scripts-at-a-glance)
  - [What gets auto-installed (and what does not)](#what-gets-auto-installed-and-what-does-not)
  - [Linux / WSL example session](#-linux--wsl-ubuntu-2404--example-session)
  - [Windows 10 example session](#-windows-10-powershell--example-session)
  - [Useful flags](#useful-flags)
- [Manual build (no scripts)](#manual-build-no-scripts)
- [Test video location](#test-video-location)
- [Running the tracker](#running-the-tracker)
- [Output format](#output-format)
- [Project structure](#project-structure)
- [Roadmap](#roadmap)
- [How to contribute](#how-to-contribute)
- [Code of conduct](#code-of-conduct)
- [License](#license)
- [Authors and acknowledgements](#authors-and-acknowledgements)

---

## Why OpenWatch

Small businesses ("microbusinesses") are disproportionately exposed to crimes
of opportunity — and the people committing them often *loiter* around the
premises before acting. Most off-the-shelf surveillance systems either:

- only **record** (no real-time understanding), or
- ship as closed, expensive, vendor-locked black boxes.

OpenWatch is an **open, reproducible, research-grade** baseline that any
student, researcher, or small-business owner can build on:

- 🔍 **Person detection** — MobileNet-SSD via OpenCV's DNN module
- 🆔 **Persistent multi-object tracking** — ByteTrack-based ID assignment
- 📊 **Structured CSV export** — the data substrate for behavior analysis
- 🚨 **Designed for behavior analysis** (loitering / suspicious dwell-time) on top of the CSV
- ⚡ **CPU-only** — no GPU required, runs on a laptop or an edge device
- 🖥️ **Cross-platform** — Windows (MSVC) and Linux/WSL Ubuntu (Clang 18 + C++20)
- 📦 **One-command install** per platform (see [Quick start](#quick-start-one-command-per-os))

---

## SIAI research alignment

This project is built in alignment with the research mission of the
[Stevens Institute for Artificial Intelligence (SIAI)](https://www.stevens.edu/stevens-institute-for-artificial-intelligence),
which advances AI and machine learning to solve complex, real-world problems
across disciplines.

| SIAI research area | How OpenWatch contributes |
|---|---|
| **Robotics, perception & human-machine interaction** | Reproducible perception pipeline for tracking humans in video |
| **Foundations of AI & machine learning** | Open baseline for benchmarking detection + tracking + behavior-recognition algorithms |
| **Societal impact** | Affordable, open security tooling for microbusinesses; loitering / suspicious-activity research |
| **Cognitive networking and computing** | Structured CSV output enables downstream AI/ML workflows and edge deployment |

> *"SIAI hopes to amplify the impact of its research and analysis through
> collaborations with industry, government, foundations and academic
> partners."* — Stevens Institute for Artificial Intelligence

This collaboration between **Dibcode** (industry) and **Prof. Iounut** at
Stevens (academia) reflects exactly that cross-sector model.

---

## Features

- 🔍 Person detection with MobileNet-SSD (Caffe model, OpenCV DNN)
- 🆔 Persistent ID tracking across frames with ByteTrack (vendored under `bytetrack/`)
- 📊 CSV export of `x, y, width, height, time_in_seconds, track_id` per tracked person per frame
- 🖥️ Live overlay window with colored bounding boxes and ID labels (Windows)
- 🖼️ Frame-snapshot saving for headless environments such as WSL (Linux)
- ⚡ CPU-only inference — no GPU required
- 🔁 Cross-platform: Windows (MSVC + vcpkg) and Linux / WSL Ubuntu 24.04 (Clang 18 + Ninja)
- 🧱 Foundation for the upcoming loitering / suspicious-activity detector (Phase 2)

---

## Architecture

```
                       Video input (MP4)
                              │
                              ▼
                  ┌─────────────────────────┐
                  │  OpenCV VideoCapture    │  ← frame extraction
                  └────────────┬────────────┘
                               │
                               ▼
                  ┌─────────────────────────┐
                  │  MobileNet-SSD (DNN)    │  ← person detection (class 15)
                  │  OpenCV DNN, CPU         │   confidence ≥ 0.4
                  └────────────┬────────────┘
                               │ std::vector<byte_track::Object>
                               ▼
                  ┌─────────────────────────┐
                  │  ByteTracker             │  ← multi-object tracking
                  │  (byte_track::)          │   persistent track IDs
                  └────────────┬────────────┘
                               │ tracked objects (id + bbox)
                               ▼
              ┌─────────────────────────────────────┐
              │  Output layer                        │
              │   ├── live bbox overlay  (Windows)   │
              │   ├── frame snapshots    (Linux/WSL) │
              │   └── tracking_data.csv  (both)      │  ← Phase 1 deliverable
              └─────────────────────────────────────┘
                               │
                               ▼     (next: Phase 2)
              ┌─────────────────────────────────────┐
              │  Suspicious-activity analyzer        │
              │   ├── per-track dwell time           │
              │   ├── microbusiness zone overlap     │
              │   └── loitering alerts               │
              └─────────────────────────────────────┘
```

---

## Supported platforms

| Platform | Compiler | Standard | Build system | Display |
|---|---|---|---|---|
| **Ubuntu 24.04 LTS** (native or WSL2) | `clang++` 18 (LLVM 18) | C++20 | CMake + Ninja | Frame snapshots in `build-linux/output/` |
| **Windows 10** | MSVC v143 (Visual Studio 2022) | C++20 | CMake + vcpkg | Live `cv::imshow` window |

> Ubuntu 24.04 is the officially supported Linux target because it ships
> `clang-18` and the C++20 standard library that OpenWatch depends on.

---

## Quick start

> **Before you start:**
> 1. Confirm the MobileNet-SSD model files are present at
>    `models/MobileNetSSD_deploy.prototxt` and
>    `models/MobileNetSSD_deploy.caffemodel`. They are committed in the repo,
>    so a fresh `git clone` already has them. If yours doesn't, see
>    [`models/DOWNLOAD-INSTRUCTIONS.txt`](models/DOWNLOAD-INSTRUCTIONS.txt).
> 2. Confirm a test video at `videos/video1.mp4` (inside the cloned repo).
>    This folder **and its contents are tracked by git**, so any reference
>    clip travels with the repo. See [Test video location](#test-video-location).

### The scripts at a glance

OpenWatch ships **one entry-point script per OS**. The user runs **one
command** and gets a working tracker:

| OS | The one command you run | Where you run it |
|---|---|---|
| Linux / WSL Ubuntu 24.04 | `bash scripts/run.sh` | from the repo root, in a Bash shell |
| Windows 10               | `powershell -ExecutionPolicy Bypass -File scripts\run.ps1` | from the repo root, in PowerShell |

`run.{sh,ps1}` does **everything end-to-end** in this order:

1. Runs the matching `doctor.{sh,ps1}` internally to inspect your toolchain.
2. If anything is missing, **prompts you** before installing it.
3. Creates the appropriate build folder (`build-linux/` or `build-windows/`).
4. Configures CMake.
5. Compiles.
6. Launches the tracker.

You **never** need to call `doctor` separately — it's optional and only
useful if you want to inspect your environment before any build happens.

### What gets auto-installed (and what does not)

The rule of thumb is simple: **anything with a CLI installer is
auto-installed; anything that needs a GUI installer is not.**

#### 🐧 On Linux / WSL Ubuntu 24.04 — fully hands-off

After you confirm the install prompt with `y`, `run.sh` runs:

```bash
sudo apt update
sudo apt install -y clang-18 libc++-18-dev libc++abi-18-dev \
                    cmake ninja-build pkg-config git build-essential \
                    libopencv-dev libeigen3-dev
```

That's the whole toolchain. Total time on a fresh Ubuntu 24.04: **2 - 5 minutes**.

#### 🪟 On Windows 10 — three tools you install once, by hand

These need GUI installers and the script cannot do them for you. The
doctor will report each as `MISSING` with a download link if needed:

| Component | Where to get it |
|---|---|
| **Git for Windows** | [git-scm.com/download/win](https://git-scm.com/download/win) |
| **CMake ≥ 3.20** (any 3.20+ works; verified with 4.3.x) | [cmake.org/download](https://cmake.org/download/) |
| **Visual Studio 2022** with the **Desktop development with C++** workload (provides the **MSVC v143** compiler — the Windows build uses MSVC; clang/LLVM is **Linux-only** here) | [visualstudio.microsoft.com/downloads](https://visualstudio.microsoft.com/downloads/) |

Once those three are installed, **everything else is auto-installed** by
`run.ps1` after you confirm the prompt with `y`:

- [vcpkg](https://github.com/microsoft/vcpkg) at `C:\vcpkg` (cloned + bootstrapped)
- `opencv4[core,dnn,jpeg,png,ffmpeg]:x64-windows` via vcpkg (~15 - 30 min the first time)
- `eigen3:x64-windows` via vcpkg (~1 min)

### 🐧 Linux / WSL Ubuntu 24.04 — example session

```bash
git clone https://github.com/dibcode/open-watch.git
cd open-watch

# All-in-one: doctor -> (auto-install if needed) -> cmake -> build -> run
bash scripts/run.sh
```

What you'll see:
- Live progress lines while compiling (Ninja).
- Frame-by-frame progress from the tracker (`Processed frame: 50` ...).
- WSL is headless, so **no live window opens**. Instead the binary writes:
  - `build-linux/output/tracking_data.csv`
  - `build-linux/output/track_frame_*.jpg` (frame snapshots with bounding boxes overlaid)

Open one of the JPGs from Windows Explorer to visually confirm the bounding
boxes look right.

Optional standalone diagnostic (does **not** install anything):

```bash
bash scripts/doctor.sh        # report only
bash scripts/doctor.sh --auto # report + apt-install missing pieces
```

### 🪟 Windows 10 (PowerShell) — example session

```powershell
git clone https://github.com/dibcode/open-watch.git
cd open-watch

# All-in-one: doctor -> (auto-install if needed) -> cmake -> build -> run
powershell -ExecutionPolicy Bypass -File scripts\run.ps1
```

What you'll see:
- Live progress lines while compiling (MSBuild).
- A live OpenCV window opens with bounding boxes + persistent track IDs.
- Press <kbd>Esc</kbd> to stop early, or let the video play to the end.
- The CSV is written to `build-windows\Release\tracking_data.csv`.

Optional standalone diagnostic (does **not** install anything):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1        # report only
powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1 -Auto  # report + bootstrap vcpkg + vcpkg install
```

### Useful flags

| Flag (Linux) | Flag (Windows) | Effect |
|---|---|---|
| `--yes`        | `-Yes`        | Non-interactive: auto-confirm the install prompt |
| `--build-only` | `-BuildOnly`  | Configure + compile, but don't launch the tracker |
| `--clean`      | `-Clean`      | Wipe `build-linux/` or `build-windows/` before configuring |
|                | `-VcpkgRoot <path>` | Use a vcpkg install at a custom location (default `C:\vcpkg`) |

> First-time `vcpkg install opencv4[…]` typically takes 15 - 30 minutes. After
> that, subsequent runs reuse the cache and are fast.

---

## Manual build (no scripts)

If you'd rather run the CMake commands yourself, these are the exact commands
`scripts/run.sh` and `scripts/run.ps1` execute internally.

### Manual — Linux / WSL Ubuntu 24.04

```bash
# 1. Install system dependencies (one-time)
sudo apt update
sudo apt install -y clang-18 cmake ninja-build pkg-config \
                    libopencv-dev libeigen3-dev build-essential

# 2. From the repo root, create + enter the Linux build folder
mkdir -p build-linux && cd build-linux

# 3. Configure
cmake .. -G Ninja \
         -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_CXX_COMPILER=clang++ \
         -DCMAKE_CXX_STANDARD=20

# 4. Compile
cmake --build . --config Release

# 5. Run (from build-linux/)
./person_detector_linux
```

### Manual — Windows 10 (MSVC + vcpkg)

```powershell
# 1. Install vcpkg + dependencies (one-time)
git clone https://github.com/microsoft/vcpkg.git C:\vcpkg
C:\vcpkg\bootstrap-vcpkg.bat
C:\vcpkg\vcpkg.exe install opencv4[core,dnn,jpeg,png,ffmpeg]:x64-windows eigen3:x64-windows

# 2. From the repo root, create + enter the Windows build folder
mkdir build-windows ; cd build-windows

# 3. Configure
cmake .. -G "Visual Studio 17 2022" -A x64 `
         -DCMAKE_BUILD_TYPE=Release `
         -DCMAKE_CXX_STANDARD=20 `
         -DCMAKE_PREFIX_PATH="C:/vcpkg/installed/x64-windows" `
         -DCMAKE_TOOLCHAIN_FILE="C:/vcpkg/scripts/buildsystems/vcpkg.cmake"

# 4. Compile
cmake --build . --config Release

# 5. Run (from build-windows\Release\)
cd Release
.\tracker_windows.exe
```

---

## Test video location

The default path the trackers look for is **`videos/video1.mp4` inside the
repo**. Both `src/tracker_linux.cpp` and `src/tracker_windows.cpp` try a
small list of repo-relative fallbacks so the binary works no matter which
directory you launch it from:

| Order | Path tried             | Resolves correctly when launching from           |
|------:|------------------------|--------------------------------------------------|
| 1     | `../videos/video1.mp4`    | `build-linux/`            (Linux canonical)   |
| 1     | `../../videos/video1.mp4` | `build-windows/Release/`  (Windows canonical) |
| 2     | `videos/video1.mp4`       | the repo root                                 |
| 3     | the other repo-relative variant | a different build subfolder             |

All paths are **repo-relative** — there are no hardcoded absolute paths or
usernames in the source, so the program works on any machine.

Recommended layout:

```
open-watch/
├── ...
└── videos/
    ├── README.md
    ├── .gitkeep
    └── video1.mp4     ← drop your test video here (committed with the repo)
```

> The `videos/` folder **and its contents are tracked by git**. A small
> reference clip travels with the repo, so anyone who clones it can run the
> pipeline end-to-end without having to source their own footage. Keep
> clips short (a few seconds to ~1 minute) so the repo stays lightweight.

---

## Running the tracker

| Platform | Live window? | Frame snapshots? | CSV file location |
|---|---|---|---|
| **Windows** | ✅ Yes (`cv::imshow`, press <kbd>Esc</kbd> to stop) | ❌ | `build-windows\Release\tracking_data.csv` |
| **Linux / WSL** | ❌ (headless on WSL) | ✅ Saved into `build-linux/output/track_frame_*.jpg` | `build-linux/output/tracking_data.csv` |

> **Why no live window on WSL?** WSL Ubuntu does not have a display server
> bound to the Windows desktop by default. Saving periodic frames to disk is
> the standard workaround and gives you reproducible visual evidence the
> pipeline ran end-to-end.

---

## Output format

Both platforms produce the same CSV schema:

| Column | Type | Description |
|---|---|---|
| `x` | int | Top-left X coordinate of bounding box (pixels) |
| `y` | int | Top-left Y coordinate of bounding box (pixels) |
| `width` | int | Width of bounding box (pixels) |
| `height` | int | Height of bounding box (pixels) |
| `time_in_seconds` | double | Frame timestamp (`frameNum / fps`) |
| `track_id` | int | Persistent ID assigned by ByteTrack |

**Example:**

```csv
x,y,width,height,time_in_seconds,track_id
142,88,65,180,0.033333,1
310,95,60,175,0.033333,2
145,90,64,181,0.066667,1
```

> One row = one tracked person in one frame. Multiple rows per frame if
> multiple people are detected. This is the input format Phase 2's loitering
> analyzer will consume.

---

## Project structure

```
open-watch/
├── models/
│   ├── MobileNetSSD_deploy.prototxt
│   ├── MobileNetSSD_deploy.caffemodel
│   └── DOWNLOAD-INSTRUCTIONS.txt
├── src/
│   ├── tracker_windows.cpp          ← Windows tracker (live window + CSV)
│   └── tracker_linux.cpp            ← Linux/WSL tracker (snapshots + CSV)
├── bytetrack/                       ← Vendored ByteTrack C++ algorithm
│   ├── BYTETracker.{h,cpp}
│   ├── KalmanFilter.{h,cpp}
│   ├── lapjv.{h,cpp}
│   ├── Object.{h,cpp}
│   ├── Rect.{h,cpp}
│   └── STrack.{h,cpp}
├── scripts/
│   ├── doctor.sh                    ← Diagnose the Linux/WSL toolchain (--auto installs)
│   ├── doctor.ps1                   ← Diagnose the Windows toolchain (-Auto installs)
│   ├── run.sh                       ← Linux/WSL: doctor + cmake + build + run
│   └── run.ps1                      ← Windows:    doctor + cmake + build + run
├── videos/                          ← Test footage (folder + contents tracked by git)
│   ├── README.md
│   ├── .gitkeep
│   └── video1.mp4                   ← default test clip the trackers look for
├── build-windows/                   ← Created by run.ps1 on first run (gitignored)
├── build-linux/                     ← Created by run.sh  on first run (gitignored)
├── CMakeLists.txt
├── CITATION.cff
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── LICENSE
└── README.md
```

> **Should I commit `build-windows/` and `build-linux/`?** **No.** They
> contain machine-specific compiled artifacts (object files, generated
> Makefiles, vcpkg-resolved paths, etc.) that don't belong in version
> control. They are listed in `.gitignore`. The install scripts recreate
> them on every machine.

---

## Roadmap

### ✅ Phase 1 — Perception foundation (this repo)
- [x] Windows build with live video display + CSV
- [x] Linux / WSL build with frame snapshots + CSV
- [x] Two-script UX per OS (`doctor` + `run`) with auto-install fallback
- [x] Cross-platform CMake (`C++20`, MSVC + clang 18)

### 🔬 Phase 2 — Suspicious-activity detection
- [ ] Microbusiness zone definition (polygon ROIs in image space)
- [ ] Per-track dwell-time accumulation across `track_id`
- [ ] Loitering classifier (configurable threshold, e.g. > 60 s in zone)
- [ ] Alert event log (CSV/JSON) — frame, track_id, zone, dwell_time
- [ ] Labeled dataset generation: normal vs. loitering samples

### 🛣️ Phase 3 — Edge & detector upgrades
- [ ] YOLOX as drop-in detector alternative to MobileNet-SSD
- [ ] Edge deployment — Raspberry Pi 5, NVIDIA Jetson, Arduino-class MCUs
- [ ] RTSP / live-camera input mode
- [ ] Optional GPU acceleration (CUDA / OpenCL backends)

---

## How to contribute

We welcome contributions from researchers, students, and engineers. This
project is an active collaboration with Stevens Institute of Technology and
is intended to grow as a research resource.

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for the full guide. Quick version:

```bash
# 1. Fork, then clone your fork
git clone https://github.com/your-username/open-watch.git
cd open-watch

# 2. Create a branch
git checkout -b feat/loitering-zone-config

# 3. Make changes, commit using Conventional Commits
git commit -m "feat: add polygon-based microbusiness zone config"

# 4. Push and open a PR against main
```

### Contribution areas

| Area | Examples |
|---|---|
| 🐛 Bug fixes | Wrong bbox coordinates, CSV encoding issues, build-script edge cases |
| ✨ Phase 2 features | Zone definitions, loitering detector, alerting |
| 📚 Documentation | Setup guides, diagrams, video walkthroughs |
| 🔬 Research tools | Python analysis notebooks, dataset labeling helpers |
| 🧪 Testing | Test videos with known ground truth, regression CSVs |
| 🐳 DevOps | Docker image, CI matrix (Ubuntu 24.04 + Windows) |

---

## Code of conduct

This project follows the
[Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating,
you are expected to uphold this standard. In keeping with SIAI's commitment
to interdisciplinary, inclusive research, contributors from all backgrounds
(academia, industry, students) are warmly welcomed.

---

## License

OpenWatch is licensed under the **MIT License** — see [LICENSE](LICENSE) for
details. You are free to use, modify, and distribute this software for both
research and commercial purposes with attribution.

---

## Authors and acknowledgements

**Zandor Sanchez** — Founder, [Dibcode](https://dibcode.com)
Lead developer and industry collaborator.

**Prof. Iounut** — Faculty, Stevens Institute of Technology
Academic collaborator through the
[Stevens Institute for Artificial Intelligence (SIAI)](https://www.stevens.edu/stevens-institute-for-artificial-intelligence).

### Third-party libraries

- [OpenCV](https://opencv.org/) — Computer vision and DNN inference
- [ByteTrack](https://github.com/ifzhang/ByteTrack) — Multi-object tracking algorithm (vendored under `bytetrack/`)
- [Eigen](https://eigen.tuxfamily.org/) — Linear algebra (used by ByteTrack's Kalman filter)
- [MobileNet-SSD](https://github.com/chuanqi305/MobileNet-SSD) — Caffe detection model

---

> *"Advancing AI and machine learning to solve complex problems that advance
> technology — and make the world a better place."*
> — Stevens Institute for Artificial Intelligence
