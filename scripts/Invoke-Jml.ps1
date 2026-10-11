#requires -Version 7.2
<# Default mode reads Graph and writes local evidence only. -Apply changes the lab tenant.
   Manager is HR metadata in the report; this version does not set Entra manager relationships.
   Never run concurrent instances. Only designated static groups are reconciled. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CsvPath,
    [Parameter(Mandatory)][guid]$TenantId,
    [Parameter(Mandatory)][string]$Domain,
    [Parameter(Mandatory)][string]$GroupMapPath,
    [switch]$Apply,
    [string]$FailureEmployeeId = '',
    [string]$OutputDirectory = './reports'
)
$ErrorActionPreference = 'Stop'
$run = [guid]::NewGuid().ToString()
$events = [Collections.Generic.List[object]]::new()
$report = [Collections.Generic.List[object]]::new()
$mode = if ($Apply) { 'Apply' } else { 'Preview' }
function Event($employee,$action,$outcome,$detail) {
    $events.Add([pscustomobject]@{RunId=$run;TimeUtc=[datetime]::UtcNow.ToString('o');Mode=$mode;EmployeeId=$employee;Action=$action;Outcome=$outcome;Detail=$detail})
}
function Graph($method,$path,$body=$null) {
    $request = @{Method=$method;Uri="https://graph.microsoft.com/v1.0$path";OutputType='Hashtable';ErrorAction='Stop'}
    if ($null -ne $body) { $request.Body = ($body | ConvertTo-Json -Depth 10 -Compress); $request.ContentType='application/json' }
    try { Invoke-MgGraphRequest @request } catch { throw 'Graph request failed; inspect private tenant audit logs' }
}
function Collection($path) {
    $items = @(); $page = Graph GET $path
    $items += @($page.value)
    while ($page.'@odata.nextLink') {
        if (-not $page.'@odata.nextLink'.StartsWith('https://graph.microsoft.com/v1.0/')) { throw 'Unexpected paging endpoint' }
        $page = Graph GET $page.'@odata.nextLink'.Substring('https://graph.microsoft.com/v1.0'.Length)
        $items += @($page.value)
    }
    return $items
}
function Change($employee,$action,$path,$method,$body=$null) {
    if (-not $Apply) { Event $employee $action 'Planned' 'No directory write'; return }
    try { $response = Graph $method $path $body; if ($action -eq 'RevokeSessions' -and $response.value -ne $true) { throw 'Graph did not confirm session revocation' }; Event $employee $action 'Succeeded' 'Graph accepted operation' }
    catch { Event $employee $action 'Failed' 'Graph operation failed; inspect tenant audit logs privately'; throw }
}
function Memberships($id) {
    @((Collection "/users/$id/memberOf?`$select=id") | ForEach-Object { $_.id })
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
try {
    if ($Domain -notmatch '^[a-z0-9-]+\.onmicrosoft\.com$') { throw 'Use the initial managed onmicrosoft.com lab domain' }
    $context = Get-MgContext
    if (-not $context -or $context.TenantId -ne $TenantId.ToString() -or $context.AuthType -ne 'Delegated') { throw 'Connect to the specified lab tenant using delegated authentication first' }
    $groups = Get-Content $GroupMapPath -Raw | ConvertFrom-Json -AsHashtable
    if (($groups.Keys | Sort-Object) -join ',' -ne 'Finance,HR,IT') { throw 'Group map must contain exactly Finance, HR, IT' }
    if (@($groups.Values | Select-Object -Unique).Count -ne 3) { throw 'Group IDs must be distinct' }
    foreach ($dep in @('HR','IT','Finance')) {
        $gid = [guid]::Parse($groups[$dep]).ToString(); $groups[$dep] = $gid
        $g = Graph GET "/groups/$gid?`$select=id,displayName,securityEnabled,mailEnabled,groupTypes,isAssignableToRole,onPremisesSyncEnabled,description"
        if ($g.displayName -ne "LAB-JML-$dep" -or $g.description -ne 'JML-LAB-ONLY' -or -not $g.securityEnabled -or $g.mailEnabled -or $g.isAssignableToRole -or $g.onPremisesSyncEnabled -or @($g.groupTypes).Count -gt 0) { throw "Unsafe or unsupported lab group: $dep" }
    }
    $rows = @(Import-Csv $CsvPath)
    if ($rows.Count -eq 0) { throw 'Empty HR input' }
    foreach ($column in @('EmployeeId','DisplayName','Department','Manager','StartDate','Status','Approved')) {
        if ($column -notin $rows[0].PSObject.Properties.Name) { throw "Missing column: $column" }
    }
    $duplicates = @($rows | Group-Object EmployeeId | Where-Object Count -gt 1 | ForEach-Object Name)
    foreach ($r in $rows) {
        $before = ''; $after = ''; $result = 'NeedsReview'; $reason = ''; $upn = ''; $u = $null
        try {
            $date = [datetime]::MinValue
            if ($r.EmployeeId -notmatch '^LAB[0-9]{3}$') { throw 'EmployeeId must match LAB plus three digits' }
            if ($r.EmployeeId -in $duplicates) { throw 'Duplicate employee ID: every occurrence blocked' }
            if ([string]::IsNullOrWhiteSpace($r.DisplayName) -or [string]::IsNullOrWhiteSpace($r.Manager)) { throw 'Missing display name or HR manager metadata' }
            if (-not $groups.ContainsKey($r.Department)) { throw 'Missing or unapproved department' }
            if ($r.Status -cnotin @('Active','Terminated')) { throw 'Status must be Active or Terminated' }
            if ($r.Approved -cne 'Yes') { throw 'HR approval required' }
            if (-not [datetime]::TryParseExact($r.StartDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$date)) { throw 'Invalid start date; use yyyy-MM-dd' }
            if ($r.Status -eq 'Active' -and $date.Date -gt (Get-Date).Date) { throw 'Future start date: no access granted' }
            $upn = "$($r.EmployeeId.ToLower())@$Domain"
            $matches = @(Collection "/users?`$filter=employeeId eq '$($r.EmployeeId)'&`$select=id,userPrincipalName,employeeId,department,accountEnabled,employeeType,displayName")
            $collisions = @(Collection "/users?`$filter=userPrincipalName eq '$upn'&`$select=id,employeeId,employeeType")
            if ($matches.Count -gt 1) { throw 'Ambiguous directory employee ID' }
            if ($matches.Count -eq 1) {
                $u = $matches[0]
                if ($u.employeeType -ne 'JML-LAB-ONLY' -or $u.userPrincipalName -ne $upn) { throw 'Identity is not the expected lab account' }
            } elseif ($collisions.Count -gt 0) { throw 'UPN collision with unmanaged identity' }
            $members = if ($u) { @(Memberships $u.id) } else { @() }
            $before = (@($groups.Keys | Where-Object { $groups[$_] -in $members }) | Sort-Object) -join ';'
            $after = $before
            if ($r.Status -eq 'Terminated') {
                if (-not $u) { Event $r.EmployeeId 'Offboard' 'NoChange' 'Account absent'; $result='NoChange' }
                else {
                    if ($u.accountEnabled) { Change $r.EmployeeId 'Disable' "/users/$($u.id)" PATCH @{accountEnabled=$false} }
                    else { Event $r.EmployeeId 'Disable' 'NoChange' 'Already disabled' }
                    # Always retry revocation on rerun; a prior partial offboard must not skip it.
                    Change $r.EmployeeId 'RevokeSessions' "/users/$($u.id)/revokeSignInSessions" POST
                    foreach ($dep in $groups.Keys) {
                        if ($groups[$dep] -in $members) { Change $r.EmployeeId "Remove-$dep" "/groups/$($groups[$dep])/members/$($u.id)/`$ref" DELETE }
                    }
                    $result = if ($Apply) { 'Succeeded' } else { 'Planned' }
                }
            } else {
                if (-not $u) {
                    Event $r.EmployeeId 'CreateDisabledUser' $(if ($Apply) {'Started'} else {'Planned'}) 'Marked lab identity; password never logged'
                    if (-not $Apply) {
                        Event $r.EmployeeId "Add-$($r.Department)" 'Planned' 'Only approved department group'
                        Event $r.EmployeeId 'Enable' 'Planned' 'After successful provisioning'; $result='Planned'; $reason='New user planned'; continue
                    }
                    $bytes = [byte[]]::new(24); [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
                    $password = 'Aa9!' + [Convert]::ToBase64String($bytes)
                    $u = Graph POST '/users' @{accountEnabled=$false;displayName="[LAB] $($r.DisplayName)";mailNickname=$r.EmployeeId.ToLower();userPrincipalName=$upn;employeeId=$r.EmployeeId;employeeType='JML-LAB-ONLY';department=$r.Department;passwordProfile=@{password=$password;forceChangePasswordNextSignIn=$true}}
                    $password=$null; Event $r.EmployeeId 'CreateDisabledUser' 'Succeeded' 'Reset password privately if a login test is needed'
                } elseif (-not $u.accountEnabled) { throw 'Existing disabled account requires manual review; no automatic reactivation' }
                $changed = $false
                # Revoke old managed access BEFORE adding new access. Never delete the user object.
                foreach ($dep in $groups.Keys) {
                    if ($dep -ne $r.Department -and $groups[$dep] -in $members) {
                        Change $r.EmployeeId "Remove-$dep" "/groups/$($groups[$dep])/members/$($u.id)/`$ref" DELETE; $changed=$true
                    }
                }
                if ($groups[$r.Department] -notin $members) {
                    if ($Apply -and $FailureEmployeeId -eq $r.EmployeeId) {
                        Event $r.EmployeeId "Add-$($r.Department)" 'Failed' 'Controlled injected failure before grant'
                        throw 'Controlled failure; no new department access granted'
                    }
                    Change $r.EmployeeId "Add-$($r.Department)" "/groups/$($groups[$r.Department])/members/`$ref" POST @{'@odata.id'="https://graph.microsoft.com/v1.0/directoryObjects/$($u.id)"}; $changed=$true
                }
                if ($u.department -ne $r.Department) { Change $r.EmployeeId 'UpdateDepartment' "/users/$($u.id)" PATCH @{department=$r.Department}; $changed=$true }
                if (-not $u.accountEnabled) { Change $r.EmployeeId 'Enable' "/users/$($u.id)" PATCH @{accountEnabled=$true}; $changed=$true }
                $result = if (-not $changed) { 'NoChange' } elseif ($Apply) { 'Succeeded' } else { 'Planned' }
                if (-not $changed) { Event $r.EmployeeId 'Reconcile' 'NoChange' 'Approved membership already present' }
            }
            $reason = 'Processing completed; compare observed access with desired state'
        } catch {
            $reason = 'Validation, identity, or operation failure: review execution log'
            # Do not export raw Graph exceptions, which may contain private context.
            Event $r.EmployeeId 'Record' 'NeedsReview' $(if ($_.Exception.Message -like '*Graph*' -or $_.Exception.Message -like '*Response*') {'Directory operation failed; check private audit logs'} else {$_.Exception.Message})
            $result='NeedsReview'
        } finally {
            if ($u -and $Apply) {
                try {
                    $observed = @(Memberships $u.id)
                    $after = (@($groups.Keys | Where-Object { $groups[$_] -in $observed }) | Sort-Object) -join ';'
                    $final = Graph GET "/users/$($u.id)?`$select=accountEnabled,department"
                    if ($result -eq 'Succeeded' -and (($r.Status -eq 'Active' -and (-not $final.accountEnabled -or $after -ne $r.Department -or $final.department -ne $r.Department)) -or ($r.Status -eq 'Terminated' -and ($final.accountEnabled -or $after)))) {
                        $result='NeedsReview'; $reason='Observed state differs from expected state; replication or partial failure requires review'
                    }
                } catch { $after='UNVERIFIED'; $result='NeedsReview'; $reason='Post-operation verification failed' }
            }
            $report.Add([pscustomobject]@{RunId=$run;Mode=$mode;EmployeeId=$r.EmployeeId;DisplayName=$r.DisplayName;Manager=$r.Manager;Status=$r.Status;DesiredDepartment=$r.Department;BeforeGroups=$before;ObservedAfterGroups=$after;Result=$result;Reason=$reason})
        }
    }
} catch { Event '' 'Preflight' 'Failed' 'Preflight failed; no further records processed'; throw }
finally {
    $events | Export-Csv "$OutputDirectory/execution-$run.csv" -NoTypeInformation
    $report | Export-Csv "$OutputDirectory/report-$run.csv" -NoTypeInformation
    $report | Format-Table EmployeeId,Status,BeforeGroups,ObservedAfterGroups,Result -AutoSize
    Write-Host "Mode: $mode | Run: $run | Evidence: $OutputDirectory"
}
