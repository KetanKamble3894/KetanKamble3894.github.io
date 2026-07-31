---
title: App Deployment Failures — Power BI
description: The Power BI report built on the read-only App Deployment Failures snapshot — pre-built, Blob-connected.
tags:
  - Intune
  - Power BI
---

# App Deployment Failures — Power BI report

Built on the read-only snapshot from the **[App Deployment Failures script](../scripts/app-deployment-failures.md)** — no live tenant connection, just the sanitized CSV the collector writes to Blob.

![App Deployment Failures — example report (synthetic lab data)](../assets/img/app-deployment-failures-report.png){ .kk-zoom }

*Example built on synthetic `@contoso.com` data.*

## Download the template

[:material-download: App Deployment Failures template (.pbit)](../assets/pbit/app-deployment-failures.pbit){ .md-button .md-button--primary }

!!! info "Opens to a finished report"
    The `.pbit` carries the data model, **every DAX measure**, *and* a **pre-built report page**
    (KPI cards, bar charts, a detail table and slicers). On open it prompts for three parameters —
    **`StorageAccount`**, **`ContainerName`**, **`FileName`** — then for your storage credentials, and
    loads straight from the container your collector writes to. No manual building.

## The measures

```dax
Total Apps       = DISTINCTCOUNT(Apps[DisplayName])
Failed Installs  = SUM(Apps[FailedDevices])
Devices Targeted = SUM(Apps[TotalTargeted])
Avg Failure Rate = AVERAGE(Apps[FailureRatePct])
```

## How it's wired

The collector writes the CSV to your storage account; the template reads it from Blob. Because the
shaping and pre-aggregation already happened in the runbook, Power BI stays thin — connect, refresh,
slice. Swap the three parameters for your own container and nothing else changes.

## Related

- :material-script-text: **The script** → [App Deployment Failures](../scripts/app-deployment-failures.md)
- :material-book-open-variant: **The story** → [Which app is failing, and why](../blog/posts/app-deployment-failures.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
