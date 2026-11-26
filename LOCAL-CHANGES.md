# Local adaptation log

Upstream snapshot imported from `grimygunnz/nvidia-3070-VI` commit `6e9c1dd9fb32daaa855f446560a4d1f8df5f8424` (2026-11-26). Its original `LICENSE` is retained. The file list and upstream Git blob IDs are in `.source-manifest.json`.

Upstream `main` later advanced to `25ff2168267d967c5e428f94726a7384e59cd5b7`. That commit changes only `docs/nvidia-8gb.md`; the local copy of that file is synchronized to its blob `083f560cfa9dc798d16c1924f3b13ed062f1da10`. No runtime source changed between these revisions.

## Local changes

- `crates/victory-formats/src/texture.rs`: parenthesize `(i * 7)` before shifting in a test fixture expression. This preserves Rust operator-precedence behavior and fixes the upstream CI's `clippy::precedence` error under `-D warnings` (runs `45877144008` and `45880961297`). It still needs local `cargo clippy --all-targets -- -D warnings` and `cargo test --workspace` verification.
- `crates/victory-hle/src/modules/dstorage.rs` and `crates/victory-hle/Cargo.toml`: size the DirectStorage worker pool to the physical-core count, with an override (`VICTORY_DSTORAGE_WORKERS`, 1–64) and a fallback if Windows cannot report cores. Ported from [`fxceless/victory-fork#1044`](https://github.com/fxceless/victory-fork/pull/1044), authored by Key-rs. That open PR measured 5.7 ms/MB copy-back at 16 workers versus 2.4–3.5 ms/MB at 8 on a Ryzen 7 8845H / RTX 4060 Laptop. The target Ryzen 7 7700X has 8 physical / 16 logical cores; local FPS and copy timing remain unverified because Cargo is unavailable.

No other upstream source file is intentionally modified. The checkout's upstream commit history is not present because the restricted environment exposed repository files through the read-only GitHub API rather than Git transport. Local commits separately record the imported snapshot, Clippy fix, upstream documentation sync, and physical-core worker port.
