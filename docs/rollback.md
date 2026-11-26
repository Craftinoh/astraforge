# Rollback procedure

The source snapshot and local edits are isolated in the nested Git repository `third_party/nvidia-3070-VI`; its commits import the upstream snapshot, apply the Clippy fix, sync the current upstream documentation, port the physical-core worker count and two descriptor lifetime fixes, and use neutral launcher defaults. The latest source commit is `c6f1fc4`. The root workspace has no Git repository yet. No game runtime files were modified. Benchmark, build, launch, and prewarm logs/cache/data default outside the workspace.

To remove only the artifacts added by this investigation, delete these individual files:

- `third_party/nvidia-3070-VI/` (the isolated source checkout, including its local `.git` history)

- `tools/Build-VIctory.ps1`
- `tools/Collect-VIctoryHardware.ps1`
- `tools/Compare-VIctoryRuns.ps1`
- `tools/Export-VIctoryPublicReport.ps1`
- `tools/Measure-VIctoryGameplay.ps1`
- `tools/Prewarm-VIctory.ps1`
- `tools/Start-VIctory3070.ps1`
- `tools/Start-VIctoryGPU.ps1`
- `tools/Test-VIctoryBenchmarkHarness.ps1`
- `tools/Victory-BenchmarkCommon.psm1`
- `profiles/rtx3070-profiles.json`
- `profiles/gpu-profiles.json`
- `docs/benchmark-procedure.md`
- `docs/changelog.md`
- `docs/rollback.md`
- `docs/RTX3070-assessment.md`
- `docs/RTX3070-variable-audit.md`
- `docs/fork-comparison.md`
- `docs/launcher-profiles.md`
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

The scripts have not been run against a game binary. The public-report exporter and generic GPU profile launcher are workspace tooling. If they are run later, benchmark/build/prewarm output defaults under `%LOCALAPPDATA%\VIctory`; each build and cold/warm working cache receives its own directory. Remove only specific generated directories you want to discard. Do not remove the user's existing VIctory shader cache, immutable prewarm seed, or game saves as a rollback step.
