# Project vision: VIctory GPU Profiles

## What we are building

We want to take VIctory beyond the usual vibe-coded emulator fork and make it a reference for how a compatibility project is designed, implemented, tested, documented, credited, and maintained.

That means the project should explain how it works, show which hardware profile is active, preserve the source and authorship of imported changes, measure actual application frames, publish reproducible evidence, and state what has not been verified. A patch should not become a “performance fix” just because it compiles or changes a counter.

## Hardware strategy

The first profile family targets NVIDIA, starting with RTX 3070 Ampere and its 8 GB VRAM limit. GPU identity and vendor-specific tuning live in a profile manifest; Stability, Balanced, Performance, and Quality remain runtime presets inside that hardware profile.

AMD is a planned phase. It will receive its own adapter selection, memory policy, shader behavior, presets, and validation. NVIDIA settings will not be copied onto AMD hardware, or vice versa, without measurements and correctness checks.

## Performance standard

The initial gameplay acceptance target is at least 30 real application FPS, with a 1% low of at least 30 FPS across repeated runs of the same route. Reports must distinguish cold and warm cache states, use application-frame classification, and include frametime and memory behavior. A menu, loading screen, generated frame, short best-case clip, or synthetic test cannot establish this target.

Where the exact game files, GPU, or runtime are unavailable, record the blocker and prepare the validation procedure. Never invent benchmark results or describe an unmeasured profile as faster.

## Anonymous reporting

Public benchmark labels use neutral names such as `scene-01`. Reports must not identify the game, its executable, personal directory paths, save files, user account, or other private data. Raw captures stay local unless they have been reviewed and sanitized.

The repository must not contain game content, keys, personal saves, credentials, local shader caches, or unredacted hardware reports. Use only the owner's authorized local files for runtime work.

## Engineering principles

- Keep GPU profiles and runtime presets data-driven and reversible.
- Separate vendor-specific code paths and test each architecture independently.
- Preserve necessary draws, synchronization, and resource transitions; do not manufacture FPS by omitting work.
- Gate memory optimizations on runtime budget and pressure measurements.
- Treat shader translation, wave size, descriptor lifetime, and resource residency as correctness concerns first.
- Keep release and diagnostic builds separate, record toolchain and artifact hashes, and retain rollback instructions.
- Use repeatable gameplay captures, comparison runs, and visual checks before calling an optimization successful.
- Keep every upstream credit, license, source commit, and local patch origin visible.

## Source and community credits

The initial base follows COOL_FOX Pareto-residency at `f4b48ad766`, with the public `grimygunnz/nvidia-3070-VI` derivative as the practical NVIDIA 8 GB source snapshot. Local source commits record the Clippy correction, physical-core DirectStorage workers from fxceless #1044, descriptor heap identity from fxceless #1324, and descriptor lifetime handling from `Itsbatt/victory-unified` commit `768735a`.

Other repositories and proposals were reviewed as references, not merged wholesale. The [source-credit ledger](source-credits.md), [fork comparison](fork-comparison.md), and nested source `LOCAL-CHANGES.md` keep those decisions and upstream credits auditable. The source's GPL-3.0 license remains in force.

## Milestones

1. Stabilize and validate the RTX 3070 profile on the user's machine.
2. Measure repeated, anonymous gameplay routes and find the actual CPU/GPU bottleneck.
3. Reach or document the measured limit against the 30 FPS acceptance target.
4. Add AMD as a separately implemented and measured profile family.
5. Publish build, test, benchmark, attribution, and rollback practices that other compatibility projects can reproduce.
