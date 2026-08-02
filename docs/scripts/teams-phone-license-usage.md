---
title: Teams Phone License Usage
description: Read-only Teams Phone (Voice) license-usage report — who holds a license, who has a number, who never calls — with a reclaim risk tier per user.
tags:
  - Microsoft Graph
  - Entra ID
  - Azure Automation
  - Power BI
---

# Teams Phone License Usage

Read-only Teams Phone license-usage report — who holds a Teams Phone license, who has a number, and who never calls — joined to the manager, with a reclaim risk tier per user. Exports a CSV to Blob for Power BI.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Report-TeamsPhoneLicenses.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Report-TeamsPhoneLicenses.ps1){ .md-button }

!!! note "Read-only"
    It reads users, licenses and Teams usage reports via Graph (a `$batch` POST that only *reads*
    managers), classifies each user by an observational risk tier, and writes a CSV to your Blob. It
    changes nothing in the tenant. Scopes are all read: `User.Read.All`, `Organization.Read.All`,
    `AuditLog.Read.All`, `Reports.Read.All`, `Directory.Read.All` + `Storage Blob Data Contributor`.

## 1 · The script

Set the CONFIG block (resource group, storage account, container — all `@contoso`-style placeholders)
and confirm your tenant's Teams Phone **SKU GUIDs** from `subscribedSkus`, then run.

??? example "View the full script"
    ```powershell
    --8<-- "assets/scripts/Report-TeamsPhoneLicenses.ps1"
    ```

## 2 · The risk tiers

The report tags each licensed user — **Tier 1 Disabled account · Tier 2 Never signed in · Tier 3
Inactive >90 days · Tier 4 No Teams activity · Tier 5 Active** — as *observational* signals. A human
decides what to reclaim.

## Related

- :material-book-open-variant: **The story** → [Teams Phone licenses, paid for and never used](../blog/posts/teams-phone-license-usage.md)
