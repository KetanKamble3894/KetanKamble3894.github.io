---
title: Unrenamed Device Report
description: Read-only detector for Windows devices still on the default DESKTOP- name — emailed to the team with the handling rules.
tags:
  - Intune
  - Microsoft Graph
  - Azure Automation
---

# Unrenamed Device Report

Read-only detector for Windows devices still on the default `DESKTOP-` name in Intune — the ones whose Autopilot rename never completed — emailed to the team with the handling rules.

[:material-download: Download the script](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Report-UnrenamedDevices.ps1){ .md-button .md-button--primary }
[:material-github: View on GitHub](https://github.com/KetanKamble3894/zero-access-agent/blob/main/scripts/Report-UnrenamedDevices.ps1){ .md-button }

!!! note "Read-only"
    It authenticates with a Managed Identity, GETs devices whose name starts with `DESKTOP-`, and
    emails an HTML table. It needs only `DeviceManagementManagedDevices.Read.All` — no write scope.
    The rename / reprovision steps are described in the email as a **human process**, not actions this
    script takes.

## 1 · The script

Set the CONFIG block at the top — the SMTP server, sender, recipients and your corporate rename prefix
(all ship as `@contoso.com` placeholders) — then run.

??? example "View the full script"
    ```powershell
    --8<-- "assets/scripts/Report-UnrenamedDevices.ps1"
    ```

## Related

- :material-book-open-variant: **The story** → [The devices that never got renamed: finding the DESKTOP- stragglers](../blog/posts/unrenamed-desktop-devices.md)
