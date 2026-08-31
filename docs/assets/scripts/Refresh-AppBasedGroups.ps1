#requires -Version 7.0
<#
.SYNOPSIS
    Refresh-AppBasedGroups.ps1 - the REFRESH runbook. Reconciles each app-based Entra group's
    membership against who currently has the app in Intune. Adds freely, removes only after
    three safety gates. Report-only by default, with a CSV audit trail every run.

.DESCRIPTION
    Pairs with New-AppBasedEntraGroups.ps1. That one creates the groups; this one keeps them
    current. It walks every group whose name matches the convention "<Prefix> - <App> (CG)",
    works out which detected-app rows that app covers (name match, wildcards allowed), maps
    each device that has the app across the three-hop id chain to its Entra object id, and
    reconciles the group's membership.

    Built for a large, unattended estate. Instead of one Graph call per device, it reads all
    managed devices once and all Entra devices once and builds two in-memory hashtable lookups,
    so a full run is minutes not hours and mostly dodges throttling. Adds come straight from
    the inventory read. Removals are dangerous - a bad read could empty a group that is
    driving a required install - so nothing is removed until the run clears three gates. When
    unsure it does nothing and still processes the safe half, the adds.

    WRITE-CAPABLE. Unlike the read-only Zero-Access collectors, this one writes group
    membership. It never creates or deletes groups. DryRun is the default; it prints and
    CSV-logs exactly what it would change and touches nothing until you set DryRun to $false.

.PARAMETER DryRun
    $true (default) prints and logs the adds/removes it WOULD make and changes nothing.
    $false applies them, within the gates.

.PARAMETER RemoveStaleMembers
    $true lets the run remove members that no longer have the app (still gated). $false
    (default) only ever adds. Turn removals on once you trust the preview.

.PARAMETER OnlyApps
    Limit the run to groups whose app matches these names/patterns, e.g. -OnlyApps "TeamViewer*".
    Wildcards allowed. Omit to process every group under the prefix.

.NOTES
    Managed-Identity Graph app roles this runbook needs:
      DeviceManagementManagedDevices.Read.All     (managed devices, detected apps, each app's devices)
      Device.Read.All                             (Entra device objects)
      GroupMember.Read.All                        (read current members)
      GroupMember.ReadWrite.All                   (add and remove members)
    Plus the Azure RBAC role "Storage Blob Data Contributor" on the storage account (CSV only).
    Note: this runbook does NOT need Group.ReadWrite.All. Give that only to the creator.

    GENERIC / PARAMETERIZED: no resource group, storage account, tenant, or real app data is
    hardcoded. Run against a personal lab tenant only.

    BETA ENDPOINT: managed devices and detectedApps are on /beta; groups and devices on /v1.0
    behave the same for these calls. Re-verify after Graph updates.

    MIT licensed. Microsoft, Intune, Entra and Microsoft Graph are trademarks of the Microsoft
    group of companies. Independent content, not endorsed by Microsoft. Verify every endpoint
    and permission in your own lab tenant before relying on it.
#>

param(
    [bool]$DryRun = $true,
    [bool]$RemoveStaleMembers = $false,
    [string[]]$OnlyApps
)

# ===========================================================================
#  CONFIGURE ME  ->  set these three, then run.
# ===========================================================================
$ResourceGroup  = "<your-resource-group-name>"     # resource group that holds your storage account
$StorageAccount = "<your-storage-account-name>"    # storage account name (lowercase, globally unique)
$Container      = "<your-container-name>"           # blob container, e.g. "intune-reports"

$GroupPrefix    = "MDM Apps Discovered"             # must match the creator runbook's prefix
# ===========================================================================

if ("$ResourceGroup $StorageAccount $Container" -match '<your-') {
    throw "Set ResourceGroup, StorageAccount, and Container at the top of the script before running."
}

$Graph = "https://graph.microsoft.com/beta"
$GraphV1 = "https://graph.microsoft.com/v1.0"
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference  = 'Continue'
$results = [System.Collections.Generic.List[PSObject]]::new()

#region ---- HELPERS -------------------------------------------------------------

function Invoke-MyGraphGetRequest {
    param ([Parameter(Mandatory)][string]$URL)
    $AllResults = [System.Collections.Generic.List[PSObject]]::new()
    for ($Attempt = 1; $Attempt -le 5; $Attempt++) {
        try {
            do {
                $Response = Invoke-WebRequest -Uri $URL -Method GET -Headers $script:Headers -UseBasicParsing
                $Parsed   = $Response.Content | ConvertFrom-Json
                if ($Parsed.value) { $AllResults.AddRange([PSObject[]]$Parsed.value) }
                $URL = $Parsed.'@odata.nextLink'
            } while ($URL)
            return $AllResults
        }
        catch {
            $Code = [int]$_.Exception.Response.StatusCode
            if ($Code -eq 429 -or $Code -ge 500) {
                $Wait = [math]::Max(5 * $Attempt, 15)
                Write-Verbose "Throttled/transient ($Code) on GET. Waiting ${Wait}s..."
                Start-Sleep -Seconds $Wait
                continue
            }
            Write-Error "Graph GET failed [$URL]: $_"
            return $null
        }
    }
    return $null
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
                Write-Verbose "Throttled/transient ($Code) on $Method. Waiting ${Wait}s..."
                Start-Sleep -Seconds $Wait
                continue
            }
            throw
        }
    }
    throw "Graph $Method failed after retries: $URL"
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

# Az context for the CSV upload only (Graph uses the raw token above).
try { Connect-AzAccount -Identity -ErrorAction Stop | Out-Null }
catch { Write-Warning "Connect-AzAccount -Identity failed; CSV upload will be skipped: $_" }

#endregion

#region ---- BUILD THE TWO LOOKUP MAPS (ONCE) -----------------------------------
#
#  This is the whole reason it scales. One paged read of managed devices, one of Entra
#  devices, then every device resolves with a dictionary hit instead of a Graph call.

Write-Verbose "Reading all Intune managed devices..."
$IntuneDevices = Invoke-MyGraphGetRequest "$Graph/deviceManagement/managedDevices?`$select=id,deviceName,azureADDeviceId"
$IntuneDeviceMap = @{}
foreach ($d in $IntuneDevices) { $IntuneDeviceMap[$d.id] = $d }   # managedDevice.id -> device (has azureADDeviceId)

Write-Verbose "Reading all Entra devices..."
$EntraDevices = Invoke-MyGraphGetRequest "$GraphV1/devices?`$select=id,deviceId,displayName"
$EntraDeviceMap = @{}
foreach ($e in $EntraDevices) {
    # deviceId is the registration GUID that Intune's azureADDeviceId points at.
    if ($e.deviceId) { $EntraDeviceMap[$e.deviceId] = $e }
}

Write-Verbose "Reading detected apps..."
$Detected = Invoke-MyGraphGetRequest "$Graph/deviceManagement/detectedApps?`$select=id,displayName,version,deviceCount"

#endregion

#region ---- WALK THE GROUPS AND RECONCILE --------------------------------------

Write-Verbose "Reading app-based groups under prefix '$GroupPrefix'..."
$Groups = Invoke-MyGraphGetRequest "$GraphV1/groups?`$filter=startswith(displayName,'$GroupPrefix')&`$select=id,displayName,description"

foreach ($group in $Groups) {
    $groupId = $group.id

    # The app this group is for: strip the prefix and the "(CG)" suffix off the display name.
    $appLabel = $group.displayName -replace [regex]::Escape("$GroupPrefix - "), '' -replace '\s*\(CG\)\s*$',''

    # -OnlyApps filter (wildcards allowed).
    if ($OnlyApps -and -not ($OnlyApps | Where-Object { $appLabel -like $_ })) { continue }

    Write-Verbose "Group: $($group.displayName)  (app: $appLabel)"

    # Which detected-app rows count as this app? Match the label as a name or a prefix, so a
    # group named for "TeamViewer" folds every TeamViewer version and variant into one set.
    $appRows = $Detected | Where-Object { $_.displayName -eq $appLabel -or $_.displayName -like "$appLabel*" }
    if (-not $appRows) {
        Write-Warning "  No detected-app rows match '$appLabel' this run. Skipping (adds and removes both) to avoid acting on an empty read."
        continue
    }

    # --- resolve the members the app implies, across the three-hop id chain ---
    $memberIds  = @{}   # Entra object id -> device name (the thing we bind as a member)
    $intuneCount = 0
    foreach ($appVersion in $appRows) {
        $mds = Invoke-MyGraphGetRequest "$Graph/deviceManagement/detectedApps/$($appVersion.id)/managedDevices?`$select=id,deviceName"
        foreach ($d in $mds) {
            $intuneCount++
            $aadId = $IntuneDeviceMap[$d.id].azureADDeviceId   # Intune device -> registration GUID
            if (-not $aadId -or $aadId -eq '00000000-0000-0000-0000-000000000000') { continue }  # workplace-joined etc.
            $obj = $EntraDeviceMap[$aadId]                     # registration GUID -> Entra device object
            if ($obj) { $memberIds[$obj.id] = $d.deviceName }  # bind the OBJECT id as the member
        }
    }

    # Current members of the group.
    $current = Invoke-MyGraphGetRequest "$GraphV1/groups/$groupId/members?`$select=id"
    $currentMemberIds = @{}
    foreach ($m in $current) { $currentMemberIds[$m.id] = $true }

    # --- the safe half: adds ---
    $toAdd = @($memberIds.Keys | Where-Object { -not $currentMemberIds.ContainsKey($_) })

    # --- the dangerous half: removals, only past three gates ---
    $fetchIncomplete = $false

    # Gate 0 - resolution. Devices were fetched but none mapped to Entra. That is a
    # mapping failure, not "the app is gone", so it must not drive removals.
    if ($intuneCount -gt 0 -and $memberIds.Count -eq 0) { $fetchIncomplete = $true }

    # Gate 1 - completeness. The number we resolved has to reconcile with Graph's own
    # deviceCount for the app. If we are more than 5% short, the read was partial.
    $graphSaysCount = ($appRows | Measure-Object deviceCount -Sum).Sum
    if ($graphSaysCount -gt 0 -and $intuneCount -lt ($graphSaysCount * 0.95)) { $fetchIncomplete = $true }

    # If the fetch was incomplete, skip removals this run and still process the adds.
    $toRemove = if ($RemoveStaleMembers -and -not $fetchIncomplete) {
        @($currentMemberIds.Keys | Where-Object { -not $memberIds.ContainsKey($_) })
    } else { @() }

    # Gate 2 - never mass-remove, even on a clean read. If a refresh wants to drop more
    # than half a group (and more than ten), something is wrong. Skip and shout.
    if ($toRemove.Count -gt 10 -and $toRemove.Count -gt ($currentMemberIds.Count / 2)) {
        Write-Warning "  Would remove $($toRemove.Count) of $($currentMemberIds.Count) - too many, skipping removals for this group."
        $toRemove = @()
    }

    Write-Output ("  {0}: resolved {1}, current {2}, +{3} add, -{4} remove{5}" -f `
        $appLabel, $memberIds.Count, $currentMemberIds.Count, $toAdd.Count, $toRemove.Count, `
        $(if ($fetchIncomplete) { " (partial read - removals skipped)" } else { "" }))

    # --- apply, unless this is a dry run ---
    if (-not $DryRun) {
        # Adds go up in batches of twenty, the Graph limit for members@odata.bind.
        for ($i = 0; $i -lt $toAdd.Count; $i += 20) {
            $batch = $toAdd[$i..([Math]::Min($i + 19, $toAdd.Count - 1))]
            Invoke-MyGraphWriteRequest "$GraphV1/groups/$groupId" -Method PATCH -Body @{
                "members@odata.bind" = @($batch | ForEach-Object { "$GraphV1/directoryObjects/$_" })
            }
        }
        # Removals go one at a time so one bad object can't fail the batch.
        foreach ($id in $toRemove) {
            Invoke-MyGraphWriteRequest "$GraphV1/groups/$groupId/members/$id/`$ref" -Method DELETE
        }
    }

    # --- record every intended change for the CSV, add or remove, dry run or not ---
    foreach ($id in $toAdd)    { $results.Add([PSCustomObject]@{ Group=$group.displayName; App=$appLabel; Action='add';    ObjectId=$id; Device=$memberIds[$id];        Applied=(-not $DryRun) }) }
    foreach ($id in $toRemove) { $results.Add([PSCustomObject]@{ Group=$group.displayName; App=$appLabel; Action='remove'; ObjectId=$id; Device='(no longer has app)'; Applied=(-not $DryRun) }) }
}

#endregion

#region ---- WRITE THE CSV AUDIT TRAIL AND UPLOAD -------------------------------

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$kind    = if ($DryRun) { 'preview' } else { 'applied' }
$csvName = "AppBasedGroups-$kind-$stamp.csv"
$csvPath = Join-Path $env:TEMP $csvName
$results | Sort-Object Group, Action, Device | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Verbose "Wrote $($results.Count) rows to $csvName"

try {
    $Ctx = (Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccount).Context
    Set-AzStorageBlobContent -File $csvPath -Container $Container -Blob "agent-data/$csvName" `
                             -Context $Ctx -Force | Out-Null
    Write-Verbose "Uploaded: agent-data/$csvName"
}
catch { Write-Warning "Blob upload failed (CSV is still at $csvPath): $_" }

if ($DryRun) { Write-Output "`nDRY RUN - nothing was changed. Read $csvName, then run with -DryRun `$false to apply." }
Write-Verbose "Script completed."

#endregion
