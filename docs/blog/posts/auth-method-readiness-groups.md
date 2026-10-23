---
title: "Entra SMS/voice MFA retirement: find phone-only users"
description: "Microsoft-provided SMS and voice MFA retires 1 Feb 2027 (MC1426371). This runbook finds phone-only Entra users and groups them by passkey readiness."
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

# Find phone-only Entra users before Microsoft-provided SMS and voice retires

![Cover: Microsoft retiring its own SMS and voice delivery and defaulting to passkeys, and a runbook, read-only by default, that sorts every Entra user into method-strength groups so the telephony-only list is ready to act on](../../assets/img/banners/auth-method-readiness-groups.webp){ .post-cover width="1200" height="630" fetchpriority=high }

Microsoft has put dates on retiring its own SMS and voice delivery for MFA, and the first question that comes up is a simple one, who is still on a phone code? Microsoft's own analyzer tells you if the tenant is in scope, this runbook tells you who. We wanted the actual users, sorted by the strongest method they have, kept current, and sitting in Entra groups we can point a Conditional Access policy or a comms campaign at, so that's what we built.

<!-- more -->

<div class="hook-embed" markdown="0">
<iframe scrolling="no" src="/assets/hooks/auth-method-readiness-groups.html" title="Before and after: authentication method registration data sitting flat, then sorted into live Entra groups per method strength, with the telephony-only group ready to target before Microsoft-provided SMS and voice retire" loading="lazy" style="display:block;width:100%;aspect-ratio:1200/470;border:0;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.35)"></iframe>
</div>

!!! success "The payoff"
    Microsoft stops sending SMS and voice codes itself on 1 February 2027 for most users. This runbook reads the Entra registration report, puts every in-scope user into one group by their strongest method (phishing-resistant, strong, telephony-only, nothing usable) and keeps those groups in sync. By default it only reads, as a dry run, and it has four gates before it ever removes anyone. The telephony-only group is your migration list, and the complete runbook is linked at the end.

## What's retiring, and when

Microsoft announced it in message center post [MC1426371](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-sms-voice-retirement), with more detail in [Microsoft's FAQ](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-sms-voice-retirement-faq). Passkeys became the default sign-in experience on 1 September 2026. Microsoft-provided SMS and voice delivery retires on 1 February 2027 for everyone except Global Administrators and external users, and they move on 1 July 2027. Internal guests stay on the February date with members, which is why the runbook keeps them in scope and only drops external users.

What goes away is Microsoft's own telephony delivery, SMS and voice as methods stay. If your organisation still needs them, you can configure your own telephony provider through the Microsoft Security Store from 30 October 2026. If you don't, anyone whose only method is SMS or voice loses their way in on the day, and those are the people this runbook finds.

Microsoft also publishes the [entra-sms-voice-usage-analyzer](https://github.com/microsoft/entra-sms-voice-usage-analyzer) script, and any non-zero result from it means your tenant is in scope. It doesn't give you the people as something you can act on, though, and turning off SMS is easy compared to knowing which 600 or 6,000 accounts would lose their only working method that morning. So for every active user we work out their strongest registered method and put them in one of these:

- phishing-resistant: a passkey (device-bound or synced), a FIDO2 key, Windows Hello for Business, a platform credential. Already where Microsoft wants everyone.
- strong but not phishing-resistant: Authenticator push or passwordless, a software or hardware one-time passcode, third-party MFA like Duo. Fine for now, they'll need moving later.
- telephony-only: the only thing registered is a phone number, SMS or voice. This is the group that breaks on the day unless you bring your own telephony provider.
- nothing usable: no method at all, or only single-factor ones like email, security questions or a QR code with PIN, and none of those are MFA.

## Why assigned groups instead of dynamic ones

The first instinct is a dynamic group, "members whose strongest method is a phone number", and you can't write that rule. Dynamic membership rules run on attributes of the user object, and registered authentication methods aren't on the user object, they come from a separate report. It's the same gap we hit when we built [app-based Entra groups](app-based-entra-groups.md), there's no rule for "has this app installed" either.

So these are assigned groups that you create once by hand, and the runbook keeps their membership in sync from the report. From where you sit they behave like dynamic groups, membership updates itself on every run, the runbook just does the job a membership rule normally would. That's the operational-groups idea, a group maintained by automation because a rule can't express what you need. We wrote this runbook from scratch for our own requirement, and it never creates, renames or deletes a group, it only adds and removes members of groups you made first.

## Permissions

The part that reads your whole directory and everyone's registered methods should hold as little write access as we can manage. Reading and classifying needs read scopes only, `User.Read.All`, `AuditLog.Read.All` and `GroupMember.Read.All`, granted to the Automation account's managed identity, and the sorting happens in memory. The registration report itself needs an Entra ID P1 or P2 licence in the tenant.

The one write it can ever do is adding and removing members of your groups, and only that needs `GroupMember.ReadWrite.All`. Even with that scope it defaults to a dry run and changes nothing until someone sets one parameter, so if you only want the lists, don't grant the write scope at all. The CSV upload to storage is optional too, the runbook ships with placeholder storage names and skips the upload until you put your own in.

## How the runbook works

<div class="mermaid-live" markdown="0">
--8<-- "assets/diagrams/auth-method-readiness-groups.svg"
</div>

It reads the users and the registration report, classifies every in-scope user into one group, writes a summary and a CSV per group, and then, only if you've turned the dry run off, reconciles each group's membership to match. Reads and CSVs happen on every run, writes only after the gates below pass.

### The classification map

Each registered method maps to a class, and the map is explicit:

```powershell
$MethodClassMap = @{
    'fido2SecurityKey'            = 'PhishingResistant'
    'passKeyDeviceBound'          = 'PhishingResistant'
    'passKeySynced'               = 'PhishingResistant'
    'windowsHelloForBusiness'     = 'PhishingResistant'
    'macOsSecureEnclaveKey'       = 'PhishingResistant'
    'microsoftAuthenticatorPush'  = 'Strong'
    'softwareOneTimePasscode'     = 'Strong'
    'hardwareOneTimePasscode'     = 'Strong'
    'externalAuthMethod'          = 'Strong'      # third-party MFA such as Duo, MFA but not phishing-resistant
    'mobilePhone'                 = 'Telephony'
    'officePhone'                 = 'Telephony'
    'email'                       = 'SsprOnly'    # password reset only, not MFA
    'qrCodePin'                   = 'NotMfa'      # QR code + PIN, Microsoft documents it as single-factor
    # ... the full map is in the runbook
}
# A value that isn't in the map is Unknown. It goes to Review, it never lands in a group on a guess.
```

Then each user lands in one group by their strongest method, strongest first:

```powershell
$group =
    if     ($hasPR)               { 'PhishingResistant' }   # a passkey beats everything else they hold
    elseif ($hasStr)              { 'StrongNotPR' }
    elseif ($hasUnk)              { 'Review' }              # an unrecognised value never decides
    elseif ($hasTel)              { 'TelephonyOnly' }       # the migration list
    elseif (-not $reg)            { 'NoRegistrationData' }
    elseif ($methods.Count -eq 0) { 'NoMfa' }               # nothing registered
    elseif ($hasTap -and -not ($hasSspr -or $hasNotMfa)) { 'Review' }   # Temporary Access Pass only
    elseif ($hasNotMfa)           { 'NoMfa' }               # QR code + PIN, single-factor
    elseif ($hasSspr)             { 'NoMfa' }               # email or security questions only
    else                          { 'Review' }
```

A value Graph returns that the map doesn't know goes to a Review group for a person to look at, and the run's summary names it along with a best guess, so a future Microsoft rename can't quietly file someone as safe. Certificate values are never guessed as phishing-resistant, because certificate-based auth can be single-factor or multi-factor depending on how your CBA policy is set up. A QR code with PIN is single-factor, so someone with a QR code and SMS lands in telephony-only, where they belong. And phishing-resistant methods that live on one machine, Windows Hello for Business or the macOS Secure Enclave key, count as phishing-resistant but get flagged separately, since a credential tied to one laptop doesn't help that person on a phone browser or a loaner machine.

### Four gates before anything changes

The classification half can't hurt anyone, the sync half can remove a user from a group, and a wrong removal means a Conditional Access policy suddenly stops applying to someone. So even with the dry run off, four checks stand between the classification and a change.

The coverage gate aborts the run if fewer than 90 percent of in-scope users have a registration row, because that pattern usually means a throttled or failed read and publishing a membership list off a bad read is how you empty a group by accident. Graph doesn't return registration rows for disabled users at all, so keep `ExcludeDisabledAccounts` on, otherwise disabled accounts drag coverage down and trip the gate for no real reason.

```powershell
if ($inScopeCoverage -lt ($MinCoveragePercent / 100)) {
    throw "In-scope coverage is only $([int]($inScopeCoverage*100))%, below the $MinCoveragePercent% floor. " +
          "That points at a failed or throttled read. Aborting rather than publishing a misleading list."
}
```

The partition check needs the groups to account for every classified user exactly once, with no gaps and no double counting, or nothing is applied.

The removal gate has one honest exception. A user moving from telephony-only to phishing-resistant is an explained removal from the old group, that's the campaign working, so it always applies. Only users who dropped out of the classification completely (deleted, disabled, now external, or a bad read) are gated, and if too large a share of a group would go for that reason, those removals are skipped while the moves still go through.

The group-shape guard refuses anything that isn't a plain cloud security group. On-premises-synced, role-assignable, mail-enabled and dynamic-membership groups all get skipped, so the runbook can't fight a dynamic rule or write to a group it doesn't own.

```powershell
if ($g.onPremisesSyncEnabled)                       { return 'SKIPPED - on-premises synced' }
if (@($g.groupTypes) -contains 'DynamicMembership') { return 'SKIPPED - dynamic membership group' }
if ($g.isAssignableToRole)                           { return 'SKIPPED - role-assignable group' }
```

When all of that passes, it adds and removes members in Graph batches of 20 and writes a CSV of every add and remove as it goes.

## What you get, and what each group is for

A run prints the group counts first. These are synthetic numbers on a sample tenant, yours will look different:

```text
GroupKey             Members  NonHuman  ProposedName
--------             -------  --------  ------------
PhishingResistant    1840     0         Auth - Phishing-resistant Method Users (CG)
StrongNotPR          2210     0         Auth - Strong Method Users (CG)
TelephonyOnly        430      22        Auth - Telephony Only Users (CG)
NoMfa                85       0         Auth - No Method Registered Users (CG)
NoRegistrationData   12       0         Auth - No Registration Data Users (CG)
Review               6        0         Auth - Manual Review Users (CG)
ExclusionNonHuman    22       22        Auth - Non-human Accounts Exclusion (CG)
```

The TelephonyOnly row is the one to watch. Here that's 430 accounts, 22 of them non-human and excluded, so 408 real people to move before Microsoft-provided delivery stops. The run ends with that number in one line you can paste into a status update, and it compares against the previous run so you can see it come down as the campaign goes.

That group is the one with a clock on it. Point a Conditional Access report-only policy at it to see who'd be affected, hand it to the service desk as the call list, and run a registration campaign at it while you watch it shrink run over run. When Microsoft-provided SMS and voice stop, anyone still in it is exactly who would have lost access, and you'll have dealt with them on your own schedule instead of on the cutover morning.

<div class="mermaid-live" markdown="0">
--8<-- "assets/diagrams/auth-method-readiness-groups-use.svg"
</div>

The phishing-resistant and strong groups can sit together under a parent group you create by hand, and that parent is a good Conditional Access target. Everyone in it already has something stronger than a phone registered, so a policy with a custom authentication strength that leaves out SMS and voice moves them off phone codes now without locking anyone out (run it in report-only first). Leave system-preferred authentication alone, though. It's Microsoft-managed and on for all users by default, and narrowing it to the parent would drop the Review users, anyone on a Temporary Access Pass, and anyone who registered a method since the report last refreshed. The runbook doesn't touch the parent, it just keeps the two groups underneath it current.

!!! note "Coming next: the Power BI report"
    These CSVs are the raw material. A detailed Power BI report on top of them is in the works, so you can watch the telephony-only number trend down week over week and slice it by department and account type.

## Gotchas from the lab

- The registration report can lag by up to 36 hours, that's Microsoft's documented figure, so someone who registered a passkey this morning can still show as telephony-only. Read the in-scope coverage line in the output rather than the raw ratio.
- Phishing-resistant on one machine isn't the same as portable. Someone whose only strong credential is Windows Hello for Business on one laptop is fine on that laptop and stuck on a phone browser. The runbook flags it and you decide if that's good enough for your risk.
- Internal guests stay in scope on the February date, but Microsoft's FAQ says passkey support for B2B users and internal guests is only planned for the end of 2026, so for now those people may need Authenticator rather than a passkey.
- `employeeType` is the cleanest signal for service and admin accounts when HR fills it in. Name patterns are the fallback, and short fragments like "sa" hit real names, so the name match is kept narrow and anything it can't place goes to Review.
- Read the dry-run output properly before you let it write anything. The gates catch the big mistakes, but you'll spot a wrong group name or an odd count much faster than any gate will.

## Get the complete runbook

The full runbook, all of it, is on the setup page with the permissions list, and on GitHub. Create the seven groups by hand first, put your own storage names in (or leave the placeholders and skip the upload), give the managed identity the read scopes, and run it with DryRun on. Once the dry-run output looks right, schedule it in Azure Automation, daily is plenty for a migration you're tracking week over week.

[:material-file-code: The complete runbook and setup](../../scripts/auth-method-readiness-groups.md){ .md-button .md-button--primary } [:material-github: Runbook on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Report-AuthMethodReadiness.ps1){ .md-button }

It's the same move as everything else on this site. Reading and sorting your whole directory needs no write access, and the one write, group membership, is gated, starts as a dry run and only touches groups you made yourself. The deadline is Microsoft's, but the list is yours, and you can work it down months before anyone gets stuck at a sign-in prompt.

## Questions people ask

**When is Microsoft-provided SMS and voice MFA retiring?**
On 1 February 2027 for most users, and on 1 July 2027 for Global Administrators and external users. Passkeys became the default on 1 September 2026. It's Microsoft's own delivery that retires, and from 30 October 2026 you can configure your own telephony provider through the Microsoft Security Store if you still need SMS or voice.

**How do I find users who only have SMS or voice MFA?**
Read `reports/authenticationMethods/userRegistrationDetails` from Microsoft Graph with `AuditLog.Read.All` and work out each user's strongest method from `methodsRegistered`. The ones whose only MFA method is a phone number are your list, and the runbook in this post does that and keeps them in a group.

**Can a dynamic group target users by their authentication method?**
No. Dynamic membership rules evaluate attributes of the user object, and registered methods come from the registration report, so you use assigned groups that automation keeps in sync.

**Does this runbook change anything in my tenant?**
Not by default. It runs as a dry run, makes GET calls only and writes CSVs. With the dry run off it only adds and removes members of groups you created, and only after the coverage, partition, removal and group-shape gates pass.

## References

- **MC1426371, Passkeys by default and retirement of Microsoft-provided SMS and voice** (Microsoft Entra message center): [mc.merill.net/message/MC1426371](https://mc.merill.net/message/MC1426371)
- **Passkeys by default and retirement of Microsoft-provided SMS and voice authentication** (Microsoft Learn, the authoritative dates): [learn.microsoft.com](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-sms-voice-retirement)
- **FAQ for Microsoft-provided SMS and voice retirement** (Microsoft Learn): [learn.microsoft.com](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-sms-voice-retirement-faq)
- **MC1519855, Choose your own telephony provider for SMS and voice authentication** (Microsoft Entra message center): [mc.merill.net/message/MC1519855](https://mc.merill.net/message/MC1519855)
- **entra-sms-voice-usage-analyzer** (Microsoft, GitHub, tells you if the tenant is in scope): [github.com/microsoft/entra-sms-voice-usage-analyzer](https://github.com/microsoft/entra-sms-voice-usage-analyzer)
- **Authentication methods activity** (Microsoft Learn, P1 or P2 licence and the 36-hour latency): [learn.microsoft.com](https://learn.microsoft.com/en-us/entra/identity/authentication/howto-authentication-methods-activity)
- **userRegistrationDetails resource type** (Microsoft Graph, the report this reads): [learn.microsoft.com](https://learn.microsoft.com/en-us/graph/api/resources/userregistrationdetails)
- **System-preferred authentication** (Microsoft Learn): [learn.microsoft.com](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-system-preferred-authentication)
- **QR code authentication method** (Microsoft Learn, single-factor): [learn.microsoft.com](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-authentication-qr-code)
- **Operational groups in Entra** (entra.news, related reading on maintaining assigned groups by automation): [entra.news/p/operational-groups-in-entra-with](https://entra.news/p/operational-groups-in-entra-with)

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "When is Microsoft-provided SMS and voice MFA retiring?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "On 1 February 2027 for most users, and on 1 July 2027 for Global Administrators and external users. Passkeys became the default on 1 September 2026. It's Microsoft's own delivery that retires, and from 30 October 2026 you can configure your own telephony provider through the Microsoft Security Store if you still need SMS or voice."
      }
    },
    {
      "@type": "Question",
      "name": "How do I find users who only have SMS or voice MFA?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Read reports/authenticationMethods/userRegistrationDetails from Microsoft Graph with AuditLog.Read.All and work out each user's strongest method from methodsRegistered. The users whose only MFA method is a phone number are your list. The runbook in this post does that and keeps them in an Entra group."
      }
    },
    {
      "@type": "Question",
      "name": "Can a dynamic group target users by their authentication method?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "No. Dynamic membership rules evaluate attributes of the user object, and registered authentication methods come from the separate registration report, so you use assigned groups that automation keeps in sync."
      }
    },
    {
      "@type": "Question",
      "name": "Does this runbook change anything in my tenant?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Not by default. It runs as a dry run, makes GET calls only and writes CSVs. With the dry run off it only adds and removes members of groups you created, and only after the coverage, partition, removal and group-shape gates pass."
      }
    }
  ]
}
</script>

---

*Personal lab pattern. All examples use synthetic values, there is no real tenant, user or storage account here. Verify authentication-method behaviour and the retirement dates in your own tenant and on Microsoft Learn. Independent content, not affiliated with, sponsored by, or endorsed by Microsoft. Microsoft, Entra, Microsoft Graph and Azure are trademarks of the Microsoft group of companies.*
