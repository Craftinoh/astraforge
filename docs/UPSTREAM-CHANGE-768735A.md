# Descriptor writes deferred until GPU idle

Source: [`Itsbatt/victory-unified@768735a`](https://github.com/Itsbatt/victory-unified/commit/768735ad589eb9951a5c8812c4675bbf3b9ed765). The RTX 3070 report in that fork associates in-flight descriptor rewrites with `0x887A0006` MMU-fault device removal. Its long stability run is separate from the outdoor performance result, which was about 3 FPS; this is stability evidence, not an FPS claim.

The local port queues a slot's null rewrite and resource release while submissions are flying. At an idle submission boundary it applies the queued work only if the slot has not since been remade. Texture-view refreshes are also skipped while submissions are flying. This preserves the old descriptor and the resource it references until the GPU is done with it.

The change is isolated in commit `fix(descriptor): defer live slot rewrites until GPU idle`. A regression test covers both a still-cleared slot and a slot remade after queuing. The Windows Rust toolchain and D3D12 test device are unavailable in this environment, so compilation and execution remain unverified.
