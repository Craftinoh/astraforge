# Model-assisted review orchestration

AstraForge can send a bounded, read-only source review to any text-only,
OpenAI-compatible Chat Completions endpoint. The model never edits the checkout and its
answer is stored outside Git for independent review.

## Local configuration

Set these values in the user environment. Keep the API key out of commands, prompts,
logs, issues, commits, and pull requests.

```powershell
[Environment]::SetEnvironmentVariable('ASTRAFORGE_MODEL_BASE_URL', 'https://provider.example/v1', 'User')
[Environment]::SetEnvironmentVariable('ASTRAFORGE_MODEL_ID', 'coding-model', 'User')
```

Store the provider key under `INGENIUM_API_KEY`, or pass a different variable name with
`-ApiKeyEnvironmentVariable`. The script reads the process environment first and then
the current user's environment. It never prints or writes the key.

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
network request. Inputs must be explicit text files, are capped at 512 KiB each, and the
complete JSON request is capped below the provider's 1 MiB limit. Generated, cache,
credential-like, and private-data paths are rejected. The default complete-request
ceiling is 450 KiB to leave room for model output inside a large coding context; use
separate reviews instead of raising it for unrelated subsystems.

The default output directory is `%LOCALAPPDATA%\AstraForge\model-reviews`. Treat every
finding as an untrusted hypothesis: trace the full call path, check upstream provenance,
implement only a focused reversible change, and run the validation required by
`AGENTS.md`. A model response is never proof of correctness, visual quality, stability,
or performance.
