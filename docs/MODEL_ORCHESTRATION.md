# Model-assisted review orchestration

AstraForge can send a bounded, read-only source review to any text-only,
OpenAI-compatible Chat Completions endpoint. The model never edits the checkout and its
answer is stored outside Git for independent review.

## Preferred model routes

The maintainer or Claude Code remains responsible for repository state, source tracing,
validation, and accepting or rejecting every change. Models are optional assistants;
their output is never evidence.

### OpenCode with DeepSeek Free Flash

Use OpenCode and DeepSeek Free Flash for a small, isolated implementation or review
task when that client and model are available. In this checkpoint the `opencode`
command was not found on PATH and the route had not been tested end to end. Check the
current installation and model availability before delegating. Give it a dedicated
branch or a narrowly scoped patch, ask it to preserve the worktree, and review the full
diff locally. Do not provide private application data, credentials, raw captures, or
unredacted hardware reports.

### Local Qwen coding model

The user runs a Qwen coding model locally as the preferred long-context coding
assistant. It is reached through a local OpenAI-compatible endpoint, so the review
wrapper can use it with the settings in "Local configuration" below, pointing
`ASTRAFORGE_MODEL_BASE_URL` at the local server and `ASTRAFORGE_MODEL_ID` at the alias
the local server reports. Do not hard-code a model name or context length; check what
the local server serves. Use only bounded, text-only source excerpts.

OpenCode and the Qwen endpoint are separate routes. Do not assume OpenCode is using
DeepSeek, or that the AstraForge review wrapper is connected to either route, until its
effective provider/model configuration has been checked without printing credentials.
If both are available, assign different, non-overlapping questions and compare each
answer against the local source.

## Local configuration

Set these values in the user environment. Keep the API key out of commands, prompts,
logs, issues, commits, and pull requests.

```powershell
[Environment]::SetEnvironmentVariable('ASTRAFORGE_MODEL_BASE_URL', 'https://provider.example/v1', 'User')
[Environment]::SetEnvironmentVariable('ASTRAFORGE_MODEL_ID', 'coding-model', 'User')
```

Store the provider key under `ASTRAFORGE_MODEL_API_KEY`, or pass a different variable
name with `-ApiKeyEnvironmentVariable`. The script reads the process environment first
and then the current user's environment. It never prints or writes the key.

## Review one bounded task

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tools\Invoke-AstraForgeModelReview.ps1 `
  -Task 'Review descriptor lifetime for concrete use-after-free or synchronization risks.' `
  -InputPath `
    .\third_party\nvidia-3070-VI\crates\victory-gpu\src\descriptor\host.rs, `
    .\third_party\nvidia-3070-VI\crates\victory-gpu\src\descriptor.rs
```

Use `-DryRun` first to inspect the selected filenames and request size without making a
network request. Inputs must be explicit text files. Whole-file inputs are capped at
512 KiB; a file up to 4 MiB is allowed only when an inclusive line range is selected.
Only the selected excerpt is sent, and the complete JSON request is capped below the
endpoint's 1 MiB limit. Generated, cache, credential-like, and private-data paths are
rejected. The default complete-request ceiling is 450 KiB to leave room for model output
inside a large coding context; use separate reviews instead of raising it for unrelated
subsystems.

For a large source file, pass inclusive line windows with `-InputLineRanges` while keeping
the full file on the explicit-input allowlist, so only the selected excerpt is sent:

```powershell
-InputPath .\path\to\host.rs, .\path\to\donor-findings.md `
  -InputLineRanges @{ 'host.rs' = @(1211, 1289) }
```

Use an inclusive comma-separated string when a review needs disjoint sections from one
file, such as a type definition, constructor, and implementation:

```powershell
-InputLineRanges @{ 'shadow.rs' = '27-105,2892-3013,5358-5418' }
```

The default output directory is `%LOCALAPPDATA%\AstraForge\model-reviews`. Treat every
finding as an untrusted hypothesis: trace the full call path, check upstream provenance,
implement only a focused reversible change, and run the validation required by
`AGENTS.md`. A model response is never proof of correctness, visual quality, stability,
or performance.
