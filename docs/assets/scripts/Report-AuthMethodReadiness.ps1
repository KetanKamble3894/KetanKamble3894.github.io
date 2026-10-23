param(
    [Parameter(Mandatory = $false, HelpMessage = "True = report only (GET calls only). False = also add/remove group members to match the classification.")]
    [bool]$DryRun = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Optional. Resolve groups by object ID: 'PhishingResistant=<guid>;StrongNotPR=<guid>;...;ExclusionNonHuman=<guid>'. Keys not listed fall back to displayName lookup.")]
    [string]$GroupIdMap = "",

    [Parameter(Mandatory = $false, HelpMessage = "Skip disabled accounts.")]
    [bool]$ExcludeDisabledAccounts = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Skip external users: #EXT# in the UPN, or an externalUserState from a B2B invitation. Internal guests stay in scope; Microsoft keeps them on the 1 February 2027 date with members.")]
    [bool]$ExcludeExternalGuests = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Comma separated name fragments that mark a non-human account. Matched against the UPN local part; fragments of 5+ characters are also matched against the display name.")]
    [string]$ServiceAccountPatterns = "svc,service,sa,shared,room,equip,equipment,printer,scanner,kiosk,test,demo,mailbox,noreply,no-reply",

    [Parameter(Mandatory = $false, HelpMessage = "Comma separated prefixes that mark an admin account. Matched against the UPN local part only. Used only when employeeType is empty or unmapped.")]
    [string]$AdminAccountPatterns = "adm,admin,a-,_adm",

    [Parameter(Mandatory = $false, HelpMessage = "employeeType value -> kind. Kinds: Person, NonHuman, Admin. This is the PRIMARY test; name patterns are the fallback for empty or unmapped values. Unmapped values are counted in the summary.")]
    [string]$EmployeeTypeMap = "Employee=Person;Partner=Person;Common=NonHuman;System=NonHuman;test=NonHuman;Admin=Admin",

    [Parameter(Mandatory = $false, HelpMessage = "Warn when a group moves more than this percent against the previous run. 0 disables the check.")]
    [int]$DriftWarnPercent = 15,

    [Parameter(Mandatory = $false, HelpMessage = "Abort if fewer than this percent of IN-SCOPE users have a registration row. Guards against a failed read.")]
    [int]$MinCoveragePercent = 90,

    [Parameter(Mandatory = $false, HelpMessage = "Skip UNEXPLAINED removals for a group if one run would remove more than this percent of it. Users moving to another group are always removed; this only gates users that vanished from the classification.")]
    [int]$MaxRemovalPercent = 80
)

#-- Step 1 - Variables ---------------------------------------------------------------------
$GraphBase          = "https://graph.microsoft.com"
# Storage for the CSV upload. Replace all three with your own names, or leave them as they are
# and the runbook skips the upload and still classifies and syncs. Storage account names are
# globally unique, so never publish your real one.
$ResourceGroup      = "<your-resource-group>"
$StorageAccount     = "<yourstorageaccount>"
$Container          = "<your-container>"
$BlobFolder         = "auth-method-groups"
$ExportLocation     = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$Today              = Get-Date -Format 'yyyy-MM-dd'
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference  = 'Continue'
$script:RunStart    = Get-Date
$script:TimeBudgetMinutes = 150     # Automation fair share is 180. Stop sleeping on throttles well before it.

# Group display names. Change here and in the portal together, or pass GroupIdMap.
$GroupDefs = [ordered]@{
    'PhishingResistant'  = 'Auth - Phishing-resistant Method Users (CG)'
    'StrongNotPR'        = 'Auth - Strong Method Users (CG)'
    'TelephonyOnly'      = 'Auth - Telephony Only Users (CG)'
    'NoMfa'              = 'Auth - No Method Registered Users (CG)'
    'NoRegistrationData' = 'Auth - No Registration Data Users (CG)'
    'Review'             = 'Auth - Manual Review Users (CG)'
}
$ExclusionKey  = 'ExclusionNonHuman'
$ExclusionName = 'Auth - Non-human Accounts Exclusion (CG)'

Write-Output "AuthMethodGroups 2.2 | ExcludeDisabled=$ExcludeDisabledAccounts | ExcludeExternalGuests=$ExcludeExternalGuests | DriftWarnPercent=$DriftWarnPercent | MaxRemovalPercent=$MaxRemovalPercent"
if ($DryRun) { Write-Output "DRY RUN. GET calls only. Nothing in Entra is created or changed." }
else         { Write-Output "APPLY MODE. Group MEMBERSHIP will be changed. No group is created, renamed or deleted by this runbook." }

#-- Step 2 - Graph helpers ------------------------------------------------------------------
# One place decides whether a failed call is worth retrying and for how long. Both the GET
# and the write helper use it, so Retry-After parsing and the time budget are fixed once.
# PS7 exposes Headers.RetryAfter.Delta; PS5 exposes Headers['Retry-After']. Both are handled.
function Get-GraphRetryDecision {
    param($ErrorRecord, [int]$Attempt, [int]$MaxRetries)
    $code = $null
    if ($ErrorRecord.Exception.Response) { try { $code = [int]$ErrorRecord.Exception.Response.StatusCode } catch { } }
    $detail = ''
    try { if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) { $detail = $ErrorRecord.ErrorDetails.Message } } catch { }
    $retryable = ($null -ne $code) -and ($code -in @(429, 503, 504))
    if (-not $retryable -or $Attempt -ge $MaxRetries) {
        return [pscustomobject]@{ Retry = $false; StatusCode = $code; Wait = 0; Detail = $detail }
    }
    $wait = 60
    try {
        $hdr = $ErrorRecord.Exception.Response.Headers
        if ($hdr.RetryAfter -and $hdr.RetryAfter.Delta) { $wait = [int][math]::Ceiling($hdr.RetryAfter.Delta.TotalSeconds) }
        elseif ($hdr['Retry-After'])                    { $wait = [int]$hdr['Retry-After'] }
    } catch { }
    if ($wait -le 0) { $wait = 60 }
    $wait = [math]::Min($wait, 300)
    if (((Get-Date) - $script:RunStart).TotalMinutes -gt $script:TimeBudgetMinutes) {
        throw "Time budget of $($script:TimeBudgetMinutes) minutes exhausted while Graph was throttling. Nothing further was changed. Re-run later."
    }
    return [pscustomobject]@{ Retry = $true; StatusCode = $code; Wait = $wait; Detail = $detail }
}

# GET with paging. Returns the collected .value array (an empty array is a valid, empty result)
# or $null when the call failed. -Single returns one object instead of paging a collection.
# Nothing in here may use Write-Output: it would be captured into the return value.
function Invoke-MyGraphGetRequest {
    param([string]$URL, [int]$MaxRetries = 10, [switch]$WarnOnly, [switch]$Single)
    Write-Verbose "GET $URL"
    $AllResults = [System.Collections.Generic.List[object]]::new()
    do {
        $WebRequest = $null
        $attempt    = 0
        while (-not $WebRequest) {
            try {
                $WebRequest = Invoke-WebRequest -Uri $URL -Method GET -Headers $script:Headers -UseBasicParsing -Verbose:$false
            } catch {
                $attempt++
                $d = Get-GraphRetryDecision -ErrorRecord $_ -Attempt $attempt -MaxRetries $MaxRetries
                if (-not $d.Retry) {
                    $msg = "GET failed (HTTP $($d.StatusCode)) for ${URL}: $($_.Exception.Message) $($d.Detail)"
                    if ($WarnOnly) { Write-Warning $msg } else { Write-Error $msg }
                    return $null
                }
                Write-Warning "Throttled (HTTP $($d.StatusCode)) - attempt $attempt of $MaxRetries, waiting $($d.Wait) s..."
                Start-Sleep -Seconds $d.Wait
            }
        }
        $ResponseData = ($WebRequest.Content | ConvertFrom-Json)
        if ($Single) { return $ResponseData }
        if ($null -ne $ResponseData.value) { foreach ($v in $ResponseData.value) { $AllResults.Add($v) } }
        $URL = $ResponseData.'@odata.nextLink'
    } while ($URL)
    return ,$AllResults.ToArray()
}

# Writes (PATCH / POST). Only reached when DryRun is false. Returns Success, StatusCode, Data, Detail.
function Invoke-MyGraphWriteRequest {
    param([string]$URL, [string]$Method = "POST", $Body, [int]$MaxRetries = 10)
    $json    = $Body | ConvertTo-Json -Depth 6
    $attempt = 0
    while ($true) {
        try {
            $resp = Invoke-RestMethod -Uri $URL -Method $Method -Headers $script:Headers -ContentType "application/json" -Body $json -Verbose:$false
            return [pscustomobject]@{ Success = $true; StatusCode = 200; Data = $resp; Detail = '' }
        } catch {
            $attempt++
            $d = Get-GraphRetryDecision -ErrorRecord $_ -Attempt $attempt -MaxRetries $MaxRetries
            if (-not $d.Retry) {
                return [pscustomobject]@{ Success = $false; StatusCode = $d.StatusCode; Data = $null; Detail = "$($_.Exception.Message) $($d.Detail)" }
            }
            Start-Sleep -Seconds $d.Wait
        }
    }
}

# Adds or removes members one request each inside a $batch (20 per call). Used for all removals
# and as the fallback when a 20-member PATCH is rejected as a whole. $batch returns 200 even when
# sub-requests fail, so every sub-response is inspected. Returns Done / Deferred / Failed counts.
#   Add:    201/204 done; 400 "already exist" done (end state reached); 404 deferred (user gone).
#   Remove: 204 done; 404 done (not a member is the end state).
function Invoke-GroupMembershipBatch {
    param([string]$GroupId, [string[]]$MemberIds, [ValidateSet('Add','Remove')][string]$Action, [int]$MaxRetries = 10)
    $done = 0; $deferred = 0; $failed = 0
    for ($i = 0; $i -lt $MemberIds.Count; $i += 20) {
        $slice    = @($MemberIds[$i..([Math]::Min($i + 19, $MemberIds.Count - 1))])
        $requests = @()
        for ($j = 0; $j -lt $slice.Count; $j++) {
            if ($Action -eq 'Remove') {
                $requests += @{ id = "$j"; method = 'DELETE'; url = "/groups/$GroupId/members/$($slice[$j])/`$ref" }
            } else {
                $requests += @{ id = "$j"; method = 'POST'; url = "/groups/$GroupId/members/`$ref"
                                headers = @{ 'Content-Type' = 'application/json' }
                                body = @{ '@odata.id' = "$GraphBase/v1.0/directoryObjects/$($slice[$j])" } }
            }
        }
        $attempt = 0
        while ($true) {
            $res = Invoke-MyGraphWriteRequest -URL "$GraphBase/v1.0/`$batch" -Method POST -Body @{ requests = $requests }
            if (-not $res.Success) {
                if ($res.StatusCode -eq 403) { throw "Graph refused a membership change with 403. The managed identity needs GroupMember.ReadWrite.All (admin consented) for DryRun = false. $($res.Detail)" }
                $failed += $requests.Count; break
            }
            $retry = @(); $wait = 30
            foreach ($r in $res.Data.responses) {
                $req = $requests | Where-Object { $_.id -eq $r.id } | Select-Object -First 1
                $uid = if ($req) { ($req.url -split '/')[-2] } else { $r.id }
                if ($Action -eq 'Add') { $uid = if ($req) { ($req.body.'@odata.id' -split '/')[-1] } else { $r.id } }
                $errMsg = ''; try { $errMsg = [string]$r.body.error.message } catch { }
                switch ($true) {
                    ($r.status -in @(200, 201, 204))                                        { $done++; break }
                    ($Action -eq 'Remove' -and $r.status -eq 404)                            { $done++; break }
                    ($Action -eq 'Add' -and $r.status -eq 400 -and $errMsg -match 'already exist') { $done++; break }
                    ($Action -eq 'Add' -and $r.status -eq 404)                               { $deferred++; Write-Warning "  $Action deferred, user $uid not found (deleted since the read?)"; break }
                    ($r.status -eq 429)                                                     { $retry += $req; try { $ra = [int]$r.headers.'Retry-After'; if ($ra -gt $wait) { $wait = [math]::Min($ra, 300) } } catch { }; break }
                    ($r.status -eq 403)                                                     { throw "Graph refused a membership change with 403 for user $uid. The managed identity needs GroupMember.ReadWrite.All. $errMsg" }
                    default                                                                 { $failed++; Write-Warning "  $Action failed (HTTP $($r.status)) for user $uid : $errMsg" }
                }
            }
            if ($retry.Count -eq 0) { break }
            $attempt++
            if ($attempt -gt $MaxRetries) { $failed += $retry.Count; break }
            if (((Get-Date) - $script:RunStart).TotalMinutes -gt $script:TimeBudgetMinutes) { throw "Time budget exhausted during membership batches." }
            Start-Sleep -Seconds $wait
            $requests = $retry
        }
    }
    return [pscustomobject]@{ Done = $done; Deferred = $deferred; Failed = $failed }
}

# Probes one endpoint with a single-row read so a missing permission is named up front.
# Nothing in here may use Write-Output: it would be captured into the return value.
function Test-GraphAccess {
    param([string]$Url, [string]$Needs, [string]$For)
    try {
        Invoke-RestMethod -Uri $Url -Method GET -Headers $script:Headers -Verbose:$false | Out-Null
        return $true
    } catch {
        $code = $null; if ($_.Exception.Response) { try { $code = [int]$_.Exception.Response.StatusCode } catch { } }
        if     ($code -eq 403) { Write-Warning "  DENIED  $For - the managed identity is missing '$Needs', or it is granted but not consented." }
        elseif ($code -eq 401) { Write-Warning "  DENIED  $For - token rejected (401). Check the identity is enabled on the Automation account." }
        elseif ($null -eq $code) { Write-Warning "  FAILED  $For - no HTTP response. $($_.Exception.Message)" }
        else                   { Write-Warning "  FAILED  $For - HTTP $code. $($_.Exception.Message)" }
        return $false
    }
}

#-- Step 3 - Authentication ------------------------------------------------------------------
Write-Verbose "Obtaining Graph token"
if ($env:IDENTITY_ENDPOINT) {
    $tokenHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $tokenHeaders.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER)
    $tokenHeaders.Add("Metadata", "True")
    $accessToken = (Invoke-RestMethod $env:IDENTITY_ENDPOINT -Method 'POST' -Headers $tokenHeaders `
                    -ContentType 'application/x-www-form-urlencoded' -Body @{ resource = 'https://graph.microsoft.com/' }).access_token
} else {
    $imdsUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fgraph.microsoft.com%2F"
    $accessToken = (Invoke-RestMethod -Uri $imdsUri -Method GET -Headers @{ Metadata = "true" }).access_token
}
if (-not $accessToken) { throw "Failed to obtain a Graph access token from the managed identity endpoint." }
$script:Headers = @{ 'Authorization' = "Bearer $accessToken" }
Write-Verbose "Graph token obtained"

# Az context for the CSV upload. Harmless if the sandbox is already connected. A failure here
# does not stop classification; it only disables the upload, and says so.
$script:StorageCtx = $null
if ("$ResourceGroup$StorageAccount$Container" -match '<') {
    Write-Warning "Storage names are still placeholders; CSVs will be written to the job but not uploaded."
} else { try {
    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    $script:StorageCtx = (Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccount -ErrorAction Stop).Context
    Write-Verbose "Storage context obtained"
} catch {
    Write-Warning "Azure storage context unavailable; CSVs will be written to the job but not uploaded. $_"
} }

#-- Step 3b - Permission preflight -----------------------------------------------------------
Write-Output "Checking Graph permissions..."
$okUsers  = Test-GraphAccess -Url "$GraphBase/v1.0/users?`$top=1&`$select=id" -Needs 'User.Read.All' -For 'List users'
Write-Output "  $(if ($okUsers)  { 'OK     ' } else { 'FAILED ' }) List users"
$okReg    = Test-GraphAccess -Url "$GraphBase/v1.0/reports/authenticationMethods/userRegistrationDetails?`$top=1" -Needs 'AuditLog.Read.All (and an Entra ID P1 or P2 licence in the tenant)' -For 'Read registration details'
Write-Output "  $(if ($okReg)    { 'OK     ' } else { 'FAILED ' }) Read authentication method registration details"
$okGroups = Test-GraphAccess -Url "$GraphBase/v1.0/groups?`$top=1&`$select=id" -Needs 'GroupMember.Read.All' -For 'Read groups'
Write-Output "  $(if ($okGroups) { 'OK     ' } else { 'FAILED ' }) Read groups and members (needed for the diff, even in DryRun)"
if (-not ($okUsers -and $okReg -and $okGroups)) {
    throw "Preflight failed. Grant the permissions above to the managed identity and consent them, then re-run. Nothing was read."
}
if (-not $DryRun) { Write-Output "  (write)  GroupMember.ReadWrite.All cannot be probed without writing; a 403 on the first change aborts the apply step." }

#-- Step 4 - Classification helpers ----------------------------------------------------------
# Explicit map of the documented methodsRegistered values. Anything not listed is Unknown: it
# goes to Review, never to a group on a pattern guess, and the summary names it with a best
# guess so a person adds it here on purpose. Order of precedence is decided in Step 7.
$script:MethodClassMap = @{
    'fido2SecurityKey'                  = 'PhishingResistant'
    'passKeyDeviceBound'                = 'PhishingResistant'
    'passKeyDeviceBoundAuthenticator'   = 'PhishingResistant'
    'passKeyDeviceBoundWindowsHello'    = 'PhishingResistant'
    'passKeySynced'                     = 'PhishingResistant'   # synced passkey, works across the user's devices
    'windowsHelloForBusiness'           = 'PhishingResistant'
    'macOsSecureEnclaveKey'             = 'PhishingResistant'
    'microsoftAuthenticatorPush'        = 'Strong'
    'microsoftAuthenticatorPasswordless'= 'Strong'
    'softwareOneTimePasscode'           = 'Strong'
    'hardwareOneTimePasscode'           = 'Strong'
    'externalAuthMethod'                = 'Strong'      # third-party MFA (e.g. Duo): satisfies MFA, not phishing-resistant
    'mobilePhone'                       = 'Telephony'
    'alternateMobilePhone'              = 'Telephony'
    'officePhone'                       = 'Telephony'
    'temporaryAccessPass'               = 'Temporary'
    'email'                             = 'SsprOnly'
    'securityQuestion'                  = 'SsprOnly'
    'none'                              = 'None'
    'qrCodePin'                         = 'NotMfa'      # QR code + PIN, Microsoft documents it as single-factor
    'unknownFutureValue'                = 'Unknown'
}
# Portable phishing-resistant methods work from any device. Device-bound ones (Hello, Secure
# Enclave) do not help on a phone browser or a replacement laptop. Reported, not yet a group.
$script:PortablePR = @('fido2SecurityKey','passKeyDeviceBound','passKeyDeviceBoundAuthenticator','passKeySynced')

function Get-MethodClass {
    param([string]$Method)
    if ([string]::IsNullOrWhiteSpace($Method)) { return 'Unknown' }
    if ($script:MethodClassMap.ContainsKey($Method)) { return $script:MethodClassMap[$Method] }
    return 'Unknown'   # not in the map: Review, never a pattern guess
}

# Best guess for an unmapped value, used ONLY in the warning and summary so a person can add it to
# the map. It never decides a group. Certificate auth can be single- or multi-factor depending on
# your CBA policy, so it is never guessed as phishing-resistant.
function Get-MethodGuess {
    param([string]$Method)
    $m = ([string]$Method).ToLowerInvariant()
    if ($m -match 'x509|certificate')                          { return 'certificate, check your CBA policy (single- or multi-factor)' }
    if ($m -match 'passkey|fido2|windowshello|secureenclave')  { return 'PhishingResistant' }
    if ($m -match 'authenticator|oath|onetimepasscode|totp')   { return 'Strong' }
    if ($m -match 'phone|sms|voice')                           { return 'Telephony' }
    if ($m -match 'temporaryaccesspass')                       { return 'Temporary' }
    if ($m -match '^email$|securityquestion|alternateemail|qrcode') { return 'NotMfa' }
    return 'no guess'
}

# Builds a token-aware regex from a comma list, or $null when the list is empty. An empty regex
# would match everything, so the caller must test for $null before using it.
function New-PatternRegex {
    param([string]$Patterns, [switch]$Prefix, [int]$MinLength = 0)
    $parts = @($Patterns -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_.Length -ge $MinLength } | ForEach-Object {
        $p = $_; $e = [regex]::Escape($p)
        if ($Prefix) { if ($p -match '[-_.]$') { "^$e" } else { "^$e[-_.]" } }
        elseif ($p -match '[-_]')    { "(^|[-_. ])$e" }
        elseif ($p.Length -le 4)     { "(^|[-_. ])$e([-_. ]|\d|$)" }
        else                         { "(^|[-_. ])$e" }
    })
    if ($parts.Count -eq 0) { return $null }
    return ($parts -join '|')
}

$script:SvcRegexUpn  = New-PatternRegex -Patterns $ServiceAccountPatterns
$script:SvcRegexName = New-PatternRegex -Patterns $ServiceAccountPatterns -MinLength 5   # short tokens hit real names ("Sa Nguyen", "Jan Test")
$script:AdmRegex     = New-PatternRegex -Patterns $AdminAccountPatterns -Prefix
$script:AdmExact     = @($AdminAccountPatterns   -split ',' | ForEach-Object { $_.Trim().Trim('-','_','.') } | Where-Object { $_ })
$script:SvcExact     = @($ServiceAccountPatterns -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# employeeType is the authoritative signal when HR populates it. Keys are case-insensitive.
$script:EmpTypeMap = @{}
foreach ($pair in ($EmployeeTypeMap -split '[;,]')) {
    if ($pair -match '^\s*([^=]+?)\s*=\s*(Person|NonHuman|Admin)\s*$') { $script:EmpTypeMap[$Matches[1].ToLowerInvariant()] = $Matches[2] }
    elseif ($pair.Trim()) { Write-Warning "EmployeeTypeMap entry ignored (expected Value=Person|NonHuman|Admin): '$pair'" }
}
$script:UnmappedEmpTypes = @{}

function Get-AccountKind {
    param([string]$Upn, [string]$DisplayName, [string]$EmployeeType)
    if ([string]::IsNullOrWhiteSpace($Upn)) { return 'Unknown' }
    # 1. employeeType, when present and mapped, decides on its own.
    if (-not [string]::IsNullOrWhiteSpace($EmployeeType)) {
        $k = $EmployeeType.Trim().ToLowerInvariant()
        if ($script:EmpTypeMap.ContainsKey($k)) {
            switch ($script:EmpTypeMap[$k]) { 'Admin' { return 'Admin' } 'NonHuman' { return 'ServiceOrShared' } default { return 'Person' } }
        }
        if (-not $script:UnmappedEmpTypes.ContainsKey($k)) { $script:UnmappedEmpTypes[$k] = 0 }
        $script:UnmappedEmpTypes[$k]++
    }
    # 2. Fallback for empty or unmapped employeeType: name patterns.
    $local = (($Upn -split '@')[0]).ToLowerInvariant()
    $name  = ([string]$DisplayName).ToLowerInvariant()
    if ($local -in $script:AdmExact)                                              { return 'Admin' }
    if ($local -in $script:SvcExact)                                              { return 'ServiceOrShared' }
    if ($script:AdmRegex     -and $local -match $script:AdmRegex)                 { return 'Admin' }
    if ($script:SvcRegexUpn  -and $local -match $script:SvcRegexUpn)              { return 'ServiceOrShared' }
    if ($script:SvcRegexName -and $name  -match $script:SvcRegexName)             { return 'ServiceOrShared' }
    return 'Person'
}

# Writes a CSV that always has a header row, even when there are no rows. A 0-byte file breaks
# Power BI refresh and the drift reader.
function Export-CsvSafe {
    param([object[]]$Rows, [string]$Path, [string[]]$Columns)
    if ($Rows -and $Rows.Count -gt 0) {
        $Rows | Select-Object $Columns | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -Force
    } else {
        Set-Content -Path $Path -Value ('"' + ($Columns -join '","') + '"') -Encoding UTF8 -Force
    }
}

#-- Step 5 - Users (bulk) --------------------------------------------------------------------
Write-Verbose "Fetching users..."
$UserSelect = "id,userPrincipalName,displayName,accountEnabled,userType,externalUserState,employeeType,department,jobTitle,companyName,createdDateTime"
$Users = Invoke-MyGraphGetRequest -URL "$GraphBase/v1.0/users?`$select=$UserSelect&`$top=999"
if ($null -eq $Users -or $Users.Count -eq 0) { throw "Failed to fetch users (or the directory returned none). Aborting." }
Write-Output "Users fetched: $($Users.Count)"

#-- Step 6 - Registration details (bulk) -----------------------------------------------------
Write-Verbose "Fetching authentication method registration details..."
$RegDetails = Invoke-MyGraphGetRequest -URL "$GraphBase/v1.0/reports/authenticationMethods/userRegistrationDetails?`$top=999"
if ($null -eq $RegDetails -or $RegDetails.Count -eq 0) { throw "Failed to fetch registration details (or the report returned no rows). Aborting." }
Write-Output "Registration rows fetched: $($RegDetails.Count)"

$RegMap = @{}
foreach ($r in $RegDetails) { if ($r.id) { $RegMap[$r.id] = $r } }

# Raw ratio only, for diagnosis. The gate is in Step 7b, against the in-scope population.
$rawCoverage = [math]::Round($RegMap.Count / $Users.Count, 3)
Write-Output "Registration rows cover $($RegMap.Count) of $($Users.Count) directory objects ($([int]($rawCoverage*100))%) - see in-scope coverage below, which is the number that matters."

#-- Step 7 - Classify every in-scope user ----------------------------------------------------
$Rows            = [System.Collections.Generic.List[object]]::new()
$UnknownMethods  = @{}
$skippedDisabled = 0; $skippedExternal = 0; $noRegRow = 0

foreach ($u in $Users) {
    if ($ExcludeDisabledAccounts -and -not $u.accountEnabled) { $skippedDisabled++; continue }
    # Only external users are out of scope: #EXT# in the UPN, or an externalUserState, which Graph
    # sets on B2B-invited accounts. Internal guests (userType Guest, neither signal) sign in here with
    # methods registered here, and Microsoft keeps them on the 1 February 2027 date with members.
    $isExternalGuest = ([string]$u.userPrincipalName -like '*#EXT#*') -or (-not [string]::IsNullOrEmpty([string]$u.externalUserState))
    if ($ExcludeExternalGuests -and $isExternalGuest) { $skippedExternal++; continue }

    $reg     = if ($RegMap.ContainsKey($u.id)) { $RegMap[$u.id] } else { $null }
    if (-not $reg) { $noRegRow++ }
    $methods = @(); if ($reg -and $reg.methodsRegistered) { $methods = @($reg.methodsRegistered) }
    $methods = @($methods | Where-Object { $_ -and $_ -ne 'none' })

    $classes = @{}
    foreach ($m in $methods) {
        $c = Get-MethodClass -Method $m
        $classes[$c] = $true
        if ($c -eq 'Unknown') {
            if (-not $UnknownMethods.ContainsKey($m)) { $UnknownMethods[$m] = 0 }
            $UnknownMethods[$m]++
        }
    }
    $hasPR   = $classes.ContainsKey('PhishingResistant')
    $hasStr  = $classes.ContainsKey('Strong')
    $hasTel  = $classes.ContainsKey('Telephony')
    $hasUnk  = $classes.ContainsKey('Unknown')
    $hasTap  = $classes.ContainsKey('Temporary')
    $hasSspr = $classes.ContainsKey('SsprOnly')
    $hasNotMfa = $classes.ContainsKey('NotMfa')   # single-factor sign-in such as QR code + PIN
    $hasPortablePR = @($methods | Where-Object { $_ -in $script:PortablePR }).Count -gt 0

    # Precedence. Strongest first. An unrecognised value never decides a safe group on its own:
    # it goes to Review for a person to look at, and is listed in the summary.
    $reason = ''
    $group =
        if     ($hasPR)                  { 'PhishingResistant' }
        elseif ($hasStr)                 { 'StrongNotPR' }
        elseif ($hasUnk)                 { $reason = 'UnknownMethod'; 'Review' }
        elseif ($hasTel)                 { 'TelephonyOnly' }
        elseif (-not $reg)               { 'NoRegistrationData' }
        elseif ($methods.Count -eq 0)    { $reason = 'NothingRegistered'; 'NoMfa' }
        elseif ($hasTap -and -not ($hasSspr -or $hasNotMfa)) { $reason = 'TapOnly'; 'Review' }
        elseif ($hasNotMfa)              { $reason = 'SingleFactorOnly'; 'NoMfa' }
        elseif ($hasSspr)                { $reason = 'SsprMethodsOnly'; 'NoMfa' }
        else                             { 'Review' }

    $kind    = Get-AccountKind -Upn $u.userPrincipalName -DisplayName $u.displayName -EmployeeType ([string]$u.employeeType)
    $ageDays = ''; try { if ($u.createdDateTime) { $ageDays = [int]((Get-Date) - [datetime]$u.createdDateTime).TotalDays } } catch { }

    $Rows.Add([pscustomobject]@{
        UserId               = $u.id
        UserPrincipalName    = $u.userPrincipalName
        DisplayName          = $u.displayName
        UserType             = $u.userType
        Department           = $u.department
        JobTitle             = $u.jobTitle
        EmployeeType         = $u.employeeType
        AccountKind          = $kind
        IsAdmin              = $(if ($reg) { [bool]$reg.isAdmin } else { $false })
        AccountAgeDays       = $ageDays
        MembershipGroup      = $group
        Reason               = $reason
        ExclusionNonHuman    = ($kind -ne 'Person')
        MethodsRegistered    = ($methods -join ';')
        HasPhishingResistant = $hasPR
        HasPortablePR        = $hasPortablePR
        HasStrong            = $hasStr
        HasTelephony         = $hasTel
        PreferredMethod      = $(if ($reg) { [string]$reg.userPreferredMethodForSecondaryAuthentication } else { '' })
        IsSsprRegistered     = $(if ($reg) { [bool]$reg.isSsprRegistered } else { $null })
        SnapshotDate         = $Today
    })
}
Write-Output "Classified: $($Rows.Count) | skipped disabled: $skippedDisabled | skipped external guests: $skippedExternal | no registration row: $noRegRow"

#-- Step 7b - Coverage gate against the in-scope population ----------------------------------
$inScopeCoverage = if ($Rows.Count -gt 0) { [math]::Round(($Rows.Count - $noRegRow) / $Rows.Count, 3) } else { 0 }
Write-Output "In-scope registration coverage: $($Rows.Count - $noRegRow) of $($Rows.Count) classified users ($([int]($inScopeCoverage*100))%)"
if ($inScopeCoverage -lt ($MinCoveragePercent / 100)) {
    throw ("In-scope coverage is only $([int]($inScopeCoverage*100))%, below the $MinCoveragePercent% floor. " +
           "That points at a failed or throttled registration read rather than a tenant with no MFA. " +
           "Aborting rather than publishing a misleading membership list. If this is genuinely normal, lower MinCoveragePercent and re-run.")
}
if ($script:UnmappedEmpTypes.Count -gt 0) {
    Write-Warning "employeeType values not in EmployeeTypeMap (name patterns used instead): $(($script:UnmappedEmpTypes.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')"
}
if ($UnknownMethods.Count -gt 0) {
    Write-Warning "Unrecognised authentication method values found. Holders went to Review (Reason=UnknownMethod). Add them to MethodClassMap:"
    foreach ($k in ($UnknownMethods.Keys | Sort-Object)) { Write-Warning "  $k  ($($UnknownMethods[$k]) users) - looks like: $(Get-MethodGuess $k)" }
}

#-- Step 8 - Summary and reconciliation ------------------------------------------------------
$Summary = [System.Collections.Generic.List[object]]::new()
function Add-SummaryRow { param($Key, $Name, $Members, $NonHuman) $Summary.Add([pscustomobject]@{ GroupKey=$Key; ProposedName=$Name; Members=[int]$Members; NonHuman=[int]$NonHuman; SnapshotDate=$Today }) }

foreach ($key in $GroupDefs.Keys) {
    $members = @($Rows | Where-Object { $_.MembershipGroup -eq $key })
    Add-SummaryRow $key $GroupDefs[$key] $members.Count @($members | Where-Object ExclusionNonHuman).Count
}
$excl = @($Rows | Where-Object ExclusionNonHuman)
Add-SummaryRow $ExclusionKey $ExclusionName $excl.Count $excl.Count

# Information rows. Not groups. Drift and partition checks skip anything prefixed 'Info:'.
Add-SummaryRow 'Info:PR_DeviceBoundOnly' 'PhishingResistant users whose only PR method is device-bound (Hello/Secure Enclave)' @($Rows | Where-Object { $_.MembershipGroup -eq 'PhishingResistant' -and -not $_.HasPortablePR }).Count 0
Add-SummaryRow 'Info:AdminsTelephonyOnly' 'Admin accounts (isAdmin) still telephony-only - raise ahead of the SMS and voice retirement' @($Rows | Where-Object { $_.IsAdmin -and $_.MembershipGroup -eq 'TelephonyOnly' }).Count 0
Add-SummaryRow 'Info:TelephonyOnlyUnder14Days' 'Telephony-only accounts created in the last 14 days (likely still onboarding)' @($Rows | Where-Object { $_.MembershipGroup -eq 'TelephonyOnly' -and $_.AccountAgeDays -ne '' -and [int]$_.AccountAgeDays -lt 14 }).Count 0
foreach ($k in ($UnknownMethods.Keys | Sort-Object)) { Add-SummaryRow "Info:UnknownMethod" "Unrecognised method value: $k (looks like: $(Get-MethodGuess $k))" $UnknownMethods[$k] 0 }
foreach ($k in ($script:UnmappedEmpTypes.Keys | Sort-Object)) { Add-SummaryRow "Info:EmployeeTypeUnmapped" "employeeType '$k' is not in EmployeeTypeMap; name patterns were used for these users" $script:UnmappedEmpTypes[$k] 0 }
$Rows | Where-Object { $_.MembershipGroup -eq 'TelephonyOnly' } | Group-Object { if ($_.EmployeeType) { [string]$_.EmployeeType } else { '(empty)' } } | Sort-Object Count -Descending | ForEach-Object {
    Add-SummaryRow "Info:TelephonyOnlyByEmployeeType" "TelephonyOnly with employeeType = $($_.Name)" $_.Count @($_.Group | Where-Object ExclusionNonHuman).Count
}

Write-Output "`n=== GROUP MEMBERSHIP ($(if ($DryRun) { 'proposed' } else { 'to apply' })) ==="
$Summary | Format-Table GroupKey, Members, NonHuman, ProposedName -AutoSize | Out-String -Width 220 | Write-Output

# Partition check: the six membership groups must cover every classified user exactly once.
$partition = ($Summary | Where-Object { $_.GroupKey -in $GroupDefs.Keys } | Measure-Object Members -Sum).Sum
if ($partition -ne $Rows.Count) {
    throw "Membership groups sum to $partition but $($Rows.Count) users were classified. The groups are not a clean partition. Nothing was changed."
}
Write-Output "Reconciliation OK: $($GroupDefs.Count) membership groups partition all $($Rows.Count) classified users exactly once."

#-- Step 8b - Drift against the previous run -------------------------------------------------
if ($DriftWarnPercent -gt 0 -and $script:StorageCtx) {
    $prevBlob = Get-AzStorageBlob -Container $Container -Blob "$BlobFolder/AuthGroup_Summary.csv" -Context $script:StorageCtx -ErrorAction SilentlyContinue
    if (-not $prevBlob) {
        Write-Output "`nNo previous summary in storage. Drift check skipped (first run)."
    } else {
        try {
            $prevPath = Join-Path $ExportLocation "AuthGroup_Summary_previous.csv"
            Get-AzStorageBlobContent -Container $Container -Blob "$BlobFolder/AuthGroup_Summary.csv" -Destination $prevPath -Context $script:StorageCtx -Force -ErrorAction Stop | Out-Null
            $prev = @(Import-Csv -Path $prevPath)
            $prevMap = @{}; foreach ($p in $prev) { if ($p.GroupKey -and $p.Members -match '^\d+$') { $prevMap[$p.GroupKey] = [int]$p.Members } }
            $prevDate = if ($prev.Count -gt 0) { $prev[0].SnapshotDate } else { 'unknown' }
            Write-Output "`n=== DRIFT AGAINST $prevDate ==="
            $drifted = $false
            foreach ($row in ($Summary | Where-Object { $_.GroupKey -notlike 'Info:*' })) {
                if (-not $prevMap.ContainsKey($row.GroupKey)) { Write-Output "  $($row.GroupKey): new this run ($($row.Members))"; continue }
                $was = $prevMap[$row.GroupKey]; $now = [int]$row.Members; $delta = $now - $was
                $pct = if ($was -gt 0) { [math]::Round(([math]::Abs($delta) / $was) * 100, 1) } elseif ($now -gt 0) { 100 } else { 0 }
                $line = "  $($row.GroupKey): $was -> $now ($(if ($delta -ge 0) { '+' })$delta, $pct%)"
                if ($pct -ge $DriftWarnPercent -and [math]::Abs($delta) -ge 25) { Write-Warning "$line  <- moved more than $DriftWarnPercent%, check before trusting these counts"; $drifted = $true }
                else { Write-Output $line }
            }
            if (-not $drifted) { Write-Output "  No group moved more than $DriftWarnPercent%." }
        } catch {
            Write-Warning "Drift check failed (not a first run): $_"
        }
    }
}

#-- Step 9 - CSVs ----------------------------------------------------------------------------
$Files = @{}
$memberCols = @('UserId','UserPrincipalName','DisplayName','UserType','Department','JobTitle','AccountKind','IsAdmin','AccountAgeDays','Reason','MethodsRegistered','HasPortablePR','PreferredMethod','SnapshotDate')
foreach ($key in $GroupDefs.Keys) {
    $path = Join-Path $ExportLocation "AuthGroup_$key.csv"
    Export-CsvSafe -Rows @($Rows | Where-Object { $_.MembershipGroup -eq $key }) -Path $path -Columns $memberCols
    $Files["AuthGroup_$key.csv"] = $path
}
$exclPath = Join-Path $ExportLocation "AuthGroup_$ExclusionKey.csv"
Export-CsvSafe -Rows $excl -Path $exclPath -Columns @('UserId','UserPrincipalName','DisplayName','AccountKind','IsAdmin','MembershipGroup','MethodsRegistered','SnapshotDate')
$Files["AuthGroup_$ExclusionKey.csv"] = $exclPath

$sumPath = Join-Path $ExportLocation "AuthGroup_Summary.csv"
Export-CsvSafe -Rows $Summary.ToArray() -Path $sumPath -Columns @('GroupKey','ProposedName','Members','NonHuman','SnapshotDate')
$Files["AuthGroup_Summary.csv"] = $sumPath

$allPath = Join-Path $ExportLocation "AuthGroup_AllUsers.csv"
$Rows.ToArray() | Export-Csv -Path $allPath -NoTypeInformation -Encoding UTF8 -Force
$Files["AuthGroup_AllUsers.csv"] = $allPath
Write-Output "CSV files written: $($Files.Count)"

#-- Step 10 - Upload --------------------------------------------------------------------------
if ($script:StorageCtx) {
    try {
        foreach ($name in $Files.Keys) {
            Set-AzStorageBlobContent -File $Files[$name] -Container $Container -Blob "$BlobFolder/$name" -Context $script:StorageCtx -Force -ErrorAction Stop | Out-Null
        }
        Set-AzStorageBlobContent -File $sumPath -Container $Container -Blob "$BlobFolder/history/AuthGroup_Summary_$Today.csv" -Context $script:StorageCtx -Force -ErrorAction Stop | Out-Null
        Write-Output "Uploaded to '$Container/$BlobFolder/' plus a dated summary under history/."
    } catch {
        Write-Warning "Upload failed (CSVs still listed in the job output above): $_"
    }
} else {
    Write-Warning "Upload skipped: no storage context."
}

#-- Step 11 - Resolve groups and compute the diff ---------------------------------------------
# Groups are created by hand, once. This step only ever adds and removes members.
$ChangeRows = [System.Collections.Generic.List[object]]::new()
$ApplyStats = [System.Collections.Generic.List[object]]::new()
function Add-ApplyStat { param($Name, $Desired, $Current, $Added, $Removed, $Deferred, $Failed, $Action) $ApplyStats.Add([pscustomobject]@{ GroupName=$Name; Desired=[int]$Desired; Current=[int]$Current; Added=[int]$Added; Removed=[int]$Removed; Deferred=[int]$Deferred; Failed=[int]$Failed; Action=$Action; SnapshotDate=$Today }) }

# Optional ID map: "Key=guid;Key=guid". Keys are the $GroupDefs keys plus ExclusionNonHuman.
$IdMap = @{}
foreach ($pair in ($GroupIdMap -split '[;,]')) {
    if ($pair -match '^\s*([A-Za-z]+)\s*=\s*([0-9a-fA-F-]{36})\s*$') { $IdMap[$Matches[1]] = $Matches[2] }
    elseif ($pair.Trim()) { Write-Warning "GroupIdMap entry ignored (expected Key=<guid>): '$pair'" }
}

# Desired membership per group key, plus the set of every classified user for the removal gate.
$Desired = [ordered]@{}
foreach ($key in $GroupDefs.Keys) { $Desired[$key] = @($Rows | Where-Object { $_.MembershipGroup -eq $key } | Select-Object -ExpandProperty UserId) }
$Desired[$ExclusionKey] = @($excl | Select-Object -ExpandProperty UserId)
$AllClassified = @{}; foreach ($r in $Rows) { $AllClassified[$r.UserId] = $true }
$GroupNames = [ordered]@{}; foreach ($key in $GroupDefs.Keys) { $GroupNames[$key] = $GroupDefs[$key] }; $GroupNames[$ExclusionKey] = $ExclusionName

# Resolves one group to a validated object. Returns $null (and a stat row) when it must be skipped.
function Resolve-TargetGroup {
    param([string]$Key, [string]$ExpectedName)
    $sel = 'id,displayName,securityEnabled,mailEnabled,groupTypes,onPremisesSyncEnabled,isAssignableToRole'
    if ($IdMap.ContainsKey($Key)) {
        $g = Invoke-MyGraphGetRequest -URL "$GraphBase/v1.0/groups/$($IdMap[$Key])?`$select=$sel" -WarnOnly -Single
        if ($null -eq $g) { return [pscustomobject]@{ Group=$null; Why='SKIPPED - ID lookup failed or group not found' } }
        if ($g.displayName -ne $ExpectedName) { Write-Warning "  $Key : group $($g.id) is named '$($g.displayName)', expected '$ExpectedName'. Using it by ID; update GroupDefs or the portal so they match." }
    } else {
        $odataName = $ExpectedName -replace "'", "''"
        $list = Invoke-MyGraphGetRequest -URL "$GraphBase/v1.0/groups?`$filter=displayName eq '$odataName' and securityEnabled eq true and mailEnabled eq false&`$select=$sel" -WarnOnly
        if ($null -eq $list) { return [pscustomobject]@{ Group=$null; Why='SKIPPED - name lookup failed' } }
        if ($list.Count -eq 0) { return [pscustomobject]@{ Group=$null; Why='SKIPPED - group not found (create it first; this runbook never creates groups)' } }
        if ($list.Count -gt 1) { return [pscustomobject]@{ Group=$null; Why="SKIPPED - $($list.Count) groups share this name; pass GroupIdMap" } }
        $g = $list[0]
    }
    if ($g.mailEnabled -or -not $g.securityEnabled)         { return [pscustomobject]@{ Group=$null; Why='SKIPPED - not a security group' } }
    if ($g.onPremisesSyncEnabled)                            { return [pscustomobject]@{ Group=$null; Why='SKIPPED - on-premises synced, cannot be written from the cloud' } }
    if (@($g.groupTypes) -contains 'DynamicMembership')      { return [pscustomobject]@{ Group=$null; Why='SKIPPED - dynamic membership group' } }
    if ($g.isAssignableToRole)                               { return [pscustomobject]@{ Group=$null; Why='SKIPPED - role-assignable group' } }
    return [pscustomobject]@{ Group=$g; Why='' }
}

Write-Output "`n=== MEMBERSHIP $(if ($DryRun) { '(DRY RUN - nothing will be changed)' } else { '(APPLYING)' }) ==="

try {
    foreach ($key in $GroupNames.Keys) {
        $groupName  = $GroupNames[$key]
        $desiredIds = @($Desired[$key])

        $res = Resolve-TargetGroup -Key $key -ExpectedName $groupName
        if ($null -eq $res.Group) {
            Write-Warning "  $groupName : $($res.Why). Membership untouched."
            Add-ApplyStat $groupName $desiredIds.Count 0 0 0 0 0 $res.Why
            continue
        }
        $group = $res.Group

        # Only user members are read, so a nested group or device can never be diffed out and deleted.
        # A failed read must not look like an empty group, or everyone gets added again.
        $currentMembers = Invoke-MyGraphGetRequest -URL "$GraphBase/v1.0/groups/$($group.id)/members/microsoft.graph.user?`$select=id&`$top=999" -WarnOnly
        if ($null -eq $currentMembers) {
            Write-Warning "  $groupName : could not read current members, skipped to avoid a wrong diff."
            Add-ApplyStat $groupName $desiredIds.Count 0 0 0 0 0 'SKIPPED - member read failed'
            continue
        }
        $currentIds = @{}; foreach ($m in $currentMembers) { if ($m.id) { $currentIds[$m.id] = $true } }
        $desiredSet = @{}; foreach ($d in $desiredIds)     { $desiredSet[$d] = $true }

        $toAdd    = @($desiredIds | Where-Object { -not $currentIds.ContainsKey($_) })
        $toRemove = @($currentIds.Keys | Where-Object { -not $desiredSet.ContainsKey($_) })

        # Removal gate. A user moving to another membership group is an explained removal and is
        # always applied: that is the campaign working. Only users who vanished from the whole
        # classification (deleted, disabled, now external, or a bad read) are gated.
        $explained   = @($toRemove | Where-Object { $AllClassified.ContainsKey($_) })
        $unexplained = @($toRemove | Where-Object { -not $AllClassified.ContainsKey($_) })
        $gateTripped = $false
        if ($currentIds.Count -ge 50 -and $unexplained.Count -gt ($currentIds.Count * ($MaxRemovalPercent / 100))) {
            Write-Warning "  $groupName : $($unexplained.Count) of $($currentIds.Count) members are no longer in the classification at all, over the $MaxRemovalPercent% ceiling. Those removals skipped; moves to other groups still applied."
            $toRemove = $explained; $gateTripped = $true
        }

        Write-Output ("  {0}`n      desired {1} | current {2} | add {3} | remove {4} (moves {5}, gone {6})" -f $groupName, $desiredIds.Count, $currentIds.Count, $toAdd.Count, $toRemove.Count, $explained.Count, $(if ($gateTripped) { 0 } else { $unexplained.Count }))

        $result = if ($DryRun) { 'DryRun' } else { 'Pending' }
        foreach ($id in $toAdd)    { $ChangeRows.Add([pscustomobject]@{ GroupName=$groupName; Change='Add';    UserId=$id; Result=$result; SnapshotDate=$Today }) }
        foreach ($id in $toRemove) { $ChangeRows.Add([pscustomobject]@{ GroupName=$groupName; Change='Remove'; UserId=$id; Result=$result; SnapshotDate=$Today }) }

        if ($DryRun) {
            Add-ApplyStat $groupName $desiredIds.Count $currentIds.Count $toAdd.Count $toRemove.Count 0 0 $(if ($gateTripped) { '[DRY RUN] would update, removal gate tripped' } else { '[DRY RUN] would update' })
            continue
        }

        #-- Apply: adds in 20s via PATCH, fall back to per-user $batch when a PATCH is rejected as a whole.
        $added = 0; $deferred = 0; $failed = 0
        for ($i = 0; $i -lt $toAdd.Count; $i += 20) {
            $chunk = @($toAdd[$i..([Math]::Min($i + 19, $toAdd.Count - 1))])
            $w = Invoke-MyGraphWriteRequest -URL "$GraphBase/v1.0/groups/$($group.id)" -Method PATCH -Body @{
                "members@odata.bind" = @($chunk | ForEach-Object { "$GraphBase/v1.0/directoryObjects/$_" })
            }
            if ($w.Success) { $added += $chunk.Count; continue }
            if ($w.StatusCode -eq 403) { throw "Graph refused a membership change with 403. The managed identity needs GroupMember.ReadWrite.All (admin consented) for DryRun = false. $($w.Detail)" }
            Write-Warning "  PATCH of $($chunk.Count) adds rejected (HTTP $($w.StatusCode)); retrying one by one. $($w.Detail)"
            $b = Invoke-GroupMembershipBatch -GroupId $group.id -MemberIds $chunk -Action Add
            $added += $b.Done; $deferred += $b.Deferred; $failed += $b.Failed
        }
        $rm = if ($toRemove.Count -gt 0) { Invoke-GroupMembershipBatch -GroupId $group.id -MemberIds $toRemove -Action Remove } else { [pscustomobject]@{ Done=0; Deferred=0; Failed=0 } }

        $label = if (($failed + $rm.Failed + $deferred) -eq 0) { 'Applied' } else { 'Partial - see job log' }
        foreach ($c in ($ChangeRows | Where-Object { $_.GroupName -eq $groupName -and $_.Result -eq 'Pending' })) { $c.Result = $label }
        $action = "Updated (+$added/-$($rm.Done))"
        if ($gateTripped)                          { $action = "$action - removal gate tripped" }
        if ($deferred -gt 0)                       { $action = "$action - $deferred deferred (user gone)" }
        if ($failed -gt 0 -or $rm.Failed -gt 0)    { $action = "$action - INCOMPLETE ($($failed + $rm.Failed) failed, next run retries)" }
        Write-Output "      applied: added $added, removed $($rm.Done), deferred $deferred, failed $($failed + $rm.Failed)"
        Add-ApplyStat $groupName $desiredIds.Count $currentIds.Count $added $rm.Done $deferred ($failed + $rm.Failed) $action
    }
}
finally {
    #-- Step 12 - Status block and change log, written even if the apply loop threw ----------
    $statusPath = Join-Path $ExportLocation "AuthGroup_ApplyStatus.csv"
    Export-CsvSafe -Rows $ApplyStats.ToArray() -Path $statusPath -Columns @('GroupName','Desired','Current','Added','Removed','Deferred','Failed','Action','SnapshotDate')
    $changePath = Join-Path $ExportLocation "AuthGroup_Changes.csv"
    Export-CsvSafe -Rows $ChangeRows.ToArray() -Path $changePath -Columns @('GroupName','Change','UserId','Result','SnapshotDate')
    if ($script:StorageCtx) {
        try {
            Set-AzStorageBlobContent -File $statusPath -Container $Container -Blob "$BlobFolder/AuthGroup_ApplyStatus.csv" -Context $script:StorageCtx -Force -ErrorAction Stop | Out-Null
            Set-AzStorageBlobContent -File $changePath -Container $Container -Blob "$BlobFolder/AuthGroup_Changes.csv" -Context $script:StorageCtx -Force -ErrorAction Stop | Out-Null
            Set-AzStorageBlobContent -File $statusPath -Container $Container -Blob "$BlobFolder/history/AuthGroup_ApplyStatus_$Today.csv" -Context $script:StorageCtx -Force -ErrorAction Stop | Out-Null
            Write-Output "Status and change log uploaded, plus a dated copy under '$BlobFolder/history/'."
        } catch {
            Write-Warning "Status upload failed: $_"
        }
    }
}

Write-Output "`n=== STATUS ==="
$ApplyStats | Format-Table GroupName, Desired, Current, Added, Removed, Deferred, Failed, Action -AutoSize | Out-String -Width 240 | Write-Output

$tel = $Summary | Where-Object { $_.GroupKey -eq 'TelephonyOnly' } | Select-Object -First 1
if ($tel) { Write-Output "Programme measure: $($tel.Members - $tel.NonHuman) people (plus $($tel.NonHuman) non-human accounts) still hold telephony as their only method." }

if ($DryRun) { Write-Output "`nDRY RUN. Nothing was changed. Set DryRun = false to apply." }
else         { Write-Output "`nMembership applied. No groups were created and none can be by this runbook." }
Write-Output "Duration: $([math]::Round(((Get-Date) - $script:RunStart).TotalMinutes, 1)) minutes"
