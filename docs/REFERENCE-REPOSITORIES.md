# Upstream reference repositories

This inventory contains isolated, shallow Git clones used for read-only source and PR
comparison. They are stored outside the AstraForge checkout at
`%LOCALAPPDATA%\AstraForge\references\upstreams`. They are not GitHub forks, are not
build inputs, and do not imply that any branch was merged. Record every patch origin in
`source-credits.md` and the subtree `LOCAL-CHANGES.md` before accepting it.

## Local shallow clone snapshots

| Repository | Local snapshot | Notes |
|---|---|---|
| `Marvisak/VIctory` | `63bcca43c6a0` | Original project reference |
| `trustno1-coder/VIctory-NVIDIA` | `d12eb1b23da4` | NVIDIA branch; PR #18 is a broad graphics candidate, review only the matching pipeline path |
| `avatarmanz/VIctory-7900XTX` | `014d52dedf83` | AMD branch; NVIDIA reuse requires independent evidence |
| `fxceless/victory-fork` | `9a9091d180f0` | PR/issue comparison, including the RTX 4080 recipe |
| `PastiiJay/klbf-lab` | `82f8ed5` | DXIL and shader optimizer comparison |
| `Itsbatt/victory-unified` | `92dc8785eb4e` | RTX 3070 / 8 GB comparison |
| `soldsawn/victory-nvidia-8gb` | `c09a44e97df4` | NVIDIA 8 GB texture/residency comparison |
| `codec-d/cool_fox` mirror | `f4b48ad766dd` | User-provided mirror clone succeeded; matches the Pareto-residency reference commit |

The local snapshots are shallow and blob-filtered. To inspect files, fetch only the
needed commit/object and keep the clone outside Git. Refresh a snapshot before relying
on its open/merged PR state; a local HEAD is a point-in-time source revision.

## Additional read-only audit snapshots

| Repository | Audit state | Findings captured in |
|---|---|---|
| `TaynanGT/Vice-Tay` | Current GitHub audit head `25324741`; local reference clone was older at `231b6a9` | `docs/fork-comparison.md`; PR #206 and #274 merged, #452 and #453 are diagnostic proposals |
| `stellarr-studio/kelvaroq` | Local clone snapshot `92606ea`; issue state checked separately | `docs/fork-comparison.md`; issue #25 reports a black output case with low reported VRAM use |

The trustno PR #18 head is fetched in the external `VIctory-NVIDIA` reference at
`e0703c136d472a67c5f00a1a9296d2e6790fcea6`; GitHub lists 58 commits / 64 files. A
three-dot diff against the later local main snapshot lists 77 paths because the branches
diverged from merge base `9341f4316f0265786a95a6791a428f14d5695cb1`. Do not confuse this
PR ref with the local clone's main snapshot `d12eb1b23da4`.

`codec-d/cool_fox` on GitHub returned 404 during the audit. The supplied mirror is now
reachable and its HEAD is `f4b48ad766ddbec1a1867022cd42f7645b0dd55e`, matching the
requested Pareto-residency baseline. Verify future mirror history before treating it as
the canonical repository.

## Safe comparison workflow

1. Record the exact upstream commit or PR and inspect its diff, tests, author, and
   license.
2. Compare only the same subsystem and call path in the selected source subtree.
3. Keep vendor-specific code conditional on a confirmed adapter identity and preserve
   the original path for other vendors.
4. Port one complete, reversible change at a time, with tests and provenance.
5. Validate correctness before performance. A donor benchmark is not an AstraForge
   result, and a model review is not proof.
