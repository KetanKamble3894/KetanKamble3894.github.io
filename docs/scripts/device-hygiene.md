---
title: Device Hygiene
description: Compliance, encryption, stale check-ins and the small signals that separate a healthy fleet from a drifting one.
tags:
  - Intune
  - Defender / Security
  - Microsoft Graph
---

# Device Hygiene

Compliance, encryption, stale check-ins and the small signals that separate a healthy fleet from a drifting one.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-DeviceHygiene.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-DeviceHygiene.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script (33 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-DeviceHygiene.ps1"
    ```

## 2 · The Power BI template

!!! note "`.pbit` goes here"
    Drop `device-hygiene.pbit` into `docs/assets/pbit/` and swap this note for a download button:
    `[:material-download: Device Hygiene template](../assets/pbit/device-hygiene.pbit)`

## 3 · Example report

![Device Hygiene — example Power BI report](../assets/img/report-placeholder.svg)

*Replace `report-placeholder.svg` with a screenshot of your own `Device Hygiene` report.*

## Related

- :material-chart-box: **Power BI report** → [Device Hygiene report](../powerbi/device-hygiene-report.md)
- :material-book-open-variant: **Deep-dive teardown** → [in the Zero-Access Agent project](../projects/zero-access-agent/collectors/device-hygiene.md)

