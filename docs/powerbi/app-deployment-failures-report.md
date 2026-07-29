---
title: App Deployment Failures — Power BI
description: The Power BI report built on the App Deployment Failures snapshot.
tags:
  - Intune
  - Power BI
---

# App Deployment Failures — Power BI report

Built on the read-only snapshot from the **[App Deployment Failures script](../scripts/app-deployment-failures.md)** — no live tenant connection, just the sanitized CSV.

![App Deployment Failures report](../assets/img/report-placeholder.svg)

## Download the template

!!! note "`.pbit` goes here"
    Drop `app-deployment-failures.pbit` into `docs/assets/pbit/`, then link it:
    `[:material-download: Download App Deployment Failures template](../assets/pbit/app-deployment-failures.pbit)`

## How it's wired

The report points at the CSV the collector writes to Blob storage. Because the shaping already happened in the runbook, the Power BI side stays thin: connect to the CSV, refresh, done. Swap the source path for your own container.

## Related

- :material-script-text: **The script** → [App Deployment Failures](../scripts/app-deployment-failures.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
