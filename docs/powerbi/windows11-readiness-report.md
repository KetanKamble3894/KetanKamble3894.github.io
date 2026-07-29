---
title: Windows 11 Readiness — Power BI
description: The Power BI report built on the Windows 11 Readiness snapshot.
tags:
  - Intune
  - Windows / Autopilot
  - Power BI
---

# Windows 11 Readiness — Power BI report

Built on the read-only snapshot from the **[Windows 11 Readiness script](../scripts/windows11-readiness.md)** — no live tenant connection, just the sanitized CSV.

![Windows 11 Readiness report](../assets/img/report-placeholder.svg)

## Download the template

!!! note "`.pbit` goes here"
    Drop `windows11-readiness.pbit` into `docs/assets/pbit/`, then link it:
    `[:material-download: Download Windows 11 Readiness template](../assets/pbit/windows11-readiness.pbit)`

## How it's wired

The report points at the CSV the collector writes to Blob storage. Because the shaping already happened in the runbook, the Power BI side stays thin: connect to the CSV, refresh, done. Swap the source path for your own container.

## Related

- :material-script-text: **The script** → [Windows 11 Readiness](../scripts/windows11-readiness.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
