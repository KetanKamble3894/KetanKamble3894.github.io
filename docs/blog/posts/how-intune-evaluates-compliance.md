---
date: 2026-07-29
draft: false
comments: true
categories:
  - How it works
tags:
  - Intune
  - Entra ID
  - Defender / Security
---

# How Intune actually decides a device is compliant

When you switch on a compliance policy, the portal eventually shows a green check. But what happens *between* "device enrolled" and "Conditional Access lets it in"? The answer isn't a live query — it's a check-in loop, an expiry clock, and a handoff to Entra ID.

<!-- more -->

!!! note "Draft — pending my own lab verification"
    This is a first pass built from the official mechanics. The callouts marked **Lab** are where I'll drop what I reproduce in my own tenant before this goes fully live.

## The short answer

Intune doesn't continuously watch your device. The device evaluates the rules **locally** and reports a verdict on a schedule; Intune stores that verdict, **ages it**, and passes it to Microsoft Entra ID, where Conditional Access reads it. Compliance is a *reported, expiring fact* — not a real-time check.

## The backend, step by step

1. **Assignment.** A compliance policy is a set of platform-specific rules assigned to user or device groups — one policy per platform. The device picks it up on its next check-in after assignment.
2. **Local evaluation.** The device's MDM agent checks each rule against local state and reports **per-setting** results. The first pass after enrolment can take **up to 24 hours** to appear while the device receives the policy, processes it, and reports back.
3. **Status calculation.** Intune rolls the per-setting results into a **per-policy** verdict. If multiple policies disagree, the **most secure** one wins. A device lands in one of four states: **Compliant**, **Noncompliant**, **In grace period**, or **Not evaluated**.
4. **The validity clock.** This is the quiet one. The tenant setting *Compliance status validity period* (default **30 days**, configurable 1–120) means a device must **re-report** within that window — if it goes silent, it's flipped to noncompliant *even with zero rule changes*.
5. **Error handling.** If a setting returns an error, the device's last known status is **held for up to 7 days** to let evaluation finish. After that, it falls to Noncompliant (or In grace period, if configured), and CA-protected access drops with it.
6. **The handoff.** The verdict flows to Entra ID; a Conditional Access policy set to *Require device to be marked as compliant* reads it. Watch the tenant-wide *Mark devices with no compliance policy assigned as* — it **defaults to Compliant**, which is a silent hole if you gate access on CA. Flip it to **Not compliant**.
7. **What re-triggers evaluation.** New enrolment, periodic contact enforcement, a device property changing on sync, a policy assignment change, or a user tapping *Check compliance* in the Company Portal. Windows also has **client-driven** re-evaluation (preview) that proactively requests a re-check when local state changes.

## What you can observe

The read-only signals that expose all of this — **last check-in time**, **per-device compliance state**, and **grace-period membership** — are exactly what the [Device Hygiene collector](../../scripts/device-hygiene.md) snapshots, and what its [Power BI report](../../powerbi/device-hygiene-report.md) visualises. No live tenant poking required.

## Gotchas (and what surprised me in the lab)

!!! warning "Lab-verified"
    - **The 30-day clock bites quietly.** A device that just goes offline is marked noncompliant with no rule change at all. *(Lab: confirm the exact flip timing I observed.)*
    - **"No policy = Compliant" default.** Left unchanged, unmanaged devices sail through CA. *(Lab: screenshot my tenant's setting.)*
    - **The up-to-24h first report** makes fresh enrolments look "Not evaluated" longer than people expect. *(Lab: my observed time after a forced sync.)*

## Reproduce it yourself

Enrol a lab device, assign one simple rule (e.g. require BitLocker), force a sync from Company Portal, then watch the state move from *Not evaluated* → *Compliant* — both in **Devices > Monitor** and in the Device Hygiene snapshot.

## Related & next
- **Surfaces this data:** [Device Hygiene](../../scripts/device-hygiene.md) script + report.
- **Next in the series:** how Windows Autopatch orchestrates update rings (coming soon).

---
*Sources: Microsoft Learn — [Device compliance policies overview](https://learn.microsoft.com/en-us/intune/device-security/compliance/overview) and [Monitor compliance policies](https://learn.microsoft.com/en-us/intune/device-security/compliance/monitor-policy).*
