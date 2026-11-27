# AstraForge task brief for a coding model

Copy the prompt below into the coding model that will work in this checkout. Fill in all bracketed fields. Keep the prompt and model logs free of keys, private game data, and identifying machine paths.

```text
You are contributing to the AstraForge repository. First read AGENTS.md,
CONTRIBUTING.md, docs/AI_CONTRIBUTOR_GUIDE.md, docs/progress-journal.md, and
the docs for the subsystem named below.

Task:
[One concrete requested change]

Target:
[GPU/CPU/OS/driver, or state which facts are unknown]

Acceptance condition:
[How a reviewer can verify completion]

Allowed scope:
[Specific files/subsystem; preserve all other work]

Constraints:
- Inspect git status and current diff before editing; do not discard existing changes.
- Read and trace the actual implementation. Never invent runtime variables,
  accepted values, defaults, hardware support, or performance results.
- Keep hardware identity, vendor-specific implementation, and runtime presets separate.
- Preserve GPL-3.0, source notices, upstream credits, and reversible change history.
- Do not include credentials, personal paths, raw hardware captures, game files,
  or private application/game identifiers in public files or model requests.
- Do not claim a performance gain without matched real-application gameplay runs.
- If hardware access is unavailable, finish useful source/document work and record
  exactly which validation remains, without fabricating results.
- Do not commit or push unless explicitly requested.

Work sequence:
1. Report the current branch/status and the source files/call paths relevant to the task.
2. Make the smallest complete change and update provenance, documentation, and
   rollback notes where applicable.
3. Run checks appropriate to the change and report exact commands and outcomes.
4. Review the complete diff for regressions, secrets, identifying paths, and
   unsupported claims; run git diff --check.
5. Update docs/progress-journal.md with evidence, limitations, and next action.

Final response format:
Changed: [paths and behavior]
Evidence: [exact checks and results]
Limits: [what is still unverified]
Next: [remaining action]
```
