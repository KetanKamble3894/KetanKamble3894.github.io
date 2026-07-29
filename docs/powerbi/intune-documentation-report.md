---
title: Intune Documentation — Power BI
description: The Power BI report built on the Intune Documentation snapshot.
tags:
  - Intune
  - Power BI
---

# Intune Documentation — Power BI report

Built on the read-only snapshot from the **[Intune Documentation script](../scripts/intune-documentation.md)** — no live tenant connection, just the sanitized CSV.

![Intune Documentation report](../assets/img/report-placeholder.svg)

## Download the template

!!! note "`.pbit` goes here"
    Drop `intune-documentation.pbit` into `docs/assets/pbit/`, then link it:
    `[:material-download: Download Intune Documentation template](../assets/pbit/intune-documentation.pbit)`

## How it's wired

The report points at the CSV the collector writes to Blob storage. Because the shaping already happened in the runbook, the Power BI side stays thin: connect to the CSV, refresh, done. Swap the source path for your own container.

## Related

- :material-script-text: **The script** → [Intune Documentation](../scripts/intune-documentation.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
