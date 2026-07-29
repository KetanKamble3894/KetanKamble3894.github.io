---
title: Policy Assignments
description: Resolves which policies land on which groups, so 'why did this device get that setting?' has an answer.
tags:
  - Intune
  - Microsoft Graph
---

# Policy Assignments

Resolves which policies land on which groups, so 'why did this device get that setting?' has an answer.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-PolicyAssignments.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-PolicyAssignments.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script (26 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-PolicyAssignments.ps1"
    ```

## 2 · The Power BI template

!!! note "`.pbit` goes here"
    Drop `policy-assignments.pbit` into `docs/assets/pbit/` and swap this note for a download button:
    `[:material-download: Policy Assignments template](../assets/pbit/policy-assignments.pbit)`

## 3 · Example report

![Policy Assignments — example Power BI report](../assets/img/report-placeholder.svg)

*Replace `report-placeholder.svg` with a screenshot of your own `Policy Assignments` report.*

## Related

- :material-chart-box: **Power BI report** → [Policy Assignments report](../powerbi/policy-assignments-report.md)
- :material-book-open-variant: **Deep-dive teardown** → [in the Zero-Access Agent project](../projects/zero-access-agent/collectors/policy-assignments.md)

