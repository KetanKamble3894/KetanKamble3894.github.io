---
title: "Passkey readiness as live Entra groups"
description: "Microsoft is retiring SMS and voice MFA for passkeys. A read-only runbook that sorts every Entra user into a method group and keeps those groups current."
date: 2026-10-22
slug: passkey-readiness-entra-auth-method-groups
draft: false
comments: true
categories:
  - Behind the portal
  - Entra ID
  - Compliance
tags:
  - Entra ID
  - Microsoft Graph
  - Authentication methods
  - Passkey
  - Conditional Access
  - Managed Identity
---

# Before SMS and voice MFA retire, know who is passkey-ready, as a group

![Cover: Microsoft retiring SMS and voice MFA and defaulting to passkeys, and a read-only runbook that sorts every Entra user into method-strength groups so the telephony-only list is ready to act on](../../assets/img/banners/auth-method-readiness-groups.webp){ .post-cover width="1200" height="630" fetchpriority=high }

Microsoft has put a date on something a lot of us have been meaning to get to. Passkeys are becoming the default, and Microsoft-provided SMS and voice are being retired as authentication methods. So the question stops being "should we move people off text-message codes" and becomes "who is still on one, and can we see that list today."

We needed an honest answer to that, as a thing we could act on and not just a number in a dashboard. Not just a count of how many people are on phone-based MFA, but the actual users, split by how strong their method really is, kept current, and sitting in groups we can point a Conditional Access policy or a comms campaign at. This is the read-only runbook we built to produce that, and the way it keeps the groups in sync without ever being allowed to break anyone's sign-in.

<!-- more -->

<div class="hook-embed" markdown="0">
<iframe scrolling="no" src="/assets/hooks/auth-method-readiness-groups.html" title="Before and after: authentication method registration data sitting flat, then sorted into live Entra groups per method strength, with the telephony-only group ready to target before SMS MFA retires" loading="lazy" style="display:block;width:100%;aspect-ratio:1200/470;border:0;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.35)"></iframe>
</div>

!!! success "The payoff"
    Microsoft is making passkeys the default and retiring Microsoft-provided SMS and voice MFA on 1 February 2027 for most users. This is a read-only runbook that reads the Entra authentication-method registration report, sorts every in-scope user into one group by their strongest method (phishing-resistant, strong, telephony-only, nothing), and keeps those assigned groups in sync. It defaults to a dry run, writes a CSV of every change, and has four gates before it removes anyone. The telephony-only group is the one that matters right now: it is your migration list, ready to target.

## The deadline that makes this worth doing now

Microsoft announced in message center post MC1426371 that it is turning passkeys on by default and retiring Microsoft-provided SMS and voice as authentication methods. The reasoning they give is blunt: text-message and phone-call codes do not hold up against modern phishing and AI-assisted attacks. The dates are set. Passkeys become the default on 1 September 2026, and Microsoft-provided SMS and voice are retired on 1 February 2027 for everyone except global administrators and external users, who get until 1 July 2027. That split is the reason the runbook keeps members and internal guests in scope and drops external guests, their deadline is the later one.

The practical problem is that you can't move people you can't see. "Turn off SMS" is easy. Knowing which 600 or 6,000 accounts will lose their only working method the day you do it is the hard part, and that's a reporting problem before it's a policy problem.

## What we actually need to know

A flat count isn't enough. For every active user we want their strongest registered method, because that is what decides whether they sail through the change or get locked out:

- phishing-resistant: a passkey, FIDO2 key, Windows Hello for Business, a platform credential. These people are already where Microsoft wants everyone.
- strong but not phishing-resistant: Authenticator push or passwordless, a software or hardware one-time passcode, a third-party MFA like Duo. Fine today, not the end state.
- telephony-only: the only thing registered is a phone number, SMS or voice. This is the group that breaks when the method retires.
- nothing usable: no method, or only self-service password reset answers, which aren't MFA.

Sort every person into exactly one of those by their strongest method and the telephony-only bucket becomes your migration list. That is the whole point.

## Read-only to classify, gated to change

The thing that reads your entire directory and everyone's registered methods is the last thing you want holding write access. So it does not have any. It runs as a managed identity with read-only Graph scopes, reads the users and the registration report, and classifies in memory. Even the group sync, which does eventually write, defaults to a dry run and changes nothing until a person sets one parameter. Give the automation the data, never standing permission to lock people out.

## Why these are assigned groups, not dynamic

The natural instinct is a dynamic group: "members where their strongest method is a phone number." You can't write that rule. Dynamic membership rules run on directory attributes on the user object, and a person's registered authentication methods aren't attributes on the user, they come from a separate report. There's no dynamic rule that can read registration state, the same way there wasn't a dynamic rule for "has this app installed" in the Intune world.

So these are assigned groups, created once by hand, and kept in sync by the runbook off the report. From where you sit the result behaves like a dynamic group, the membership updates itself on every run, it just gets driven by the runbook instead of a membership rule, because no rule can read registration state. This is the operational-groups idea, a group you maintain by automation because a dynamic rule cannot express what you need. Nathan McNulty has shared scripts and writing on operational groups in Entra, and his GitHub is worth a read for the broader pattern. This runbook was built on our own for our own requirement, I did not take code or logic from there, but credit to him for putting the idea out in the open. The runbook here never creates, renames or deletes a group. It only ever adds and removes members, and only to groups you made first.

One setup choice worth knowing: you can nest the phishing-resistant and strong groups inside a parent "System Preferred MFA" group and point the system-preferred MFA policy at the parent, so the two already-fine groups drive that policy together. The nesting is a one-time manual step. The runbook does not touch the parent, it just keeps the two leaf groups current underneath it.

## How it works

<div class="mermaid-live" markdown="0">
--8<-- "assets/diagrams/auth-method-readiness-groups.svg"
</div>

It reads the users and the registration report, classifies every in-scope user into one group, writes the summary and the per-group CSVs, and then, only if you asked it to apply, reconciles each assigned group's membership to match. Reads and CSVs always happen. Writes only happen when you flip the dry run off, and only after the gates below pass.

## The classification, in precedence order

Each registered method maps to a class. The map is explicit so a new or renamed Graph value is caught rather than guessed:

```powershell
$MethodClassMap = @{
    'fido2SecurityKey'                = 'PhishingResistant'
    'passKeyDeviceBound'              = 'PhishingResistant'
    'windowsHelloForBusiness'         = 'PhishingResistant'
    'macOsSecureEnclaveKey'           = 'PhishingResistant'
    'microsoftAuthenticatorPush'      = 'Strong'
    'softwareOneTimePasscode'         = 'Strong'
    'hardwareOneTimePasscode'         = 'Strong'
    'externalAuthMethod'              = 'Strong'       # third-party MFA, satisfies MFA, not phishing-resistant
    'mobilePhone'                     = 'Telephony'
    'officePhone'                     = 'Telephony'
    'email'                           = 'SsprOnly'     # password reset only, not MFA
    # ... see the full map on the scripts page
}
```

Then a user lands in one group by their strongest method, strongest first. The order is the whole decision:

```powershell
$group =
    if     ($hasPR)               { 'PhishingResistant' }   # a passkey beats everything else they hold
    elseif ($hasStr)              { 'StrongNotPR' }
    elseif ($hasUnk)              { 'Review' }              # an unrecognised value never auto-decides
    elseif ($hasTel)              { 'TelephonyOnly' }       # the migration list
    elseif (-not $reg)            { 'NoRegistrationData' }
    elseif ($methods.Count -eq 0) { 'NoMfa' }
    else                          { 'Review' }
```

Two deliberate choices in there. A value Graph returns that the map does not recognise never decides a group on its own, it goes to a Review group for a person to look at and is listed in the summary, so a future Microsoft rename can never silently misfile someone into "safe". And device-bound phishing-resistant methods (Windows Hello, Secure Enclave) are counted as phishing-resistant but also flagged separately, because a credential tied to one laptop doesn't help that person on a phone browser or a loaner machine. That is reported, not yet its own group.

## Turning the classification into groups, without breaking sign-in

The classification half is harmless. The sync half can remove a user from a group, and a wrong removal here is a Conditional Access policy suddenly not applying to someone. So the write path is gated. It defaults to a dry run, and even when you turn that off, four checks stand between the classification and an actual change:

A coverage gate. If fewer than 90 percent of in-scope users have a registration row, the run aborts. That pattern means a throttled or failed read, not a tenant with no MFA, and publishing a membership list off a bad read is how you empty a group by accident.

```powershell
if ($inScopeCoverage -lt ($MinCoveragePercent / 100)) {
    throw "In-scope coverage is only $([int]($inScopeCoverage*100))%, below the $MinCoveragePercent% floor. " +
          "That points at a failed or throttled read. Aborting rather than publishing a misleading list."
}
```

A partition check. The membership groups must account for every classified user exactly once, no gaps and no double counting, or nothing is applied.

A removal gate, with an honest exception. A user moving from telephony-only to phishing-resistant is an explained removal from the old group, and that is the campaign working, so it always applies. Only users who vanished from the classification entirely (deleted, disabled, now out of scope, or a bad read) are gated, and if too large a share of a group would be removed for that reason, those removals are skipped and the moves still go through.

A group-shape guard. Before it writes, it refuses anything that is not a plain cloud security group. On-premises-synced, role-assignable, mail-enabled, and dynamic-membership groups are all skipped, so the runbook can never fight a dynamic rule or try to write a group it does not own.

```powershell
if ($g.onPremisesSyncEnabled)                       { return 'SKIPPED - on-premises synced' }
if (@($g.groupTypes) -contains 'DynamicMembership') { return 'SKIPPED - dynamic membership group' }
if ($g.isAssignableToRole)                           { return 'SKIPPED - role-assignable group' }
```

Only when all of that passes does it add in batches and remove through the audited batch path, writing a CSV of every add and remove as it goes.

## What the summary looks like

On a run it prints the group counts first. These are synthetic numbers on a sample tenant, your shape will differ:

```text
GroupKey             Members  NonHuman  ProposedName
--------             -------  --------  ------------
PhishingResistant    1840     0         Auth - Phishing-resistant Method Users
StrongNotPR          2210     0         Auth - Strong Method Users
TelephonyOnly        430      22        Auth - Telephony Only Users
NoMfa                85       0         Auth - No Method Registered Users
NoRegistrationData   12       0         Auth - No Registration Data Users
Review               6        0         Auth - Manual Review Users
```

That TelephonyOnly row is the headline. 430 people, 22 of them non-human accounts that get excluded, so 408 real users to move before the method retires. The run ends by saying exactly that in a line you can drop into a status update, and it tracks the number down over time as the campaign runs.

!!! note "Coming next: the Power BI report"
    These CSVs are the raw material. A detailed Power BI report that sits on top of them is coming soon, so you can watch the telephony-only number trend down week over week and slice it by department and account type. This post is the groups and the runbook that keep them current, the report is the next piece.

## The telephony-only list is the one that matters right now

Every other group is useful, but the telephony-only group is the one with a clock on it. Point a Conditional Access report-only policy at it to see who would be affected. Hand it to the service desk as the call list. Drive a registration campaign at it and watch it shrink run over run. When SMS and voice retire, the people in that group are exactly the ones who would have lost access, and you dealt with them on your schedule instead of on the cutover morning.

## What each group is for

The telephony-only group gets the attention, but every group has a job once it exists. The telephony-only one is the migration list you act on now; the phishing-resistant and strong groups are the ones you can nest under a System Preferred MFA parent and drive policy with; the rest are triage. This is the whole point of making them groups instead of a spreadsheet, each one is something a policy, a campaign or a person can be pointed at.

<div class="mermaid-live" markdown="0">
--8<-- "assets/diagrams/auth-method-readiness-groups-use.svg"
</div>

## Gotchas from the lab

- The registration report is a report, not the user object. That is the whole reason a dynamic group cannot do this, and it is also why coverage can lag reality by a bit. Read the in-scope coverage line, not the raw ratio.
- Device-bound phishing-resistant is not the same as portable. Someone whose only passkey is Windows Hello on one laptop is phishing-resistant on that laptop and stuck on a phone browser. The runbook flags this; decide whether that is good enough for your risk.
- SSPR methods are not MFA. Email and security questions satisfy self-service password reset, not multi-factor, so a user with only those is in the "nothing usable" group, not a safe one.
- employeeType is the clean signal for service and admin accounts, when HR fills it in. Name patterns are the fallback, and short fragments like "sa" will hit real names, so the name match is deliberately narrow and anything it cannot place goes to Review.
- Dry run first, every time. The gates exist, but the cheapest safety is reading the proposed changes before you ever let it write. The default is a dry run for a reason.

## Why this is the pattern

This is the same move as everything else here. The part that reads your whole directory holds no write access. The part that writes is gated, defaults to doing nothing, and can only touch groups you made yourself. The deadline is Microsoft's, but the list is yours, and you get to work it down on your own terms rather than finding out who was telephony-only on the day it stopped working.

## References, Microsoft and community documentation

- **MC1426371, Passkeys by default and retirement of Microsoft-provided SMS and voice** (Microsoft Entra message center): [mc.merill.net/message/MC1426371](https://mc.merill.net/message/MC1426371)
- **Passkeys by default and retirement of Microsoft-provided SMS and voice authentication** (Microsoft Learn, the authoritative dates): [learn.microsoft.com](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-sms-voice-retirement)
- **userRegistrationDetails resource type** (Microsoft Graph, the report this reads): [learn.microsoft.com](https://learn.microsoft.com/en-us/graph/api/resources/userregistrationdetails)
- **Nathan McNulty on GitHub** (scripts and writing on operational groups in Entra, independent prior art on the pattern, this runbook took no code from it): [github.com/nathanmcnulty/nathanmcnulty](https://github.com/nathanmcnulty/nathanmcnulty)
- **Operational groups in Entra** (entra.news, related reading on maintaining assigned groups by automation): [entra.news/p/operational-groups-in-entra-with](https://entra.news/p/operational-groups-in-entra-with)

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Can a dynamic group target users by their registered authentication method?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "No. Dynamic membership rules evaluate directory attributes on the user object, and a user's registered authentication methods are not user attributes, they come from the separate authentication-method registration report. So you use assigned (operational) groups kept in sync by automation instead."
      }
    },
    {
      "@type": "Question",
      "name": "Is Microsoft really retiring SMS and voice MFA?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Yes. In message center post MC1426371 Microsoft announced passkeys becoming the default and the retirement of Microsoft-provided SMS and voice as authentication methods, with a timeline running into 2027. The authoritative dates are on Microsoft Learn under the SMS and voice retirement concept page."
      }
    },
    {
      "@type": "Question",
      "name": "Does this runbook change anything in my tenant?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Not by default. It runs read-only and only produces CSVs. The optional group sync defaults to a dry run and changes nothing until you set one parameter, and even then it only adds and removes members of groups you created, never creating, renaming or deleting a group, and only after a coverage, partition, removal and group-shape gate pass."
      }
    },
    {
      "@type": "Question",
      "name": "What counts as phishing-resistant versus strong?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Phishing-resistant means passkeys, FIDO2 security keys, Windows Hello for Business and platform credentials. Strong-but-not-phishing-resistant means Authenticator push or passwordless, software or hardware one-time passcodes, and third-party MFA such as Duo. Telephony means SMS or voice only, which is the method being retired."
      }
    }
  ]
}
</script>

---

*Personal lab pattern. All examples use synthetic values, there is no real tenant, user, group or storage account here. Verify authentication-method behaviour and the retirement dates in your own tenant and on Microsoft Learn. Independent content, not affiliated with, sponsored by, or endorsed by Microsoft. Microsoft, Entra, Microsoft Graph and Azure are trademarks of the Microsoft group of companies.*
