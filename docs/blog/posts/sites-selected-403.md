---
date: 2026-07-20
draft: false
comments: true
categories:
  - Zero-Access
tags:
  - Entra ID
  - Microsoft Graph
---

# The Sites.Selected 403 that started it all

It began with a permission error that wouldn't quit. Sites.Selected looked right, the role assignment looked right — and Graph still returned 403. Chasing *why* led somewhere better than a fix: an architecture where the AI never touches a live system at all.

<!-- more -->

!!! note "Work in progress"
    The full write-up is on the way. This post is published early so the series is visible — check back shortly, or follow along on [GitHub](https://github.com/KetanKamble3894/zero-access-agent).
