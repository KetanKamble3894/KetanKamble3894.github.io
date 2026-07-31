---
title: Windows 11 Readiness — Power BI
description: The Power BI report built on the read-only Windows 11 Readiness snapshot — pre-built, Blob-connected.
tags:
  - Intune
  - Power BI
---

# Windows 11 Readiness — Power BI report

Built on the read-only snapshot from the **[Windows 11 Readiness script](../scripts/windows11-readiness.md)** — no live tenant connection, just the sanitized CSV the collector writes to Blob.

![Windows 11 Readiness — example report (synthetic lab data)](../assets/img/windows11-readiness-report.png){ .kk-zoom }

*Example built on synthetic `@contoso.com` data.*

## Download the template

[:material-download: Windows 11 Readiness template (.pbit)](../assets/pbit/windows11-readiness.pbit){ .md-button .md-button--primary }

!!! info "Opens to a finished report"
    The `.pbit` carries the data model, **every DAX measure**, *and* a **pre-built report page**
    (KPI cards, bar charts, a detail table and slicers). On open it prompts for three parameters —
    **`StorageAccount`**, **`ContainerName`**, **`FileName`** — then for your storage credentials, and
    loads straight from the container your collector writes to. No manual building.

## The measures

```dax
Total Devices = DISTINCTCOUNT(Readiness[DeviceName])
Ready %       = DIVIDE(CALCULATE(DISTINCTCOUNT(Readiness[DeviceName]), Readiness[Windows11ReadinessState] = "Capable"), [Total Devices])
Not Capable   = CALCULATE(DISTINCTCOUNT(Readiness[DeviceName]), Readiness[Windows11ReadinessState] = "Not capable")
TPM Failures  = CALCULATE(DISTINCTCOUNT(Readiness[DeviceName]), Readiness[TPMCheckFailed] = "true")
```

## How it's wired

The collector writes the CSV to your storage account; the template reads it from Blob. Because the
shaping and pre-aggregation already happened in the runbook, Power BI stays thin — connect, refresh,
slice. Swap the three parameters for your own container and nothing else changes.

## Related

- :material-script-text: **The script** → [Windows 11 Readiness](../scripts/windows11-readiness.md)
- :material-book-open-variant: **The story** → [Which devices can't take Windows 11](../blog/posts/windows11-readiness.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
