---
title: "Ignite 2026 GA vs preview: Intune and Entra"
description: "What Ignite 2026 made generally available for Intune, Windows 365, Defender and Entra admins, what's still preview, and a short plan for next week."
date: 2026-11-20
slug: ignite-2026-ga-vs-preview-admins
draft: false
comments: true
categories:
  - Intune
  - Entra ID
tags:
  - Ignite 2026
  - Intune
  - Entra ID
  - Windows 365
  - Defender / Security
  - Agent 365
---

# Ignite 2026 for Intune, Entra and Windows 365 admins: what's GA and what's preview

![Ignite 2026 for endpoint and identity admins. Generally available: Windows 365 context-based redirections, Defender runtime protection for local agents, Agent 365 plugins and skills governance, Edge for Business extension safety. Preview, pilot only: Conditional Access policy plans, Intune local AI agents governance, declarative device management, Windows MAM](../../assets/img/banners/ignite-2026-ga-vs-preview.webp){ .post-cover width="1200" height="630" fetchpriority=high }

After every Ignite I end up asking the same thing, what can actually go to production next week and what's still preview. Ignite 2026 ran 17 to 20 November in San Francisco and online, the Book of News is long this year, so I went through it for endpoint and identity admins and sorted it by Microsoft's own status as of 20 November.

Four items are generally available now, according to the Book of News: Windows 365 context-based redirections, Defender runtime protection for local AI agents, Agent 365 plugins and skills governance, and Edge for Business extension safety. That's where I'd start, though the Defender one has a couple of catches. The headline Intune and Entra items, like Conditional Access policy plans and local AI agents governance, are still preview, fine for a pilot but not something I'd put in production yet.

<!-- more -->

<div class="hook-embed" markdown="0">
<iframe scrolling="no" src="/assets/hooks/ignite-2026-ga-vs-preview.html" title="Before and after: every Ignite 2026 announcement looks ready for production; sorted by Microsoft's own status, the generally available items go to change next week and the preview items go to a pilot group" loading="lazy" style="display:block;width:100%;aspect-ratio:1200/470;border:0;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.35)"></iframe>
</div>

## Generally available at Ignite 2026

### Windows 365 context-based redirections

You can now allow or restrict clipboard, drive, printer and USB redirection per connection, depending on how trusted that connection is, using Microsoft Entra authentication context. According to the Windows 365 blog it's GA in Azure Virtual Desktop too.

### Defender runtime protection for local AI agents on Windows

Microsoft lists two kinds of protection. Agent-native protection covers Claude Code, GitHub Copilot CLI, the GitHub Copilot app, Claude Desktop in Code mode and the VS Code extensions for GitHub Copilot and Claude Code. Network-based protection covers OpenClaw, Ollama Desktop, ChatGPT Classic and ChatGPT Desktop in Chat mode. You set it up in the Defender or Intune portal in Audit or Block mode, and the Book of News says it'll be available to Defender for Endpoint P2 customers.

Before you switch it on, read Microsoft's AI agent support matrix. It still labels the Windows runtime protection tables as preview, which doesn't match the Book of News, and it says an agent being supported doesn't mean protection is enabled on the device. Network inspection also doesn't cover agents that use certificate pinning or HTTP/3, so start in Audit.

Local agent discovery in Defender is generally available on managed Windows and macOS devices, and it shows which agents sit on which device and user before you block anything. Discovery under Windows Subsystem for Linux is still preview though. If you want that list outside the Defender portal, my [read-only local AI agent inventory](local-ai-agent-inventory.md) builds the same kind of list from a script.

### Agent 365 plugins and skills governance

In the Microsoft 365 admin center you can pick which plugins and skills are available for Microsoft 365 Copilot and Copilot Cowork, and assign them to specific users and groups. The one part that isn't GA yet is gateway support for Azure AI Gateway and LiteLLM.

### Edge for Business extension safety

You get an organisation-wide inventory of browser extensions, with a risk score for each extension and each version, and Microsoft says the scores come from Akamai and Spin.AI. Extension leak control didn't make it, that one is still preview.

### Also generally available

Microsoft marks these as generally available too. They're lower on my list, but check them if you run the product.

- Windows: the new Windows Endpoint Security Platform.
- Windows 365: Direct Stream updates for Cloud PC users (the GPU part comes later as a preview), Cloud PCs that can run local AI models with up to 32 vCPU and GPU options, Output Protection (input protection is still preview), and the monitoring and reporting platform in Intune.
- Entra: Microsoft MCP Server for Enterprise, and agentic traffic acquisition in Global Secure Access.
- Agent 365: the tools registry. Connecting external catalogs is due in December, in private preview.

## Still in preview after Ignite 2026

Microsoft marks these as preview, apart from the last one, so keep them to a pilot group for now.

- Conditional Access policy plans in Entra. Microsoft says you describe the access you want once and then manage the policies from there.
- Agent ID for discovered local agents in Entra, starting with GitHub Copilot CLI and Claude Code.
- Local AI agents governance in Intune. Devices with unapproved agents, found through Microsoft Agent 365 discovery, can be marked noncompliant, and Conditional Access can then block them.
- Declarative device management for Windows, in Intune.
- Mobile Application Management (MAM) for Windows in Windows App, and the Windows 365 admin assistant in the Intune admin center.
- Dynamic Agent Risk, gateway support for MCP server governance and parts of cost management, all in Agent 365.
- Managed agent browsing in Edge for Business, where each agent works with its own Microsoft Entra agent identity.
- Purview data loss prevention for Copilot and for local agents on Windows.
- Learning and permissive mode in the new Windows controls for isolating AI agents. The Book of News lists this one as generally available, but under a heading that says all the updates are preview. I'm treating it as preview until Microsoft clears that up.

Further down the list, Windows baseline protection, Enterprise App Management auto-updates for all Windows apps and Autopatch OS reliability reporting are in private preview. In Entra it's specific options that are preview. For Privileged Identity Management that's MyAccess, secure Azure VM connectivity and more control over standing access, for dynamic membership groups it's MemberOf Next and Transitive Reports To. Cross-tenant configuration management is preview too. Global Secure Access has preview controls for local agents, MCP Firewall, unsanctioned agents and adaptive access.

The Agent 365 action center is expected in December. The Book of News says private preview, the Agent 365 blog just says preview.

## What to do next week

1. Pick one of the four GA items and take it through your normal change process, with a pilot group and a way to roll it back.
2. For the previews you care about, Conditional Access policy plans or Windows MAM for example, write a pilot list with an owner and a review date for each.
3. Tell security and the service desk which items are GA and which are still preview, so nobody starts planning around something that isn't released.
4. Check licences before you pilot anything. Going by the Book of News, Defender runtime protection will be available to Defender for Endpoint P2 customers, and agents need an Agent 365 licence for what Microsoft calls "enterprise-grade" management, security and governance. The Agent 365 blog adds that the premium features need Agent 365 or ME7. Microsoft also says agent insights in Viva Insights will stop needing an Agent 365 licence, but they'll still need at least 50 assigned Copilot licences.
5. Have a look at Agent 365 management insights for Microsoft agents in the Microsoft 365 admin center. They now show by default, whatever your Agent 365 licensing.

## Questions people ask

**What did Ignite 2026 make generally available for endpoint and identity admins?**
Windows 365 context-based redirections, Defender runtime protection for local AI agents on Windows, Agent 365 plugins and skills governance, and Edge for Business extension safety, according to the Book of News. Local agent discovery in Defender and the Windows Endpoint Security Platform are generally available too.

**Is Intune local AI agents governance generally available?**
No, it's preview. Devices with unapproved agents can be marked noncompliant, and Conditional Access can then block them.

**What do I need for Defender runtime protection for local AI agents?**
The Book of News says it will be available to Defender for Endpoint P2 customers. You set it up in the Defender or Intune portal in Audit or Block mode, and the support matrix lists which agents are covered.

## Sources

- [Microsoft Ignite 2026 Book of News](https://news.microsoft.com/events/ignite/2026/book-of-news/), 17 to 20 November 2026
- [Windows 365 at Ignite 2026: Introducing new Cloud PC capabilities for people, agents and IT](https://techcommunity.microsoft.com/blog/windows-itpro-blog/windows-365-at-ignite-2026-introducing-new-cloud-pc-capabilities-for-people-agen/4570006), Windows IT Pro Blog
- [What's new in Microsoft Agent 365: Ignite 2026](https://techcommunity.microsoft.com/blog/agent-365-blog/whats-new-in-microsoft-agent-365-ignite-2026/4571753), Agent 365 Blog
- [Ignite 2026: What's new in Microsoft Defender & Sentinel](https://techcommunity.microsoft.com/blog/microsoftthreatprotectionblog/ignite-2026-whats-new-in-microsoft-defender--sentinel/4569975), Microsoft Defender Blog
- [Microsoft Defender for Endpoint AI agent support matrix](https://learn.microsoft.com/en-us/defender-endpoint/ai-agent-support-matrix), Microsoft Learn

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {"@type": "Question", "name": "What did Ignite 2026 make generally available for endpoint and identity admins?", "acceptedAnswer": {"@type": "Answer", "text": "Windows 365 context-based redirections, Defender runtime protection for local AI agents on Windows, Agent 365 plugins and skills governance, and Edge for Business extension safety, according to the Book of News. Local agent discovery in Defender and the Windows Endpoint Security Platform are generally available too."}},
    {"@type": "Question", "name": "Is Intune local AI agents governance generally available?", "acceptedAnswer": {"@type": "Answer", "text": "No, it's preview. Devices with unapproved agents can be marked noncompliant, and Conditional Access can then block them."}},
    {"@type": "Question", "name": "What do I need for Defender runtime protection for local AI agents?", "acceptedAnswer": {"@type": "Answer", "text": "The Book of News says it will be available to Defender for Endpoint P2 customers. You set it up in the Defender or Intune portal in Audit or Block mode, and the support matrix lists which agents are covered."}}
  ]
}
</script>

---

*Personal roundup. Product status is as Microsoft published it at Ignite 2026 and can change, so check the sources before you plan around it. Independent content, not affiliated with, sponsored by, or endorsed by Microsoft or any vendor named here. Microsoft, Intune, Entra, Windows 365, Defender and Agent 365 are trademarks of the Microsoft group of companies. Other product names belong to their owners and are named here as Microsoft lists them.*
