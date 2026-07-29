---
title: Policy Assignments — Power BI
description: The Power BI report built on the Policy Assignments snapshot.
tags:
  - Intune
  - Power BI
---

# Policy Assignments — Power BI report

Built on the read-only snapshot from the **[Policy Assignments script](../scripts/policy-assignments.md)** — no live tenant connection, just the sanitized CSV.

![Policy Assignments report](../assets/img/report-placeholder.svg)

## Download the template

!!! note "`.pbit` goes here"
    Drop `policy-assignments.pbit` into `docs/assets/pbit/`, then link it:
    `[:material-download: Download Policy Assignments template](../assets/pbit/policy-assignments.pbit)`

## How it's wired

The report points at the CSV the collector writes to Blob storage. Because the shaping already happened in the runbook, the Power BI side stays thin: connect to the CSV, refresh, done. Swap the source path for your own container.

## Related

- :material-script-text: **The script** → [Policy Assignments](../scripts/policy-assignments.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
