---
title: Read-Only Gate
description: The founding artifact of the Zero-Access Pattern — a runtime gate that proves a collector's identity can only read, and aborts if it can't.
tags:
  - Microsoft Graph
  - Azure Automation
  - Defender / Security
---

# Read-Only Gate

The claim behind everything else on this site is that the collectors **cannot write to your tenant**.
This is the script that makes that claim executable. It runs *as* the identity a collector uses, asks
Microsoft Graph which application permissions that identity actually holds, and **hard-fails the run if
any of them is not read-only**. The boundary is enforced by architecture — not by trust.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/read-only-gate.ps1){ .md-button .md-button--primary }

## 1 · The script

It authenticates as a **Managed Identity**, resolves its own service principal, maps Microsoft Graph's
app-role IDs to their values, lists the roles actually granted to the identity, and classifies each as
read (`.Read.All` / `.Read`) or write. One write role and the gate throws. Dot-source it at the top of a
collector runbook and the collector aborts *before* its first Graph call if the identity isn't clean.

??? example "View the full script"
    ```powershell
    --8<-- "assets/scripts/read-only-gate.ps1"
    ```

## 2 · Two ways to run it

**As a standalone audit** — run it and read the report and exit code:

```
Zero-Access read-only gate — identity: aa-collectors  [<guid>]
[read ] DeviceManagementManagedDevices.Read.All
[read ] Directory.Read.All
[read ] User.Read.All
READ-ONLY GATE PASSED — 3 Graph role(s), all read-only. Safe to collect.
```

**As a guard** — the first lines of every collector runbook:

```powershell
. .\read-only-gate.ps1          # throws and stops the run if a write scope is present
# ... collector logic only runs past this line if the gate passed ...
```

## 3 · What it needs

It runs under a **system-assigned Managed Identity**, and to read its *own* permissions it needs a
directory read scope — `Directory.Read.All` or `Application.Read.All`. Both are read-only and already
part of the pattern; the gate reports them as such. The only module is
`Microsoft.Graph.Authentication` (for `Invoke-MgGraphRequest`) — no full SDK, so the Graph calls stay
visible and light.

!!! warning "It's a guardrail, not a licence to be careless"
    The gate verifies the roles that are *granted*. The first line of defence is still never granting a
    write scope in the first place. The gate is what catches the day someone does — and turns a silent
    mistake into a failed run.

## Related

- :material-book-open-variant: **The origin story** → [The 403 that started it](../../blog/the-403-that-started-the-zero-access-pattern/)
- :material-shield-lock: **The bigger picture** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
- :material-cog-outline: **Where it plugs in** → [Setting up the collection layer](../projects/zero-access-agent/azure-automation-setup.md)
