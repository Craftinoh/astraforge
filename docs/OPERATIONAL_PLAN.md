# RTX 3070 operational plan

This is the durable execution plan for the NVIDIA-first AstraForge work. Read it with
`AGENTS.md`, `README.md`, and `docs/progress-journal.md` when resuming.

## Objective and acceptance target

Deliver the most stable and efficient build supported by the available source for a
desktop RTX 3070 8 GB and Ryzen 7 7700X. The target is at least 30 real application FPS
with a 1% low of at least 30 across repeated, matched gameplay captures. This is an
acceptance target, not a promised result. Visual correctness, device stability,
frametime consistency, and memory safety are also required.

Public files and benchmark reports use anonymous scene names and must not identify the
private application, publisher, executable, save data, or personal paths. Installed
files are read-only. Keep caches, captures, runtime data, and raw hardware reports
outside the repository and installation.

## Current checkpoint — 2026-11-27

- **Source base:** COOL_FOX Pareto-residency descendant through the NVIDIA 8 GB source
  subtree, plus focused, credited changes. Current Vice-Tay shader and NVIDIA pipeline
  changes are still uncommitted. Preserve the complete worktree.
- **Git state:** `main` is ahead of `origin/main` by one commit and has local Rust,
  launcher, and documentation edits. Do not reset or overwrite them. No commit or push
  has been made for this dirty change group.
- **Hardware:** RTX 3070 is the first DXGI adapter; driver 610.88, Shader Model 6.8,
  WaveOps 32, PCIe Gen4 x16; Ryzen 7 7700X, 8 physical / 16 logical cores; 32 GiB RAM;
  Windows 11 Pro 26H2. Hardware reports stay outside Git. ReBAR is inferred from the
  BAR aperture and is not directly verified.
- **Build:** diagnostic artifact
  `20261127-142101-Diagnostic-thinlto-native-f14407dc`, SHA-256
  `85F425828C5E34CBDDD1F0AD68FFC7DFCD18EEECCD6CBA30A94322C8F3F48503`. It records
  `SourceDirty=true`; it is not a clean Release build or release candidate.
- **Source checks:** latest recorded shader suite: 283 passed / 4 ignored. Focused
  pipeline-library bypass test: 1 passed. Host pipeline tests: 6 passed. These are
  correctness/build checks, not gameplay evidence.
- **Prewarm:** external shader/cache data already exists under
  `%LOCALAPPDATA%\AstraForge\prewarm` (about 25,765 files / 971.8 MiB). Preserve it;
  do not include it in Git.
- **Latest run:** the pre-run dialog passed checks and launched the diagnostic runtime.
  A captured image shows an entirely black render area. The user observed occasional
  startup-logo flashes after manual controller input. Automation did not inject input.
- **Black output fixed (O16):** the cause was local commit `f8b6af5`. Its shader view
  clamp (slot 737,855) sat below the 2^18 dynamic descriptors, so every per-draw table
  read null. The working tree reverts it. Frame captures show the account screen,
  loading art, and first-boot menus on the AstraForge build. Bisection: `a0748dc`
  renders, `f8b6af5` is black, and the revert renders. A reference build later crashed
  with an access violation in title code while loading the story; that is the next
  stability item, and it has not yet been reproduced on the AstraForge build.
- **Earlier slot analysis (superseded, kept for history):** the `0x1c8`/`0x218` refusals are a
  startup burst. In the latest run there were at least 16,384 and 2,048 calls, all
  within the first ~1.5 s, and none in the remaining ~5.5 min. Every reference fork has
  the same refusal stub, and trustno PR #18 measured its open-world baseline with both
  slots refused. PR #18 links its black/grey world to pieces pipelines that were handed
  out and never drew, not to refusal. No port was made. Across all ten logged local runs,
  before and after the current shader/PSO patches, the title stays at 4–39 draws/frame
  with about 0 ms GPU time, 0 drops for missing pipelines, and storage-layer world-data
  reads. The next lead is why the title never leaves this front-end and loading state
  and why its few draws present black. See `docs/fork-comparison.md`.
- **Memory/device evidence:** across 50 samples, process-private memory peaked at 6.85
  GiB and working set at 4.03 GiB; available physical memory bottomed at 9.55 GiB and
  available commit at 9.89 GiB. Process GPU counters peaked near 1.73 GiB dedicated and
  1.02 GiB shared. System-wide `nvidia-smi` reported 1,138–2,960 MiB used and 2–100%
  GPU utilization; activity cannot be attributed to the runtime. No DXGI device removal
  or explicit VRAM exhaustion appeared during this interval. This is startup/black-output
  behavior, not sustained gameplay memory evidence.
- **Frame telemetry:** no `presentmon-frames.csv` was produced. PresentMon stdout/stderr
  are empty, so the available evidence cannot distinguish an unstarted hotkey recording
  from an attach failure. The installed CLI help lists the configured `--process_id`,
  `--output_file`, and hotkey options; verify capture with a non-game smoke test before
  the next scene. The continuous 1-second `nvidia-smi.csv` contains 333 rows. System-wide
  GPU utilization varied from 2% to 100% system-wide and cannot be attributed to the
  runtime. The engine's repeated 30 Hz / 33.3 ms and 35 draws/frame counters are not FPS
  evidence.
- **External sources:** shallow, blob-filtered comparison clones are under
  `%LOCALAPPDATA%\AstraForge\references\upstreams`; they are local references, not
  public GitHub forks or instructions to merge entire branches. See
  `docs/REFERENCE-REPOSITORIES.md` and `docs/fork-comparison.md`.
- **Model routes:** user requests OpenCode + DeepSeek Free Flash and a local Qwen coding
  model as optional, separate assistants. The `opencode` command was not on PATH and
  neither route was verified end-to-end in this checkpoint. See
  `docs/MODEL_ORCHESTRATION.md`; never store keys or private runtime data.

## Work queue

| ID | Work item | State | Completion gate |
|---|---|---|---|
| O1 | Provider-neutral model-review wrapper | Complete | Keep bounded inputs, credentials outside Git, and independently verify every model claim |
| O2 | Upstream comparisons | Audited selectively; no whole-fork merge | Refresh only relevant PRs and record their exact source and evidence |
| O3 | Placed-view canonicalization and descriptor lifetime | Source/tests complete | Gameplay memory, visual correctness, and long-run stability remain open |
| O4 | Shadow/resource lock contention | Diagnostic-only wait telemetry exists | Measure real gameplay contention before changing lock scope |
| O5 | NVIDIA shader translation | Audited; several focused donor corrections are locally applied | Validate affected shaders and rendered output; do not infer black-screen resolution from unit tests |
| O6 | 8 GB residency/texture pressure | Static audit complete; one runtime interval logged | Validate long gameplay under dynamic DXGI, shared-memory, RAM, and commit pressure |
| O7 | Earlier incremental source groups | Complete at published commits | Keep prior evidence and rollback history intact |
| O8 | Pre-run and diagnostic runtime | Pre-run passed; output black | Fix a source-traced pipeline/translation issue, then confirm visible output before benchmark work |
| O9 | Shader/pipeline preparation | External prewarm complete | Confirm cache fingerprint and cold/warm behavior after a visible runtime is established |
| O10 | Gameplay baseline | Blocked by black output and missing PresentMon capture | Capture repeated anonymous scenes with valid real-frame classification and visual review |
| O11 | Profile tuning | Waiting for O10 | Compare Stability, Balanced, Performance, and Quality with matched runs |
| O12 | Release candidate | Not ready | Require clean Release/diagnostic builds, visual validation, real gameplay benchmarks, hashes, credits, report, and rollback instructions |
| O13 | Partial-piece shadow comparison correctness | Complete at `abcb275` | 48 MiB regression reproduced old overflow and passed debug/Release; full library suite passed |
| O14 | Per-heap decoration-bake coverage | Source/tests/build complete | Gameplay visual validation remains pending |
| O15 | Pre-run/telemetry harness | Dialog and 5-second / 1-second telemetry exercised; preflight and benchmark harness pass | Determine why the PresentMon file is absent; test hotkey start/stop and non-game capture without altering runtime code blindly |
| O16 | Black-screen diagnosis | Fixed in the working tree (revert `f8b6af5`); start-up screens render in captures | Commit the revert; confirm on a user-driven run; PR #18 pieces stay a later performance candidate |
| O19 | Stability at story load | New; a reference build crashed with an access violation (null write) in title code at world entry | Reproduce on the AstraForge build at 720p, collect the crash report, and trace the faulting call before any tuning |
| O17 | Comparison repository inventory | Seven shallow clones present | Record snapshot hashes; obtain the requested COOL_FOX mirror snapshot if reachable |
| O18 | Current Vice-Tay shader/PSO changes | Focused tests and dirty diagnostic build recorded | Independently confirm each patch against the black output before calling it a fix |

## Next actions

1. Read `AGENTS.md`, `README.md`, this plan, the latest `docs/progress-journal.md`
   entry, `docs/CLAUDE_CODE_HANDOFF.md`, `docs/fork-comparison.md`,
   `docs/source-credits.md`, and subtree `LOCAL-CHANGES.md`.
2. Run `git status --short --branch` and inspect the complete diff. Preserve the current
   uncommitted Rust and launcher work.
3. O16 is fixed (revert `f8b6af5`). Next is O19: reproduce and trace the story-load crash
   at 720p (user preference: stability first, no HD/4K targets yet). Superseded text:
   diagnose the early state
   without relaunching an unchanged build. From existing logs and source, determine what
   the 4–39 draws/frame target and present, whether the compose/present path writes the
   swap chain, and what the title waits on after its world-data reads. A diagnostic-only
   log addition is acceptable if it is justified by that trace.
4. Parse the edited PowerShell files and run the focused preflight and benchmark-harness
   tests. Correct any telemetry-script defect before another runtime attempt.
5. Fix and smoke-test PresentMon CLI capture without injecting controller input. The
   user advances to any gameplay scene and reviews the resulting window.
6. Before any new launch, refresh the RTX 3070 adapter and the 12 GiB available-commit
   gate. Keep the installed files unchanged.
7. Update this plan and the journal with exact commands/results after each evidence step.
   Do not commit or push unless the user requests the reviewed change group.

## Runtime experiment order after visible output is restored

1. Capture a diagnostic startup and shader/pipeline cold-cache run.
2. Use the user to advance to repeatable scenes; test indoor, outdoor/vegetation, water,
   and high-density routes when accessible.
3. Capture cold and warm cohorts with PresentMon application-frame classification.
   Record median/mean FPS, 1%/0.1% lows, mean/p95/p99 frametime, GPU/CPU/RAM/commit,
   dedicated/shared VRAM, pipeline misses, texture streaming, loading, device loss, TDR,
   and visual defects.
4. Compare Series S first. Test Series X separately and only if it renders correctly.
5. Change one subsystem or one coherent patch group per matched comparison. Roll back
   changes that regress correctness, stability, or frametime.

## Non-negotiable gates

- Do not merge forks wholesale or invent runtime settings.
- Do not remove required draws, shaders, barriers, synchronization, or lifetime handling.
- Do not bypass adapter, feature, commit-headroom, or privacy preflights.
- Do not change installed files. Keep caches, captures, logs, and runtime data outside
  both the installation and the repository.
- A model response is a hypothesis, never a bug report or performance result by itself.
- Menus, startup logos, synthetic tests, duplicate/generated frames, and the internal
  caption are not gameplay FPS evidence.
- Keep credentials, responses, raw hardware data, installed files, caches, saves,
  captures, and binaries outside Git.
