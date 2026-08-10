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

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph read-only (`.Read.All` scopes), and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script (26 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-InventoryAllDevices.ps1"
    ```

## 2 · The Power BI template

[:material-download: Inventory — All Devices template (.pbit)](../assets/pbit/inventory-all-devices.pbit){ .md-button .md-button--primary }

Carries the parameterised CSV connection, the full schema, and every DAX measure. Full Power Query,
DAX and visual layout live on the **[report page](../powerbi/inventory-all-devices-report.md)**.

## 3 · Example report

![Inventory — All Devices — example Power BI report (synthetic lab data)](../assets/img/inventory-all-devices-report.png){ .kk-zoom }

*Built on synthetic `@contoso.com` data. Point the template at your own snapshot to see your fleet.*

## Related

- :material-chart-box: **Power BI report** → [Inventory — All Devices report](../powerbi/inventory-all-devices-report.md)
- :material-book-open-variant: **Deep-dive teardown** → [in the Zero-Access Agent project](../projects/zero-access-agent/collectors/inventory-all-devices.md)

