---
title: Inventory — All Devices — Power BI
description: The Power BI report built on the Inventory — All Devices snapshot.
tags:
  - Intune
  - Power BI
---

# Inventory — All Devices — Power BI report

Built on the read-only snapshot from the **[Inventory — All Devices script](../scripts/inventory-all-devices.md)** — no live tenant connection, just the sanitized CSV.

![Inventory — All Devices report](../assets/img/report-placeholder.svg)

## Download the template

!!! note "`.pbit` goes here"
    Drop `inventory-all-devices.pbit` into `docs/assets/pbit/`, then link it:
    `[:material-download: Download Inventory — All Devices template](../assets/pbit/inventory-all-devices.pbit)`

## How it's wired

The report points at the CSV the collector writes to Blob storage. Because the shaping already happened in the runbook, the Power BI side stays thin: connect to the CSV, refresh, done. Swap the source path for your own container.

## Related

- :material-script-text: **The script** → [Inventory — All Devices](../scripts/inventory-all-devices.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
