---
title: Device Hygiene — Power BI
description: The Power BI report built on the Device Hygiene snapshot.
tags:
  - Intune
  - Defender / Security
  - Power BI
---

# Device Hygiene — Power BI report

Built on the read-only snapshot from the **[Device Hygiene script](../scripts/device-hygiene.md)** — no live tenant connection, just the sanitized CSV.

![Device Hygiene report](../assets/img/report-placeholder.svg)

## Download the template

!!! note "`.pbit` goes here"
    Drop `device-hygiene.pbit` into `docs/assets/pbit/`, then link it:
    `[:material-download: Download Device Hygiene template](../assets/pbit/device-hygiene.pbit)`

## How it's wired

The report points at the CSV the collector writes to Blob storage. Because the shaping already happened in the runbook, the Power BI side stays thin: connect to the CSV, refresh, done. Swap the source path for your own container.

## Related

- :material-script-text: **The script** → [Device Hygiene](../scripts/device-hygiene.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
