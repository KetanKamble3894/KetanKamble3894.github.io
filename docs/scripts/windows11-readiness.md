---
title: Windows 11 Readiness
description: Hardware-readiness across the estate — TPM, CPU, RAM — so the Windows 11 plan is grounded in data.
tags:
  - Intune
  - Windows / Autopilot
  - Microsoft Graph
---

# Windows 11 Readiness

Hardware-readiness across the estate — TPM, CPU, RAM — so the Windows 11 plan is grounded in data.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-Windows11Readiness.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-Windows11Readiness.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script (17 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-Windows11Readiness.ps1"
    ```

## 2 · The Power BI template

!!! note "`.pbit` goes here"
    Drop `windows11-readiness.pbit` into `docs/assets/pbit/` and swap this note for a download button:
    `[:material-download: Windows 11 Readiness template](../assets/pbit/windows11-readiness.pbit)`

## 3 · Example report

![Windows 11 Readiness — example Power BI report](../assets/img/report-placeholder.svg)

*Replace `report-placeholder.svg` with a screenshot of your own `Windows 11 Readiness` report.*

## Related

- :material-chart-box: **Power BI report** → [Windows 11 Readiness report](../powerbi/windows11-readiness-report.md)
- :material-book-open-variant: **Deep-dive teardown** → [in the Zero-Access Agent project](../projects/zero-access-agent/collectors/windows11-readiness.md)

