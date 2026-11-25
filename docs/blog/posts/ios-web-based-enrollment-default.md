---
title: "Intune iOS web-based enrollment default, 2027"
description: "Web-based device enrollment becomes the Intune default for new iOS/iPadOS enrollment profiles in early 2027. What changes, who it affects, and what to check."
date: 2026-11-24
slug: web-based-ios-enrollment-default-early-2027
draft: false
comments: true
categories:
  - Intune
tags:
  - Intune
  - iOS
  - Enrollment
  - Microsoft Graph
  - PowerShell
---

# Web-based iOS/iPadOS enrollment becomes the Intune default in early 2027

![Web-based iOS/iPadOS enrollment becomes the Intune default for new enrollment profiles in early 2027. Existing profiles stay as they are, Company Portal stays, and web-based enrollment needs iOS/iPadOS 15 or later](../../assets/img/banners/ios-web-based-enrollment-default.webp){ .post-cover width="1200" height="630" fetchpriority=high }

Short answer, Microsoft updates the web-based enrollment flow for iOS/iPadOS in late January 2027, and from early 2027 web-based device enrollment becomes the default when you create a new iOS/iPadOS enrollment profile in Intune. Existing profiles aren't touched and Company Portal isn't being deprecated for iOS/iPadOS. What I'd check now is Microsoft Authenticator, the SSO extension policy for Just-in-Time registration, and any personal iPhones or iPads still below iOS/iPadOS 15.

Rishita Sarin, Product Manager 2 on Microsoft Intune, wrote it up on the Intune Customer Success blog on 23 November 2026, and two message center posts carry the detail, MC1476216 for the new default and MC1565959 for the updated experience.

<!-- more -->

<div class="hook-embed" markdown="0">
<iframe scrolling="no" src="/assets/hooks/ios-web-based-enrollment-default.html" title="Before and after: today a personal iPhone enrollment starts in the Company Portal app and sign-in isn't reduced to one prompt; from early 2027 new iOS/iPadOS enrollment profiles default to web-based enrollment that starts from Teams, Outlook or Safari and aims for one sign-in prompt, and existing profiles stay as they are" loading="lazy" style="display:block;width:100%;aspect-ratio:1200/470;border:0;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.35)"></iframe>
</div>

## What changes and when

There are really two things here, and they land at slightly different times.

### The updated web-based flow, late January 2027 (MC1565959)

MC1565959 says Intune updates the web-based device enrollment experience for iOS/iPadOS in late January 2027 (the blog says early 2027). Per the blog, users can start enrollment from Microsoft Teams or Microsoft Outlook, or from an enrollment URL in Safari, and guided steps walk them through enrolling, installing the management profile, completing registration and getting back to the work app.

Registration uses Just-in-Time (JIT) registration, with Microsoft Authenticator and the Microsoft Entra ID SSO extension, and the aim is one authentication prompt during enrollment. The Company Portal app isn't needed as the starting point anymore.

### Web-based becomes the default, early 2027 (MC1476216)

MC1476216 says that from early 2027, web-based device enrollment is the default when you create a new iOS/iPadOS enrollment profile. Existing enrollment profiles aren't affected. For the no-profile case the message center post is narrower than the blog, it says new tenants that haven't created an enrollment profile will enroll with web-based enrollment.

Company Portal isn't being deprecated on iOS/iPadOS. It stays available after enrollment and you can keep deploying it as a required or available app.

There are two details on Microsoft Learn that the blog doesn't repeat. Safari is the only supported browser for this type of enrollment, and it's what downloads the management profile. The flow also still goes through the Company Portal website, so "no Company Portal app" doesn't mean nothing from Company Portal is involved.

## Who it affects

- Admins who create new iOS/iPadOS enrollment profiles after the change lands.
- New tenants without an iOS/iPadOS enrollment profile.
- Help desks and onboarding guides, because the steps users see will look different. MC1565959 says no admin action is needed but user guidance may need an update, and the updated flow only reaches tenants already using a web-based profile.

Neither the blog nor the message center posts mention a licensing change. The message center archive I used notes it has only seen both posts in Education tenants so far, so check Message center in your own tenant.

## What to check first

1. **Your enrollment profiles.** List your iOS/iPadOS enrollment type profiles with their default enrollment type, priority and assignments. Intune applies them in priority order, so if a user is assigned more than one profile, the higher priority profile wins.
2. **Microsoft Authenticator.** The blog recommends deploying it as a required app for users who enroll iOS/iPadOS devices. Learn says the device isn't ready for work until Authenticator is on it, which can take a few minutes.
3. **The SSO extension policy for JIT.** Configure or update the Microsoft Entra ID SSO extension policy, with the `device_registration` key set to `{{DEVICEREGISTRATION}}`. Learn also recommends `browser_sso_interaction_enabled` set to `1`, says to remove trailing spaces around keys and values or JIT registration won't work, and says not to add Microsoft apps, Authenticator included, to the policy. MC1476216 says admins need to deploy this policy for web enrollment, and that without JIT registration and Authenticator users may be unable to complete device registration and access protected organizational resources.
4. **Conditional Access.** The blog recommends configuring it consistently, so I'd check your policies before the new flow reaches users.
5. **OS versions.** Web-based enrollment needs iOS/iPadOS 15 or later. If a web-based profile reaches a device on 14.9 or earlier, Intune enrolls it with app-based device enrollment instead, and that needs the Company Portal app. If you already track Apple OS versions for compliance, the [Apple OS release watch](apple-os-release-watch.md) covers that side.
6. **Safari.** Update your user guidance if people use a different default browser.

## A read-only check

This lists your iOS/iPadOS enrollment type profiles and any personal iPhones or iPads still below 15.0. It only reads, like the [read-only Intune Suite audit](intune-suite-read-only-audit.md). The profile endpoint is Graph beta, which Microsoft says can change more often, so I wouldn't build anything permanent on it.

```powershell
# Read-only. Lists iOS/iPadOS enrollment type profiles and personal iPhones/iPads below version 15.
# Needs the Microsoft.Graph.Authentication module. The profile endpoint is Graph beta, which can change.
Set-StrictMode -Off   # Graph responses can leave out keys, so a strict profile shouldn't break the run
Connect-MgGraph -Scopes 'DeviceManagementServiceConfig.Read.All','DeviceManagementManagedDevices.Read.All' -NoWelcome

function Get-GraphAll([string]$Uri) {
    $items = @()
    while ($Uri) {
        $page   = Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop   # stop on errors, don't loop
        if ($page.value) { $items += $page.value }
        $Uri    = $page.'@odata.nextLink'
    }
    $items
}

# 1. iOS/iPadOS enrollment type profiles, highest priority first (0 is highest)
#    The profile platform enum has only iOS, with no separate iPadOS value.
$base     = 'https://graph.microsoft.com/beta/deviceManagement/appleUserInitiatedEnrollmentProfiles'
$profiles = @(Get-GraphAll $base | Where-Object { $_.platform -eq 'iOS' } | Sort-Object { $_.priority })
if ($profiles.Count -eq 0) { 'No iOS/iPadOS enrollment type profile found.' }
$profiles | ForEach-Object {
    [pscustomobject]@{
        Profile     = $_.displayName
        Priority    = $_.priority
        DefaultType = $_.defaultEnrollmentType   # webDeviceEnrollment means web-based
        Assignments = @(Get-GraphAll "$base/$($_.id)/assignments").Count
    }
} | Format-Table -AutoSize

# 2. Personal iPhones and iPads below 15.0. A web-based profile sends devices on 14.9 or earlier
#    to app-based enrollment, which needs Company Portal.
$apple = Get-GraphAll 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices' |
    Where-Object { $_.operatingSystem -in 'iOS', 'iPadOS' -and $_.managedDeviceOwnerType -eq 'personal' }
$below15 = @(); $unread = @()
foreach ($d in $apple) {
    $v = $null
    if (-not [version]::TryParse($d.osVersion, [ref]$v)) { $unread += $d; continue }
    if ($v -lt [version]'15.0') { $below15 += $d }
}
$row = { [pscustomobject]@{ Device = $_.deviceName; OS = $_.operatingSystem; Version = $_.osVersion; User = $_.userPrincipalName } }
$below15 | ForEach-Object $row | Format-Table -AutoSize
if (-not $below15) { 'No personal iOS/iPadOS devices below 15.0 found.' }
if ($unread) {
    "Couldn't read the OS version on $($unread.Count) device(s), check these by hand:"
    $unread | ForEach-Object $row | Format-Table -AutoSize
}
```

A few notes on how it's built:

- It uses `Connect-MgGraph` and `Invoke-MgGraphRequest` from the Microsoft Graph PowerShell SDK, with the least privileged read permissions the Graph pages list.
- Assignments are read per profile from the documented `/assignments` path, because the list call doesn't document `$expand`.
- The profile `platform` enum has only `iOS`, with no iPadOS value, and Learn doesn't say how iPad profiles are reported, so the script filters on `iOS`.
- The device check matches both `iOS` and `iPadOS`, since Learn doesn't say which value iPads report, and filters in PowerShell instead of using `$filter` or `$select`, which the managedDevices list page doesn't document. That means a bigger download, but it only relies on documented behaviour.
- Devices whose OS version can't be read are listed separately so you can check them by hand, nothing is dropped silently.
- It turns strict mode off for its own run and stops on the first Graph error, so a strict profile, a missing next-page link or a failed call won't leave the loop running. A server that kept repeating the same next-page link would still loop, which Graph doesn't do in practice.
- Run it as a `.ps1` file. If you paste it into an open console, the strict mode change stays in that session.

I tested the logic against mock Graph responses (paging, an empty response, iOS and iPadOS, a device on exactly 15.0, company devices, a version it can't read, no old devices at all, strict mode and a failed call, all run as a script file), not against a live tenant, so run it in a test tenant first.

If part 1 comes back empty, you have no iOS/iPadOS enrollment type profile. The message center post only covers new tenants in that state, so in an existing tenant I'd create a profile on purpose rather than wait to see what the default does.

## Questions people ask

**Is Company Portal being deprecated on iOS/iPadOS?**
No. Microsoft says Company Portal isn't being deprecated on iOS/iPadOS. It's just not the starting point for web-based enrollment, and you can keep deploying it as a required or available app.

**When does web-based enrollment become the default in Intune?**
From early 2027, for new iOS/iPadOS enrollment profiles (MC1476216). Existing profiles aren't affected. The updated web-based experience comes first, in late January 2027 (MC1565959).

**Which iOS versions support web-based device enrollment?**
iOS/iPadOS 15 or later. Devices on 14.9 or earlier that get a web-based profile are enrolled with app-based device enrollment, which needs the Company Portal app.

## Sources

- [Use web-based device enrollment for BYOD enrollment on iOS/iPadOS](https://techcommunity.microsoft.com/blog/intunecustomersuccess/use-web-based-device-enrollment-for-byod-enrollment-on-iosipados/4576027), Rishita Sarin, Intune Customer Success blog, 23 November 2026
- [MC1476216, Web based device enrollment will become default method for iOS/iPadOS device enrollment](https://mc.merill.net/message/MC1476216), message center
- [MC1565959, Updated web-based device enrollment experience for iOS/iPadOS](https://mc.merill.net/message/MC1565959), message center
- [Set up web based device enrollment](https://learn.microsoft.com/en-us/intune/device-enrollment/apple/setup-web-based-ios), Microsoft Learn
- [Set up Just-in-Time registration](https://learn.microsoft.com/en-us/intune/device-enrollment/apple/setup-just-in-time-registration), Microsoft Learn
- [appleUserInitiatedEnrollmentProfile resource type (beta)](https://learn.microsoft.com/en-us/graph/api/resources/intune-enrollment-appleuserinitiatedenrollmentprofile?view=graph-rest-beta), Microsoft Graph
- [List appleUserInitiatedEnrollmentProfiles (beta)](https://learn.microsoft.com/en-us/graph/api/intune-enrollment-appleuserinitiatedenrollmentprofile-list?view=graph-rest-beta), Microsoft Graph
- [List appleEnrollmentProfileAssignments (beta)](https://learn.microsoft.com/en-us/graph/api/intune-enrollment-appleenrollmentprofileassignment-list?view=graph-rest-beta), Microsoft Graph
- [List managedDevices](https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-list?view=graph-rest-1.0), Microsoft Graph
- [managedDevice resource type](https://learn.microsoft.com/en-us/graph/api/resources/intune-devices-manageddevice?view=graph-rest-1.0), Microsoft Graph
- [Invoke-MgGraphRequest](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/invoke-mggraphrequest) and [Connect-MgGraph](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph), Microsoft Graph PowerShell

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {"@type": "Question", "name": "Is Company Portal being deprecated on iOS/iPadOS?", "acceptedAnswer": {"@type": "Answer", "text": "No. Microsoft says Company Portal isn't being deprecated on iOS/iPadOS. It's just not the starting point for web-based enrollment, and you can keep deploying it as a required or available app."}},
    {"@type": "Question", "name": "When does web-based enrollment become the default in Intune?", "acceptedAnswer": {"@type": "Answer", "text": "From early 2027, for new iOS/iPadOS enrollment profiles (MC1476216). Existing profiles aren't affected. The updated web-based experience comes first, in late January 2027 (MC1565959)."}},
    {"@type": "Question", "name": "Which iOS versions support web-based device enrollment?", "acceptedAnswer": {"@type": "Answer", "text": "iOS/iPadOS 15 or later. Devices on 14.9 or earlier that get a web-based profile are enrolled with app-based device enrollment, which needs the Company Portal app."}}
  ]
}
</script>

---

*Personal write-up. All examples use synthetic values, there's no real tenant, user or device here. Dates and behaviour are as Microsoft published them in November 2026 and can change, so check the sources before you plan around them. Independent content, not affiliated with, sponsored by, or endorsed by Microsoft or Apple. Microsoft, Intune, Entra, Teams, Outlook and Authenticator are trademarks of the Microsoft group of companies, and Apple, iPhone, iPad, iOS, iPadOS and Safari are trademarks of Apple Inc.*
