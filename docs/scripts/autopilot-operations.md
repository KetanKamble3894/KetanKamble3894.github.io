---
title: Autopilot Operations
description: Autopilot registrations, profiles and deployment health — the enrolment funnel, made visible.
tags:
  - Windows / Autopilot
  - Intune
  - Microsoft Graph
---

# Autopilot Operations

Autopilot registrations, profiles and deployment health — the enrolment funnel, made visible.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-AutopilotOperations.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-AutopilotOperations.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script (68 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-AutopilotOperations.ps1"
    ```

## 2 · The Power BI template

!!! note "`.pbit` goes here"
    Drop `autopilot-operations.pbit` into `docs/assets/pbit/` and swap this note for a download button:
    `[:material-download: Autopilot Operations template](../assets/pbit/autopilot-operations.pbit)`

## 3 · Example report

![Autopilot Operations — example Power BI report](../assets/img/report-placeholder.svg)

*Replace `report-placeholder.svg` with a screenshot of your own `Autopilot Operations` report.*

## Related

- :material-chart-box: **Power BI report** → [Autopilot Operations report](../powerbi/autopilot-operations-report.md)
- :material-book-open-variant: **Deep-dive teardown** → [in the Zero-Access Agent project](../projects/zero-access-agent/collectors/autopilot-operations.md)

