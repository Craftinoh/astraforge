# Claude Code continuation handoff

Updated 2026-11-27. Read this after `AGENTS.md`, `README.md`,
`docs/OPERATIONAL_PLAN.md`, and the latest `docs/progress-journal.md` entry. Then read
`docs/fork-comparison.md`, `docs/source-credits.md`, and
`third_party/nvidia-3070-VI/LOCAL-CHANGES.md` before touching source.

## Mission

Continue AstraForge in small, testable steps for the RTX 3070. The current blocker is a
fully black captured render area. Diagnose the local pipeline/shader path, keep the
installed files read-only, and do not claim gameplay FPS or a visual fix until the user
can see a rendered scene and a real-frame capture verifies it.

## Preserve the current worktree

At handoff, `main` is one commit ahead of `origin/main` and has uncommitted changes in
launcher scripts, documentation, and these renderer/shader files:

- `crates/victory-gpu/src/host.rs`
- `crates/victory-gpu/src/pipeline/host.rs`
- `crates/victory-gpu/src/pipeline/library.rs`
- `crates/victory-shader/src/emit/lower.rs`
- `crates/victory-shader/src/emit/wave.rs`
- `crates/victory-shader/src/resource.rs`

There is also a new pre-run window module at `tools/AstraForge-PreRunWindow.psm1`.
Start by running `git status --short --branch` and reviewing the full diff. Do not reset,
clean, checkout over, amend, or overwrite this work.

## Observed runtime evidence

- A pre-run dialog passed its checks and launched the diagnostic build. The render area
  in the captured application window is entirely black. The user reports occasional
  startup-logo flashes after manual controller input; automation did not send input.
- Runtime logs repeatedly report D3D12 pipeline-creation refusal at slots `0x1c8` and
  `0x218`. A separate counter reports zero draws discarded for missing host pipelines;
  trace the warning path instead of interpreting that counter as an all-clear.
- The window caption showed about 30 presents/s / 33.3 ms and 35 draws/frame. These are internal runtime counters, not validated application FPS.
- The interval did not show device removal, TDR, or explicit VRAM exhaustion. Across 50 samples, process-private memory peaked at 6.85 GiB, working set at 4.03 GiB, free physical memory bottomed at 9.55 GiB, and free commit at 9.89 GiB. Process GPU counters peaked near 1.73 GiB dedicated and 1.02 GiB shared. System-wide `nvidia-smi` reported 1,138–2,960 MiB used and 2–100% utilization; those values may include other processes. No sustained gameplay-memory conclusion is justified.
- The log reports zero depth-twin/depth-plane draws. This does not prove that descriptor
  handling is the black-screen cause.
- Captures and logs remain outside Git. No `presentmon-frames.csv` exists. PresentMon
  stdout/stderr are empty, so this does not show whether the configured hotkey recording
  was started or attachment failed. The installed CLI help lists the configured
  process-ID, output-file, and hotkey options; run a non-game smoke capture before the
  next gameplay attempt. The continuous one-second `nvidia-smi.csv` contains 333 rows;
  its utilization is system-wide and varied from 2% to 100%, so it cannot be attributed
  to this runtime.

## Existing patch and build state

- Local shader changes adapt three translation corrections from Vice-Tay merge
  `708dbfe` / PR #229: Wave32 collision-register lowering, `v_add_f16` inline half
  constants, and root-constant table offsets. Their focused tests passed.
- Local D3D12 pipeline changes adapt Vice-Tay commit `fa8fc1d`: NVIDIA pipelines with
  static samplers bypass the persistent host pipeline library unless
  `VICTORY_LIBRARY_STATIC_SAMPLERS=1`. The bypass and host-pipeline tests passed. This
  remains unverified as a black-screen fix.
- Current diagnostic artifact:
  `%LOCALAPPDATA%\AstraForge\builds\artifacts\20261127-142101-Diagnostic-thinlto-native-f14407dc\cargo-target\diag\victory.exe`
  SHA-256 `85F425828C5E34CBDDD1F0AD68FFC7DFCD18EEECCD6CBA30A94322C8F3F48503`.
  Manifest says `SourceDirty=true`; do not call it a release artifact.
- External prewarm data is under `%LOCALAPPDATA%\AstraForge\prewarm`, about 25,765
  files / 971.8 MiB. Keep it and any new build output outside the repo and installation.
- Prior recorded checks: PowerShell preflight 18 cases, benchmark harness 6 cases,
  shader suite 283 passed / 4 ignored, pipeline-library bypass 1 passed, host-pipeline
  tests 6 passed. Whole-workspace rustfmt reports broad existing differences in the
  imported source; do not format those files wholesale.

## Black output fixed (2026-11-27, later)

Root cause: local commit `f8b6af5` lowered the portable-heap shader clamp to slot
737,855 while the dynamic descriptors stayed above it, so every per-draw table read null.
The working tree reverts that commit. The diagnosis used frame captures
(`VICTORY_CAPTURE`) and builds outside the repo: `a0748dc` renders, `f8b6af5` is black,
and the revert renders. PR #18 builds rendered with the pieces switch on and off, so
its pipelines are not needed for this symptom. Next is O19 (story-load crash), at 720p.
The probe scripts used live in the session scratchpad and are not part of the repo.

## O16 result (2026-11-27, Claude Code; superseded by the section above)

Steps 1–4 below were evaluated. PR #18 was **not** ported. The slot refusals are a startup
burst: at least 16,384 calls to `0x1c8` and 2,048 to `0x218`, all within about 1.5 s,
then none. Every reference fork refuses the same slots. PR #18 measured its
open-world baseline with them refused and attributes its black/grey world to pieces
pipelines that were handed out but never drew. All ten local run logs stay at 4–39
draws/frame with about 0 ms GPU time, both before and after the current shader/PSO
patches. Full reasoning: `docs/fork-comparison.md` § "O16 trace result". The steps
below are kept as history; the new first task is the early-state diagnosis in
`docs/OPERATIONAL_PLAN.md` next action 3, then PresentMon (step 6).

## First task (superseded by the O16 result above): trace the black screen

1. The correlation is specific: trustno PR #18 says its methods `0x1c8` and `0x218`
   create pipelines from loose pieces; refusing those calls drops draws, including a
   scene-composite path associated with a black/grey world. The local run logs refusals
   at both exact slots. Treat this as the leading hypothesis, not a confirmed fix.
2. Inspect the PR's pipeline-pieces commits only: `cb33680`, `8823e15`, `0fae809`,
   `9449ec9`, `89bfaf0`, `c6a4b60`, and `c12a77f`. The PR head is
   `e0703c136d472a67c5f00a1a9296d2e6790fcea6` (58 commits; GitHub lists 64 files; a
   later-main three-dot diff lists 77 paths). Exclude its unrelated ray tracing,
   display, Reflex, memory, streaming, and parallel-submit work.
3. Compare the parsing/assembly path with local `victory-gpu/src/device.rs`,
   `victory-gpu/src/pipeline.rs`, and the shader translator. The local opt-in
   `VICTORY_RAW_COMPUTE` handles only method `0x218` and is not equivalent to the PR's
   piece assembler. The donor reports that some compute-piece layouts remain wrong;
   evaluate graphics-only handling first.
4. Check whether the current local shader and static-sampler changes affect these exact
   warnings. Add the smallest complete regression test for a reproduced path. Update
   source credits and subtree `LOCAL-CHANGES.md` for every imported source change.
5. Run the focused test, pinned diagnostic build, PowerShell parser, preflight tests,
   benchmark harness, and `git diff --check` that apply to the patch. Do not relaunch an
   unchanged build into the same black result.
6. Repair and smoke-test PresentMon capture outside the game. Verify the CSV contains
   per-frame records before scheduling a scene capture.
7. When a source-traced fix is ready, refresh the adapter and 12 GiB commit preflight,
   show the pre-run dialog, launch once, and let the user advance the controller to a
   scene. Capture a screenshot and logs outside Git.

## Model routes requested by the user

- **OpenCode + DeepSeek Free Flash:** optional bounded coding/review delegate. The
  `opencode` command was not found on PATH in this checkpoint, and the route has not
  been tested end-to-end. Verify the client/model before assigning work. Keep its
  changes on a focused branch and review the diff locally.
- **INGENIUM / Qwen coding model:** optional long-context coding assistant through the
  OpenAI-compatible endpoint described in `docs/MODEL_ORCHESTRATION.md`. The user says
  calls are free and unlimited; this was not verified against current account limits.
  Check the live model alias and quota before relying on that. Keep the API key only in
  `INGENIUM_API_KEY`; the review wrapper needs
  `-ApiKeyEnvironmentVariable INGENIUM_API_KEY`. Never write or print the key.
- Send only explicit, bounded public-source excerpts. Responses are hypotheses to check,
  not proof. Keep private runtime logs, screenshots, installed-file paths, credentials,
  and raw hardware reports local.

## Upstream reference inventory

Seven shallow comparison clones plus the requested COOL_FOX mirror are outside this
repo; see `docs/REFERENCE-REPOSITORIES.md` for exact snapshot commits. Vice-Tay and
Kelvaroq audit snapshots are also recorded there. Use isolated reference diffs, not
whole-repository imports. Relevant current diagnostic proposals are Vice-Tay #452/#453;
the local black-screen lead is trustno #18, whose refused pipeline method slots match
the runtime warnings. Broader lineage acknowledgements are in `docs/source-credits.md`;
that list does not mean all listed code was imported into AstraForge.

## Reporting and publication rules

Update `docs/progress-journal.md`, `docs/OPERATIONAL_PLAN.md`, this handoff, and the
source-credit ledgers after each evidence-bearing step. Public reports use anonymous
scene labels. Do not name the private application, publisher, executable, or paths.
Do not stage private files, caches, captures, binaries, model keys, or raw logs. Create
focused commits only after review; push or publish only when the user requests it.
