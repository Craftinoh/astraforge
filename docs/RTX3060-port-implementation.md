# How the `host-02` Vice-Tay port is implemented

This document explains the local changes behind the RTX 3060 runs in [`RTX3060-vice-tay-findings.md`](RTX3060-vice-tay-findings.md). They sit uncommitted on top of [`TaynanGT/Vice-Tay@877a40e8`](https://github.com/TaynanGT/Vice-Tay/commit/877a40e891d04635e988303499382eae7eaebc2c): 16 modified files and 1 new script (473 lines added, 382 removed). **None of this code is part of this pull request.** It is described here so AstraForge maintainers can judge what to port. Each section names the file, what the code does, where it came from, and whether AstraForge already has it.

## Summary

| Change | Vice-Tay files | Origin | In AstraForge? |
|---|---|---|---|
| 1. Water programs removed from the default wave-wide list | `crates/victory-shader/src/emit/mod.rs`, `scripts/play.ps1` | Local, after the `fxceless/victory-fork` README finding | Not needed: no such list, and wave-wide is off by default |
| 2. Raw buffer views bounded to their buffer | `crates/victory-gpu/src/descriptor/host.rs` | [fxceless #1266](https://github.com/fxceless/victory-fork/pull/1266) by lichenlang89 | **No** (port candidate) |
| 3. Embedded DXBC hashed by its declared size | `apps/victory/src/shader.rs` | [trustno1-coder/VIctory-NVIDIA #21](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/21) by Yusuf Al-Khawaldeh | **No** (port candidate) |
| 4. Violet probe artifacts discarded before the ambient cap | `crates/victory-gpu/src/ambient.rs` | [VIctory-NVIDIA #29](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/29) by Ahyildiz | **No** (port candidate) |
| 5. Optional en-US keyboard layout on focus | `crates/victory-hle/src/modules/lifecycle.rs` | [VIctory-NVIDIA #17](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/17) by superboynick and trustno1-coder | **No** (optional) |
| 6. DirectStorage workers sized to physical cores | `crates/victory-hle/src/modules/dstorage.rs`, `crates/victory-hle/Cargo.toml` | [fxceless #1044](https://github.com/fxceless/victory-fork/pull/1044) by Key-rs, via AstraForge `f0ab013` | Yes (came from AstraForge) |
| 7. Commit headroom starts at zero | `crates/victory-gpu/src/residency.rs` | AstraForge `42435bf` | Yes (came from AstraForge) |
| 8. Indirect-budget test fixtures | `crates/victory-gpu/src/indirect.rs` (tests only) | AstraForge `468b79b` | Yes (came from AstraForge) |
| 9. Frame panel redesigned around a 30 fps budget | `crates/victory-gpu/src/host/panel.rs`, `crates/victory-gpu/src/shadow.rs` | Local | No (AstraForge uses a caption instead) |
| 10. Resource tracker script | `scripts/track-performance.ps1` (new) | Local | Overlaps `tools/Measure-AstraForgeGameplay.ps1` |
| 11. PresentMon summary in `measure-frames.ps1` | `scripts/measure-frames.ps1`, `docs/tests.md` | Adapted from AstraForge `Measure-AstraForgeGameplay.ps1` (`6d0135c`) | Yes (AstraForge's harness) |
| 12. Credits and notes | `docs/credits.md`, `docs/victory-nvidia.md` | Local | n/a |

## 1. Water: wave-wide default list

**Problem.** On this RTX 3060 the sea showed flaring black squares (`scene-01`, `scene-02`).

**Cause.** Vice-Tay has `DEFAULT_WAVE_WIDE_HASHES` in `emit/mod.rs`. On hosts with 32-lane waves, these console wave64 compute programs are emitted in a "wave-wide" form, which runs one console wave as two host waves joined by group barriers. The list held four hashes. Two of them, `6f225b641c5b0708` and `5dc3b25986622949`, are water programs. Their wave-wide output was wrong, which matches the symptom the `fxceless/victory-fork` README (2026-11-27) reports.

**Change.** The two water hashes were removed, leaving `369cbe906ea72764` and `2cc4c197ee29e291`:

```rust
const DEFAULT_WAVE_WIDE_HASHES: [&str; 2] = [
    "369cbe906ea72764",
    "2cc4c197ee29e291",
];
```

Without the wave-wide form, those two programs fail translation ("shader does not translate"), so the pipeline layer drops their dispatches. `VICTORY_WAVE_WIDE=1` with `VICTORY_WAVE_WIDE_ONLY=<hashes>` can still name them back in for a test. `scripts/play.ps1` only changes its warning text from "4 safe shaders" to "2 safe shaders".

**Result.** The player reported correct-looking water. The gameplay median went from 15.4 to 17.5 fps, but in single runs on different routes.

**Limits.** This is a workaround, not a fix: the water work is skipped, not translated. AstraForge's `AGENTS.md` forbids removing shader work, so it should not be ported as is. The real fix is the fork's paired wave64 translator (`paired.rs`, `paired_fp32.rs`, `wave64_after_loop.rs` and related files, about 6,000 lines).

**AstraForge.** Not applicable. AstraForge's `emit/mod.rs` has no default hash list, and its wave-wide form is off unless `VICTORY_WAVE_WIDE=1`. The risk is only that someone turns it on globally.

## 2. Raw buffer views bounded to their buffer

**What it does.** Previously, a dynamic raw SRV or UAV took its element count from the title's length alone: `(len / 4).clamp(1, u32::MAX)`. A view could then extend past the end of the D3D12 buffer it was placed on. The new helper reads the buffer's real width and returns `None` when the view cannot start inside it:

```rust
fn raw_view_elements(width: u64, offset: u64, len: u64) -> Option<u32> {
    if !offset.is_multiple_of(16) {
        return None;
    }
    let available = width.saturating_sub(offset) / 4;
    let elements = (len / 4).max(1).min(available).min(u64::from(u32::MAX));
    (elements != 0).then_some(elements as u32)
}
```

When it returns `None`, the slot gets a null descriptor (`null_raw_at` / `null_raw_uav_at`). Otherwise the view is shortened to whole dwords inside the buffer. A unit test (`raw_views_fit_complete_aligned_dwords`) covers in-range, clipped, past-the-end, too-small and misaligned cases.

**Why it matters.** Out-of-bounds raw views are undefined behaviour in D3D12 and a known cause of device removal on NVIDIA. This is a correctness guard, not a speed change.

## 3. Embedded DXBC hashed by its declared size

**What it does.** `apps/victory/src/shader.rs` finds DXBC containers embedded in title files for offline warming. Before, it passed everything from the `DXBC` magic to the end of the file to the parser and the hash. Now it reads the container's declared size at byte offset `0x18` and hashes exactly that slice:

```rust
let size = u32::from_le_bytes(tail.get(0x18..0x1c)?.try_into().ok()?) as usize;
let data = tail.get(..size)?;
Container::parse(data).ok()?;
```

**Why it matters.** At runtime the title hands over exactly one container, so its hash covers only those bytes. The old scanner hashed trailing bytes too, so `victory warm` stored pipelines under keys the runtime never asked for, and the warm cache missed. The test `embedded_containers_keep_runtime_hashes` checks that an embedded container keeps its runtime hash.

## 4. Violet probe artifacts in the ambient stand-in

One line in `ambient.rs`, before the existing luminance cap:

```rust
if (was.b > 2.5 * was.g && was.b > was.r && was.b > 0.02) was = 0.0;
```

The ambient stand-in for the disabled ray-traced lighting sometimes reads strongly blue-violet probe values that pass the brightness cap. These values are discarded. This is a visual fix only.

## 5. Optional en-US keyboard layout

`lifecycle.rs` adds `english_input()`. When `VICTORY_IME_ENGLISH=1` is set and the title window gains focus, it looks through the layouts Windows has already loaded and selects en-US (`0x0409`) for the title's thread. It loads nothing new and is off by default. It helps with non-US keyboard layouts, where the title misreads keys.

## 6–8. Changes that came from AstraForge

- **DirectStorage workers** (`dstorage.rs`, plus the `Win32_System_SystemInformation` feature in `Cargo.toml`): `physical_cores()` reads processor records from `GetLogicalProcessorInformationEx`. `choose_workers()` uses the physical-core count (8 on this i7-11700F), with `VICTORY_DSTORAGE_WORKERS` (1–64) as an override. The SMT siblings stay free for submission and copy-back work.
- **Commit headroom** (`residency.rs`): `AVAILABLE_COMMIT` starts at `0` instead of `u64::MAX`, so speculative uploads wait for a valid Windows sample.
- **Indirect-budget fixtures** (`indirect.rs`): test-only corrections, no runtime change.

## 9. Frame panel (on-screen overlay)

`host/panel.rs` was rewritten (489 lines changed) around the 30 fps goal:

- Large rendered-fps number, coloured mint within 33.3 ms, amber up to 1.5× that, red beyond.
- Frame time in ms and the 1% low.
- A frame-time history graph with the 33.3 ms budget as a dashed line.
- Rows: CPU submission time, CPU %, GPU % (marked `EST` when estimated), VRAM used/budget, game RAM, system RAM, and draws per frame with the dropped count.
- Memory rows turn amber at 92% full.

The old panel's VRAM breakdown (`vram_breakdown()` in `shadow.rs`) was removed because the new panel no longer uses it. AstraForge currently shows `AstraForge | <FPS> | <ms/frame> | <draws/frame>` in the window caption instead.

## 10. Resource tracker script

`scripts/track-performance.ps1` (new, 183 lines) works in two modes:

- **Launch:** it starts `play.ps1` with the machine preset, DLSS mode and extra `VICTORY_*` settings (only `VICTORY_*` names are accepted).
- **Attach:** it watches an already running process.

Once per second it writes a CSV under `%LOCALAPPDATA%\victory\performance\<session>`. Each row holds the rendered fps (parsed from the runtime's log reports, blank when the last report is more than 10 s old), the game's private working set, system RAM, game and system GPU % (busiest engine), and game and system dedicated VRAM. It reads Windows performance counters through CIM. It is a monitoring tool, not a benchmark; AstraForge's `Measure-AstraForgeGameplay.ps1` with PresentMon is the stronger instrument.

## 11. PresentMon summary

`scripts/measure-frames.ps1 -PresentMon` summarizes a PresentMon CSV from its `MsBetweenPresents` column. It keeps only application-classified frames when frame types exist and labels unclassified captures as such. It also accepts `-ProcessId` and `-SwapChainAddress` for captures with several streams. This logic was adapted from AstraForge's harness.

## Suggested port order for AstraForge

1. **Change 2** (raw-view bounds): a small correctness guard with a unit test.
2. **Change 3** (DXBC declared size): makes offline warming hit the runtime cache. AstraForge's journal reports long pipeline creation stalls.
3. **Change 4** (violet probes): a one-line visual fix in the same ambient code.
4. **Change 5**: optional.

Each port should follow `AGENTS.md`: trace the call path, credit the original author in `docs/source-credits.md` and `LOCAL-CHANGES.md`, and add the regression test.
