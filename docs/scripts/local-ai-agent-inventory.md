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

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph read-only (`.Read.All` scopes), and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

??? example "View the full script (27 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-LocalAIAgentInventory.ps1"
    ```

## 2 · The Power BI template

[:material-download: Local AI Agent Inventory template (.pbit)](../assets/pbit/local-ai-agent-inventory.pbit){ .md-button .md-button--primary }

Carries the parameterised CSV connection, the full schema, and the governance DAX measures. Full
Power Query, DAX and layout live on the **[report page](../powerbi/local-ai-agent-inventory-report.md)**.

## 3 · Example report

![Local AI Agent Inventory — example shadow-AI governance report (synthetic lab data)](../assets/img/local-ai-agent-inventory-report.png){ .kk-zoom }

*Built on synthetic `@contoso.com` data — 140 devices, 84 carrying unsanctioned AI.*

## Related

- :material-chart-box: **Power BI report** → [Local AI Agent Inventory report](../powerbi/local-ai-agent-inventory-report.md)
- :material-book-open-variant: **Deep-dive teardown** → [in the Zero-Access Agent project](../projects/zero-access-agent/collectors/local-ai-agent-inventory.md)

