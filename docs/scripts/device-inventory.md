---
title: Device Inventory
description: The simplest end-to-end collector — a clean starting point to learn the read-only pattern before the bigger ones.
tags:
  - Intune
  - Microsoft Graph
  - Azure Automation
---

# Device Inventory

The simplest end-to-end collector — a clean starting point to learn the read-only pattern before the bigger ones.

!!! tip "This page is the template"
    Every script in the library follows this shape: **the script → the `.pbit` → an example report screenshot**, plus tags and cross-links. Use it as the model for the rest.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-DeviceInventory.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-DeviceInventory.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

```powershell
--8<-- "assets/scripts/Collect-DeviceInventory.ps1"
```

## 2 · The Power BI template

!!! note "`.pbit` goes here"
    Drop `device-inventory.pbit` into `docs/assets/pbit/` and swap this note for a download button:
    `[:material-download: Device Inventory template](../assets/pbit/device-inventory.pbit)`

## 3 · Example report

![Device Inventory — example Power BI report](../assets/img/report-placeholder.svg)

*Replace `report-placeholder.svg` with a screenshot of your own `Device Inventory` report.*

## Related

- :material-chart-box: **Power BI report** → [Device Inventory report](../powerbi/device-inventory-report.md)

