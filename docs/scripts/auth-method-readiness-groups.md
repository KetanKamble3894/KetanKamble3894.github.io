---
title: Auth Method Readiness Groups
description: A read-only Entra runbook that sorts users by their strongest auth method and keeps assigned readiness groups in sync, before SMS and voice MFA retire.
tags:
  - Entra ID
  - Microsoft Graph
  - Authentication methods
  - Passkey
  - Azure Automation
---

# Auth Method Readiness Groups

One Azure Automation runbook that answers "who is still on SMS" as a group you can act on. It reads the Entra authentication-method registration report, sorts every in-scope user into one group by their strongest method (phishing-resistant, strong, telephony-only, nothing), and keeps those assigned groups in sync. It runs as a Managed Identity and defaults to a dry run.

[:material-github: Runbook on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Report-AuthMethodReadiness.ps1){ .md-button .md-button--primary }

!!! warning "Write-capable - the exception to the read-only pattern"
    The report half is read-only. The optional group sync writes: it adds and removes members of
    assigned Entra groups (`GroupMember.ReadWrite.All`). It defaults to `DryRun = $true` and changes
    nothing until you set it to `$false`. It never creates, renames or deletes a group, only groups you
    made first are ever touched, every run writes a CSV of what it did or would do, and removals only
    happen after four safety gates (coverage, partition, removal share, and a group-shape guard that
    skips on-premises-synced, role-assignable and dynamic groups). Read the
    [full walkthrough](../blog/posts/auth-method-readiness-groups.md) before you run it.

## What it needs

Read-only to classify, and one write scope only when you turn the dry run off:

- `User.Read.All` - list users
- `AuditLog.Read.All` - read the authentication-method registration report
- `GroupMember.Read.All` - read current group membership for the diff (needed even in a dry run)
- `GroupMember.ReadWrite.All` - add and remove members, only used when `DryRun = $false`

Create the six readiness groups plus the exclusion group by hand first (the runbook never creates them),
set the storage config at the top, then run with `-DryRun $true` and read the proposed changes before you
ever let it write.

??? example "View Report-AuthMethodReadiness.ps1"
    ```powershell
    --8<-- "assets/scripts/Report-AuthMethodReadiness.ps1"
    ```

## Related

- :material-book-open-variant: **The story** -> [Passkey readiness as live Entra groups](../blog/posts/auth-method-readiness-groups.md)
- :material-group: **The same idea for apps** -> [App-based Entra groups to replace SCCM collections](../blog/posts/app-based-entra-groups.md)
