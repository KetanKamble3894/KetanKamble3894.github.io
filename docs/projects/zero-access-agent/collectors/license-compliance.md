---
title: License Compliance — collector teardown
description: How the read-only runbook finds corporate Windows devices whose primary user is missing an Intune or Windows Enterprise licence — the Graph calls behind the report.
tags:
  - Intune
  - Entra ID
  - Microsoft Graph
  - Azure Automation
---

# License Compliance — how it actually works

Finance wants to know it isn't paying for licences nobody uses. IT wants to know a device isn't
sitting *outside* management because its user was never given an Intune licence. Same question from
two directions: **which corporate Windows devices have a primary user who is missing an Intune
and/or Windows Enterprise entitlement?** Tedious to answer by hand, trivial once the answer is a
snapshot. This collector is a scheduled, **read-only** Azure Automation runbook that walks Microsoft
Graph, checks each user's licences once, and writes a sanitized CSV. No live tenant connection for
the report — Power BI and the agent only ever see the snapshot.

![The Graph calls behind the License Compliance report — read-only sequence](../../../assets/img/license-compliance-graph-flow.png)

## The Graph calls behind it

Everything is a **GET**. Nothing is ever written back to the tenant.

1. **Get a token — no secrets.** The runbook authenticates with its **Managed Identity** via the
   `IDENTITY_ENDPOINT`, so there are no stored keys or app secrets anywhere in the script.

2. **Pull the Windows corporate fleet with a primary user** (paged):
   ```
   GET /beta/deviceManagement/managedDevices
       ?$filter=operatingSystem eq 'Windows' and managedDeviceOwnerType eq 'company'
       &$select=id,deviceName,userPrincipalName,userId,lastSyncDateTime
       &$top=1000
   ```
   Paging follows `@odata.nextLink` until it's exhausted. The `userId` comes back **on the device
   object**, so there's no separate "who's the primary user" call.

3. **Look up each unique user once** (v1.0) — and grab the manager in the *same* request:
   ```
   GET /v1.0/users/{userId}
       ?$select=id,userPrincipalName,employeeType,city,country
       &$expand=manager($select=mail,department,officeLocation)
   ```
   The `$expand=manager` is the quiet efficiency win — user context *and* the escalation contact
   (manager mail / department / office) come back in one round-trip instead of two.

4. **Read that user's assigned licences** (v1.0):
   ```
   GET /v1.0/users/{userId}/licenseDetails?$select=skuPartNumber
   ```
   The result is a list of SKU part numbers — `SPE_E3`, `ENTERPRISEPACK`, `EMS`, and so on.

5. **Decide, in code.** Each user's SKUs are compared against two configurable sets —
   `$IntuneSKUs` and `$WindowsEnterpriseSKUs`. Miss either entitlement and the device is reported,
   with the friendly product names resolved from Microsoft's public SKU→name mapping.

6. **Write the snapshot to Blob storage** — a root `License_Compliance.csv` for Power BI and a
   size-gated `agent-data/` copy for the AI-search layer.

### The permissions (least-privilege, read-only)

`DeviceManagementManagedDevices.Read.All` · `User.Read.All` · `Directory.Read.All`

## The bit that's the *opposite* of the non-compliance collector

The [Non-Compliant Devices](noncompliant-devices.md) collector fans **out** — one call per device,
then one per failing policy — because compliance detail is per-device. This one deliberately fans
**in**: licences are per **user**, and a fleet has far more devices than users. So it caches on
`userId` — a user with five laptops is checked **once**, not five times:

- **1** paged call for the device list, then
- **1** user-detail call **per unique user** (cached), then
- **1** `licenseDetails` call **per unique user** (cached).

On a 5,000-device fleet with 3,000 users, that's ~6,000 user calls instead of ~10,000 device-keyed
ones — and the cache means re-runs of hot users cost nothing. Same read-only discipline, opposite
shape.

## The one thing almost everyone gets wrong: Office 365 E3 ≠ Microsoft 365 E3

This is the story worth telling, because it trips up seasoned admins and it's the single reason a
report like this earns its keep. **"E3" is not one thing.**

| Product | SKU part number | Includes Intune? |
|---|---|---|
| **Microsoft 365 E3** | `SPE_E3` | **Yes** — Intune Plan 1 is inside it |
| **Office 365 E3** | `ENTERPRISEPACK` | **No** — Office apps only, no EMS, no Intune |
| Enterprise Mobility + Security E3 | `EMS` | **Yes** — this is where the Intune licence lives |
| Office 365 E5 | `ENTERPRISEPREMIUM` | **No** |

A user holding **Office 365 E3** looks fully licensed at a glance — and their Windows device is
*unmanaged*, because that SKU carries no Intune entitlement. That's exactly the account this report
is built to surface. The logic lives in one configurable line:

```powershell
$IntuneSKUs = @("EMSPREMIUM", "SPE_F1", "SPE_E3", "SPE_E5", "SPE_F3", "INTUNE_O365")
```

`ENTERPRISEPACK` is deliberately **not** in that list — so an Office 365 E3 user correctly reports
as *missing Intune*. Get this SKU set wrong and the whole report is wrong; it's the one thing to
review before you trust the output.

!!! warning "Beta endpoint"
    Managed devices use **/beta**; users and `licenseDetails` use **/v1.0**. Beta shapes can change
    without notice — reproduce it in your own lab before you depend on it.

## Two small touches worth copying

**Friendly licence names.** Raw SKUs like `SPE_E3` mean nothing to most readers, so the runbook
resolves them through Microsoft's public "Product names and service plan identifiers" mapping
(`License_Details.csv`, kept in the container). A missing mapping degrades to the raw SKU — it never
breaks the report.

**An explicit all-clear row.** If nobody is missing a licence, the CSV isn't empty — it carries a
single "ALL CLEAR" row stamped with the date. An empty file is ambiguous ("did it run? did it
fail?"); an explicit all-clear is an *answer*. The agent can say "everyone's licensed as of the
19th" instead of finding nothing.

## Run it yourself — no tenant needed

The [synthetic dataset](../../../scripts/license-compliance.md) ships a fake-but-realistic
`Common_account_License.csv` — every account holds only **non-Intune** SKUs (Office 365 E3/E5/F3,
Power BI, Exchange, Project, Visio, or no licence at all), so each one legitimately belongs in a
"without Intune" report. Point the [Power BI report](../../../powerbi/license-compliance-report.md) at
it and the whole thing lights up with **no Graph access at all**.

## Related

- :material-script-text: **The script** → [Collect-LicenseComplianceCheck.ps1](../../../scripts/license-compliance.md)
- :material-chart-box: **The report** → [License Compliance — Power BI](../../../powerbi/license-compliance-report.md)
- :material-shield-lock: **The pattern** → [Zero-Access Agent](../index.md)

---

*Sanitized: parameterised storage source, no real account, synthetic data only. Independent content —
not affiliated with, sponsored by, or endorsed by Microsoft. Microsoft, Intune, Entra, Microsoft
Graph, Azure and Power BI are trademarks of the Microsoft group of companies. Everything here comes
from a personal lab.*
