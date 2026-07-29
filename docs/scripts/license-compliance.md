---
title: License Compliance
description: Maps assigned vs consumed licences across the tenant — the report finance and IT both ask for.
tags:
  - Entra ID
  - Microsoft 365
  - Microsoft Graph
---

# License Compliance

Maps assigned vs consumed licences across the tenant — the report finance and IT both ask for.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-LicenseComplianceCheck.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-LicenseComplianceCheck.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script (14 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-LicenseComplianceCheck.ps1"
    ```

## 2 · The Power BI template

!!! note "`.pbit` goes here"
    Drop `license-compliance.pbit` into `docs/assets/pbit/` and swap this note for a download button:
    `[:material-download: License Compliance template](../assets/pbit/license-compliance.pbit)`

## 3 · Example report

![License Compliance — example Power BI report](../assets/img/report-placeholder.svg)

*Replace `report-placeholder.svg` with a screenshot of your own `License Compliance` report.*

## Related

- :material-chart-box: **Power BI report** → [License Compliance report](../powerbi/license-compliance-report.md)
- :material-book-open-variant: **Deep-dive teardown** → [in the Zero-Access Agent project](../projects/zero-access-agent/collectors/license-compliance.md)

