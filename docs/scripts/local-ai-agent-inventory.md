---
title: Local AI Agent Inventory
description: Inventories local AI-agent tooling across managed devices — a modern-workspace signal most fleets can't see yet.
tags:
  - Intune
  - Microsoft Graph
---

# Local AI Agent Inventory

Inventories local AI-agent tooling across managed devices — a modern-workspace signal most fleets can't see yet.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-LocalAIAgentInventory.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-LocalAIAgentInventory.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph with GET only, and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script (27 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-LocalAIAgentInventory.ps1"
    ```

## 2 · The Power BI template

!!! note "`.pbit` goes here"
    Drop `local-ai-agent-inventory.pbit` into `docs/assets/pbit/` and swap this note for a download button:
    `[:material-download: Local AI Agent Inventory template](../assets/pbit/local-ai-agent-inventory.pbit)`

## 3 · Example report

![Local AI Agent Inventory — example Power BI report](../assets/img/report-placeholder.svg)

*Replace `report-placeholder.svg` with a screenshot of your own `Local AI Agent Inventory` report.*

## Related

- :material-chart-box: **Power BI report** → [Local AI Agent Inventory report](../powerbi/local-ai-agent-inventory-report.md)
- :material-book-open-variant: **Deep-dive teardown** → [in the Zero-Access Agent project](../projects/zero-access-agent/collectors/local-ai-agent-inventory.md)

