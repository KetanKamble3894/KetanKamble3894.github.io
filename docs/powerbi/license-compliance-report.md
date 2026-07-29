---
title: License Compliance — Power BI
description: The Power BI report that surfaces every Windows device whose primary user is missing an Intune or Windows Enterprise licence — with raw SKUs mapped to real product names.
tags:
  - Intune
  - Entra ID
  - Power BI
---

# License Compliance — Power BI report

Built on the read-only snapshot from the **[License Compliance script](../scripts/license-compliance.md)** —
no live tenant connection, just the sanitized CSV. It answers, fast: which corporate Windows devices
have a primary user who is **missing an Intune (and/or Windows Enterprise) licence** — and *what
licences they do hold*, in plain product names.

![License Compliance report](../assets/img/license-compliance-report.png)

## What it shows

- **Total Device Count** and **Total Unique Accounts** — the size of the exposure at a glance.
- **By Country / Office Location / Department** — where the unlicensed devices concentrate.
- **Detail table** — one row per device, with primary user, manager, location and the friendly
  licence list.
- **Slicers** — device name and manager email search, to hand a filtered list to the right owner.

## Download the template

[:material-download: Download the License Compliance template](../assets/pbit/license-compliance.pbit){ .md-button .md-button--primary }

Open it in free Power BI Desktop, point the query's `Source =` at the synthetic
`Common_account_License.csv`, **Close & Apply**, and it lights up with no tenant access at all.

## The one clever bit: friendly licence names

Graph hands you SKU *part numbers* — `ENTERPRISEPACK`, `SPE_E3`, `EMS` — which nobody outside
licensing reads at a glance. The report maps them to the actual product names an admin recognises:

| Raw SKU | Product name |
|---|---|
| `ENTERPRISEPACK` | Office 365 E3 |
| `ENTERPRISEPREMIUM` | Office 365 E5 |
| `STANDARDPACK` | Office 365 E1 |
| `DESKLESSPACK` | Office 365 F3 |
| `OFFICESUBSCRIPTION` | Microsoft 365 Apps for enterprise |
| `EXCHANGESTANDARD` / `EXCHANGEENTERPRISE` | Exchange Online (Plan 1 / Plan 2) |
| `POWER_BI_STANDARD` / `POWER_BI_PRO` | Power BI (free) / Power BI Pro |
| `PROJECTPROFESSIONAL` | Project Plan 3 |
| `VISIOCLIENT` | Visio Plan 2 |

Because the field is multi-value (`ENTERPRISEPACK;POWER_BI_STANDARD`), the mapping replaces the
**longest, most specific tokens first** — otherwise a short SKU eats a longer one (`EMS` is a
substring of `EMSPREMIUM`; `ENTERPRISEPACK` shares a prefix with `ENTERPRISEPREMIUM`). Blank licence
strings render as **`(no license)`** rather than an empty cell, because "no licence at all" is the
clearest *without-Intune* case of the lot.

!!! tip "Office 365 E3 is supposed to appear here"
    If you see **Office 365 E3** in the list and expect it to include Intune — it doesn't.
    That's *Microsoft 365 E3* (`SPE_E3`). Office 365 E3 (`ENTERPRISEPACK`) is Office apps only, no
    device management. See the [teardown](../projects/zero-access-agent/collectors/license-compliance.md)
    for the full E3-vs-E3 breakdown.

## Data source

A single read-only export, `Common_account_License.csv`, produced by the collector runbook and
written to Blob storage. Key columns:

`DeviceName · PrimaryUserEmail · City · Country · ManagerEmail · ManagerDepartment ·
ManagerOfficeLocation · AssignedLicenses · LastIntuneSync`

## Build it yourself (no tenant needed)

1. Grab `Common_account_License.csv` from the synthetic dataset (fake-but-realistic — every account
   holds only non-Intune SKUs, `contoso.com` demo users, 10 countries).
2. Open the `.pbit` in **free Power BI Desktop**, point the query's `Source =` at the local CSV,
   **Close & Apply**.
3. Add the friendly-name column if you want polished product names in the table:
   ```DAX
   FriendlyLicenses =
   VAR s0  = 'CommonAccountwithoutIntuneLicense'[AssignedLicenses]
   VAR s1  = SUBSTITUTE(s0,  "ENTERPRISEPREMIUM",   "Office 365 E5")
   VAR s2  = SUBSTITUTE(s1,  "ENTERPRISEPACK",      "Office 365 E3")
   VAR s3  = SUBSTITUTE(s2,  "STANDARDPACK",        "Office 365 E1")
   VAR s4  = SUBSTITUTE(s3,  "DESKLESSPACK",        "Office 365 F3")
   VAR s5  = SUBSTITUTE(s4,  "OFFICESUBSCRIPTION",  "Microsoft 365 Apps for enterprise")
   VAR s6  = SUBSTITUTE(s5,  "EXCHANGEENTERPRISE",  "Exchange Online (Plan 2)")
   VAR s7  = SUBSTITUTE(s6,  "EXCHANGESTANDARD",    "Exchange Online (Plan 1)")
   VAR s8  = SUBSTITUTE(s7,  "POWER_BI_STANDARD",   "Power BI (free)")
   VAR s9  = SUBSTITUTE(s8,  "POWER_BI_PRO",        "Power BI Pro")
   VAR s10 = SUBSTITUTE(s9,  "PROJECTPROFESSIONAL", "Project Plan 3")
   VAR s11 = SUBSTITUTE(s10, "VISIOCLIENT",         "Visio Plan 2")
   VAR s12 = SUBSTITUTE(s11, ";", ", ")
   RETURN IF(TRIM(s12) = "", "(no license)", s12)
   ```
4. **View → Themes → Browse for themes →** apply `KetanKamble-PowerBI-Theme.json`, then
   **Insert → Image →** drop in the logo.

## Notes

- **Sanitized:** ships with a parameterised storage source (no real account), neutral branding, and
  synthetic data only. Every figure on screen comes from the fake fleet.
- **Independent content** — not affiliated with, sponsored by, or endorsed by Microsoft. Microsoft,
  Intune, Entra and Power BI are trademarks of the Microsoft group of companies.

## Related

- :material-script-text: **The script** → [License Compliance](../scripts/license-compliance.md)
- :material-book-open-variant: **How it works** → [teardown](../projects/zero-access-agent/collectors/license-compliance.md)
- :material-shield-lock: **Part of** → [Zero-Access Agent](../projects/zero-access-agent/index.md)
