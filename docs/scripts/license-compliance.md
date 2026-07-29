---
title: License Compliance
description: A read-only runbook that finds corporate Windows devices whose primary user is missing an Intune or Windows Enterprise licence.
tags:
  - Intune
  - Entra ID
  - Microsoft Graph
  - Azure Automation
---

# License Compliance

Finds every corporate Windows device whose primary user is **missing an Intune and/or Windows
Enterprise licence** — the accounts that look fine at a glance but leave a device unmanaged.
Read-only, Managed Identity, no secrets.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-LicenseComplianceCheck.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-LicenseComplianceCheck.ps1){ .md-button }

## 1 · The script

It authenticates with a Managed Identity, queries Microsoft Graph with GET-only requests
(`managedDevices` → per-user `users` with `$expand=manager` → `licenseDetails`), compares each
user's SKUs against a configurable Intune / Windows-Enterprise entitlement set, resolves friendly
product names, and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script"
    ```powershell
    --8<-- "assets/scripts/Collect-LicenseComplianceCheck.ps1"
    ```

The whole Graph flow — and the Office 365 E3 vs Microsoft 365 E3 trap that makes this report worth
building — is in the **[teardown](../projects/zero-access-agent/collectors/license-compliance.md)**.

## 2 · The Power BI template

[:material-download: License Compliance template](../assets/pbit/license-compliance.pbit){ .md-button }

Open it in free Power BI Desktop, point the query's `Source =` at the synthetic
`Common_account_License.csv`, and it lights up with no tenant access at all.

## 3 · Example report

![License Compliance — example report](../assets/img/license-compliance-report.png)

## Related

- :material-chart-box: **Power BI report** → [License Compliance report](../powerbi/license-compliance-report.md)
- :material-book-open-variant: **How it works (teardown)** → [License Compliance teardown](../projects/zero-access-agent/collectors/license-compliance.md)
