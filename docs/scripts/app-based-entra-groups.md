---
title: App-Based Entra Groups
description: Two Azure Automation runbooks that rebuild SCCM-style collections in Intune - one creates an assigned Entra group per app, the other keeps each group's membership in sync with the devices that have the app.
tags:
  - Intune
  - Microsoft Graph
  - Entra
  - Azure Automation
---

# App-Based Entra Groups

Two Azure Automation runbooks that give you back the one thing Intune has no answer for after Configuration Manager (SCCM) goes away: a reusable group of "every device that has this app installed". One runbook creates the groups, the other keeps them in sync. Both run as a Managed Identity.

[:material-github: Creator runbook on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/New-AppBasedEntraGroups.ps1){ .md-button .md-button--primary }
[:material-github: Refresh runbook on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Refresh-AppBasedGroups.ps1){ .md-button }

!!! warning "Write-capable - the exception to the read-only pattern"
    Unlike the read-only collectors in this library, these two runbooks write to your tenant. The
    creator creates Entra groups (`Group.ReadWrite.All`); the refresh adds and removes group members
    (`GroupMember.ReadWrite.All`). Both default to `DryRun = $true` and change nothing until you set it
    to `$false`, every run writes a CSV of what it did or would do, and removals only happen after three
    safety gates. Read the [full walkthrough](../blog/posts/app-based-entra-groups.md) before you run either.

## 1 · The creator runbook

Reads Intune detected apps and creates one **assigned** Entra group per app you list, named
`MDM Apps Discovered - <App> (CG)`. Set `$AppPatterns` to the apps you care about (a trailing `*` is a
wildcard, so `TeamViewer*` becomes one group), then run the dry run first.

??? example "View New-AppBasedEntraGroups.ps1"
    ```powershell
    --8<-- "assets/scripts/New-AppBasedEntraGroups.ps1"
    ```

## 2 · The refresh runbook

Walks every group under the prefix, works out which detected-app rows the group covers, maps each device
across the three-hop id chain to its Entra object id, and reconciles membership. Adds freely, removes only
past the three gates. Report-only by default, with a CSV audit trail. Set the storage config at the top,
then run with `-DryRun $true` and read the preview.

??? example "View Refresh-AppBasedGroups.ps1"
    ```powershell
    --8<-- "assets/scripts/Refresh-AppBasedGroups.ps1"
    ```

## Related

- :material-book-open-variant: **The story** → [App-based Entra groups to replace SCCM collections](../blog/posts/app-based-entra-groups.md)
- :material-cog: **One-time setup** → [Setting up the collection layer](../projects/zero-access-agent/azure-automation-setup.md)
