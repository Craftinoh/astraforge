# RTX 3060 hardware report (`host-02`)

Sanitized intake from [`templates/hardware-report.template.md`](templates/hardware-report.template.md). It backs the candidate `nvidia-rtx3060` entry in `profiles/gpu-profiles.json`. It is **not** an AstraForge support or performance claim: no AstraForge build has been run on this machine yet. The runtime observations below come from a different tree (Vice-Tay) and are in [`RTX3060-vice-tay-findings.md`](RTX3060-vice-tay-findings.md).

## Submission

- Anonymous host label: `host-02`
- Date and timezone: 2026-11-27, CET (UTC+1)
- Contribution scope: hardware report + candidate profile
- Source commit/build ID: AstraForge `main` at `8a8bee1` (profiles and docs only; no source build)

## Machine facts

| Property | Observed value | Source / confidence |
|---|---|---|
| GPU model | NVIDIA GeForce RTX 3060 | DXGI `EnumAdapters1` and nvidia-smi |
| GPU vendor ID | `0x10DE` | DXGI |
| GPU device ID | `0x2504` (revision `0xA1`) | DXGI |
| GPU architecture | Ampere GA106, compute capability 8.6 | nvidia-smi capability; die name from the NVIDIA device-ID table |
| Dedicated VRAM | 12,288 MiB (nvidia-smi); 11.83 GiB (DXGI `DedicatedVideoMemory`) | Both queried |
| Shared GPU memory | 15.94 GiB | DXGI |
| Driver version | 621.01 (Windows `32.0.16.2101`) | nvidia-smi / WMI |
| GPU adapter order | RTX 3060 is the first DXGI adapter; second is Microsoft Basic Render Driver | DXGI enumeration |
| PCIe link | Gen 4 x16 (max and current, P3 state) | nvidia-smi; link may drop at idle |
| Resizable BAR | Likely enabled: BAR1 aperture 16,384 MiB ≥ 12,288 MiB framebuffer | Inferred from BAR1 size, not a firmware query |
| CPU model | Intel Core i7-11700F | OS query |
| Physical / logical cores | 8 / 16 | OS query |
| CPU instruction set | AVX2 present | Runtime query |
| RAM installed / effective speed | 32 GiB (2 × 16 GiB) / 3200 MT/s configured | OS query |
| Available RAM / commit | 4.45 GiB / 1 GiB available of 37.91 GiB limit | Measured **while the emulator was running**, so not a preflight value |
| Windows edition/build | Windows 11 Home 26H2, build 26300 | OS query |
| D3D12 feature level | Not read (collector run without `-DxDiagReportPath`) | — |
| Shader model | 6.8 | D3D12 feature query |
| Wave operations / lane range | Supported / 32–32 | D3D12 feature query |
| Other D3D12 tiers | Mesh shader Tier 1, sampler feedback Tier 0.9, raytracing Tier 1.2 | D3D12 feature query |

Collected with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Collect-AstraForgeHardware.ps1 -OutputPath .\out\hardware-latest.json
```

The raw JSON stays in ignored `out/`. Adapter LUIDs, PCI bus IDs, board model and paging-file paths were removed from this report.

## Runtime evidence

None on AstraForge. See the Vice-Tay findings for what was observed on this GPU with another tree, and why those numbers are not AstraForge evidence.

## Conclusions

- Evidence level: `inspected` (hardware query only).
- What this report establishes: the adapter identity, memory and feature values used by the candidate profile, and that the RTX 3060 is the first DXGI adapter, so the renderer's default-adapter device creation picks it.
- What it does not establish: that AstraForge renders, runs or performs on this GPU, or that the RTX 3070 baseline values copied into `rtx3060-profiles.json` are right for 12 GB.
- Note on commit headroom: during emulation the available commit fell to about 1 GiB. The paging file was a few GiB at the time. The launcher's `-MinimumAvailableCommitGiB` (default 12) and the profile's 20 GiB warning are expected to trigger on this machine unless the paging file is enlarged (a fixed size of about 16 GiB was suggested to the owner; not yet applied).
- Reproduction steps: run the collector command above on the target PC.
- Suggested next action: a `Start-AstraForge.ps1 -GpuProfile nvidia-rtx3060 -Profile Stability` preflight, then matched gameplay captures per [`benchmark-procedure.md`](benchmark-procedure.md).

## Privacy review

- [x] No game/application title, publisher, executable name, save ID, or identifying route detail.
- [x] No usernames, machine names, serials, adapter LUIDs, device-instance paths, or personal paths.
- [x] No API keys, credentials, raw logs, ETL, saves, binaries, or cache data.
- [x] GPU and OS observations are separated from inference or user-reported information.
