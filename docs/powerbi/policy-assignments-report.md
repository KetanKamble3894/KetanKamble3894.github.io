---
title: Policy Assignments — Power BI
description: The Power BI report built on the read-only Policy Assignments snapshot — pre-built, Blob-connected.
tags:
  - Intune
  - Power BI
---

# Policy Assignments — Power BI report

Built on the read-only snapshot from the **[Policy Assignments script](../scripts/policy-assignments.md)** — no live tenant connection, just the sanitized CSV the collector writes to Blob.

![Policy Assignments — example report (synthetic lab data)](../assets/img/policy-assignments-report.png){ .kk-zoom }

*Example built on synthetic `@contoso.com` data.*

## Download the template

[:material-download: Policy Assignments template (.pbit)](../assets/pbit/policy-assignments.pbit){ .md-button .md-button--primary }

!!! info "Opens to a finished report"
    The `.pbit` carries the data model, **every DAX measure**, *and* a **pre-built report page**
    (KPI cards, bar charts, a detail table and slicers). On open it prompts for three parameters —
    **`StorageAccount`**, **`ContainerName`**, **`FileName`** — then for your storage credentials, and
    loads straight from the container your collector writes to. No manual building.

## The measures

```dax
Total Assignments      = COUNTROWS(Assignments)
Distinct Policies      = DISTINCTCOUNT(Assignments[PolicyName])
Dynamic-group Targets  = CALCULATE(COUNTROWS(Assignments), Assignments[IsDynamicGroup] = "true")
Broken Targets         = CALCULATE(COUNTROWS(Assignments), Assignments[TargetGroupStatus] <> "Active")
```

## How it's wired

The collector writes the CSV to your storage account; the template reads it from Blob. Because the
shaping and pre-aggregation already happened in the runbook, Power BI stays thin — connect, refresh,
slice. Swap the three parameters for your own container and nothing else changes.

## Related

- :material-script-text: **The script** → [Policy Assignments](../scripts/policy-assignments.md)
- :material-book-open-variant: **The story** → [Every policy, every target](../blog/posts/policy-assignments.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
