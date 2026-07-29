---
title: Inventory — All Devices
description: Full managed-device inventory across the fleet — the backbone dataset every other report leans on.
tags:
  - Intune
  - Microsoft Graph
  - Azure Automation
---

# Inventory — All Devices

Full managed-device inventory across the fleet — the backbone dataset every other report leans on.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-InventoryAllDevices.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-InventoryAllDevices.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script (26 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-InventoryAllDevices.ps1"
    ```

## 2 · The Power BI template

!!! note "`.pbit` goes here"
    Drop `inventory-all-devices.pbit` into `docs/assets/pbit/` and swap this note for a download button:
    `[:material-download: Inventory — All Devices template](../assets/pbit/inventory-all-devices.pbit)`

## 3 · Example report

![Inventory — All Devices — example Power BI report](../assets/img/report-placeholder.svg)

*Replace `report-placeholder.svg` with a screenshot of your own `Inventory — All Devices` report.*

## Related

- :material-chart-box: **Power BI report** → [Inventory — All Devices report](../powerbi/inventory-all-devices-report.md)
- :material-book-open-variant: **Deep-dive teardown** → [in the Zero-Access Agent project](../projects/zero-access-agent/collectors/inventory-all-devices.md)

