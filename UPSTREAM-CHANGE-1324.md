# Ported descriptor heap identity guard

Source: merged [`fxceless/victory-fork#1324`](https://github.com/fxceless/victory-fork/pull/1324), authored by CwWwWwW; merge commit `52ac4ec0f8a03f103c146e60228e53612759d435`.

The title can release a shader-visible heap while command lists still retain dynamic descriptor ranges from it. A later host heap may reuse the same address before those lists reset. Address-only release then looks up the new heap and can free its live range. The port adds a monotonic host-heap identity to each list's dynamic-range record and rejects releases to a different identity.

Added a regression test that allocates from heap A, attempts to release through heap B's identity, verifies A's free count is unchanged, then verifies A's own identity releases the range. Upstream reports this WARP test plus 218 `victory-gpu` tests passing; this local copy has not been compiled because Cargo/Rust are unavailable. The guard addresses range ownership after address reuse. It is separate from descriptor writes racing in-flight GPU work; that RTX 3070-specific deferral has not been ported.
