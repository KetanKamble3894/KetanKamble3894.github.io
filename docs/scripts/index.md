---
title: Scripts
description: A library of standalone, read-only PowerShell for the Modern Workplace.
---


# Scripts library

Standalone, read-only PowerShell for Intune, Entra and Graph. Each script is grab-and-use: **the script,
its `.pbit`, and an example report** — plus the topic tags so you can find it again. Many of these are the
same collectors that **club together** into [Zero-Access Agent](../projects/zero-access-agent/index.md).

!!! tip "New here? Start with the worked example"
    **[Device Inventory](device-inventory.md)** shows the full template end to end.

| Script | What it does | Topics |
|---|---|---|
| [Read-Only Gate](./read-only-gate.md) | The founding artifact — proves a collector's identity can only read, and aborts the run if it can't. | Microsoft Graph · Azure Automation · Defender / Security |
| [Non-Compliant Devices](./noncompliant-devices.md) | Every non-compliant Windows device and the exact failing settings. | Intune · Microsoft Graph · Defender / Security |
| [Device Inventory](./device-inventory.md) | The simplest end-to-end collector — a clean starting point to learn the read-only pattern before the bigger ones. | Intune · Microsoft Graph · Azure Automation |
| [Inventory — All Devices](./inventory-all-devices.md) | Full managed-device inventory across the fleet — the backbone dataset every other report leans on. | Intune · Microsoft Graph · Azure Automation |
| [Intune Documentation](./intune-documentation.md) | Snapshots your Intune configuration — profiles, policies and settings — as documentation you can diff over time. | Intune · Microsoft Graph |
| [Policy Assignments](./policy-assignments.md) | Resolves which policies land on which groups, so 'why did this device get that setting?' has an answer. | Intune · Microsoft Graph |
| [Device Hygiene](./device-hygiene.md) | Compliance, encryption, stale check-ins and the small signals that separate a healthy fleet from a drifting one. | Intune · Defender / Security · Microsoft Graph |
| [App Deployment Failures](./app-deployment-failures.md) | Surfaces app installs that failed and where, so remediation targets the real devices, not the whole ring. | Intune · Microsoft Graph |
| [License Compliance](./license-compliance.md) | Maps assigned vs consumed licences across the tenant — the report finance and IT both ask for. | Entra ID · Microsoft 365 · Microsoft Graph |
| [Windows 11 Readiness](./windows11-readiness.md) | Hardware-readiness across the estate — TPM, CPU, RAM — so the Windows 11 plan is grounded in data. | Intune · Windows / Autopilot · Microsoft Graph |
| [Autopilot Operations](./autopilot-operations.md) | Autopilot registrations, profiles and deployment health — the enrolment funnel, made visible. | Windows / Autopilot · Intune · Microsoft Graph |
| [Local AI Agent Inventory](./local-ai-agent-inventory.md) | Inventories local AI-agent tooling across managed devices — a modern-workspace signal most fleets can't see yet. | Intune · Microsoft Graph |
| [Synthetic Fleet Generator](./synthetic-fleet.md) | Generates fake-but-realistic fleet CSVs — duplicates, missing values, reimaged serials — so you can run everything with no tenant. | Azure Automation |
