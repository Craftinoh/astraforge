# Contributor handoff: one clone, one machine profile

This is the repeatable workflow for a contributor who wants to test AstraForge on their own PC and return useful profile evidence. Shader and shared engine work can stay with the maintainer while the contributor owns hardware discovery and measurements.

## Roles

| Role | Owns | Hands off |
|---|---|---|
| Hardware contributor | Local machine inventory, adapter/profile preflight, runtime tuning experiments, repeatable captures, sanitized evidence | Hardware report, exact source/build, setting delta, test results, limits |
| Project maintainer | Shared shader and engine changes, source attribution, review, deciding what becomes a supported profile | Reviewed source commit and updated project docs |
| Coding model | Focused implementation/review within the assigned scope, following `AGENTS.md` | Proposed diff and evidence; no independent support/performance claims |

The contributor can report a machine profile without editing shader code. If they find a shader or renderer defect, they should provide a minimal reproduction and capture details; the maintainer can then implement or review the shared fix separately from profile tuning.

## Contributor steps

1. Clone the public repository and create a branch for the GPU family or focused task. Replace the example branch suffix with a short vendor/GPU slug. Use an anonymous host label in reports; do not put a person's name in the branch or public artifacts.

   ```powershell
   git clone https://github.com/Craftinoh/astraforge.git
   Set-Location astraforge
   git switch -c profile-nvidia-rtx3070
   ```

2. Open the checkout in the coding environment/model. Tell it to read `AGENTS.md`, `CONTRIBUTING.md`, and `docs/AI_CONTRIBUTOR_GUIDE.md`. Copy `docs/templates/AI_TASK_PROMPT.md` and give it one bounded task. Do not give the model raw inventory files, credentials, saves, or local game paths.

3. Capture a local hardware inventory:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Collect-AstraForgeHardware.ps1 `
     -OutputPath .\out\hardware-latest.json `
     -DxDiagReportPath .\out\dxdiag-latest.txt
   ```

   The raw report under `out/` is local and ignored by Git. Use `docs/templates/hardware-report.template.md` to prepare a separately reviewed, sanitized handoff. Record unknown and user-reported values as such; do not infer effective memory clocks, ReBAR, feature support, or adapter selection.

4. Check the actual renderer path before tuning. Today it creates the D3D12 device from the first DXGI adapter; putting another device ID in JSON does not select that GPU. NVIDIA RTX 3070 Ampere is the only active candidate profile; other cards need a validated candidate and adapter/tooling support before being described as supported. AMD is not enabled.

5. Keep experiments isolated. Do not change the shared RTX 3070 preset to represent another card. Use only runtime variables that the checked-out source parses and consumes. For each comparison, change one setting or one clearly grouped setting set, keep the build/scene/cache state matched, and save raw captures locally.

6. Run the relevant preflight and checks. Synthetic harness tests only validate the harness. Rust/D3D12 changes require the pinned build and appropriate tests. Performance claims require repeated real application frames and the comparison procedure in `benchmark-procedure.md`.

7. Return a pull request using `.github/PULL_REQUEST_TEMPLATE.md`. Include the sanitized machine report, GPU/OS/driver, source commit and build hash, profile/settings delta, exact commands/results, repeat count and scene alias, limitations, and rollback. Keep raw logs, ETL, CSV, paths, and private application identifiers local.

## Maintainer integration

- Review machine facts separately from code claims.
- Keep a hardware-only profile report separate from a renderer change and from a benchmark claim.
- Import shader/engine fixes as focused commits with exact upstream provenance and GPL-3.0 notices.
- Do not mark a GPU active or a preset faster until adapter selection, feature checks, stability, visual correctness, and the relevant evidence gate pass.
- Update `docs/progress-journal.md`, `docs/source-credits.md`, and `third_party/nvidia-3070-VI/LOCAL-CHANGES.md` when the accepted change requires them.

See [`GPU_PROFILE_SUBMISSION.md`](GPU_PROFILE_SUBMISSION.md) for the technical profile schema and acceptance gate.
