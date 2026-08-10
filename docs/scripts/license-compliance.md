---
title: License Compliance
description: Corporate Windows devices whose primary user is missing an Intune and/or Windows Enterprise licence.
tags:
  - Intune
  - Microsoft Graph
  - Power BI
---

# License Compliance

Corporate Windows devices whose primary user is missing an Intune and/or Windows Enterprise licence.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-LicenseComplianceCheck.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-LicenseComplianceCheck.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph read-only (`.Read.All` scopes), and writes a sanitized CSV snapshot. Set the CONFIG values at the top, then run.

??? example "View the full script (14 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-LicenseComplianceCheck.ps1"
    ```

## 2 · The Power BI template

[:material-download: License Compliance template (.pbit)](../assets/pbit/license-compliance.pbit){ .md-button .md-button--primary }

Opens to a **pre-built report** — KPI cards, charts, a detail table and slicers, already wired. On open it prompts for your **Storage account / container / file**, then loads from Blob. Full details on the **[report page](../powerbi/license-compliance-report.md)**.

## 3 · Example report

![License Compliance — example report (synthetic lab data)](../assets/img/license-compliance-report.png){ .kk-zoom }

*Built on synthetic `@contoso.com` data. Point the template at your own snapshot to see your fleet.*

## Related

- :material-book-open-variant: **The story** → [Who's missing an Intune license](../blog/posts/license-compliance.md)
- :material-chart-box: **Power BI report** → [License Compliance report](../powerbi/license-compliance-report.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
