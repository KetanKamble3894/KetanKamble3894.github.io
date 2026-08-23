---
title: "Governing Intune device wipes with Multi Admin Approval"
description: "Intune Multi Admin Approval puts device wipe and retire behind a second admin, but nobody watches the queue. A read-only runbook that alerts, tickets and reports."
date: 2026-08-19
slug: governing-device-wipes-multi-admin-approval
draft: false
comments: true
categories:
  - Behind the portal
  - Intune
  - Compliance
tags:
  - Intune
  - Microsoft Graph
  - Multi Admin Approval
  - Managed Identity
  - Zero Trust
---

# Governing Intune device wipes with Multi Admin Approval

![Cover: an Intune device-wipe request stopped at a two-person approval gate, with a read-only runbook alerting and reporting on every approval](../../assets/img/banners/maa-wipe-retire-governance.webp){ .post-cover width="1200" height="630" fetchpriority=high }

A while back a device wipe request sat in our Intune approval queue for most of a day before anyone noticed it. Nothing was broken. That is just how Multi Admin Approval works, and it is the gap this post is about.

If you have turned MAA on for device wipe and retire, you already know the good part. One admin asks for the wipe, a different admin has to approve it, and no single person can factory reset a laptop on their own. I like it. It is the kind of guardrail that should have been in the product years ago.

Here is the part nobody warns you about. Microsoft gave you the gate, but it forgot the doorbell. There is no email when a request comes in, no ticket, nothing shows up on a dashboard. It quietly assumes someone is sitting in Tenant administration > Multi Admin Approval > Received requests all day, and in real life nobody does that. So legitimate wipes stall, the service desk opens "wipe not working" tickets that were never broken, and months later nobody can tell you who approved what.

I did not want to give my one admin a new job of babysitting that screen. So I built the missing half instead. It is a small read-only runbook that watches the queue, emails the service desk the moment a request lands, and keeps its own history for Power BI. It can read the approval requests and nothing else. It cannot approve, it cannot reject, it cannot wipe. Below is how it works and how to set it up in your own tenant.

<!-- more -->

<div class="hook-embed" markdown="0">
<iframe scrolling="no" src="/assets/hooks/maa-wipe-retire-governance.html" title="Before and after: without a doorbell an MAA wipe request stalls unwatched in the portal; with a read-only runbook the same request pings the service desk, raises a ticket, and is recorded" loading="lazy" style="display:block;width:100%;aspect-ratio:1200/470;border:0;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.35)"></iframe>
</div>

!!! tip "The short version"
    Turn on an MAA access policy for Device wipe and retire so both need a second admin. Scope the approvals through a custom Intune role, an approver group and Entra PIM, so approver rights are just in time. Then a scheduled runbook runs as a Managed Identity that holds only `DeviceManagementConfiguration.Read.All`, lists `operationApprovalRequests`, emails the service desk on new pending ones, and writes a merged history CSV that outlives Intune's own retention and feeds the read-only AI agent. Nothing in the reporting path can approve or act.

## The problem: one admin, one click, and it is gone

Intune's Wipe and Retire actions cannot be undone from the user side. Wipe resets the device back to factory, retire pulls the company data and management off it. Any admin with the right role can fire either one on any device in their scope. That is fine until it is not, a wrong bulk action, a compromised admin account, or someone on their last day. For actions this destructive the normal answer is two person control, and Intune has it built in.

**Scope note:** the MAA Device actions policy protects wipe, retire and delete together as one group. You cannot turn it on for just wipe and retire, so deleting the device record is gated too. I use wipe and retire as the example here because they are the destructive ones. Selective wipe (the app protection data removal) and Autopilot reset are not covered and behave exactly as before, worth saying so nobody thinks every remote action is suddenly gated.

## The gate: an MAA access policy for wipe and retire

Multi Admin Approval works through access policies. You create a policy that says this class of action now needs approval, and after that any admin who triggers it does not perform the action. They raise an approval request that a different admin has to approve first.

For destructive device actions the policy covers the Device wipe and retire action type. Once it is on:

1. Admin A selects Wipe on a device and adds a business justification (put the ticket number in there).
2. Instead of wiping, Intune creates an approval request with status `needsApproval`.
3. Admin B, who is not Admin A because self approval is blocked, reads the justification and approves or rejects.
4. Approval does not run the action. This is the part people get wrong most often. Once it is approved, the original requestor has to go back to My requests and press Complete. Only then does the wipe run. Approved is not the same as wiped.

That request object is the thing this whole governance layer watches, read-only.

## What the built-in feature leaves out

So the gate works. The problem is what happens after a request is raised. MAA creates it and then just waits. No email, no ticket, no dashboard. The whole design assumes an approver is watching the Received requests blade, and that is a habit nobody keeps. In practice that means:

- Legitimate wipes stall. A stolen laptop wipe sits pending because nobody happened to be looking at the portal.
- "Wipe not working" tickets pile up. The service desk troubleshoots a wipe that is not broken, it is just waiting for approval.
- There is no record. Six months later, who approved wiping that device and why has no answer.

None of that is a reason to skip MAA. It is a reason to stop relying on someone remembering to look, and let a read-only runbook be the thing that watches.

## The permission the reporter needs, and nothing more

The reporter reads Intune with no stored secret and no human sign in. It uses a system assigned Managed Identity on the Azure Automation account, with a single read-only Graph application permission.

The grant is the important bit. The Automation account's Managed Identity is a service principal in Entra, and you give it the least privilege app role for this job, `DeviceManagementConfiguration.Read.All`. That is all it needs to list the approval requests. You do not grant `DeviceManagementRBAC.ReadWrite.All` or anything that can approve or wipe. So the identity that reports on approvals simply cannot approve one.

App role grants are not in the portal UI, so you assign it once with Graph (run it as an admin who can consent):

```powershell
# One-time: grant the Automation account's Managed Identity a READ-ONLY Graph scope.
Connect-MgGraph -Scopes "Application.Read.All","AppRoleAssignment.ReadWrite.All"

$graphSpId  = (Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'").Id
$miObjectId = "<automation-account-managed-identity-object-id>"   # Automation account > Identity blade
$roleValue  = "DeviceManagementConfiguration.Read.All"            # least privilege to LIST requests

$appRole = (Get-MgServicePrincipal -ServicePrincipalId $graphSpId).AppRoles |
    Where-Object { $_.Value -eq $roleValue -and $_.AllowedMemberTypes -contains "Application" }

New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $miObjectId -BodyParameter @{
    principalId = $miObjectId; resourceId = $graphSpId; appRoleId = $appRole.Id
}
```

That is the entire standing permission this solution holds against your tenant. Read the approval requests, nothing else.

## The runbook: list, alert, keep the history

With the identity in place, the runbook signs in as the Managed Identity, lists the requests on the beta endpoint, spots the new pending ones, emails the service desk, and appends to a history file it keeps itself. Here is the core of it, sanitized:

```powershell
# READ-ONLY. MI holds only DeviceManagementConfiguration.Read.All. All values synthetic.
Connect-MgGraph -Identity        # no secret

# 1) READ: list every approval request (beta). Nothing here can approve or wipe.
$graph = "https://graph.microsoft.com/beta/deviceManagement/operationApprovalRequests"
$live  = @(); $u = $graph
do { $p = Invoke-MgGraphRequest -Method GET -Uri $u; $live += $p.value; $u = $p.'@odata.nextLink' } while ($u)

# 2) ALERT: email the service desk about NEW pending requests (watermark dedupe).
$lastCheck  = try { [datetime](Get-AutomationVariable -Name 'MAA-LastCheck') } catch { (Get-Date).AddDays(-1) }
$runStart   = (Get-Date).ToUniversalTime()
$pendingNew = $live | Where-Object { $_.status -eq 'needsApproval' -and [datetime]$_.requestDateTime -gt $lastCheck }

if ($pendingNew) {
    $html = ($pendingNew | ForEach-Object {
        "<tr><td>$($_.requiredOperationApprovalPolicyTypes -join ',')</td>" +
        "<td>$([System.Net.WebUtility]::HtmlEncode($_.requestor.user.displayName))</td>" +
        "<td>$([System.Net.WebUtility]::HtmlEncode($_.requestJustification))</td>" +
        "<td>$($_.requestDateTime)</td><td>$($_.id)</td></tr>" }) -join "`n"
    Send-MailMessage -SmtpServer "smtp.contoso.com" -Port 587 -UseSsl -Credential $relayCred `
        -From "intune-maa@contoso.com" -To "servicedesk@contoso.com" -BodyAsHtml `
        -Subject "ACTION REQUIRED: Intune wipe/retire approval pending ($($pendingNew.Count))" `
        -Body "<table border=1><tr><th>Operation</th><th>Requestor</th><th>Justification</th><th>Submitted</th><th>Id</th></tr>$html"
    # Advance the watermark ONLY after the alert actually sent (see gotchas).
    Set-AutomationVariable -Name 'MAA-LastCheck' -Value $runStart.ToString('o')
}

# 3) HISTORY: merge with existing CSV so records survive Intune's retention; upload for Power BI.
$history = Merge-ApprovalHistory -New $live -ExistingCsv "MAA_Requests_History.csv"   # upsert by RequestId
$history | Export-Csv "MAA_Requests_History.csv" -NoTypeInformation
# + a summary-stats CSV (counts by status, approval rate, by approver, time-to-decision).
```

Two choices in there matter. The Graph call is GET only, so the identity cannot approve, reject or wipe. Even if someone got into the runbook, it still cannot act. And the history is merged and kept by you, because Intune ages the approval requests out of its own store after a while, so your CSV becomes the durable audit record.

The full hardened runbook is on GitHub: **[`scripts/Report-MaaApprovals.ps1`](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Report-MaaApprovals.ps1)**. It has the Managed Identity token via `IDENTITY_ENDPOINT`, retry on 401 and 429 with `Retry-After`, defensive property parsing (in my tenant the beta payload put the requestor UPN under an undocumented property, so I do not assume `userPrincipalName`), the device details pulled from the `displayPayload` JSON, and the summary stats export.

!!! info "One reporter for every MAA policy, not just wipe and retire"
    Wipe and retire are the example, but the runbook lists all `operationApprovalRequests` whatever the type. MAA can protect other actions too, app deployments and scripts among them, and this same read-only reporter picks all of them up automatically. Turn on more MAA policies and you do not build a new automation each time, the one runbook alerts, tickets and reports on all of them.

## From alert to ticket to knowledge base

The email is not the end, it is the way into your existing ITSM. The generic flow, with synthetic names:

- The runbook emails a monitored service desk address (`servicedesk@contoso.com`) through an SMTP relay (`smtp.contoso.com`).
- Your ITSM watches that inbox and auto creates an incident, so each pending wipe becomes a tracked item with an owner and an SLA even when nobody is in the Intune portal.
- A short knowledge base article tells the service desk what the alert means, and that a "wipe not working" report is usually just a request waiting for approval, not a fault.

None of that writes to Intune. It is a read, a notification and a record. The tenant is never touched.

## The gate and the watcher, together

<div class="mermaid-live" markdown="0">
--8<-- "assets/diagrams/maa-wipe-retire-governance.svg"
</div>

The bottom half is the gate. An admin raises a wipe, the MAA policy turns it into an approval request, a PIM activated approver approves or rejects, and only then does the requestor complete the action so it runs. The top half is the read-only governance layer. The Managed Identity lists those requests over Graph, alerts the service desk which raises a ticket, and writes the durable history that Power BI reports on. The two halves only ever meet through a read. The reporter watches the gate, it never operates it.

## Set it up, step by step

The gate steps (1 to 3) change your tenant. The reporting steps (4 to 7) are all read-only.

1. **Create the MAA access policy** *(changes tenant)*. Add a Multi Admin Approval access policy for Device wipe and retire, assigned to the admins in scope.
2. **Create the approver role and group** *(changes tenant)*. A custom Intune role ("MAA Approvers") that grants only the approval permission, assigned to a group (`grp-MAA-Approvers`).
3. **Put the group behind PIM** *(changes tenant)*. Enable Entra PIM over the group so approver membership is just in time and audited.
4. **Stand up Azure Automation and the Managed Identity.** If you do not already run the collection layer, follow **[Setting up the collection layer](../../projects/zero-access-agent/azure-automation-setup.md)** to create the Automation account and enable its system assigned Managed Identity (no app registration, no secret). Every collector on this site shares that one setup, you build it once.
5. **Grant the read-only Graph scope.** Assign the MI `DeviceManagementConfiguration.Read.All` and nothing else (the one time script above).
6. **Import and schedule the runbook.** Import it as a PowerShell 7 runbook, publish it, and schedule it (every 15 minutes for timely alerts). Create a String Automation variable `MAA-LastCheck` for the watermark.
7. **Wire the outputs.** Point your ITSM at the service desk mailbox for auto ticketing, and point Power BI at the history CSV in Blob.

No secret is ever stored, and nothing in steps 4 to 7 can approve, reject or wipe.

## The report, and the AI agent

Because the runbook keeps a merged history plus a summary stats CSV, Power BI turns it into the view Intune will not give you. Approval volume over time, the approval versus rejection rate, time to decision, who requested and who approved, and a filterable audit table. Every number comes from the read-only CSV, the report holds no connection to the tenant.

The same summary stats snapshot also drops into the `agent-data/` feed for the [read-only AI agent](the-ai-agent-that-cant-touch-your-tenant.md). So "how many wipe approvals are pending right now" becomes a plain question answered from the dated snapshot, by an agent that, like this runbook, has no Graph scope and cannot approve or act. The governance data and the agent follow the same rule, read-only all the way down.

## Gotchas from the lab

- **Approved is not done.** After approval the original requestor has to Complete the action from My requests, approval on its own changes nothing (there is a fuller explanation in the FAQ).
- **The API is beta.** `operationApprovalRequests` lives on the Graph beta endpoint today, so pin to it on purpose, expect the shape to change, and re-check it in your own tenant.
- **Requests expire on a clock Microsoft controls.** Microsoft currently documents a 3 day expiry for unactioned requests. Treat that as something that can change and verify it in your tenant rather than building fixed logic around the number.
- **Least privilege is a choice, not a default.** It is tempting to grant `DeviceManagementRBAC.ReadWrite.All` "to be safe", but that would let the runbook approve requests. Grant `DeviceManagementConfiguration.Read.All` so it structurally cannot.
- **Intune ages requests out**, which is exactly why the runbook merges and keeps its own history CSV. Do not treat the tenant as your long term audit store.
- **Mail transport bites first.** Azure sandboxes block outbound port 25, and `Send-MailMessage` is officially obsolete, so send through an authenticated relay on 587 with TLS (a stored `PSCredential`, like the snippet), SendGrid, or your internal relay. There is a deliberate trade off here. Staying on SMTP keeps the identity read-only. Switching to Graph `sendMail` would add a `Mail.Send` write scope back and break the whole read-only idea. Scope the relay sender so it can only mail the service desk.
- **The doorbell should ring more than once.** The watermark alerts on each new pending request one time. A request that just sits there pending, the exact stall the intro is about, will not nudge you again on its own, so let the ITSM ticket's SLA carry the chase (or add an "aging pending over N hours" re-notify pass). The alert opens the ticket, and the ticket, not the runbook, is what chases it.

## FAQ

**What does Multi Admin Approval protect here?** The Device wipe and retire actions. A protected action turns into an approval request that a second, different admin has to approve, and then the requestor has to complete it.

**Does this only work for wipe and retire?** No, that is just the example. The runbook lists every approval request whatever the type, so it covers anything you protect with an MAA access policy, app deployments and scripts included. One runbook, all your MAA policies.

**Does the reporting runbook need write access to Intune?** No. It holds only `DeviceManagementConfiguration.Read.All` and does a GET. It cannot approve, reject or wipe, and that is the point.

**A wipe was approved but the device is untouched, is it broken?** Almost certainly not. Approval does not run the action, the original requestor has to go to My requests and Complete it. Until they do, nothing happens.

**Why keep your own history CSV?** Because Intune ages the approval requests out of its own store. Merging each run into a durable CSV gives you an audit trail that outlives that retention, and a stable source for Power BI and the AI agent.

**Can the runbook approve requests to speed things up?** On purpose, no. Auto approval would defeat the whole two person control. Approvals stay human through the PIM activated approver group, the runbook only watches and reports.

**Why a scheduled runbook and not a Logic App or event driven flow?** A Logic App with an ITSM connector is a perfectly good alternative and it cuts out the SMTP hop. I use a runbook because it reuses the one collection layer identity every report on this site shares (one Managed Identity, one read-only grant, no per flow licensing), and because the same run produces the durable history CSV that the Power BI report and the AI agent read, which a notification only flow would not. The trade off is polling latency, a 15 minute schedule can add up to 15 minutes before the alert fires, so tighten the schedule if minutes matter to you.

## More in this series

- [Graph 412: Intune MAA gates writes](multi-admin-approval-graph-api.md), what MAA does to app authenticated Graph writes.
- [The read-only AI agent that can't touch your tenant](the-ai-agent-that-cant-touch-your-tenant.md), where the summary stats snapshot goes next.
- [The 403 that started Zero-Access](zero-access-origin-story.md), where read-only by design came from.

## References, Microsoft documentation

- **Multi Admin Approval overview**, the access policy model for protected actions: [Use multi-admin approval in Intune](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/multi-admin-approval)
- **MAA with the Graph API**, how protected actions become approval requests: [Use Multi Admin Approval with the Microsoft Graph API](https://learn.microsoft.com/en-us/intune/fundamentals/role-based-access-control/multi-admin-approval-graph-api)
- **List operationApprovalRequests (beta)**, the read call this runbook makes: [List operationApprovalRequests](https://learn.microsoft.com/en-us/graph/api/intune-rbac-operationapprovalrequest-list?view=graph-rest-beta)
- **Azure Automation managed identity**, how the runbook runs with no stored secret: [Managed identities for an Azure Automation account](https://learn.microsoft.com/en-us/azure/automation/enable-managed-identity-for-automation)
- **Entra Privileged Identity Management**, just in time approver membership: [What is Privileged Identity Management?](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-configure)
- **Microsoft Graph permissions reference**, the `.Read.All` scope the identity holds: [Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference)

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "What does Multi Admin Approval protect here?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "The Device wipe and retire actions. A protected action becomes an approval request that a second, different admin must approve, and then the original requestor must complete it before it runs."
      }
    },
    {
      "@type": "Question",
      "name": "Does this only work for wipe and retire?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "No, that is just the example. The read-only runbook lists every operationApprovalRequest regardless of type, so it covers any action you protect with a Multi Admin Approval access policy, including app deployments and scripts. One runbook covers all your MAA policies."
      }
    },
    {
      "@type": "Question",
      "name": "Does the reporting runbook need write access to Intune?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "No. It holds only DeviceManagementConfiguration.Read.All and performs a GET. It cannot approve, reject, or wipe, and that is the point of the design."
      }
    },
    {
      "@type": "Question",
      "name": "A wipe was approved but the device is untouched, is it broken?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Almost certainly not. Approval does not run the action, the original requestor must go to My requests and choose Complete. Until they do, nothing happens to the device."
      }
    },
    {
      "@type": "Question",
      "name": "Why keep your own history CSV?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Because Intune ages approval requests out of its own store. Merging each run into a durable CSV gives you an audit trail that outlives retention, and a stable source for Power BI and the read-only AI agent."
      }
    },
    {
      "@type": "Question",
      "name": "Why a scheduled runbook and not a Logic App or event-driven flow?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "A Logic App is a fine alternative, but a runbook reuses the one read-only Managed Identity every report on the site shares and produces the durable history CSV the Power BI report and AI agent read. The trade off is polling latency, a 15 minute schedule can add up to 15 minutes before the alert fires, so tighten the cadence if minutes matter."
      }
    }
  ]
}
</script>

---

*Personal lab pattern. All names, addresses and identifiers are synthetic (`@contoso.com`, `WIN-*`), there is no real
tenant, user or device here. It uses a Microsoft Graph beta endpoint that can change, so verify it in your own
tenant. Independent content, not affiliated with, sponsored by, or endorsed by Microsoft. Microsoft, Intune,
Entra, Microsoft Graph, Azure and Power BI are trademarks of the Microsoft group of companies.*
