---
title: Power BI
description: Endpoint reports built on read-only snapshots.
---


# Power BI reports

Every report here is built on a **read-only snapshot** — a sanitized CSV a collector wrote to Blob storage.
No live tenant connection: connect to the CSV, refresh, done. Each report pairs with the script that feeds it.

| Report | Source | Script |
|---|---|---|
| [Device Inventory report](device-inventory-report.md) | Built on the Device Inventory snapshot | [script](../scripts/device-inventory.md) |
| [Inventory — All Devices report](inventory-all-devices-report.md) | Built on the Inventory — All Devices snapshot | [script](../scripts/inventory-all-devices.md) |
| [Intune Documentation report](intune-documentation-report.md) | Built on the Intune Documentation snapshot | [script](../scripts/intune-documentation.md) |
| [Policy Assignments report](policy-assignments-report.md) | Built on the Policy Assignments snapshot | [script](../scripts/policy-assignments.md) |
| [Device Hygiene report](device-hygiene-report.md) | Built on the Device Hygiene snapshot | [script](../scripts/device-hygiene.md) |
| [App Deployment Failures report](app-deployment-failures-report.md) | Built on the App Deployment Failures snapshot | [script](../scripts/app-deployment-failures.md) |
| [License Compliance report](license-compliance-report.md) | Built on the License Compliance snapshot | [script](../scripts/license-compliance.md) |
| [Windows 11 Readiness report](windows11-readiness-report.md) | Built on the Windows 11 Readiness snapshot | [script](../scripts/windows11-readiness.md) |
| [Autopilot Operations report](autopilot-operations-report.md) | Built on the Autopilot Operations snapshot | [script](../scripts/autopilot-operations.md) |
| [Local AI Agent Inventory report](local-ai-agent-inventory-report.md) | Built on the Local AI Agent Inventory snapshot | [script](../scripts/local-ai-agent-inventory.md) |

!!! note "Templates"
    The `.pbit` templates live in `docs/assets/pbit/`. Drop yours in and wire up the download buttons on each report page.
