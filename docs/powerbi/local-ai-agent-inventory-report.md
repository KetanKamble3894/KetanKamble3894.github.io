---
title: Local AI Agent Inventory — Power BI
description: The Power BI report built on the Local AI Agent Inventory snapshot.
tags:
  - Intune
  - Power BI
---

# Local AI Agent Inventory — Power BI report

Built on the read-only snapshot from the **[Local AI Agent Inventory script](../scripts/local-ai-agent-inventory.md)** — no live tenant connection, just the sanitized CSV.

![Local AI Agent Inventory report](../assets/img/report-placeholder.svg)

## Download the template

!!! note "`.pbit` goes here"
    Drop `local-ai-agent-inventory.pbit` into `docs/assets/pbit/`, then link it:
    `[:material-download: Download Local AI Agent Inventory template](../assets/pbit/local-ai-agent-inventory.pbit)`

## How it's wired

The report points at the CSV the collector writes to Blob storage. Because the shaping already happened in the runbook, the Power BI side stays thin: connect to the CSV, refresh, done. Swap the source path for your own container.

## Related

- :material-script-text: **The script** → [Local AI Agent Inventory](../scripts/local-ai-agent-inventory.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
