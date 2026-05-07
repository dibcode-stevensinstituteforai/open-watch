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
  - [Linux / WSL Ubuntu 24.04 — manual build](#-linux--wsl-ubuntu-2404--manual-build)
  - [Windows 10 (PowerShell) — script-driven build](#-windows-10-powershell--script-driven-build)
- [Manual Windows build (without `run.ps1`)](#manual-windows-build-without-runps1)
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

> **Before you start, confirm two things are present in the repo (a fresh
> `git clone` already has them):**
> 1. The model files
>    [`models/MobileNetSSD_deploy.prototxt`](models/) and
>    [`models/MobileNetSSD_deploy.caffemodel`](models/) — both committed.
>    If yours are missing, see [`models/DOWNLOAD-INSTRUCTIONS.txt`](models/DOWNLOAD-INSTRUCTIONS.txt).
> 2. A test video at `videos/video1.mp4` — also committed
>    (see [Test video location](#test-video-location)).

OpenWatch builds with **two completely separate toolchains**:

| OS | Compiler | Build system | Dependencies | Approach |
|---|---|---|---|---|
| **Linux / WSL Ubuntu 24.04** | `clang++` 18 (LLVM 18) | CMake + Ninja | Native apt packages (`libopencv-dev`, `libeigen3-dev`) | **Raw commands** — copy/paste 4 lines, no script |
| **Windows 10** | MSVC v143 (Visual Studio 2022) | CMake + vcpkg | vcpkg-installed OpenCV + Eigen | **PowerShell helper script** that wires up vcpkg toolchain automatically |

> **Why two different approaches?** On Linux, the build is one apt-install
> away and the four CMake commands fit on one screen — there's no value in
> wrapping them in a script. On Windows, the vcpkg toolchain integration
> needs many flags that are easy to typo, so a script genuinely helps.

---

### 🐧 Linux / WSL Ubuntu 24.04 — manual build

#### Step 0 — Open a Bash shell at the repo root

`cd` into the `open-watch` folder wherever you cloned it.

**Native Linux:**

```bash
cd /path/to/open-watch
```

**WSL Ubuntu inside Windows:** your Windows drives are mounted under
`/mnt/`. Translate your Windows path by replacing `C:\` with `/mnt/c/` and
the backslashes with forward slashes. For example, if you cloned the repo
to `C:\Users\YourName\Documents\open-watch`, then in WSL you run:

```bash
cd "/mnt/c/Users/YourName/Documents/open-watch"
```

#### Step 1 — Install the toolchain (one-time, on a fresh Ubuntu 24.04)

```bash
sudo apt update
sudo apt install -y clang-18 cmake ninja-build pkg-config \
                    libopencv-dev libeigen3-dev build-essential
```

Total time: 2 - 5 minutes. Already installed? Skip this step.

To verify, the versions OpenWatch was developed against are:

```
Ubuntu 24.04.1 LTS, clang++ 18.1.3, cmake 3.28.x, ninja 1.11.x, OpenCV 4.6.0
```

#### Step 2 — Configure, build, run

The first time, create the build folder. After that, you only need it once.

```bash
mkdir -p build-linux
cd build-linux
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=clang++
cmake --build . --config Release
./person_detector_linux
```

That's the whole pipeline. The `build-linux/` folder is gitignored on
purpose — every contributor (and CI) creates their own.

#### What you'll see

- Live progress while Ninja compiles `tracker_linux.cpp` and the bytetrack `*.cpp` sources, then links into `person_detector_linux`.
- Once running, the binary prints:
  ```
  Model loaded from: ../models/MobileNetSSD_deploy.prototxt
  Video opened: ../videos/video1.mp4
  Processed frame: 50
  Processed frame: 100
  ...
  Done. Processed N frames. Check 'output/' folder.
  ```
- WSL is headless, so **no live window opens**. The binary instead writes:
  - `build-linux/output/tracking_data.csv`
  - `build-linux/output/track_frame_*.jpg` (frame snapshots with bounding boxes overlaid)

To visually confirm the bounding boxes look right, open one of the JPGs from
Windows Explorer (the files live on the Windows filesystem).

#### Subsequent runs

The first three commands set up `build-linux/`. After that, just rebuild +
run:

```bash
cd build-linux
cmake --build . --config Release
./person_detector_linux
```

To wipe and start over:

```bash
rm -rf build-linux/*    # from the repo root, or `cd ..` first
mkdir -p build-linux && cd build-linux
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=clang++
cmake --build . --config Release
./person_detector_linux
```

---

### 🪟 Windows 10 (PowerShell) — script-driven build

#### Step 0 — One-time GUI installs

These need GUI installers; the script can't do them for you:

| Component | Where to get it |
|---|---|
| **Git for Windows** | [git-scm.com/download/win](https://git-scm.com/download/win) |
| **CMake ≥ 3.20** (any 3.20+ works; verified with 4.3.x) | [cmake.org/download](https://cmake.org/download/) |
| **Visual Studio 2022** with the **Desktop development with C++** workload | [visualstudio.microsoft.com/downloads](https://visualstudio.microsoft.com/downloads/) |

> The Windows target compiles with **MSVC v143** (provided by VS 2022).
> clang/LLVM is **Linux-only** in this project.

#### Step 1 — Open PowerShell at the repo root and run

```powershell
cd C:\path\to\open-watch
powershell -ExecutionPolicy Bypass -File scripts\run.ps1
```

That's it. The script will:

1. Run `scripts\doctor.ps1` to inspect your toolchain.
2. If anything is missing, prompt: `Auto-install missing dependencies (vcpkg + OpenCV + Eigen) now? [y/N]`
   - Type `y` → it bootstraps [vcpkg](https://github.com/microsoft/vcpkg) at
     `C:\vcpkg` and runs:
     - `vcpkg install opencv4[core,dnn,jpeg,png,ffmpeg]:x64-windows` (~15 - 30 min the first time)
     - `vcpkg install eigen3:x64-windows` (~1 min)
3. Create `build-windows\` at the repo root.
4. Configure CMake with the VS 2022 generator + vcpkg toolchain file.
5. Compile with MSBuild → `build-windows\Release\tracker_windows.exe`.
6. Launch the tracker. **A live OpenCV window opens** showing your video
   with bounding boxes + persistent track IDs. Press <kbd>Esc</kbd> to stop.
7. Write `tracking_data.csv` to `build-windows\Release\`.

#### Optional: doctor only (no install, no build)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1        # report only
powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1 -Auto  # report + bootstrap vcpkg + install missing packages
```

#### Useful flags for `run.ps1`

| Flag | Effect |
|---|---|
| `-Yes`              | Non-interactive: auto-confirm the install prompt |
| `-BuildOnly`        | Configure + compile, but don't launch the tracker |
| `-Clean`            | Wipe `build-windows\` before configuring |
| `-VcpkgRoot <path>` | Use a vcpkg install at a custom location (default `C:\vcpkg`) |

> First-time `vcpkg install opencv4[…]` typically takes 15 - 30 minutes. After
> that, subsequent runs reuse the cache and are fast.

---

## Manual Windows build (without `run.ps1`)

If you'd rather run the CMake commands yourself instead of using the helper
script, here is what `scripts\run.ps1` does internally. The Linux instructions
above are already the manual approach — there's nothing to "unwrap" there.

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
├── scripts/                         ← Windows-only helpers (Linux uses raw cmake commands)
│   ├── doctor.ps1                   ← Diagnose the Windows toolchain (-Auto installs)
│   └── run.ps1                      ← Windows: doctor + cmake + build + run
├── videos/                          ← Test footage (folder + contents tracked by git)
│   ├── README.md
│   ├── .gitkeep
│   └── video1.mp4                   ← default test clip the trackers look for
├── build-windows/                   ← Created by run.ps1 on first run (gitignored)
├── build-linux/                     ← You create this with `mkdir` (gitignored)
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
> control. They are listed in `.gitignore`. On Linux you create
> `build-linux/` with `mkdir`; on Windows `scripts\run.ps1` creates
> `build-windows/` for you.

---

## Roadmap

### ✅ Phase 1 — Perception foundation (this repo)
- [x] Windows build with live video display + CSV
- [x] Linux / WSL build with frame snapshots + CSV
- [x] Reproducible builds: raw CMake commands on Linux (4 lines), `scripts\run.ps1` helper on Windows (auto-installs vcpkg + OpenCV + Eigen)
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
