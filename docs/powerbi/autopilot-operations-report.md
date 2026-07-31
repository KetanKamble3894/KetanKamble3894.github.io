---
title: Autopilot Operations — Power BI
description: The Power BI report built on the read-only Autopilot Operations snapshot — pre-built, Blob-connected.
tags:
  - Intune
  - Power BI
---

# Autopilot Operations — Power BI report

Built on the read-only snapshot from the **[Autopilot Operations script](../scripts/autopilot-operations.md)** — no live tenant connection, just the sanitized CSV the collector writes to Blob.

![Autopilot Operations — example report (synthetic lab data)](../assets/img/autopilot-operations-report.png){ .kk-zoom }

*Example built on synthetic `@contoso.com` data.*

## Download the template

[:material-download: Autopilot Operations template (.pbit)](../assets/pbit/autopilot-operations.pbit){ .md-button .md-button--primary }

!!! info "Opens to a finished report"
    The `.pbit` carries the data model, **every DAX measure**, *and* a **pre-built report page**
    (KPI cards, bar charts, a detail table and slicers). On open it prompts for three parameters —
    **`StorageAccount`**, **`ContainerName`**, **`FileName`** — then for your storage credentials, and
    loads straight from the container your collector writes to. No manual building.

## The measures

```dax
Total Deployments = DISTINCTCOUNT(Autopilot[DeviceName])
Success %         = DIVIDE(CALCULATE(DISTINCTCOUNT(Autopilot[DeviceName]), Autopilot[DeploymentStatus] = "Success"), [Total Deployments])
Failed            = CALCULATE(DISTINCTCOUNT(Autopilot[DeviceName]), Autopilot[DeploymentStatus] = "Failed")
In Flight         = CALCULATE(DISTINCTCOUNT(Autopilot[DeviceName]), Autopilot[IsInFlightAtSnapshot] = "true")
```

## How it's wired

The collector writes the CSV to your storage account; the template reads it from Blob. Because the
shaping and pre-aggregation already happened in the runbook, Power BI stays thin — connect, refresh,
slice. Swap the three parameters for your own container and nothing else changes.

## Related

- :material-script-text: **The script** → [Autopilot Operations](../scripts/autopilot-operations.md)
- :material-book-open-variant: **The story** → [Where Autopilot actually breaks](../blog/posts/autopilot-operations.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
