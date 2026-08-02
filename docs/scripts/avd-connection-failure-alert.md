---
title: AVD Connection-Failure Alert
description: A Log Analytics KQL alert that catches Azure Virtual Desktop session failures and emails the AVD admins — read-only observability.
tags:
  - Azure Virtual Desktop
  - Log Analytics
  - Azure Monitor
---

# AVD Connection-Failure Alert

A short Log Analytics (KQL) query, wired into a scheduled alert rule, that catches Azure Virtual Desktop session failures the moment the session hosts log them — and emails the AVD admins with the host pool, machine and user already extracted. Read-only observability.

[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/WVD-ConnectionFailure.kql){ .md-button .md-button--primary }

!!! note "Read-only"
    This is a **Log Analytics scheduled query alert**, not a script that runs against your tenant. It
    reads the `WVDErrors` table and fires an email via an action group. It changes nothing in the AVD
    environment.

## 1 · The query

```kusto
--8<-- "assets/scripts/WVD-ConnectionFailure.kql"
```

## 2 · The alert rule

Wire the query into an Azure Monitor **scheduled query alert**: scope it to your AVD Log Analytics
workspace, condition **table rows > 0** (raise to de-noise), evaluate every few minutes, severity **Critical**, and point
it at an **action group** that emails your AVD admin list. Confirm AVD **diagnostic settings** are
sending the *Errors* category to the workspace first, or `WVDErrors` won't exist to query.

## Related

- :material-book-open-variant: **The story** → [When AVD won't connect: alerting before the tickets](../blog/posts/avd-connection-failure-alert.md)
