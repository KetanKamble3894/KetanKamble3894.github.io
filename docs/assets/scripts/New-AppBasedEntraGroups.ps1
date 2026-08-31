#requires -Version 7.0
<#
.SYNOPSIS
    New-AppBasedEntraGroups.ps1 - the CREATOR runbook. Reads Intune detected apps and
    creates one ASSIGNED Entra security group per app you want to track, named to a
    convention. Membership is left empty here; Refresh-AppBasedGroups.ps1 fills and keeps
    it in sync.

.DESCRIPTION
    Intune has no SCCM-style collections. It targets Entra security groups, so to get a
    reusable "set of devices that have app X" you need a group that something keeps current.
    This runbook makes those groups. For each pattern in $AppPatterns it creates one assigned
    (not dynamic) group called "<Prefix> - <App> (CG)" and stamps the platform into the
    description as "[Platform=Windows]". It skips a group that already exists, so it is safe
    to re-run.

    WRITE-CAPABLE. This is the one exception to the read-only Zero-Access pattern the other
    runbooks follow: creating a group is a write. It creates groups only, it never deletes or
    changes membership. DryRun is on by default and prints what it would create.

.NOTES
    Managed-Identity Graph app roles this runbook needs:
      Group.ReadWrite.All                         (create the groups - there is no narrower
                                                    scope; GroupMember.ReadWrite.All cannot
                                                    create a group)
      DeviceManagementManagedDevices.Read.All     (read detected apps to decide what to make)
      Device.Read.All                             (read Entra devices, optional here)

    GENERIC / PARAMETERIZED: no resource group, storage account, tenant, or real app data is
    hardcoded. Run against a personal lab tenant only, and read the dry run before you apply.

    BETA ENDPOINT: detectedApps is on /beta. Re-verify after Graph updates.

    MIT licensed. Microsoft, Intune, Entra and Microsoft Graph are trademarks of the Microsoft
    group of companies. Independent content, not endorsed by Microsoft. Verify every endpoint
    and permission in your own lab tenant before relying on it.
#>

# ===========================================================================
#  CONFIGURE ME  ->  set these, then run.
# ===========================================================================
$GroupPrefix = "MDM Apps Discovered"     # the naming convention the refresh runbook matches on
$Platform    = "Windows"                 # stamped into the group description as [Platform=Windows]

# The apps to track. Each entry becomes ONE group. A trailing * is a wildcard, so
# "TeamViewer*" folds every TeamViewer version and variant (TeamViewer, TeamViewer 9,
# TeamViewer Meeting, TeamViewer Host) into a single group. An exact name isolates one app.
$AppPatterns = @(
    "Microsoft Project",
    "Microsoft Visio",
    "TeamViewer*",
    "Adobe Acrobat*"
)

# Dry run is the default. It prints the groups it WOULD create and changes nothing.
# Flip to $false only after you have read the preview.
$DryRun = $true
# ===========================================================================

$Graph = "https://graph.microsoft.com/beta"
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference  = 'Continue'

#region ---- HELPERS -------------------------------------------------------------

function Invoke-MyGraphGetRequest {
    param ([Parameter(Mandatory)][string]$URL)
    Write-Verbose "GET  $URL"
    $AllResults = [System.Collections.Generic.List[PSObject]]::new()
    do {
        $Response = Invoke-WebRequest -Uri $URL -Method GET -Headers $script:Headers -UseBasicParsing
        $Parsed   = $Response.Content | ConvertFrom-Json
        if ($Parsed.value) { $AllResults.AddRange([PSObject[]]$Parsed.value) }
        $URL = $Parsed.'@odata.nextLink'
    } while ($URL)
    return $AllResults
}

function Invoke-MyGraphWriteRequest {
    param (
        [Parameter(Mandatory)][string]$URL,
        [Parameter(Mandatory)][ValidateSet('POST','PATCH','DELETE')][string]$Method,
        [hashtable]$Body
    )
    $Json = if ($Body) { $Body | ConvertTo-Json -Depth 6 } else { $null }
    for ($Attempt = 1; $Attempt -le 5; $Attempt++) {
        try {
            return Invoke-RestMethod -Uri $URL -Method $Method -Headers $script:Headers `
                       -ContentType 'application/json' -Body $Json -TimeoutSec 60
        }
        catch {
            $Code = [int]$_.Exception.Response.StatusCode
            if ($Code -eq 429 -or $Code -ge 500) {
                $Wait = [math]::Max(5 * $Attempt, 15)
                Write-Verbose "Throttled/transient ($Code). Waiting ${Wait}s (attempt $Attempt/5)..."
                Start-Sleep -Seconds $Wait
                continue
            }
            throw
        }
    }
    throw "Graph $Method failed after retries: $URL"
}

# A mailNickname has to be short and safe. Strip anything that isn't alphanumeric.
function Get-MailNickname {
    param ([string]$Name)
    $clean = ($Name -replace '[^a-zA-Z0-9]', '')
    if ($clean.Length -gt 40) { $clean = $clean.Substring(0, 40) }
    return "mdmapp_$clean"
}

#endregion

#region ---- AUTHENTICATE (MANAGED IDENTITY) ------------------------------------

Write-Verbose "Obtaining Managed Identity access token..."
try {
    $TknHeaders  = @{ "X-IDENTITY-HEADER" = $env:IDENTITY_HEADER; "Metadata" = "True" }
    $TknBody     = @{ resource = 'https://graph.microsoft.com/' }
    $AccessToken = (Invoke-RestMethod $env:IDENTITY_ENDPOINT -Method POST -Headers $TknHeaders `
                        -ContentType 'application/x-www-form-urlencoded' -Body $TknBody).access_token
    $script:Headers = @{ 'Authorization' = "Bearer $AccessToken" }
    Write-Verbose "Access token obtained."
}
catch { Write-Error "Authentication failed: $_"; throw }

#endregion

#region ---- READ DETECTED APPS -------------------------------------------------

Write-Verbose "Reading detected apps..."
$Detected = Invoke-MyGraphGetRequest "$Graph/deviceManagement/detectedApps?`$select=id,displayName,version,deviceCount"
Write-Verbose "Detected app rows: $($Detected.Count)"

# Read existing groups once so we can skip anything already there.
$Existing = Invoke-MyGraphGetRequest "$Graph/groups?`$filter=startswith(displayName,'$GroupPrefix')&`$select=id,displayName"
$ExistingNames = @{}
foreach ($g in $Existing) { $ExistingNames[$g.displayName] = $g.id }

#endregion

#region ---- CREATE ONE GROUP PER PATTERN ---------------------------------------

$Made = 0; $Skipped = 0; $NoRows = 0

foreach ($pattern in $AppPatterns) {
    # Which detected-app rows does this pattern cover? A trailing * is a wildcard.
    $rows = $Detected | Where-Object { $_.displayName -like $pattern }
    if (-not $rows) {
        Write-Warning "No detected app matches '$pattern' - nothing to create. (Check the exact name in the Discovered apps report.)"
        $NoRows++
        continue
    }

    # The group is named for the pattern, not for each row, so "TeamViewer*" is ONE group.
    $appLabel  = ($pattern -replace '\*','').Trim()
    $groupName = "$GroupPrefix - $appLabel (CG)"

    if ($ExistingNames.ContainsKey($groupName)) {
        Write-Verbose "Exists, skipping: $groupName"
        $Skipped++
        continue
    }

    $rowCount = ($rows | Measure-Object).Count
    $devApprox = ($rows | Measure-Object deviceCount -Sum).Sum

    if ($DryRun) {
        Write-Output "WOULD CREATE  $groupName   (matches $rowCount detected-app row(s), about $devApprox device installs)"
        $Made++
        continue
    }

    $body = @{
        displayName     = $groupName
        description     = "[Platform=$Platform] App-based group, membership kept in sync by Refresh-AppBasedGroups. Pattern: $pattern"
        mailEnabled     = $false
        mailNickname    = (Get-MailNickname $appLabel)
        securityEnabled = $true
        groupTypes      = @()          # empty = ASSIGNED. A dynamic group would reject manual members.
    }
    $new = Invoke-MyGraphWriteRequest "$Graph/groups" -Method POST -Body $body
    Write-Output "CREATED  $groupName   ($($new.id))"
    $Made++
}

Write-Verbose "Done. Created/would-create: $Made. Skipped existing: $Skipped. No match: $NoRows."
if ($DryRun) { Write-Output "`nDRY RUN - nothing was created. Set `$DryRun = `$false to apply." }

#endregion
