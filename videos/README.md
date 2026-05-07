# Test videos

Drop your test videos here. The default file the trackers look for is:

```
videos/video1.mp4
```

This folder **and its contents are tracked by git** — small reference
clips travel with the repo so anyone who clones it can immediately run
`scripts/run.sh` / `scripts/run.ps1` end-to-end and reproduce the same
output. Keep clips short (a few seconds to ~1 minute) to keep the repo
lightweight.

## How the source resolves this path

Both `src/tracker_linux.cpp` and `src/tracker_windows.cpp` look for the test
video in a small list of fallback locations, in order:

| Order | Path tried | Resolves correctly when running from |
|---|---|---|
| 1 | `../videos/video1.mp4`     | `build-linux/`                       (Linux)   |
| 1 | `../../videos/video1.mp4`  | `build-windows/Release/`              (Windows) |
| 2 | `videos/video1.mp4`        | the repo root                                   |
| 3 | `../../videos/video1.mp4`  | a deeper build subfolder (Linux)                |

The helper scripts (`scripts/run.sh`, `scripts/run.ps1`) always launch the
binary from the right place, so as long as `videos/video1.mp4` exists, the
tracker will find it.

## Where to get a test video

Any MP4 with one or more people walking through the frame works. A short
clip (10 - 60 seconds) is enough to verify the full
detect → track → CSV pipeline.

> Files in this folder are gitignored except for `README.md` and `.gitkeep`.
