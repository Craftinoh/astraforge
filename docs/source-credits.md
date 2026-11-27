# Source credits and provenance

This project preserves the upstream GPL-3.0 license and original source notices. See `third_party/nvidia-3070-VI/LICENSE` and `third_party/nvidia-3070-VI/LOCAL-CHANGES.md` for the source checkout and detailed patch ledger.

## Initial source base

- COOL_FOX Pareto-residency, reference commit `f4b48ad766ddbec1a1867022cd42f7645b0dd55e`, associated with `neevets/cool_fox`.
- NVIDIA 8 GB derivative `grimygunnz/nvidia-3070-VI`, imported at `6e9c1dd9fb32daaa855f446560a4d1f8df5f8424`.
- Latest synchronized upstream documentation snapshot: `25ff2168267d967c5e428f94726a7384e59cd5b7`.

## Integrated changes

| Change | Upstream origin | Local source commit | Status |
|---|---|---|---|
| Clippy precedence correction in texture-format code | Current upstream CI finding | `fe8995b` | Behavior-preserving; local compile pending |
| NVIDIA 8 GB documentation sync | `grimygunnz/nvidia-3070-VI` | `2374bca` | Documentation only |
| DirectStorage worker count bounded by physical-core count | fxceless PR #1044 | `f0ab013` | Ported; local build and performance effect unverified |
| Descriptor dynamic-range allocation retains heap identity | fxceless PR #1324 | `878dbd7` | Ported with regression test; local test pending |
| Defer descriptor nulling/resource release while submissions are in flight | `Itsbatt/victory-unified` commit `768735a` | `6e91b7b` | Ported with regression test; workspace tests pass, gameplay stress remains pending |
| Use a neutral default data directory and generic executable name in the copied launcher | Local privacy/documentation change | `afbb784`, `337310f`, `c6f1fc4` | `VICTORY_GAME_DIR` and `VICTORY_GAME_EXE` remain configurable; defaults stay outside the workspace |
| Anonymize title-specific comments and command examples | Local documentation/privacy change | `e31aafd` | Comment-only; runtime behavior unchanged |
| Reserve a null descriptor before the portable heap's dynamic descriptor tail | Local fix after model-assisted review and independent source audit; no upstream patch copied | `f8b6af5` | Adds a regression test for disjoint shader-clamp and dynamic ranges; validated by the GPU library test suite |
| Start commit-headroom admission at zero until the first valid Windows sample | Local fail-closed memory-safety change; no upstream patch copied | `42435bf` | Failed initial sampling can defer speculative uploads instead of treating commit headroom as unlimited |
| Correct two indirect-budget regression-test fixtures | Local test-only corrections | `468b79b` | Test inputs and expected accepted work now match the shader's all-or-nothing budget semantics |
| Canonicalize placed-resource padding and unused SRV/UAV union words before shape keying | [`TaynanGT/Vice-Tay#27`](https://github.com/TaynanGT/Vice-Tay/pull/27), focused commits `f07e54a2` and `ce914907`; resource-padding origin also credits `JMAN730/project-flamingo@b1e0cd1d` | `descriptor: canonicalize placed-view shape keys` change set | Two focused tests and all ten descriptor tests pass locally; gameplay memory and rendering remain unverified |

## Reviewed, not merged wholesale

The comparison report records the relevant fixes and measured evidence from the NVIDIA-focused fork, `victory-unified`, the 8 GB NVIDIA fork, the 7900 XTX fork, the fxceless fork, and the shader-lab work. Only changes with a clear source match and a plausible correctness/performance case are candidates for integration. Each imported change must retain its origin and pass the local build and validation path before it is described as verified.

## Publication policy

Keep the original GPL-3.0 license, copyright headers, and notices. Do not upload game data, executable images, keys, saves, shader caches, private logs, or raw hardware reports. Public benchmark material must use anonymous scenario aliases and omit title/executable/path identifiers. Do not describe this project as endorsed by any upstream developer or GPU vendor.
