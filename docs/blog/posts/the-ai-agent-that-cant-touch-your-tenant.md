---
description: An AI agent that answers questions about your whole endpoint fleet in plain English — with zero access to Intune, Graph or any live system.
date: 2026-10-06
slug: the-read-only-ai-agent-that-cant-touch-your-tenant
draft: false
comments: true
categories:
  - Behind the portal
  - AI
  - Power BI
tags:
  - Intune
  - Microsoft Graph
  - Azure AI Foundry
  - Azure AI Search
  - Zero Trust
---

# The read-only AI agent that can't touch your tenant

![Cover: a read-only AI agent answering endpoint questions from sanitized snapshots, with no live tenant access](../../assets/img/banners/zero-access-agent.webp){ .post-cover width="1200" height="630" fetchpriority=high }

"How many devices fail Firewall in Finland?" "Which Lenovos are out of warranty in the Madrid office?"
"Is Ollama installed anywhere, and is it approved?" You want to *ask* your fleet those questions in plain
English and get an answer in seconds. The obvious way to build that — hand an AI model live access to
Intune and Microsoft Graph — is also the most dangerous. This is the capstone of everything on this site:
an AI agent that answers all of it, and holds **no access to any live system at all**.

<!-- more -->

<div class="hook-embed" markdown="0">
<iframe src="/assets/hooks/the-ai-agent-that-cant-touch-your-tenant.html" title="Animated: the write an AI agent could make versus the write it can’t — the one-way valve" loading="lazy" style="width:100%;aspect-ratio:1200/470;border:0;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.35)"></iframe>
</div>

!!! success "The payoff"
    Answering “which disabled users still hold a Teams Phone licence?” normally means a specialist writing a Graph query. Here anyone asks in plain English and gets a cited answer from the read-only snapshot — the insight without granting an AI any power to change your tenant. That last part is the point: there is no write path back.

!!! tip "The short version"
    An Azure AI Foundry agent answers natural-language questions about the entire endpoint estate — but it
    has **no Graph scopes, no keys, no connection to Intune or Entra**, and it cannot act. It reads only from
    two Azure AI Search indexes built from the **read-only, sanitized snapshots** the ten collectors on this
    site produce. Worst case, it reads a dated, minimised snapshot — it can never see or touch the live
    tenant. That containment *is* the design.

## Why not just give the AI access to Graph?

Because "give the AI access to Graph" quietly grants three things you can't take back:

- **Standing scopes.** A live agent needs a token with `DeviceManagement...Read.All` (and people always
  creep it to ReadWrite "just for this one action"). That token now exists, refreshes forever, and is one
  prompt-injection away from being misused.
- **The ability to act.** The moment the agent can call Graph, "remediate that" or "wipe that device" is a
  function call away — an LLM one injected instruction from *wipe that device* is not a tool, it's a hazard
  wired straight into production.
- **Live data in the model's context.** Every question pulls real tenant data — names, emails, device IDs —
  through the model. That's a data-governance surface you now own on every single query.

The whole point of this project is to get the natural-language answer **without** any of that. The trick is
to separate *reading the estate* from *answering about the estate* — and to make sure the thing answering can
only ever see a **sanitized, dated copy**.

## The architecture: collect read-only, answer from snapshots

![The Zero-Access Pattern: the M365 tenant (Intune, Entra, Defender) is read by read-only collectors on Azure Automation Managed Identity, which write minimised, dated sanitized CSV snapshots to immutable Blob Storage; Azure AI Search indexes them and an AI Foundry agent answers in plain English, while Power BI reads the same snapshot — the guarantee bar reads read-only, only .Read.All Graph scopes, no write or action, the AI never touches a live system](../../assets/img/zero-access-architecture.svg){ .kk-zoom width="1280" height="640" fetchpriority=high }

Five stages, and the containment lives in the seams between them:

1. **Collect** — the ten [read-only collectors](../../projects/zero-access-agent/index.md) run as scheduled
   Azure Automation runbooks under a Managed Identity, holding **only `*.Read.All` Graph scopes — no write
   or action permission of any kind**. (Some reads are `POST` requests — the reports export API and `$batch`
   are read operations that happen to use POST — so the guarantee is the *scopes granted*, not the HTTP
   verb.) Each runbook pre-aggregates its data and writes a sanitized CSV, plus a `_Stats` file with the
   counts already computed.
2. **Store** — the CSVs land in Azure Blob: the full files feed Power BI; slim, snapshot copies feed the agent.
3. **Index** — two Azure AI Search indexers ingest from Blob into **two indexes**:
    - a **structured index** — one search document per report row (hundreds of thousands of rows across all
      the reports: inventory, compliance settings, app failures, hygiene, Autopilot, licences, AI-tool
      detections). This is the "how many / which / where" half.
    - a **documents index** — the rendered Intune configuration documentation, chunked and **vector-embedded**
      (`text-embedding-3-small`) with semantic ranking. This is the "how is it configured / why" half.
4. **Answer** — an **Azure AI Foundry agent** (a GPT model) whose **only tool is Azure AI Search**. No Graph
   connector, no code interpreter, no ability to call out. It can search the two indexes and nothing else.
5. **Ask** — you type a question; the agent searches, grounds its answer in the retrieved rows, and always
   names the report the fact came from.

It trades **freshness for containment**: answers are as current as the last snapshot, not live. For "who
owns this device / why did it fail / how many of X" that trade is invisible — and it's the whole point.

## The two halves of the fleet's knowledge

The split between the two indexes is deliberate, and it maps exactly onto the ten spokes:

- **Structured facts** — every collector's CSV becomes rows the agent can retrieve and cite: a device's
  serial and Defender health from [Inventory](../one-row-per-device-building-the-inventory-intune-wont-hand-you/);
  the failing setting from [Non-Compliant](../which-setting-actually-failed-turning-intune-non-compliance-into-a-report/);
  the recommended action from [Device Hygiene](../the-devices-no-one-owns-anymore-a-read-only-hygiene-report-with-recommended-actions/);
  and so on across all ten. (Warranty is the one field Graph doesn't hold — it's an **OEM lookup** folded
  into the inventory snapshot via the fenced enrichment utility below, not a Graph read.)
- **Pre-computed counts** — every "how many" is answered **only** from a `_Stats` report (a
  `Category / Key / Count` table the runbook computed), never by counting search results — because the agent
  only ever sees the rows it *retrieved*, a partial set, so a hand count is always wrong. This one rule is
  why the agent's numbers match Power BI instead of drifting.
- **Prose documentation** — the [Intune Documentation](../documentation-that-writes-itself-a-read-only-snapshot-of-your-whole-intune-config/)
  collector's HTML feeds the documents index, so "how does compliance work here" is answered from *your*
  documentation, not the model's general knowledge.

## The safety layer is the system prompt

Zero live access is the structural guarantee. But an ungoverned LLM will still confidently make things up,
count wrong, or over-share. So the agent's **instructions** are the second half of the design — the part most
"chat with your data" demos skip. The real guardrails (sanitized):

- **Read-only identity, stated up front.** "You have NO access to Intune, Graph, Entra, Defender or any live
  system, and you cannot make changes. You never use web search." If asked to remediate, it explains it
  can't and names the team that can.
- **Mandatory search — no memory.** It is *forbidden* from saying something "doesn't exist" unless it
  searched **this turn** and got zero rows. It can't answer from a previous turn's memory; it re-searches
  every time. That single rule kills the most common RAG failure — confidently denying data that's right
  there.
- **Count only from the stats reports.** Every total routes to the matching `_Stats` category; if there's no
  matching key, it says the exact count isn't available rather than estimating.
- **"Absence isn't evidence."** For the [shadow-AI inventory](../whos-running-ollama-on-your-fleet-a-read-only-shadow-ai-inventory/),
  a device with no rows is *not* "clean" — clean devices are deliberately excluded from the index to keep it
  small. The prompt forbids ever calling a device clean, and explains exactly when zero rows means "unknown."
- **Detected ≠ used, sanctioned ≠ approved.** It distinguishes a process that was *running* from a binary
  that's merely *installed*, and "on the Microsoft AI baseline" from "approved by the software board" — so it
  never brands a person non-compliant off the wrong field.
- **Everything is dated, and cited.** Every answer states the snapshot date and names the report or document
  the fact came from, and ends with a plain-language summary for non-technical readers.

## What it looks like in use

Ask it a real operational question and it searches the snapshots, answers, and tells you which report it
used — with a plain-language summary underneath.

![The Zero-Access Agent answering an endpoint question from the read-only snapshots — the answer cites its source report and dates the snapshot (synthetic lab data)](../../assets/img/zero-access-agent-answer.png){ .kk-zoom loading=lazy width="1512" height="880" }

## Why "zero access" is the point, not a limitation

Line the two designs up:

- **Live-access agent:** holds a refreshable Graph token, can act, streams real tenant data through the model
  on every query. Compromise it — via prompt injection, a leaked key, or a bad function call — and the blast
  radius is your production fleet.
- **Zero-access agent:** holds no token and no connection; its entire world is two read-only search indexes of
  sanitized, dated snapshots. There is nothing to act on and nothing live to leak. The worst case is that
  someone reads a snapshot they could already pull from the Power BI report.

You give up real-time freshness. In exchange the agent **cannot** change anything, **cannot** reach the tenant,
and **cannot** surprise you. For an endpoint estate, that's the right trade.

!!! warning "Be honest about what the prompt can and can't guarantee"
    Two different guarantees live here, and it's worth not conflating them. **Structural** containment — no
    token, no actions, no live connection — is enforced by the *architecture*, and it holds even if the model
    is prompt-injected. **Personal-data** protection is different: the snapshots still carry owner, manager
    and location because support answers need them, and a system prompt is a *soft* control — an injected
    instruction, or anyone holding the Search query key, can bypass "don't enumerate people." So the real
    control is **minimising at the collector**: drop the fields a report doesn't need, pre-aggregate the
    sensitive ones (shadow-AI to counts), and lock the Search key down with RBAC — *then* let the prompt add
    its no-profiling, no-enumeration layer on top. The prompt hardens behaviour; the collector and RBAC are
    what actually protect the data.

!!! info "One honest exception"
    The zero-access guarantee covers the collection → agent path. The project ships **one** optional,
    human-run enrichment utility that can write device warranty into the Notes field — it's fenced off,
    opt-in, defaults to a read-only report, and named openly rather than hidden. The agent never touches it.

## The ten collectors that feed it

Every answer the agent gives traces back to one of these read-only collectors — the ten spokes of this series:

- [Non-Compliant Devices](../which-setting-actually-failed-turning-intune-non-compliance-into-a-report/) — the failing setting, per device
- [Inventory — All Devices](../one-row-per-device-building-the-inventory-intune-wont-hand-you/) — the enriched backbone table
- [Intune Documentation](../documentation-that-writes-itself-a-read-only-snapshot-of-your-whole-intune-config/) — the prose half of the agent's knowledge
- [Policy Assignments](../every-policy-every-target-the-assignment-map-intune-wont-draw-for-you/) — every policy → every target
- [Device Hygiene](../the-devices-no-one-owns-anymore-a-read-only-hygiene-report-with-recommended-actions/) — stale/orphaned devices + owner
- [App Deployment Failures](../which-app-is-failing-and-why-turning-intune-app-errors-into-a-triage-board/) — failures triaged per app
- [License Compliance](../whos-missing-an-intune-license-finding-the-devices-slipping-through/) — the licence-gap list
- [Windows 11 Readiness](../which-devices-cant-take-windows-11--the-hardware-blocker-per-device/) — the hardware blocker, per device
- [Autopilot Operations](../where-autopilot-actually-breaks-esp-phase-failure-category-per-deployment/) — ESP phase + failure category
- [Local AI Agent Inventory](../whos-running-ollama-on-your-fleet-a-read-only-shadow-ai-inventory/) — shadow-AI, read-only

## Build it yourself

The full walkthrough — empty subscription to read-only runbooks, the two indexes, and the agent — lives on
the project page.

## FAQ

**Does the agent connect to Intune or Graph?** No. Its only tool is Azure AI Search over two read-only
indexes. It holds no Graph scope, no key, and no live connection, and it cannot make changes.

**How current are the answers?** As current as the last snapshot, not live — the collectors run on a schedule.
The agent always states the snapshot date, and for real-time status it tells you to check the Intune console.

**Can it leak personal data?** The structural risk (acting on the tenant, streaming live data) is removed by
design. Personal data in the snapshots is controlled by minimising at the collector and locking the Search
key with RBAC, with the agent's no-enumeration / no-profiling rules as a second layer.

## Related

- :material-rocket-launch: **Build it yourself** → [Zero-Access Agent](../../projects/zero-access-agent/index.md)
- :material-format-list-bulleted: **The full series** → [Behind the portal](../index.md)

---

*Screenshots use synthetic data from a personal lab — no real tenant, users, or devices. Independent content,
not affiliated with, sponsored by, or endorsed by Microsoft. Microsoft, Intune, Entra, Microsoft Graph, Azure,
Defender and Power BI are trademarks of the Microsoft group of companies.*
