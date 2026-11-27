# AI-assisted contribution guide

This guide gives a coding model the same repository context and evidence rules used for human review. Copy the task prompt near the end into your model, then fill in the task-specific fields. Do not give a model credentials, private game files, save data, or raw captures.

## Repository map

| Path | Purpose |
|---|---|
| `AGENTS.md` | Mandatory instructions for coding agents |
| `CONTRIBUTING.md` | Human contribution entry point |
| `third_party/nvidia-3070-VI/` | Imported GPL-3.0 Cargo/D3D12 source subtree |
| `profiles/gpu-profiles.json` | Hardware identity and launcher preflight manifest |
| `profiles/rtx3070-profiles.json` | RTX 3070 runtime candidate presets |
| `tools/` | Hardware collection, build, launch, prewarm, capture, comparison, report export |
| `docs/source-credits.md` | Upstream origins and integrated changes |
| `third_party/nvidia-3070-VI/LOCAL-CHANGES.md` | Imported-source patch ledger |
| `docs/benchmark-procedure.md` | Repeatable real-gameplay measurement and reporting rules |
| `docs/progress-journal.md` | Durable current state, evidence, blockers, next steps |
| `tools/Invoke-AstraForgeModelReview.ps1` | Bounded read-only review through a local OpenAI-compatible provider configuration |

The repository root is documentation and tooling; run Cargo commands inside `third_party/nvidia-3070-VI/`.

## Model workflow

1. Read `AGENTS.md`, `README.md`, `docs/project-vision.md`, `docs/integration-architecture.md`, `docs/progress-journal.md`, and the relevant subsystem docs.
2. Inspect `git status --short --branch` and the existing diff before editing. Do not discard changes from another person.
3. Turn the request into a small, reviewable change with an explicit acceptance condition. If the task depends on missing hardware or game access, do independent source/document work and record the blocker; never fabricate a runtime result.
4. Inspect actual source and call sites. For a runtime setting, confirm the parser, accepted values, default, and every consumer. For a hardware profile, confirm all fields consumed by the launcher and renderer.
5. Prefer primary sources for upstream facts. Record exact repository, commit/PR, author, license, and files changed. Preserve license headers and provenance.
6. Implement only the necessary patch. Keep hardware identity separate from runtime preset and separate each GPU family.
7. Run checks proportionate to risk. Report command, exit status, and scope; distinguish compilation/unit correctness from gameplay performance and visual correctness.
8. Review `git diff --check`, the full diff, staged files, and public output for secrets, personal paths, identifiers, unsupported claims, and private title clues.
9. Update `docs/progress-journal.md` and applicable source/provenance/rollback docs.
10. Return a concise completion note with changes, evidence, limits, and next step. Do not commit or push unless the user requests it.

## Evidence levels

Use these labels consistently:

- **Inspected:** source, configuration, or documentation was read; no runtime check implied.
- **Parsed:** a parser accepted the file; behavior is not proved.
- **Built:** the named source revision compiled with the recorded toolchain; runtime correctness is not proved.
- **Unit-tested:** named automated tests passed; gameplay, image quality, and device-loss behavior may still be unverified.
- **Hardware-validated:** the exact machine/driver ran the described scenario and the capture is reproducible.
- **Performance-validated:** at least three matched runs per group meet the comparator criteria and use real application frames.

Never upgrade an evidence level based on model confidence or a result from another GPU.

## Adding a GPU or machine

Read [`GPU_PROFILE_SUBMISSION.md`](GPU_PROFILE_SUBMISSION.md). A person can submit a sanitized hardware report without changing code. Do not add an enabled profile until the adapter can really be selected, feature checks are correct, and the launcher, telemetry, tests, and runtime path support it. Do not copy RTX 3070 texture-room values to another GPU as if measured.

The current imported renderer selects the first DXGI adapter. A JSON entry by itself cannot make a second adapter render. AMD is planned but not enabled.

## Ready-to-copy task prompt

```text
You are contributing to AstraForge. Read AGENTS.md and docs/AI_CONTRIBUTOR_GUIDE.md first.

Task: [one concrete task]
Target hardware/OS: [exact model, OS, driver if known; otherwise say unknown]
Acceptance condition: [observable and testable result]
Allowed scope: [files or subsystem]
Do not: invent runtime flags, claim unmeasured performance, discard existing work,
include secrets or private paths, or publish private application/game identifiers.

Inspect repository status and the current implementation before editing. Trace all
relevant call paths. Preserve GPL-3.0 notices and record upstream provenance for
imported changes. Keep the patch focused and reversible. Run checks appropriate to
the risk, update the progress journal and applicable docs, then report exact files,
commands/results, evidence limits, and remaining hardware-only validation.
Do not commit or push unless explicitly asked.
```

## Local model / API privacy

Model endpoints, API keys, inference logs, and private machine data are not part of this repository. Keep provider configuration local, use environment or protected local configuration, and never paste a secret into a prompt, issue, log, commit, or benchmark report. A response from any model is a proposal that must be independently checked against source, tests, and evidence.

The optional review wrapper is documented in [`MODEL_ORCHESTRATION.md`](MODEL_ORCHESTRATION.md). It accepts only explicit text files, rejects common private/generated paths, caps request size, and saves the response outside Git. These controls reduce accidental disclosure; the operator must still inspect every selected file before sending it.
