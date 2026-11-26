# Local adaptation log

Upstream snapshot imported from `grimygunnz/nvidia-3070-VI` commit `6e9c1dd9fb32daaa855f446560a4d1f8df5f8424` (2026-11-26). Its original `LICENSE` is retained. The file list and upstream Git blob IDs are in `.source-manifest.json`.

## Local changes

- `crates/victory-formats/src/texture.rs`: parenthesize `(i * 7)` before shifting in a test fixture expression. This preserves Rust operator-precedence behavior and fixes the latest upstream CI's `clippy::precedence` error under `-D warnings` (run `45877144008`). It still needs local `cargo clippy --all-targets -- -D warnings` and `cargo test --workspace` verification.

No other upstream source file is intentionally modified. The checkout's upstream commit history is not present because the restricted environment exposed repository files through the read-only GitHub API rather than Git transport. A local Git history will record the imported snapshot and this small patch separately.
