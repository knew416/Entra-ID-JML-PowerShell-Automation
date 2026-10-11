# Step-by-step walkthrough

## 1. Create the three lab groups

In the Entra admin center, open **Entra ID → Groups → All groups → New group** (navigation labels may vary). Create these groups:

| Setting | Value |
| --- | --- |
| Group type | Security |
| Names | LAB-JML-HR, LAB-JML-IT, LAB-JML-Finance |
| Description for each | JML-LAB-ONLY |
| Membership type | Assigned |
| Microsoft Entra roles can be assigned | No |
| Initial members | None |

Do not connect these groups to real resources. Copy each group's Object ID into a copy of `data/groups.example.json` named `data/groups.local.json`. Keep the keys HR, IT and Finance exactly as provided.

Capture screenshot 01 now. Confirm your initial tenant domain in **Entra ID → Overview/Properties**, for example `yourlab.onmicrosoft.com`. Copy your Tenant ID privately.

## 2. Prepare PowerShell on your Mac

Use PowerShell 7.2 or later; this script does not run in Apple's normal zsh prompt. If PowerShell is installed, open Terminal and enter `pwsh`. Otherwise install PowerShell using Microsoft's macOS instructions: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-macos

Extract this package into Downloads and change to its folder, adjusting the path if necessary:

```powershell
Set-Location ~/Downloads/Entra-JML-Automation
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Import-Module Microsoft.Graph.Authentication
$tenant = 'PASTE-YOUR-LAB-TENANT-ID'
$domain = 'yourlab.onmicrosoft.com'
$scopes = @('User.ReadWrite.All','User.Read.All','User.EnableDisableAccount.All',
    'User.RevokeSessions.All','Group.Read.All','GroupMember.ReadWrite.All')
Connect-MgGraph -TenantId $tenant -Scopes $scopes -ContextScope Process
Get-MgContext | Select-Object TenantId,AuthType
$common = @{TenantId=$tenant;Domain=$domain;GroupMapPath='./data/groups.local.json'}
```

Sign in with your lab administrator. Grant these delegated permissions only in your lab tenant. They collectively support user reads/creation/updates, disabling, session revocation, group reads and membership changes; they are broader than a production process should receive without a permissions review. The signed-in administrator also needs an appropriate Entra role, such as User Administrator for ordinary non-admin lab users. Admin consent and role assignment are separate. Never give test users administrator roles.

The script reads Graph even in preview mode, but preview makes no directory writes. It writes CSV evidence locally on your Mac. Do not start a transcript during credential entry.

## 3. Review the simulated HR input

Open `data/01-joiners.csv`. EmployeeId is the stable identity key; Department maps to one approved group; Manager is informational HR metadata; StartDate gates future access; Status controls onboarding/offboarding; Approved must be Yes.

The old dates allow the lab to run whenever you start it. Do not change them to future dates unless testing the future-start validation. Capture screenshot 02.

## 4. Preview onboarding

```powershell
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/01-joiners.csv -OutputDirectory ./reports/01-preview
```

Expected: four Planned rows, with CreateDisabledUser, department assignment and Enable planned in the execution log. Confirm there are still no LAB001–LAB004 accounts in Entra. Capture screenshot 03. If the script throws a preflight error, check tenant context, group IDs, descriptions, group type and permissions before proceeding.

## 5. Apply onboarding, then rerun exactly the same input

```powershell
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/01-joiners.csv -Apply -OutputDirectory ./reports/02-joiners
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/01-joiners.csv -Apply -OutputDirectory ./reports/03-joiners-rerun
```

Expected first run: four enabled lab accounts and one designated department group per user. The script generates initial passwords in memory and does not print or save them. If you want a test sign-in, reset the test user's password privately in Entra. An initial partial failure can leave a disabled user; review and complete provisioning manually before enabling it.

Expected second run: four NoChange results, no new CreateDisabledUser or Add operations. Confirm exactly one account per LAB employee ID and the same group member counts. Capture screenshots 04–06.

## 6. Move Rihanna and offboard Drake

Take screenshot 07 before processing: Rihanna in HR, Drake enabled in IT.

```powershell
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/02-mover-leaver.csv -OutputDirectory ./reports/04-change-preview
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/02-mover-leaver.csv -Apply -OutputDirectory ./reports/05-changes
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/02-mover-leaver.csv -Apply -OutputDirectory ./reports/06-changes-rerun
```

Expected: Rihanna removed from HR and added to IT; Department updated to IT. Drake disabled, sessions revoked and removed from IT. Beyonce and John unchanged. On rerun Rihanna remains NoChange, Drake remains disabled without duplicate/remnant designated memberships; RevokeSessions runs again deliberately. Capture screenshots 08–10.

For offboarding, prove the execution log shows Disable then RevokeSessions then membership removal. A disabled-status screenshot alone cannot prove revocation. Graph acceptance is API evidence, not proof every application session ended immediately.

## 7. Reject invalid HR data

```powershell
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/03-invalid.csv -Apply -OutputDirectory ./reports/07-invalid
```

Expected: all three rows NeedsReview; no Bruno/Alicia accounts created and no grants. Both LAB006 rows are blocked even though each department is valid. Missing department is rejected rather than assigned a default. Capture screenshot 11 and confirm LAB005/LAB006 are absent in Entra.

## 8. Demonstrate a controlled failed grant

This is a deliberately injected failure, not a real Graph outage or 403. Label it that way in GitHub. John must be enabled and in HR before this test.

```powershell
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/04-transfer-failure.csv -OutputDirectory ./reports/08-failure-preview
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/04-transfer-failure.csv -Apply -FailureEmployeeId LAB004 -OutputDirectory ./reports/09-injected-failure
```

Expected: John's HR membership is removed; the Finance grant is blocked by the injection; result NeedsReview; no Finance membership. Department may still show HR because metadata updates occur after grants. This makes the partial state visible rather than claiming success or restoring old access silently. Capture screenshot 12.

Recover using the same approved CSV without the failure flag:

```powershell
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/04-transfer-failure.csv -Apply -OutputDirectory ./reports/10-recovery
./scripts/Invoke-Jml.ps1 @common -CsvPath ./data/04-transfer-failure.csv -Apply -OutputDirectory ./reports/11-recovery-rerun
Disconnect-MgGraph
```

Expected: John added to Finance, metadata updated, next run NoChange. Capture screenshot 13. Do not rerun the original joiner CSV after transfers/offboarding: it is an old HR snapshot and could request outdated access; disabled identities are blocked from automatic reactivation.

## 9. Prepare GitHub evidence

Create a repository named `Entra-ID-Automated-JML-Lab`. Upload the script, fictional CSVs, example config, README and docs. Fill out TEST-RESULTS with actual outcomes. Create sanitized report copies in `evidence/`, preserving their run IDs so reports and operation logs can be matched. Upload actual screenshots with the checklist filenames and link them from README.

Keep `groups.local.json`, unsanitized reports, tenant IDs, real UPNs, credentials, tokens and consent screens out of GitHub. Crop screenshots to the lab identities and evidence. Replace tenant domain/IDs consistently if shown. Never blur the evidence so heavily that the group membership or result is unreadable.

After successful tenant testing, update the README status to Completed and describe any failures honestly. Optional resume wording after completion: “Built a PowerShell/Microsoft Graph JML lab using CSV-driven provisioning, department-access reconciliation, offboarding, input validation and execution reporting; tested duplicate records, missing departments and controlled grant failure.”
