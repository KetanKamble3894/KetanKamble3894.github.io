---
title: Lenovo Warranty Enrichment
description: The one opt-in tool that writes — enriching Lenovo warranty into Intune device Notes, surgically and report-only by default.
tags:
  - Intune
  - Microsoft Graph
  - Azure Automation
---

# Lenovo Warranty Enrichment

The one opt-in tool that writes — enriching Lenovo warranty into Intune device Notes, surgically and report-only by default.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/tools/Enrich-LenovoWarrantyToNotes.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/tools/Enrich-LenovoWarrantyToNotes.ps1){ .md-button }

!!! warning "This is the one script that can write"
    Everything else in the project is read-only. This tool is **report-only by default**
    (`-ReportOnly $true`) — it looks up warranty and writes a CSV, touching nothing in Intune.
    Only `-ReportOnly $false` (update mode) `PATCH`es device Notes, and that needs
    `DeviceManagementManagedDevices.ReadWrite.All` — the single write scope in the whole project.
    The append is **surgical**: it only adds warranty lines if absent and never overwrites
    existing Notes.

## 1 · The script

It authenticates with a Managed Identity, filters to Lenovo Windows devices, looks each up by
serial against Lenovo's support endpoint, and (in report mode) writes a warranty CSV locally (no Azure storage).
Set the CONFIG values at the top — including `$ReportOnly` — then run.

??? example "View the full script"
    ```powershell
    --8<-- "assets/scripts/Enrich-LenovoWarrantyToNotes.ps1"
    ```

## 2 · Permissions

- **Report-only mode (default):** `DeviceManagementManagedDevices.Read.All` — Microsoft Graph only, **no Azure storage** (the report is written locally)
- **Update mode:** `DeviceManagementManagedDevices.ReadWrite.All` — grant *only* if you run update mode

## Related

- :material-book-open-variant: **The story** → [The one script that writes: enriching Lenovo warranty into device Notes](../blog/posts/lenovo-warranty-enrichment.md)
- :material-file-document: **The full teardown** → [Enrichment tool — the one that writes](../projects/zero-access-agent/lenovo-warranty-enrichment.md)
