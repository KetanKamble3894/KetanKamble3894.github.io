---
title: Device Hygiene — Power BI
description: The Power BI report built on the read-only Device Hygiene snapshot — pre-built, Blob-connected.
tags:
  - Intune
  - Power BI
---

# Device Hygiene — Power BI report

Built on the read-only snapshot from the **[Device Hygiene script](../scripts/device-hygiene.md)** — no live tenant connection, just the sanitized CSV the collector writes to Blob.

![Device Hygiene — example report (synthetic lab data)](../assets/img/device-hygiene-report.png){ .kk-zoom }

*Example built on synthetic `@contoso.com` data.*

## Download the template

[:material-download: Device Hygiene template (.pbit)](../assets/pbit/device-hygiene.pbit){ .md-button .md-button--primary }

!!! info "Opens to a finished report"
    The `.pbit` carries the data model, **every DAX measure**, *and* a **pre-built report page**
    (KPI cards, bar charts, a detail table and slicers). On open it prompts for three parameters —
    **`StorageAccount`**, **`ContainerName`**, **`FileName`** — then for your storage credentials, and
    loads straight from the container your collector writes to. No manual building.

## The measures

```dax
Total Devices    = DISTINCTCOUNT(Hygiene[DeviceName])
Needs Action     = CALCULATE(DISTINCTCOUNT(Hygiene[DeviceName]), Hygiene[RecommendedAction] <> "None")
Inactive Devices = CALCULATE(DISTINCTCOUNT(Hygiene[DeviceName]), Hygiene[IsInactive] = "true")
Orphaned Records = CALCULATE(DISTINCTCOUNT(Hygiene[DeviceName]), Hygiene[ReportType] = "Orphaned")
```

## How it's wired

The collector writes the CSV to your storage account; the template reads it from Blob. Because the
shaping and pre-aggregation already happened in the runbook, Power BI stays thin — connect, refresh,
slice. Swap the three parameters for your own container and nothing else changes.

## Related

- :material-script-text: **The script** → [Device Hygiene](../scripts/device-hygiene.md)
- :material-book-open-variant: **The story** → [The devices no one owns anymore](../blog/posts/device-hygiene.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
