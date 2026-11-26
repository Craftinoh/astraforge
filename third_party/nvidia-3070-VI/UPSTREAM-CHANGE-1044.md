# Ported candidate: DirectStorage physical-core worker count

Source: [`fxceless/victory-fork#1044`](https://github.com/fxceless/victory-fork/pull/1044), authored by Key-rs, currently open at inspected head `4d1bf6b58e11c8796cf0f85b90e6c0a1ffca7650`.

The upstream change replaced one DirectStorage worker per logical processor with the reported physical-core count and added `VICTORY_DSTORAGE_WORKERS` (1–64) as an override. On its Ryzen 7 8845H (8c/16t) and RTX 4060 Laptop, the report measured copy-back at 5.7 ms/MB with 16 workers and 2.4–3.5 ms/MB with 8; sampled frame totals varied with scene work, so the report does not establish an FPS gain.

This port applies the same policy to the Pareto-residency descendant. The local hardware probe identifies a Ryzen 7 7700X with 8 physical and 16 logical processors, so the automatic Windows query should choose 8 workers. The switch is not set in the launch profiles; physical cores are discovered at runtime. If the OS query fails, the port falls back to half the logical count. An explicit override exists only for controlled A/B measurements.

The code is isolated in one source commit and is easy to revert. This environment has no Cargo/Rust toolchain, so neither the Windows API binding nor workspace tests/build have been verified locally. Treat it as an unbuilt optimization candidate until `cargo clippy --workspace --all-targets --locked -- -D warnings`, `cargo test --workspace --locked`, and repeated in-game measurements pass on the target PC.
