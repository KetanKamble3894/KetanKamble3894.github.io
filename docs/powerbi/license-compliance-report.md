---
title: License Compliance — Power BI
description: The Power BI report built on the License Compliance snapshot.
tags:
  - Entra ID
  - Microsoft 365
  - Power BI
---

# License Compliance — Power BI report

Built on the read-only snapshot from the **[License Compliance script](../scripts/license-compliance.md)** — no live tenant connection, just the sanitized CSV.

![License Compliance report](../assets/img/report-placeholder.svg)

## Download the template

!!! note "`.pbit` goes here"
    Drop `license-compliance.pbit` into `docs/assets/pbit/`, then link it:
    `[:material-download: Download License Compliance template](../assets/pbit/license-compliance.pbit)`

## How it's wired

The report points at the CSV the collector writes to Blob storage. Because the shaping already happened in the runbook, the Power BI side stays thin: connect to the CSV, refresh, done. Swap the source path for your own container.

## Related

- :material-script-text: **The script** → [License Compliance](../scripts/license-compliance.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
