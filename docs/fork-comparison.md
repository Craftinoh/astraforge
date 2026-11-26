# VIctory fork comparison for RTX 3070 Ampere

Reviewed public repositories and their default-branch heads on 2026-11-26. These are maintainers' measurements on different builds and scenes; they are evidence for candidate changes, not a common benchmark set.

## Selected base: COOL_FOX Pareto-residency descendant

The requested Pareto commit is [`neevets/cool_fox@f4b48ad766`](https://github.com/neevets/cool_fox/commit/f4b48ad766ddbec1a1867022cd42f7645b0dd55e). The accessible NVIDIA 8 GB descendant is [`grimygunnz/nvidia-3070-VI`](https://github.com/grimygunnz/nvidia-3070-VI), imported at `6e9c1dd` and synced through the docs-only upstream commit `25ff216`. Its Series S report measures about 16.3–17 FPS on an RTX 3070 Ti with 64 GB RAM, 7.0 GB peak VRAM, and about 55.9 ms of submission-thread work per frame. It is the closest available 8 GB NVIDIA / Series S baseline, but still below 30 FPS and materially different from this RTX 3070 / 32 GB host. The latest report explicitly rejects another refresh-ahead experiment after cutscene-start null writes/crashes.

The imported source already has dynamic local DXGI budget accounting, low-budget texture-copy limits, a fast unmapped-range path in `texture::mapped_bytes`, resident-range texture handling, commit-pressure admission, and Series S defaults. The dynamic-heap identity guard merged as [`fxceless#1324`](https://github.com/fxceless/victory-fork/pull/1324) is ported with its wrong-identity regression test. The in-flight descriptor deferral from [`victory-unified@768735a`](https://github.com/Itsbatt/victory-unified/commit/768735ad589eb9951a5c8812c4675bbf3b9ed765) is also ported: it preserves a descriptor and its referenced resource until submissions are idle, then skips slots remade in the meantime. Its RTX 3070 report links this fix to MMU-fault stability, but it is not an FPS result. Both local ports have regression tests, but neither is compiled or D3D12-validated because the Windows Rust toolchain is unavailable. The RTX 3070 profiles retain the selected base and do not add a second VRAM controller.

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
