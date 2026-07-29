---
title: Non-Compliant Devices
description: A read-only runbook that finds every non-compliant Windows device and the exact settings that failed.
tags:
  - Intune
  - Microsoft Graph
  - Defender / Security
  - Azure Automation
---

# Non-Compliant Devices

Finds every non-compliant Windows device and — the part the portal won't hand you as data — the
**exact settings** that failed, across which policies. Read-only, Managed Identity, no secrets.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-NonCompliantDevices.ps1){ .md-button .md-button--primary }

## 1 · The script

It authenticates with a Managed Identity, queries Microsoft Graph with GET-only requests
(`managedDevices` → `deviceCompliancePolicyStates` → `settingStates`), enriches with per-user context,
and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script"
    ```powershell
    --8<-- "assets/scripts/Collect-NonCompliantDevices.ps1"
    ```

## 2 · The Power BI template

[:material-download: Non-Compliant Devices template](../assets/pbit/noncompliant-devices.pbit){ .md-button }

## 3 · Example report

![Non-Compliant Windows Devices — example report](../assets/img/noncompliant-report.png)

## Related

- :material-chart-box: **Power BI report** → [Non-Compliant Devices report](../powerbi/noncompliant-devices-report.md)
- :material-book-open-variant: **How it works (teardown)** → [Non-Compliant Devices teardown](../projects/zero-access-agent/collectors/noncompliant-devices.md)
