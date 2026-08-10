---
title: Device Hygiene
description: Stale, orphaned and inactive devices — each with a recommended action and an owner team.
tags:
  - Intune
  - Microsoft Graph
  - Power BI
---

# Device Hygiene

Stale, orphaned and inactive devices — each with a recommended action and an owner team.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-DeviceHygiene.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-DeviceHygiene.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph read-only (`.Read.All` scopes), and writes a sanitized CSV snapshot. Set the CONFIG values at the top, then run.

??? example "View the full script (33 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-DeviceHygiene.ps1"
    ```

## 2 · The Power BI template

[:material-download: Device Hygiene template (.pbit)](../assets/pbit/device-hygiene.pbit){ .md-button .md-button--primary }

Opens to a **pre-built report** — KPI cards, charts, a detail table and slicers, already wired. On open it prompts for your **Storage account / container / file**, then loads from Blob. Full details on the **[report page](../powerbi/device-hygiene-report.md)**.

## 3 · Example report

![Device Hygiene — example report (synthetic lab data)](../assets/img/device-hygiene-report.png){ .kk-zoom }

*Built on synthetic `@contoso.com` data. Point the template at your own snapshot to see your fleet.*

## Related

- :material-book-open-variant: **The story** → [The devices no one owns anymore](../blog/posts/device-hygiene.md)
- :material-chart-box: **Power BI report** → [Device Hygiene report](../powerbi/device-hygiene-report.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
