---
title: Intune Documentation
description: Renders your whole Intune and Windows 365 configuration into one always-current, read-only HTML document.
tags:
  - Intune
  - Microsoft Graph
  - Documentation
---

# Intune Documentation

Renders your entire Intune and Windows 365 configuration into one always-current, human-readable HTML document — read-only, on a schedule.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-IntuneDocumentation.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Collect-IntuneDocumentation.ps1){ .md-button }

## 1 · The script

Read-only by construction — it authenticates with a Managed Identity, mints a read-only Graph token,
and injects it into the community **M365Documentation** module, which walks the tenant section by
section and renders one merged HTML document. Set the two CONFIG values at the top, then run.

??? example "View the full script (12 KB)"
    ```powershell
    --8<-- "assets/scripts/Collect-IntuneDocumentation.ps1"
    ```

## 2 · The output

Not a dashboard — a **document**. The runbook uploads a single HTML file to the storage account's
`reports/` container, where it feeds the *documentation* side of the Zero-Access Agent's knowledge
(the `euc-documents` index in Azure AI Search). The prose the agent cites; the CSV collectors handle
the numbers.

!!! info "No Power BI here — on purpose"
    This collector produces readable configuration documentation, not metrics. There's nothing to
    slice, so there's no report. See the [write-up](../blog/posts/intune-documentation.md) for why.

## 3 · Dependencies & credit

Built around the open-source **[M365Documentation](https://github.com/ThomasKur/M365Documentation)**
module by **Thomas Kurth** (plus MSAL.PS, PSWriteOffice, PSHTML). Install them into the Automation
Account from the PowerShell Gallery first. M365Documentation is GPL-3.0 and is *called* at runtime,
never vendored — so this script stays MIT.

## Related

- :material-book-open-variant: **The story** → [Documentation that writes itself](../blog/posts/intune-documentation.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
