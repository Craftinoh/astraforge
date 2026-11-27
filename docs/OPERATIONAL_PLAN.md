# RTX 3070 operational plan

This is the durable execution plan for the NVIDIA-first AstraForge work. Read it with
`AGENTS.md` and `progress-journal.md` when resuming. Update the status table whenever a
work item changes state or new evidence changes its priority.

## Objective and acceptance target

Deliver the most stable and efficient build supported by the available source for a
desktop RTX 3070 8 GB and Ryzen 7 7700X. The performance target is at least 30 real
application FPS with a 1% low of at least 30 across repeated gameplay captures. This is
an acceptance target, not a promised result. Visual correctness, device stability,
frametime consistency, and memory safety are required alongside performance.

Public files and reports use anonymous scene names and must not identify the private
application, publisher, executable, save data, or personal paths.

## Current verified baseline

| Area | State | Evidence boundary |
|---|---|---|
| Source | COOL_FOX Pareto-residency descendant plus focused credited ports | Exact origins are in `source-credits.md` and the nested `LOCAL-CHANGES.md` |
| Publication | Always verify live local/remote refs before continuing or publishing | The branch was clean at the prior O8 checkpoint; later commits must be checked with Git |
| Build | Last clean artifacts: `20261127-042402-Both-thinlto-native-7e316a03` at `abcb275`; a new build is pending for per-heap bake coverage | Existing build used Rust 1.98.1/MSVC/DXC 10.0.26100.0, Thin LTO, and native CPU; prior `--help` checks pass; no current-patch artifact yet |
| Automated tests | Per-heap coverage passes serial diagnostic (407/35 ignored) and optimized Release (349/34 ignored); earlier parallel runs showed intermittent test/process failures | Unit evidence only; no GPU gameplay, visual check, or FPS result |
| Hardware | RTX 3070 is first DXGI adapter; driver 610.88, SM 6.8, Wave32, PCIe Gen4 x16; Ryzen 7 7700X 8C/16T; 32 GiB RAM; Windows 11 Pro 26H2 | Latest raw inventory remains local and ignored; BAR1 only suggests Resizable BAR |
| Runtime data | `VICTORY_GAME_DIR` is unset; two executables were found under the standard library root but neither was confirmed as the authorized runtime | No shader prewarm, visual review, or gameplay capture yet |
| Memory readiness | Latest sample at 03:47 CET reported 10.32 GiB available commit against the 12 GiB launch floor and 11.92 GiB available physical RAM | Volatile; collect again immediately before launch; runtime launch remains blocked by the guard |
| Commit preflight | Shared check enforces a 12 GiB hard minimum in launcher and benchmark entry points; warm cache seeds are copied only after it passes | 15 PowerShell cases pass, including attempts to lower the floor, use the removed bypass, and move cache cloning ahead of the gate; no gameplay evidence |
| Model review | Configured remote coding endpoint and one minimal completion verified | Model output is untrusted review input |

## Work queue

| ID | Work item | State | Completion gate |
|---|---|---|---|
| O1 | Provider-neutral model-review wrapper | Complete | Parser and dry run pass; a live bounded review is saved outside Git; secret scan still runs before every commit |
| O2 | Vice-Tay donor audit | PR #27/#37/#85/#114 paths reviewed; #85 selectively ported; combined PR #116 is not ported wholesale | Placed-view, per-heap bake-coverage, and first-piece shadow fixes ported; lock scope, upload queue, texture store, shader translation, descriptor, and streaming changes assessed separately |
| O3 | Placed-view lifetime and leak review | Unit-tested | Canonicalizers ported; two focused tests and all ten descriptor tests pass; gameplay memory and rendering pending |
| O4 | Shadow/resource lock contention review | Lock-scope change deferred; independent shadow boundary bug fixed under O13 | Two bounded reviews and local ownership audit complete; measure local call volume and mutex contention before changing the cache lock |
| O5 | NVIDIA shader correctness review | Complete; visual check pending runtime | Wave32/Wave64 and NaN/BVH paths audited; 281 shader tests pass and a synthetic intersection test ran on the hardware adapter and WARP; no global NaN scrub or ray-disable switch exists |
| O6 | 8 GB residency and texture pressure review | Static audit complete; runtime validation pending | DXGI budget, texture admission, staging/pool lifetime, host-RAM and commit-pressure paths traced; no source patch justified without runtime pressure evidence |
| O7 | Incremental source groups | Per-heap bake-coverage patch and serial tests complete; clean pinned build pending | Run clean pinned Release/diagnostic build and both `--help` checks for the new source commit; runtime A/B remains queued for O8/O10 |
| O8 | Runtime readiness | Install path unresolved; latest commit sample is below the hard floor | Resolve authorized external game directory, refresh hardware, pass adapter/feature/commit preflight, keep data and caches outside Git |
| O9 | Shader and pipeline prewarm | Waiting for O8 | Separate first-run compilation settings from gameplay settings and fingerprint the generated cache |
| O10 | Gameplay baseline | Waiting for O8/O9 | Repeatable anonymous indoor/outdoor/high-density routes; cold and warm cohorts; visual inspection and real application-frame classification |
| O11 | Profile tuning | Waiting for O10 | Compare Stability, Balanced, Performance, and Quality with matched runs; retain only measured improvements without visual or stability regression |
| O12 | Release candidate | Waiting for O11 | Release and diagnostic artifacts, hashes, sanitized comparative report, changelog, rollback procedure, and public documentation agree |
| O13 | First partial-piece shadow comparison correctness | Complete at `abcb275` | The new 48 MiB regression failed before the fix with debug overflow; debug and optimized Release plus the full GPU library suite pass; clean Release/diagnostic artifacts and hashes are recorded |
| O14 | Decoration-bake coverage isolation and complete snapshots | Source patch complete; clean build pending | Per-heap revisions, overlapping-pass rejection, and due/lookahead snapshot completeness are covered by focused tests and serial GPU-library suites; compile clean Release/diagnostic artifacts, then observe in gameplay before any performance claim |

## Donor integration order

1. Treat Vice-Tay as a measured NVIDIA reference, not as a wholesale merge target. Its
   audited snapshot was `123c4b7`, after combined merge `0ef44bc`; the focused PR #85
   bake-coverage fix merged on 2026-11-27 and was adapted locally.
2. Compare its current commit with AstraForge's selected base by subsystem and exact
   symbol. Start with placed-view lifetime and lock contention because the donor reports
   concrete CPU and memory pressure in those paths.
3. Ask the configured coding model for a read-only second opinion using only selected
   public source files or a bounded public diff.
4. Independently trace every finding in local source. Reject findings that lack a real
   call path, ownership model, or failure mode.
5. Port the smallest complete change, preserve upstream authorship and GPL notices, add
   tests, and update provenance and rollback notes.
6. Run focused tests after each patch and the pinned Release/diagnostic build after each
   accepted Rust/D3D12 group.
7. Defer performance labels until matched gameplay captures exist on the target PC.

## Runtime experiment order

When the authorized installation is ready and the preflight has at least 12 GiB of
available commit:

1. Capture the unchanged Balanced baseline with ray tracing disabled.
2. Complete one diagnostic cold run for shader/pipeline discovery, then use a separate
   gameplay configuration for warm runs.
3. Record real FPS, average/median FPS, 1% and 0.1% lows, mean/p95/p99 frametime, GPU
   utilization/clocks/power, dedicated/shared VRAM, per-thread CPU, RAM/commit, missing
   pipelines, streaming events, device loss, TDR, loading time, and visual defects.
4. Compare Series S first. Test Series X at reduced load only as a separate cohort.
5. Change one subsystem or one coherent patch group per comparison. Roll back a change
   that worsens correctness, stability, or matched frametime distributions.

## Non-negotiable gates

- Do not merge forks wholesale or invent runtime variables.
- Do not remove required draws, barriers, synchronization, or shader work to inflate FPS.
- Do not bypass the adapter, feature, commit-headroom, or privacy preflights.
- Do not call a model finding a bug until the source path confirms it.
- Do not call compilation, WARP, menus, cinematics, duplicated frames, or generated
  frames a gameplay benchmark.
- Keep credentials, model responses, raw hardware data, game files, caches, saves,
  captures, and binaries outside Git.

## Resume checklist

1. Read `AGENTS.md`, this file, and the latest sections of `progress-journal.md` and `LUNA_MAX_HANDOFF.md`.
2. Run `git status --short --branch`; preserve any existing work.
3. Recheck the completed O1/O2 audit only if new donor evidence appears; otherwise continue from O8 and the latest source/build state.
4. Refresh hardware/commit telemetry before any runtime launch.
5. Update this plan and the progress journal before committing a completed work group.
