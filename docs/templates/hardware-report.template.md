# Hardware validation intake

Copy this file for a local test. Replace unknown values only with observations. Before sharing, remove identifying details and verify the rendered Markdown and Git diff.

## Submission

- Anonymous host label: `host-01`
- Contributor alias (optional):
- Date and timezone:
- Contribution scope: `hardware report | candidate profile | adapter support | runtime tuning | bug report`
- Source commit/build ID:

## Machine facts

| Property | Observed value | Source / confidence |
|---|---|---|
| GPU model | unknown | DXGI / user-reported / other |
| GPU vendor ID | unknown | DXGI |
| GPU device ID | unknown | DXGI |
| GPU architecture | unknown | vendor documentation / query / unknown |
| Dedicated VRAM | unknown | DXGI-reported budget/capacity, distinguish both |
| Shared GPU memory | unknown | OS query |
| Driver version | unknown | vendor tool / device manager |
| GPU adapter order | unknown | DXGI enumeration |
| PCIe link | unknown | telemetry query; load state may affect negotiated link |
| Resizable BAR | unknown | directly queried / inferred / user-reported |
| CPU model | unknown | OS query |
| Physical / logical cores | unknown / unknown | OS query |
| CPU instruction set | unknown | runtime query |
| RAM installed / effective speed | unknown / unknown | OS query / user-reported |
| Available RAM / commit | unknown / unknown | measured at capture time |
| Windows edition/build | unknown | OS query |
| D3D12 feature level | unknown | feature query |
| Shader model | unknown | feature query |
| Wave operations / lane range | unknown | feature query |

## Runtime evidence (leave blank until collected)

- Compatibility target/profile:
- Runtime preset and exact source settings:
- Internal resolution and evidence used to verify it:
- Output resolution:
- Scenario alias (`scene-01`):
- Cache state (`cold` or `warm`):
- Run duration and repetitions:
- Application-frame classification available: `yes | no`
- Median FPS / 1% low / 0.1% low:
- Frametime mean / p95 / p99:
- Dedicated/shared GPU memory peak:
- RAM / commit peak:
- Device-loss, TDR, DXGI/D3D12 errors:
- Visual review outcome:
- Raw evidence retained locally at (do not share path):

## Conclusions

- Evidence level: `inspected | parsed | built | unit-tested | hardware-validated | performance-validated`
- What this report establishes:
- What it does not establish:
- Reproduction steps:
- Suggested next action:

## Privacy review

- [ ] No game/application title, publisher, executable name, save ID, or identifying route detail.
- [ ] No usernames, machine names, serials, adapter LUIDs, device-instance paths, or personal paths.
- [ ] No API keys, credentials, raw logs, ETL, saves, binaries, or cache data.
- [ ] GPU and OS observations are separated from inference or user-reported information.
