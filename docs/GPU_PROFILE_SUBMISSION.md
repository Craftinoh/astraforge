# GPU profile and hardware submission

Use this process when a contributor wants AstraForge reviewed on a different GPU or PC. It separates machine discovery from runtime support: a report can be useful even when the GPU is not yet implemented.

## 1. Submit a sanitized hardware report

Copy [`templates/hardware-report.template.md`](templates/hardware-report.template.md). Provide exact GPU/CPU/OS/driver values when available and mark unknown fields `unknown`; do not infer them from a product family. Do not publish serial numbers, Windows usernames, machine names, adapter LUIDs, full DXDiag output, device instance paths, or personal directories.

The local collector is:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Collect-AstraForgeHardware.ps1 `
  -OutputPath .\out\hardware-latest.json `
  -DxDiagReportPath .\out\dxdiag-latest.txt
```

It writes a raw report below ignored `out/`. Review and manually sanitize it before sharing. Check `git status --short` and the final diff so a raw report cannot be accidentally staged.

Useful observations include:

- GPU name, vendor/device ID, architecture, dedicated-memory capacity, driver version, and whether the device is the first DXGI adapter.
- D3D12 feature level, shader model, wave operations and lane range, and other features actually queried by the collector.
- CPU model, physical/logical cores, instruction sets, installed/available RAM and commit headroom.
- Windows edition/build, PCIe link when available, and ReBAR only when directly reported. Distinguish detected facts from user-reported values and inference.
- Whether the game reaches a repeatable gameplay scene; no title, executable name, personal route, save ID, or path is needed in a public report.

## 2. Decide what the contribution is

Choose one scope and keep it separate:

1. **Hardware report:** add sanitized machine information to an issue or local test record. No source support claim.
2. **New candidate profile:** add identity/preflight metadata only after validating every manifest field and its consumer. Mark it candidate and unbenchmarked.
3. **Newly supported adapter:** implement adapter selection, required D3D12 checks, telemetry and runtime path, tests, and documented rollback; verify on the exact target hardware.
4. **Runtime preset:** use only settings present in the source, trace their accepted values/defaults/consumers, and compare matched runs on the same system.

Do not turn a hardware report into an enabled profile by changing JSON alone. The current source creates the device from the first DXGI adapter, so another GPU cannot be selected merely by adding its ID to `profiles/gpu-profiles.json`.

## 3. Profile contract

Before editing `profiles/gpu-profiles.json`, verify each proposed field against `tools/Start-AstraForge.ps1`, `tools/Collect-AstraForgeHardware.ps1`, and the renderer's device creation/feature queries.

| Field | Meaning | Required evidence |
|---|---|---|
| `provider` | Vendor family identifier used by tooling | Vendor/device identity and an implemented telemetry path |
| `vendorId`, `deviceIds` | PCI vendor/device IDs accepted by preflight | Local DXGI/PCI query; no marketing-name guess |
| `nameRegex` | Adapter name check used by current launcher | Exact observed Windows adapter name |
| `architecture`, `computeCapability` | Descriptive architecture/capability | Primary vendor source or driver query; omit/mark unsupported if not consumed |
| `dedicatedMemoryMiB` | Adapter dedicated memory used by preflight | DXGI query, not box specification alone |
| `shaderModelMinimum`, wave fields | Minimum shader/wave feature requirements | D3D12 feature query on the target driver |
| `consoleDefault` | Default compatibility target | Tested source/runtime path, not a performance assumption |
| `adapterSelection` | How the device is chosen | Must describe actual renderer code; currently first DXGI adapter |
| `telemetryProvider` | GPU monitoring backend used by scripts | Must be available and verified on the target |
| tuning config | Runtime settings file and values | Every variable/value audited in source; no inherited assumptions |

Only add fields that the schema consumer understands. Do not make up an environment variable because another fork or model mentions it.

## 4. Validation gate

- Parse the manifest and run the PowerShell parser checks for changed scripts.
- Run the profile preflight on the exact target and confirm the selected adapter is the one intended.
- Build with the repository-pinned toolchain. Run focused tests plus the relevant workspace tests for source changes.
- Exercise cold and warm cache behavior; monitor dedicated/shared GPU memory, commit, frametime, driver errors/device loss, and missing textures.
- For performance claims, capture at least three matched 600-second gameplay runs per cohort using the same route, output/internal resolution evidence, cache state, build and driver. Follow `docs/benchmark-procedure.md` and use its comparator.
- Review images for black frames, lighting, texture corruption, temporal instability, and other visual regressions. A synthetic test or a successful launch does not establish this gate.
- Record unsupported checks and unresolved risks. Do not claim support or a gain if the hardware was unavailable.

## 5. Keep contributor reports safe

Public reports should include an anonymous machine alias (`host-01`), GPU/CPU class, OS/driver, build/source hash, anonymous scene alias, measurement method, aggregate metrics, and caveats. Keep serial/device instance data, account names, precise local paths, raw ETL/CSV/logs, game identifiers, and saves local. Use the allowlisted exporter for benchmark output and inspect every artifact before upload.

Update the profile manifest, relevant docs, source-credit ledger, `LOCAL-CHANGES.md`, progress journal, and rollback instructions together when a source/profile feature is accepted.
