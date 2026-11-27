# Upstream fork comparison for RTX 3070 Ampere

Reviewed public repositories and their default-branch heads on 2026-11-26 and refreshed the NVIDIA donor on 2026-11-27. These are maintainers' measurements on different builds and scenes; they are evidence for candidate changes, not a common benchmark set.

## Selected base: COOL_FOX Pareto-residency descendant

The requested Pareto commit is [`neevets/cool_fox@f4b48ad766`](https://github.com/neevets/cool_fox/commit/f4b48ad766ddbec1a1867022cd42f7645b0dd55e). The accessible NVIDIA 8 GB descendant is [`grimygunnz/nvidia-3070-VI`](https://github.com/grimygunnz/nvidia-3070-VI), imported at `6e9c1dd` and synced through the docs-only upstream commit `25ff216`. Its Series S report measures about 16.3–17 FPS on an RTX 3070 Ti with 64 GB RAM, 7.0 GB peak VRAM, and about 55.9 ms of submission-thread work per frame. It is the closest available 8 GB NVIDIA / Series S baseline, but still below 30 FPS and materially different from this RTX 3070 / 32 GB host. The latest report explicitly rejects another refresh-ahead experiment after cutscene-start null writes/crashes.

The imported source already has dynamic local DXGI budget accounting, low-budget texture-copy limits, a fast unmapped-range path in `texture::mapped_bytes`, resident-range texture handling, commit-pressure admission, and Series S defaults. The dynamic-heap identity guard merged as [`fxceless#1324`](https://github.com/fxceless/victory-fork/pull/1324) is ported with its wrong-identity regression test. The in-flight descriptor deferral from [`victory-unified@768735a`](https://github.com/Itsbatt/victory-unified/commit/768735ad589eb9951a5c8812c4675bbf3b9ed765) is also ported: it preserves a descriptor and its referenced resource until submissions are idle, then skips slots remade in the meantime. Its RTX 3070 report links this fix to MMU-fault stability, but it is not an FPS result. The pinned Windows build now compiles these ports; the complete `victory-gpu` library test run passes, including host-device and WARP cases. That validates unit-level behavior, not gameplay performance or long-run game stability. The RTX 3070 profiles retain the selected base and do not add a second VRAM controller.

## Recent NVIDIA reference: `TaynanGT/Vice-Tay`

The 2026-11-27 GitHub API snapshot is [`123c4b7`](https://github.com/TaynanGT/Vice-Tay/commit/123c4b7fceac985eee2876f8774785a451092aec), following combined validation merge [`0ef44bc`](https://github.com/TaynanGT/Vice-Tay/commit/0ef44bc36e354ad18810fb5e25cad47f832266a8). Its maintainer reports one 30-minute RTX 4090 / Series S session at 21.1 FPS median, 17 FPS 1% low, and about 23.5 GiB median process memory. It also reports visible color, glow, face, cloud, reflection, and black-area defects. This is useful donor evidence, not an RTX 3070 forecast and not independent validation.

The merged [`#116`](https://github.com/TaynanGT/Vice-Tay/pull/116) combines twelve changes, including #114, and reports passing combined CI plus focused GPU, memory, and shader checks. Its paired opening-scene comparison had eight qualifying samples per run at 83.0 ms and 50.7 ms median frame time, but draw counts and pipeline queue depth differed. Treat this as a combined-run observation, not an isolated patch gain or an RTX 3070 estimate.

Its [`#27`](https://github.com/TaynanGT/Vice-Tay/pull/27) documents a concrete placed-view leak: padding and unused descriptor words created millions of false shapes, after which each later placed view became a permanent table entry. AstraForge independently confirmed that its selected base copied those words into `Shape`. The focused resource/view canonicalizers from commits `f07e54a2` and `ce914907` are now ported with two regression tests; all ten local descriptor tests pass. The PR's separate ownerless-entry cap, shader, ambient, sampler, and list changes are not included in this patch.

Its [`#37`](https://github.com/TaynanGT/Vice-Tay/pull/37) is a very broad multi-fork merge. A later donor finding links a six-FPS regression to structured views calling `shadow::exact` under a global lock and gates that path behind `VICTORY_STRUCTURED_RAW`. AstraForge has not accepted that change: the local caller and lock scope still require separate source review, correctness analysis, and tests.

Its [`#114`](https://github.com/TaynanGT/Vice-Tay/pull/114) ports the first-partial-piece alignment fix adapted from [`fxceless/victory-fork#1407`](https://github.com/fxceless/victory-fork/pull/1407), whose description credits the original finding to Kelvaroq's `stellarr-studio/kelvaroq` patch 0009. The selected local source had the same unsigned subtraction in `Shadow::differing`: with a title range starting partway through a 64 KiB piece, the first parallel cut could wrap, skipping the first comparison slice in optimized builds or panicking with overflow checks. The new synthetic 48 MiB regression reproduced the debug overflow before the fix; after the focused saturating-subtraction port it passes in debug and Release. This establishes the specific partitioning behavior only; it does not claim a gameplay-performance or visual change.

Its [`#85`](https://github.com/TaynanGT/Vice-Tay/pull/85), merged on 2026-11-27, fixes decoration-bake completion tracking. The local code used a process-global completion counter even though each `HostHeap` owns an independent texture queue; a completed scan could therefore collide with another heap's equal write count. The accepted local adaptation uses per-queue revisions, refuses certification for overlapping passes, requires the capped current/lookahead snapshots to cover every due slot, and confirms synchronous coverage only after GPU execution and descriptor publication. Regression tests cover cross-heap isolation, stale revisions, overlap, and truncation. This is a correctness/stale-texture fix; no RTX 3070 gameplay or performance result is measured. The donor's own CI and comparison remain distinct from local validation.

### PR #37 selective follow-up: waits, upload queue, texture store, and Wave32

- `VICTORY_FILL_TITLE` already exists locally as mode `1`: for fills/copies up to 64 KiB, it bypasses a flight wait if the title wrote that range since it was taken **or** no shader write landed there in the last 600 frames. Donor commit [`b6be7e3`](https://github.com/TaynanGT/Vice-Tay/commit/b6be7e3b0b2f7ead75ff999ae53e3021da17c7cb) adds mode `2`, which bypasses only on the second condition. AstraForge now exposes that narrower mode, leaves the unset default unchanged, and does not enable it in any preset. Its donor's 10-second A/B report measured 88.8 ms mean / 83.4 ms median / 104 ms p90 versus 100.5 / 88.1 / 154 ms for the tested standing scene; the maintainer said the picture held in walking checks. These figures are one donor's runs, not RTX 3070 evidence. Local unit tests cover the predicate and its 64 KiB boundary, not runtime resource freshness.
- The donor's `VICTORY_UP_QUEUE` is off by default and concerns CPU-written shadow/card buffers, not the local texture upload queue or `VICTORY_RELAY_COPY` readback queue. Its implementation batches up to 512 MiB per plan into a default-heap bounce buffer, submits a copy-queue fence, then copies bounce ranges on the drawing queue in original order. `CardPlan` retains each slot until completion, which protects normal in-flight use. The free-slot vector has no idle trim, so every peak slot can retain up to a 512 MiB bounce allocation. The error path also deserves work before any port: after `ExecuteCommandLists`, a failed `Signal` returns the slot to the free list without a completed-fence proof; if that failure can occur while the device remains usable, allocator reuse could race the copy. The fallback CPU wait after a failed queue `Wait` ignores the HRESULT from `SetEventOnCompletion`. These are unvalidated failure paths, not a reproduced defect.
- The merge report cites 269 ranges / 76.6 MB taking about 5 ms while the drawing queue was idle, versus about 0.2 ms for the later on-card copy when staged through the second queue. The broad branch comparison moved from 21.6 to 22.7 median FPS, but private memory rose from 25.0 to 32.3 GB and peak card memory from 10.1 to 16.7 GB; 64 KiB texture-pool placement accounts for part of the increase. The report does not isolate the queue's contribution, and its memory profile is a poor fit for an 8 GB card without new bounded slot accounting and target traces. No copy-queue port is selected.
- `VICTORY_TEXTURE_STORE` is opt-in and reconstructs larger texture mip levels from a disk cache keyed by shape and a digest of the resident smaller prefix. It does not reduce VRAM residency. The file cache is never trimmed; the in-memory cache has a 4 GiB target, while pending jobs use an unbounded channel and each job clones the full tiled texture. Its current load-then-increment accounting can also overshoot the nominal RAM target under concurrent cache fills. This adds commit, disk, and correctness-validation costs to an 8 GB streaming problem, so it is not ported.
- The merge's Wave32 `lane_uniform` proof is absent from the selected shader source. It proves selected wave-uniform values across whole-wave branches, ordered LDS reads, and eligible `id >> 6` expressions, then uses the proof for first-lane lowering. The donor reports three more structure-builder shaders translated (2,718 to 2,721 of 2,734) and a passing synthetic GPU fixture on an RTX 5070 Ti; it also reports the opt-in structure builder still crashing within seconds in a world run. This may improve builder coverage, but it is not a demonstrated gameplay optimization and needs a separately reviewed shader-analysis patch before any port.
- A bounded model review of `upq.rs` (`chatcmpl-af131c61fafec10b`) claimed a missing shader-resource transition and a nested mutex acquisition. Manual tracing rejected both: the bounce resource is consumed by buffer-copy commands, not bound through a shader descriptor; `make_queue` does not reacquire `QUEUE`. D3D12's queue/fence and COMMON copy-resource behavior must still be exercised locally before transplanting the queue. No model finding is accepted without source confirmation.

## RTX-specific alternative: `Itsbatt/victory-unified`

Current main at review was [`d5b5fca`](https://github.com/Itsbatt/victory-unified/commit/d5b5fca6cf3c325634f90eb897aa43d0eb665847). Its author reports an RTX 3070 8 GB / Ryzen 5 5600XT / 32 GB machine and a roughly 58-minute stable run, but the outdoor camp scene was about 3 FPS (344 ms/frame, 8,011 draws). Its Series S path had an `FFX_FSR4` failure, so that report used Series X. This is a useful stability and fault report, not a direct Series S performance comparison.

The current launcher keeps async submission and a second copy queue, but turns off on-demand levels, no-wait texture refresh, hoisted clamps, and in-place writes for its 8 GB configuration. It also uses a 100 ms pipeline wait, 2,560 MiB texture budget, 64 MiB staging buffer, and 40 ms staging interval. Those settings belong to a different engine base and Series X path; they are not silently transplanted. Its recent `mapped_bytes` fast rejection is already present in this source, alongside a mapped-view accounting path.

## Other NVIDIA 8 GB branch: `soldsawn/victory-nvidia-8gb`

Its [`README`](https://github.com/soldsawn/victory-nvidia-8gb) reports 8–10 FPS on an RTX 4060 Laptop 8 GB with Series X, `VICTORY_TEXTURE_DROP_MIPS=2`, 1080p output, and Thin LTO, at 6.6/7.0 GB VRAM. This supports mip reduction as a 8 GB experiment in that fork, but `VICTORY_TEXTURE_DROP_MIPS` is absent from the selected source and cannot be set here. The measurement is far short of 30 FPS.

## `fxceless/victory-fork` and the 4080 recipe

The [`#1268` report](https://github.com/fxceless/victory-fork/issues/1268) reports a 27.2 FPS median on RTX 4080 / i5-13600K with a 720p internal scale and a large stack of shader, command, memory, and texture changes. It also reports a 255.7 ms world-entry hitch; the result is not a 3070 estimate. The listed `#868`, `#907`, `#1044`, `#1146`, `#1210`, `#1248`, and `#1264` pull requests were open when inspected on 2026-11-26, so they are not a single reviewed, merged release stack.

- [`#868`](https://github.com/fxceless/victory-fork/pull/868): skipping write-combined readback has opt-in evidence; skipping its comparison is explicitly marked unsafe and has a device-removal report. Neither switch exists in the selected source. Do not set them or port them without source-specific correctness and visual checks.
- [`#907`](https://github.com/fxceless/victory-fork/pull/907): declares `ForceEarlyDepthStencil` from the console shader's `DB_SHADER_CONTROL`, fixing a described glass/depth corruption. It is a strong correctness candidate, but remains an uncompiled port candidate here.
- [`#1044`](https://github.com/fxceless/victory-fork/pull/1044): physical-core DirectStorage workers; measured copy-back cost fell from 5.7 to 2.4–3.5 ms/MB on an 8c/16t Ryzen 7 8845H / RTX 4060 Laptop. A small reversible port is committed locally; its local build and measurement are pending.
- [`#1146`](https://github.com/fxceless/victory-fork/pull/1146): resets landed-flight lists on a helper thread. Reported 3070 results combine this with descriptor-lock changes, so the isolated gain is unknown; the change remains opt-in upstream.
- [`#1210`](https://github.com/fxceless/victory-fork/pull/1210): the selected source already has the same `ResourceMinLODClamp` adjustment in `tiles::show_from`, with 2D and array arithmetic tests, so this code change was not duplicated. The PR adds a stronger reserved-texture GPU fixture for the nonzero minimum-LOD case; it passed on RTX 4080 and WARP, with in-game impact unmeasured. That fixture has not run locally.
- [`#1248`](https://github.com/fxceless/victory-fork/pull/1248): bundles Wave32 translation fixes, dynamic descriptor settlement, later texture rechecks, and timing/debug switches. Its report explicitly leaves several shaders out because they caused black water patches or stopped the card. It is too broad to transplant as one change.
- [`#1264`](https://github.com/fxceless/victory-fork/pull/1264): prioritizes textures named by a character-decoration bake. It reports corrected bake sources on RX 7900 XT, but the change is open and unrelated missing indexed textures remain.

The [`#868` recipe issue](https://github.com/fxceless/victory-fork/issues/1268) also reports black shards with `VICTORY_CARD_BUFFERS_MIN_KB=64` in its own stack, while the selected COOL_FOX run relies on 64 KiB padding to avoid MMU device losses. This is a real cross-branch conflict, so the local profile keeps the selected source's default and its own measured combination.

## Shader optimization and AMD-derived forks

[`PastiiJay/klbf-lab#41`](https://github.com/PastiiJay/klbf-lab/pull/41) and [`#50`](https://github.com/PastiiJay/klbf-lab/pull/50) were open handover/optimization PRs at review time. They change DXIL LICM, alias/hazard reasoning, barrier removal, and Wave32 LDS execution. The 4080 issue reports a warm-cache gain for #41 but also reports #50 rejecting four more NVIDIA compute shaders. These changes require the exact shader tests and NVIDIA validation; no shader compiler or Cargo is available here, so they are not ported.

[`avatarmanz/VIctory-7900XTX`](https://github.com/avatarmanz/VIctory-7900XTX) is actively measuring AMD renderer changes and reports roughly 16–23 FPS across its Series S / 1080p scenes with ray tracing off on RX 7900 XTX. Its own performance patches target AMD and its 32 GB host; importing them into NVIDIA command submission or shader paths without per-patch tests would be unsafe.

[`trustno1-coder/VIctory-NVIDIA`](https://github.com/trustno1-coder/VIctory-NVIDIA) reports a separate RTX 5070 12 GB stack, including a 21.8 FPS run after GPU card-compare changes. The report distinguishes real frames from NVIDIA Smooth Motion-generated frames and describes ray-walk skipping that changes indirect lighting. It is valuable as a source of NVIDIA hypotheses, not as evidence for RTX 3070.

[`Marvisak/VIctory`](https://github.com/Marvisak/VIctory) remains the original base; its current README reports about 1 FPS in its tested RX 6700 XT world scene. [`PastiiJay/klbf-lab`](https://github.com/PastiiJay/klbf-lab) now publishes repeatable real-play measurements on AMD and a newer RTX 4070 sample at 8.3 FPS, which further shows that 30 FPS is not supported by current cross-project results.

## Decision

Keep COOL_FOX Pareto-residency as the source baseline. The narrow DirectStorage worker-count change from #1044 matches this host's 8c/16t CPU and has a measured copy-back benefit on another 8c/16t Windows/NVIDIA machine. The descriptor ports address stale heap releases and in-flight descriptor/resource lifetime. Do not port `SKIP_WC_COMPARE`, broad Wave32 rewrites, renderer-specific AMD patches, or the complete 4080 launcher stack. The 30 FPS target remains unverified and is not supported by the closest published in-world measurements.

## Refresh: black-output runtime and recent NVIDIA pull requests — 2026-11-27

### Trustno NVIDIA branch

The latest audited `VIctory-NVIDIA` main was `d12eb1b23d`. Its README reports a separate
RTX 5070 12 GB / Ryzen 7 9800X3D / 64 GB configuration at 26–30 internal frames in
opening rooms with a Series X / 1440p DLSS Quality setup. That is the maintainer's own
report and is not transferable to the RTX 3070 profile.

- [PR #6](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/6) reports an RTX 3060
  12 GB / i5-12400F / 16 GB Series S run at 540p: 10–12 FPS typical and 8.6–9.2 median
  with a 3 GiB Windows BAR cap. Without the cap, that report says the run paged heavily
  and fell to 1.6–3 FPS or crashed. This supports measuring shared-memory and paging
  pressure; it does not establish the cause of a different machine's result.
- [PR #8](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/8) makes that BAR cap
  opt-in. AstraForge's selected source does not implement
  `VICTORY_WINDOWS_BAR_MB`; do not add an environment variable by copying a donor name.
  A target-specific cap would need a source patch, a clear admission meaning, and matched
  telemetry before use.
- [PR #22](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/22) reports 8.6 to
  9.6 FPS after raising helper priority in a short sample. It is not isolated on the
  current main and the corresponding setting is absent locally.
- [PR #18](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/18) is a broad graphics
  stack with reports of loose-pipeline creation failures associated with method slots
  `0x1c8` and `0x218`. AstraForge's latest runtime log also warns about refused pipeline
  creation at these slots. The O16 trace below downgrades it as a black-screen cause;
  it is a deferred performance and coverage candidate, not a port target.
- [PR #25](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/25) changes texture
  alias lifetime. Its RTX 3070 evidence combines four patches in long runs, so the
  isolated impact remains unknown.
- [PR #30](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/30) proposes a Wave32
  2D-group correction with RTX 5070 Ti correctness tests. It is a shader correctness
  candidate; no local call-path match or target image validation has been established.

#### PR #18: direct match for the observed pipeline refusals

The [PR #18 description](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/18)
explicitly says device methods `0x1c8` and `0x218` carry loose pipeline pieces (code,
metadata, and register packets). Its branch assembles these into a pipeline container
and translates the stages. It reports that refusing these calls omits the resulting
draws, including a scene-composite pipeline associated with a black/grey world and
uncleared interface. AstraForge's current log emits the same two method-slot refusal
warnings, so this is a strong source-matched hypothesis for the black output. It remains
unconfirmed on this source/build until the path is traced and a focused fix renders
correctly.

The PR head at review was `e0703c136d472a67c5f00a1a9296d2e6790fcea6`. GitHub lists 58
commits and 64 files changed. A local three-dot diff against the later audited `main`
snapshot reports 77 paths because the branches have diverged since merge base
`9341f4316f0265786a95a6791a428f14d5695cb1`. Either comparison shows a broad change. It
includes unrelated ray tracing, display, Reflex, memory, streaming, and
parallel-submission work, so do not merge it wholesale.
Its pipeline-pieces series includes `cb33680`, `8823e15`, `0fae809`, `9449ec9`,
`89bfaf0`, `c6a4b60`, and `c12a77f`. The branch provides a graphics-only mode and says
some compute-piece root layouts still translate incorrectly; that supports investigating
the graphics path first, not copying its runtime switch blindly. The local source has a
separate opt-in `VICTORY_RAW_COMPUTE` path for method `0x218`; it is not the donor's
pipeline-piece assembler and is disabled by default.

#### O16 trace result (2026-11-27): hypothesis downgraded, no port

- **Local path.** `victory-gpu/src/device.rs` maps table entries 57 (`0x1c8`) and 67
  (`0x218`) to `unknown_pipeline::<SLOT>`, which nulls `out` and returns `E_NOTIMPL`.
  It logs only calls 1–4 and powers of two, so 29 warnings are milestones, not the call
  count. Neither the local Vice-Tay shader corrections nor the static-sampler bypass
  touch this path.
- **Refusal is the upstream baseline.** COOL_FOX `f4b48ad`, trustno main `d12eb1b`,
  `victory-nvidia-8gb`, `VIctory-7900XTX`, `victory-fork`, `klbf-lab`, and
  `victory-unified` reference snapshots all carry the same refusal stub. The base
  `VIctory` snapshot does not register either slot, so both calls reach its generic
  missing-method handler. PR #18 itself reports an open-world baseline (11.8 fps median,
  RTX 5090) measured *before* its pieces switch, that is, with both slots refused.
- **What PR #18 links to the black/grey world.** Read in full, the PR attributes that
  symptom to an intermediate state of its own feature: a pieces pipeline was handed to
  the title and failed later on a worker, so the title kept a pipeline that could never
  draw. Its fix, `VICTORY_PIPELINE_PIECES_REFUSE_UNTRANSLATED`, refuses at creation so
  "the title falls back to the pipeline it would otherwise make". This is the local
  behavior today. Its compute pieces still turn the world grey; graphics pieces
  are offered as a frame-rate feature.
- **Port cost.** The seven commits touch about 4,000 lines across a new
  `pipeline/pieces.rs`, a new `native/pieces.rs`, `emit/lower.rs`, `native.rs`,
  `draw.rs`, `known.rs`, and `make.rs`. Against donor base `67d9598`, local
  `emit/lower.rs`, `emit/mod.rs`, `draw.rs`, `make.rs`, `device.rs`, and `pipeline.rs`
  differ by 112–1,455 diff lines each. A graphics-only subset still needs the translator
  changes. Without evidence that the pieces path fixes the observed output, the
  regression risk is higher than the potential benefit.
- **Decision.** Do not port the PR #18 graphics-pieces path for O16. Keep it listed as a
  later candidate for performance and coverage once a scene renders and real captures can
  measure its effect.

#### Runtime confirmation (2026-11-27, frame captures)

- The PR #18 head was built outside the repo and run with its pieces switch **on**
  (graphics only). It rendered the account screen, loading art, and first-boot menus.
  A control run with the switch **off** rendered the same screens. The refused slots are
  therefore not the cause of the black output, and the decision above stands.
- The real cause was local. Commit `f8b6af5` placed the dynamic descriptors above the
  lowered shader clamp. Bisection showed the import renders and `f8b6af5` is black, and
  the revert renders again. See `docs/changelog.md`. An earlier note in this audit said
  the run used single-plane presentation; that was wrong. The log does report
  two-plane composition, and the line had been cut off by a truncated `grep`.

### Vice-Tay diagnostic proposals and merged fixes

The latest audited default-branch head was `25324741b1`; the local clone remains an older
snapshot. [PR #452](https://github.com/avatarmanz/VIctory-7900XTX/pull/452) adds a
diagnostic breakdown for long frames, while [PR #453](https://github.com/avatarmanz/VIctory-7900XTX/pull/453)
adds timestamps by command-list type. These are measurement proposals, not FPS fixes;
their local target-run behavior is not yet established.

Vice-Tay [PR #206](https://github.com/TaynanGT/Vice-Tay/pull/206) is merged and repairs
an ambient resolve when the selected descriptor is a stencil plane. The local run
reported no depth-twin/depth-plane draws, so current counters do not support this as the
black-screen cause. [PR #274](https://github.com/TaynanGT/Vice-Tay/pull/274) adds DRED
breadcrumbs; its RTX 2080 Ti report found a significant frame cost for some breadcrumb
settings. Keep those diagnostics out of normal gameplay captures unless fault diagnosis
requires them.

### AstraForge black-screen evidence

The pre-run dialog passed and the runtime launched, but the captured render surface was
fully black. The runtime caption's 30 Hz / 33.3 ms figure is not classified application
FPS. Logs did not show device removal or VRAM exhaustion in the captured interval.
Resolved: the black output came from local commit `f8b6af5` (dynamic descriptors above
the shader clamp), not from the `0x1c8`/`0x218` refusals. Reverting it restores the
start-up screens. PresentMon still has not produced a frame CSV.
The current run therefore establishes a rendering failure, not an FPS result or a
memory-exhaustion diagnosis.

The seven comparison repositories plus the COOL_FOX mirror are cloned outside the
checkout. Exact shallow snapshot hashes are in [`REFERENCE-REPOSITORIES.md`](REFERENCE-REPOSITORIES.md).
