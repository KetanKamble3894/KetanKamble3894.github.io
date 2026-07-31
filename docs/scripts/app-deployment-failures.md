---
title: App Deployment Failures
description: Every Intune app failure rolled up per app — failed vs targeted, a rate, and a triage category.
tags:
  - Intune
  - Microsoft Graph
  - Power BI
---

# App Deployment Failures

Every Intune app failure rolled up per app — failed vs targeted, a rate, and a triage category.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-AppDeploymentFailures.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-AppDeploymentFailures.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the CONFIG values at the top, then run.

??? example "View the full script (57 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-AppDeploymentFailures.ps1"
    ```

## 2 · The Power BI template

[:material-download: App Deployment Failures template (.pbit)](../assets/pbit/app-deployment-failures.pbit){ .md-button .md-button--primary }

Opens to a **pre-built report** — KPI cards, charts, a detail table and slicers, already wired. On open it prompts for your **Storage account / container / file**, then loads from Blob. Full details on the **[report page](../powerbi/app-deployment-failures-report.md)**.

## 3 · Example report

![App Deployment Failures — example report (synthetic lab data)](../assets/img/app-deployment-failures-report.png){ .kk-zoom }

*Built on synthetic `@contoso.com` data. Point the template at your own snapshot to see your fleet.*

## Related

- :material-book-open-variant: **The story** → [Which app is failing, and why](../blog/posts/app-deployment-failures.md)
- :material-chart-box: **Power BI report** → [App Deployment Failures report](../powerbi/app-deployment-failures-report.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
