---
title: Device Inventory — Power BI
description: The Power BI report built on the Device Inventory snapshot.
tags:
  - Intune
  - Power BI
---

# Device Inventory — Power BI report

Built on the read-only snapshot from the **[Device Inventory script](../scripts/device-inventory.md)** — no live tenant connection, just the sanitized CSV.

![Device Inventory report](../assets/img/report-placeholder.svg)

## Download the template

!!! note "`.pbit` goes here"
    Drop `device-inventory.pbit` into `docs/assets/pbit/`, then link it:
    `[:material-download: Download Device Inventory template](../assets/pbit/device-inventory.pbit)`

## How it's wired

The report points at the CSV the collector writes to Blob storage. Because the shaping already happened in the runbook, the Power BI side stays thin: connect to the CSV, refresh, done. Swap the source path for your own container.

## Related

- :material-script-text: **The script** → [Device Inventory](../scripts/device-inventory.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
