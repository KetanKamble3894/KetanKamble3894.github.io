---
title: App Deployment Failures
description: Surfaces app installs that failed and where, so remediation targets the real devices, not the whole ring.
tags:
  - Intune
  - Microsoft Graph
---

# App Deployment Failures

Surfaces app installs that failed and where, so remediation targets the real devices, not the whole ring.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-AppDeploymentFailures.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-AppDeploymentFailures.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script (57 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-AppDeploymentFailures.ps1"
    ```

## 2 · The Power BI template

!!! note "`.pbit` goes here"
    Drop `app-deployment-failures.pbit` into `docs/assets/pbit/` and swap this note for a download button:
    `[:material-download: App Deployment Failures template](../assets/pbit/app-deployment-failures.pbit)`

## 3 · Example report

![App Deployment Failures — example Power BI report](../assets/img/report-placeholder.svg)

*Replace `report-placeholder.svg` with a screenshot of your own `App Deployment Failures` report.*

## Related

- :material-chart-box: **Power BI report** → [App Deployment Failures report](../powerbi/app-deployment-failures-report.md)
- :material-book-open-variant: **Deep-dive teardown** → [in the Zero-Access Agent project](../projects/zero-access-agent/collectors/app-deployment-failures.md)

