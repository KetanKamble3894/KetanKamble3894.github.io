---
title: Synthetic Fleet Generator
description: Generates fake-but-realistic fleet CSVs — duplicates, missing values, reimaged serials — so you can run everything with no tenant.
tags:
  - Azure Automation
---

# Synthetic Fleet Generator

Generates fake-but-realistic fleet CSVs — duplicates, missing values, reimaged serials — so you can run everything with no tenant.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/New-SyntheticFleet.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/New-SyntheticFleet.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, calls Microsoft Graph read-only (`.Read.All` scopes), and writes a sanitized CSV snapshot. Set the three CONFIG values at the top, then run.

```powershell
--8<-- "assets/scripts/New-SyntheticFleet.ps1"
```

## 2 · The Power BI template

!!! note "`.pbit` goes here"
    Drop `synthetic-fleet.pbit` into `docs/assets/pbit/` and swap this note for a download button:
    `[:material-download: Synthetic Fleet Generator template](../assets/pbit/synthetic-fleet.pbit)`

## 3 · Example report

![Synthetic Fleet Generator — example Power BI report](../assets/img/report-placeholder.svg)

*Replace `report-placeholder.svg` with a screenshot of your own `Synthetic Fleet Generator` report.*

