# Contributing to OpenWatch

Thank you for your interest in contributing to **OpenWatch** — an open-source
person tracking and suspicious-activity detection system, and a collaboration
between **Dibcode** and the **Stevens Institute for Artificial Intelligence (SIAI)**.

We welcome contributions from researchers, students, engineers, and anyone
curious about computer vision, multi-object tracking, and behavior analysis
for real-world security applications.

---

## Before you start

- Read the [README.md](README.md) — especially the **roadmap** so you can see
  whether your idea fits Phase 1 (perception), Phase 2 (suspicious-activity
  detection / loitering), or Phase 3 (edge / detector upgrades).
- Check [open issues](../../issues) to avoid duplicating in-flight work.
- For large changes (new detector backend, the loitering analyzer, edge
  deployment), **open an issue first** so we can align on design.

---

## Get the project building locally

You should have a working build before you start contributing. OpenWatch
ships two scripts per OS:

| Script | Purpose |
|---|---|
| `scripts/doctor.sh` / `scripts/doctor.ps1` | Diagnose your toolchain. Pass `--auto` / `-Auto` to install missing pieces. |
| `scripts/run.sh`    / `scripts/run.ps1`    | Doctor + CMake configure + build + run, in one shot. |

```bash
# Ubuntu 24.04 / WSL2
bash scripts/run.sh

# Windows 10 (PowerShell)
powershell -ExecutionPolicy Bypass -File scripts\run.ps1
```

If you need something the scripts don't cover (custom vcpkg location,
non-default compiler, Docker image, etc.), the manual CMake commands are in
the README under **Manual build (no scripts)**.

---

## Git workflow

### 1. Fork & clone

```bash
git clone https://github.com/your-username/open-watch.git
cd open-watch
git remote add upstream https://github.com/dibcode/open-watch.git
```

### 2. Keep your fork up to date

```bash
git fetch upstream
git checkout main
git merge upstream/main
```

### 3. Create a feature branch

```bash
git checkout -b feat/loitering-zone-config
# or
git checkout -b fix/csv-timestamp-precision
```

### 4. Commit using Conventional Commits

```
feat:     new capability
fix:      bug correction
docs:     documentation update
refactor: code restructure without behavior change
test:     new or updated tests
chore:    build, tooling, CI changes
perf:     performance improvement
```

Examples:

```bash
git commit -m "feat: add polygon ROI for microbusiness loitering zones"
git commit -m "fix: clamp negative bounding box coordinates before CSV write"
git commit -m "docs: add WSL2 GPU passthrough setup guide"
git commit -m "chore: bump clang requirement to 18 in install-linux.sh"
```

### 5. Open a Pull Request

Push to your fork and open a PR against `main`. In the PR description include:

- **What** was changed and **why**
- Which **phase** of the roadmap it relates to (Phase 1 / 2 / 3)
- Which **platform(s)** you tested on (Windows, Linux native, WSL2)
- Any **known limitations** or follow-up tasks

---

## Pull Request checklist

Before submitting, confirm:

- [ ] Code compiles without errors on at least one supported platform
      (Windows + MSVC *or* Ubuntu 24.04 + clang++ 18)
- [ ] No hard-coded personal paths
      (e.g. `C:\Users\Zandor\...`, `/mnt/c/Users/...`) — use relative paths
      or documented constants
- [ ] New runtime artifacts (CSV, binaries, frame snapshots) are covered by
      `.gitignore`
- [ ] If behavior changed, the README's relevant section was updated
- [ ] Commit messages follow the convention above
- [ ] Install scripts (`scripts/install-*`) still succeed on a clean machine
      if you touched dependencies

---

## Coding standards

- **Language standard:** C++20 (matches `CMakeLists.txt`)
- **Linux compiler:** `clang++` 18 (LLVM 18) on Ubuntu 24.04
- **Windows compiler:** MSVC v143 (Visual Studio 2022)
- **Indentation:** 4 spaces, no tabs
- **Step comments:** keep the existing `// --- N. Section name ---` style for readability
- **Naming:** `camelCase` for locals, `UPPER_SNAKE_CASE` for constants
- **No magic numbers:** define thresholds as named constants
  (e.g. `CONF_THRESHOLD`, `PERSON_CLASS`, `LOITERING_THRESHOLD_SEC`)
- **Platform separation:** keep Windows and Linux source files separate
  (`src/tracker_windows.cpp`, `src/tracker_linux.cpp`); do not mix
  platform-specific APIs in a shared file
- **ByteTrack folder is vendored:** treat `bytetrack/` as a third-party
  library — do not modify it for project-specific behavior; build wrappers in
  `src/` instead

---

## Reporting bugs

Open an issue with:

1. Your platform (Windows version, Ubuntu version, native or WSL2)
2. Compiler and OpenCV version (`clang++ --version`, `pkg-config --modversion opencv4`)
3. Whether you used the install script or built manually
4. Steps to reproduce
5. Expected vs. actual behavior
6. Relevant error output or logs

---

## Suggesting features

Open an issue tagged `enhancement` with:

1. A clear description of the feature
2. Which roadmap phase it belongs to (Phase 1 / 2 / 3) — or "new phase"
3. Why it's useful for the research goals (especially anything that helps
   loitering / suspicious-activity detection around microbusinesses)
4. References (papers, libraries, prior work) if relevant

---

## Research contributions

OpenWatch is affiliated with the Stevens Institute for Artificial
Intelligence. If your contribution stems from or supports academic research:

- Include a brief note in the PR description about the research context
- If citing this project in a paper, see [CITATION.cff](CITATION.cff)

We especially welcome contributions that open new research directions in:

- **Behavior analysis from video** — loitering, dwell-time, anomaly detection
- **Human-machine interaction** under real-world surveillance conditions
- **Perception under challenging conditions** (occlusion, low light, crowding,
  outdoor microbusiness environments)
- **Edge AI** — running the pipeline efficiently on Raspberry Pi / Jetson /
  Arduino-class hardware

---

## Questions?

Open a GitHub Discussion or reach out via the contacts listed in the README.
