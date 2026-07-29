---
title: Zero-Access Agent
description: The read-only AI agent pattern for endpoint intelligence.
tags:
  - Intune
  - Entra ID
  - Microsoft Graph
  - Azure Automation
---


# Zero-Access Agent

**Give the AI the reports, never the systems.** An architecture for answering questions about an endpoint
fleet with an AI agent that holds **no access to any live system**. Scheduled read-only jobs export
sanitized, pre-aggregated snapshots; the agent answers only from those.

[:material-rocket-launch: Build it yourself](build-it-yourself.md){ .md-button .md-button--primary }
[:material-github: Source on GitHub](https://github.com/KetanKamble3894/zero-access-agent){ .md-button }

## The pattern, in one screen

1. **Source** — Intune / Entra. GET-only via Managed Identity; the AI never touches it.
2. **Collect** — scheduled Azure Automation runbooks pull read-only from Graph and *pre-aggregate* into slim CSV snapshots.
3. **Store** — Azure Blob: full CSVs for Power BI, slim snapshots for the agent.
4. **Retrieve** — Azure AI Search over the snapshots, RBAC read-only.
5. **Answer** — an Azure AI Foundry agent that holds no scopes and no keys, and answers only from the index.

It trades freshness for containment — snapshots are as current as the last run, not live. That trade is the whole point.

## The ten collectors

Each is a real read-only runbook, and each pairs with a script page and a Power BI report in the library.

<div class="za-grid" markdown>
    <a class="za-card" href="collectors/inventory-all-devices/"><b>Inventory — All Devices</b><span>Full managed-device inventory across the fleet — the backbone dataset every other report leans on.</span></a>
    <a class="za-card" href="collectors/intune-documentation/"><b>Intune Documentation</b><span>Snapshots your Intune configuration — profiles, policies and settings — as documentation you can diff over time.</span></a>
    <a class="za-card" href="collectors/policy-assignments/"><b>Policy Assignments</b><span>Resolves which policies land on which groups, so 'why did this device get that setting?' has an answer.</span></a>
    <a class="za-card" href="collectors/device-hygiene/"><b>Device Hygiene</b><span>Compliance, encryption, stale check-ins and the small signals that separate a healthy fleet from a drifting one.</span></a>
    <a class="za-card" href="collectors/app-deployment-failures/"><b>App Deployment Failures</b><span>Surfaces app installs that failed and where, so remediation targets the real devices, not the whole ring.</span></a>
    <a class="za-card" href="collectors/license-compliance/"><b>License Compliance</b><span>Maps assigned vs consumed licences across the tenant — the report finance and IT both ask for.</span></a>
    <a class="za-card" href="collectors/windows11-readiness/"><b>Windows 11 Readiness</b><span>Hardware-readiness across the estate — TPM, CPU, RAM — so the Windows 11 plan is grounded in data.</span></a>
    <a class="za-card" href="collectors/autopilot-operations/"><b>Autopilot Operations</b><span>Autopilot registrations, profiles and deployment health — the enrolment funnel, made visible.</span></a>
    <a class="za-card" href="collectors/local-ai-agent-inventory/"><b>Local AI Agent Inventory</b><span>Inventories local AI-agent tooling across managed devices — a modern-workspace signal most fleets can't see yet.</span></a>
    <a class="za-card" href="collectors/noncompliant-devices/"><b>Non-Compliant Devices</b><span>Every non-compliant Windows device and the exact settings that failed — the flagship report.</span></a>
</div>

## Start with the walkthrough

- **[Build it yourself](build-it-yourself.md)** — empty subscription to read-only runbooks + a Power BI report.
- **[Collection layer setup](azure-automation-setup.md)** — the Automation Account, Managed Identity, read-only Graph roles.
- **[Enrichment tool](lenovo-warranty-enrichment.md)** — the one optional, human-run utility that can write. Fenced, opt-in, named openly.

!!! info "One honest exception"
    The read-only guarantee covers the collection → agent path. The repo ships one *optional, human-run*
    enrichment utility that can write device warranty into Notes. It's fenced off, opt-in, defaults to a
    read-only report — and named openly rather than hidden.
