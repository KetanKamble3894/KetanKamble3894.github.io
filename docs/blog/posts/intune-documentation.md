---
description: Always-current, read-only documentation of your whole Intune and Windows 365 config — built on the community M365Documentation module.
date: 2026-08-11
draft: false
comments: true
categories:
  - Behind the portal
tags:
  - Intune
  - Microsoft Graph
  - Azure Automation
  - Documentation
---

# Documentation that writes itself: a read-only snapshot of your whole Intune config

![Cover: read-only Intune and Windows 365 configuration documented automatically](../../assets/img/banners/intune-documentation.webp){ .post-cover width="1200" height="630" fetchpriority=high }

Ask an admin for "the documentation" of their Intune tenant and you'll get a nervous laugh. It's in
the portal — spread across compliance policies, configuration profiles, app assignments, Autopilot
profiles, update rings — and the moment anyone writes it down in a Word doc, it's out of date. This
is a scheduled, **read-only** collector that renders the *entire* Intune and Windows 365 configuration
into one always-current, human-readable document.

<!-- more -->

!!! tip "The short version"
    Nobody hand-documents Intune, because it's stale before you save the file. This runbook injects a
    **read-only** Graph token into the community **M365Documentation** module, walks the config section
    by section, and renders one merged HTML document — refreshed on a schedule, **no write access, no
    live tenant in the output.** It's the *prose* half of the Zero-Access Agent's knowledge (the CSV
    snapshots are the structured half).

## Why "just look in the portal" isn't documentation

The portal always shows the *current* state — that's the problem, not the solution. It's a live
control surface, not a record. When you need to answer "what did our compliance baseline look like
before the change last month?", or hand a new engineer a single readable map of the tenant, or prove
to an auditor what was configured, the portal gives you none of it:

- **It's navigation, not narrative.** Config is scattered across a dozen blades. There's no one
  document that says, top to bottom, *here is everything this tenant enforces*.
- **Manual docs die on contact.** The instant someone edits a policy, your lovingly-maintained
  runbook or Word export is wrong — and you won't know which parts.
- **Export is per-object and lossy.** You can export a profile as JSON, but that's machine data for
  one object, not a readable account of the whole estate.

So the job is to generate the documentation *from the tenant itself*, on a schedule, read-only — so
it's never more stale than its last run.

## Standing on community shoulders

This collector doesn't reinvent the documentation engine — it uses the excellent, open-source
**[M365Documentation](https://github.com/ThomasKur/M365Documentation)** module by **Thomas Kurth**,
which already knows how to walk Intune and Windows 365 section by section and render them. The runbook's
job is narrower and specific to the Zero-Access Pattern: sign in as a **Managed Identity**, mint a
**read-only** Graph token, hand that token to the module, refresh it as the collection runs, and drop
the finished HTML where the agent can cite it.

!!! note "Licensing, done right"
    M365Documentation is **GPL-3.0**. This runbook only *calls* it at runtime — you install it yourself
    from the PowerShell Gallery — so the module's source never enters this repo, and the runbook stays
    MIT. Credit where it's due.

## How it works: a read-only collector

<div class="mermaid-live" markdown="0">
--8<-- "assets/diagrams/intune-documentation.svg"
</div>

The read-only Graph app roles are all `.Read.All`:
`DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`,
`DeviceManagementManagedDevices.Read.All`, `Directory.Read.All`, and `Organization.Read.All` for the
connectivity self-test. Nothing writes.

!!! warning "Verify before you trust it"
    The exact scopes the module needs can shift between its versions — check against the
    [module's docs](https://github.com/ThomasKur/M365Documentation) for the version you install, and
    confirm each section renders in your **own lab tenant** first.

## What the output looks like

One merged, human-readable HTML record of the whole tenant — a table of contents down the side,
then section after section of the actual configuration: every compliance policy and its settings,
configuration profiles and their assignments, the app catalog, Autopilot and enrolment. It's the
document you hand a new engineer or an auditor, and it's never more stale than its last scheduled run.

![Auto-generated Intune documentation: compliance policies, configuration profiles, the app catalog and Autopilot/enrolment, each with its settings (synthetic Contoso tenant)](../../assets/img/intune-documentation-doc.webp){ .kk-zoom loading=lazy width="1500" height="2308" }

*Every value above is **synthetic lab data** (`contoso.onmicrosoft.com`) — the real run renders your own
tenant's config, read-only, and never leaves your storage account.*

## Where it goes

The rendered HTML lands in the storage account's `reports/` container and feeds the **documentation**
side of the agent's knowledge — the `euc-documents` index in Azure AI Search. That's the deliberate
split at the heart of the Zero-Access Agent: **structured CSV snapshots** answer *"how many, which,
where"*; this **prose documentation** answers *"how is it configured, and why"*. The agent reads both,
and holds no live connection to either.

## Gotchas from the lab

- **It's a document, not a dashboard.** There's no Power BI here on purpose — the output is prose you
  read (or the agent cites), not numbers you slice.
- **Install the module's dependencies first.** M365Documentation leans on MSAL.PS, PSWriteOffice and
  PSHTML — load them into the Automation Account from PSGallery before the first run, or the runbook
  stops at import.
- **Token refresh mid-collection matters.** A full tenant walk can outlast a single token; the runbook
  refreshes as it goes, so long collections don't die halfway.

!!! question "Want your whole tenant documented on a schedule?"
    Standing up read-only, always-current documentation like this is hands-on Intune work I do in the open — for a limited number of teams. It's running today against real multi-thousand-device tenants. **[Work with me →](../../work-with-me.md)**

## FAQ

**Is there a Power BI report for this one?** No — the output is a human-readable HTML document, not a dashboard. It's the prose half of the agent's knowledge; the CSV snapshots are the structured half.

**Does it copy the M365Documentation module into my repo?** No. You install the GPL module yourself from the PowerShell Gallery; the runbook only calls it at runtime, so the runbook stays MIT.

**How current is the documentation?** It's regenerated on a schedule, so it's never more stale than its last run — unlike a hand-maintained Word doc.

## More in this series

- [Every policy, every target](../policy-assignments/)
- [One row per device](../inventory-all-devices/)

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Is there a Power BI report for this one?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "No — the output is a human-readable HTML document, not a dashboard. It's the prose half of the agent's knowledge; the CSV snapshots are the structured half."
      }
    },
    {
      "@type": "Question",
      "name": "Does it copy the M365Documentation module into my repo?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "No. You install the GPL module yourself from the PowerShell Gallery; the runbook only calls it at runtime, so the runbook stays MIT."
      }
    },
    {
      "@type": "Question",
      "name": "How current is the documentation?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "It's regenerated on a schedule, so it's never more stale than its last run — unlike a hand-maintained Word doc."
      }
    }
  ]
}
</script>

## Related

- :material-script-text: **The script** → [Intune Documentation](../../scripts/intune-documentation.md)
- :material-shield-lock: **The bigger picture** → [Zero-Access Agent](../../projects/zero-access-agent/index.md) — where the prose and the snapshots come together.
- :material-open-source-initiative: **Credit** → [M365Documentation by Thomas Kurth](https://github.com/ThomasKur/M365Documentation)

---

*Screenshots use synthetic data from a personal lab — no real tenant, users, or devices. Independent
content, not affiliated with, sponsored by, or endorsed by Microsoft. Microsoft, Intune, Entra,
Microsoft Graph, Azure, Defender and Power BI are trademarks of the Microsoft group of companies.*
