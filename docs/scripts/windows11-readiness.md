---
title: Windows 11 Readiness
description: Per-device Windows 11 hardware readiness — the exact failing check, joined to make and model.
tags:
  - Intune
  - Microsoft Graph
  - Power BI
---

# Windows 11 Readiness

Per-device Windows 11 hardware readiness — the exact failing check, joined to make and model.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-Windows11Readiness.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-Windows11Readiness.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph read-only (`.Read.All` scopes), and writes a sanitized CSV snapshot. Set the CONFIG values at the top, then run.

??? example "View the full script (17 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-Windows11Readiness.ps1"
    ```

## 2 · The Power BI template

[:material-download: Windows 11 Readiness template (.pbit)](../assets/pbit/windows11-readiness.pbit){ .md-button .md-button--primary }

Opens to a **pre-built report** — KPI cards, charts, a detail table and slicers, already wired. On open it prompts for your **Storage account / container / file**, then loads from Blob. Full details on the **[report page](../powerbi/windows11-readiness-report.md)**.

## 3 · Example report

![Windows 11 Readiness — example report (synthetic lab data)](../assets/img/windows11-readiness-report.png){ .kk-zoom }

*Built on synthetic `@contoso.com` data. Point the template at your own snapshot to see your fleet.*

## Related

- :material-book-open-variant: **The story** → [Which devices can't take Windows 11](../blog/posts/windows11-readiness.md)
- :material-chart-box: **Power BI report** → [Windows 11 Readiness report](../powerbi/windows11-readiness-report.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
