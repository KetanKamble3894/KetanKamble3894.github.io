---
title: Autopilot Operations
description: Autopilot / ESP deployments classified by phase, failure category and cause — per deployment.
tags:
  - Intune
  - Microsoft Graph
  - Power BI
---

# Autopilot Operations

Autopilot / ESP deployments classified by phase, failure category and cause — per deployment.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-AutopilotOperations.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-AutopilotOperations.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the CONFIG values at the top, then run.

??? example "View the full script (68 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-AutopilotOperations.ps1"
    ```

## 2 · The Power BI template

[:material-download: Autopilot Operations template (.pbit)](../assets/pbit/autopilot-operations.pbit){ .md-button .md-button--primary }

Opens to a **pre-built report** — KPI cards, charts, a detail table and slicers, already wired. On open it prompts for your **Storage account / container / file**, then loads from Blob. Full details on the **[report page](../powerbi/autopilot-operations-report.md)**.

## 3 · Example report

![Autopilot Operations — example report (synthetic lab data)](../assets/img/autopilot-operations-report.png){ .kk-zoom }

*Built on synthetic `@contoso.com` data. Point the template at your own snapshot to see your fleet.*

## Related

- :material-book-open-variant: **The story** → [Where Autopilot actually breaks](../blog/posts/autopilot-operations.md)
- :material-chart-box: **Power BI report** → [Autopilot Operations report](../powerbi/autopilot-operations-report.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
