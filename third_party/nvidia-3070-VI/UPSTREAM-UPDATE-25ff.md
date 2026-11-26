# Upstream update: 25ff216

Current public `main` moved from `6e9c1dd` to `25ff2168267d967c5e428f94726a7384e59cd5b7`. GitHub reports one changed path: `docs/nvidia-8gb.md`; no runtime source changed. This checkout syncs that file to upstream blob `083f560cfa9dc798d16c1924f3b13ed062f1da10`.

The added report records that a second attempt to move refreshes ahead of submission crashed at the start of a cutscene, including variants that only checked in-flight writes. The source maintainer left refreshes on the submitting thread. Do not port the removed refresh-ahead experiment into the RTX 3070 build without a new correctness proof.

The CI run for this upstream commit (`45880961297`) still fails at the texture fixture's `clippy::precedence` warning under `-D warnings`; the separately committed local parentheses fix addresses that expression. The diagnostics build and tests were skipped, so the runtime source remains unverified by CI.
