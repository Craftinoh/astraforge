# Rollback procedure

The source snapshot and local edits are imported under `third_party/nvidia-3070-VI` as a Git subtree. Its reachable history includes the upstream snapshot, the Clippy fix, documentation sync, physical-core worker port, descriptor lifetime fixes, neutral launcher defaults, comment anonymization, and the newer descriptor-residency correctness fix. Root-level commits keep each local change reversible on `main`. No game runtime files were modified. Benchmark, build, launch, and prewarm logs/cache/data default outside the workspace.

To remove only the artifacts added by this investigation, delete these individual files:

- `third_party/nvidia-3070-VI/` (the source subtree; its history remains reachable from the project repository)

- `tools/Build-AstraForge.ps1`
- `tools/Collect-AstraForgeHardware.ps1`
- `tools/Compare-AstraForgeRuns.ps1`
- `tools/Export-AstraForgePublicReport.ps1`
- `tools/Measure-AstraForgeGameplay.ps1`
- `tools/Prewarm-AstraForge.ps1`
- `tools/Start-AstraForge3070.ps1`
- `tools/Start-AstraForge.ps1`
- `tools/Test-AstraForgeBenchmarkHarness.ps1`
- `tools/Invoke-AstraForgeModelReview.ps1`
- `tools/AstraForge-BenchmarkCommon.psm1`
- `profiles/rtx3070-profiles.json`
- `profiles/gpu-profiles.json`
- `docs/benchmark-procedure.md`
- `docs/changelog.md`
- `docs/rollback.md`
- `docs/RTX3070-assessment.md`
- `docs/RTX3070-variable-audit.md`
- `docs/fork-comparison.md`
- `docs/launcher-profiles.md`
- `docs/integration-architecture.md`
- `docs/MODEL_ORCHESTRATION.md`
- `docs/OPERATIONAL_PLAN.md`
- `docs/project-vision.md`
- `docs/source-credits.md`
- `docs/progress-journal.md`
- `README.md`
- `LICENSE`
- `.gitignore`
- `out/dxdiag-report.txt`
- `out/dxdiag-latest.txt`
- `out/hardware.json`
- `out/hardware-latest.json`

The scripts have not been run against a game binary. The public-report exporter and generic GPU profile launcher are workspace tooling. Benchmark/build/prewarm output defaults under `%LOCALAPPDATA%\AstraForge`; each build and cold/warm working cache receives its own directory. Remove only specific generated directories you want to discard. Do not remove the user's existing shader cache, immutable prewarm seed, or game saves as a rollback step.

To roll back only the placed-view canonicalization, revert the focused change set named `descriptor: canonicalize placed-view shape keys`. That restores direct copying of the complete 14-word resource and 16-word view descriptions and removes the two matching regression tests. Do not partially remove only one canonicalizer: resource padding and dimension-unused view words are independent sources of false shape growth.
