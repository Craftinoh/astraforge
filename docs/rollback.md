# Rollback procedure

The source snapshot and local edits are imported under `third_party/nvidia-3070-VI` as a Git subtree. Its reachable commits import the upstream snapshot, apply the Clippy fix, sync documentation, port the physical-core worker count and two descriptor lifetime fixes, use neutral launcher defaults, and anonymize comments. The latest imported source commit is `e31aafd`. The root workspace is a Git repository on `main`. No game runtime files were modified. Benchmark, build, launch, and prewarm logs/cache/data default outside the workspace.

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

The scripts have not been run against a game binary. The public-report exporter and generic GPU profile launcher are workspace tooling. If they are run later, benchmark/build/prewarm output defaults under `%LOCALAPPDATA%\AstraForge`; each build and cold/warm working cache receives its own directory. Remove only specific generated directories you want to discard. Do not remove the user's existing VIctory shader cache, immutable prewarm seed, or game saves as a rollback step.
