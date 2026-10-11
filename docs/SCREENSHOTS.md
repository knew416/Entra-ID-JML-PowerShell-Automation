# Important portfolio screenshots

Use real screenshots from your tenant. These are capture instructions, not generated evidence.

| File | When and where | What must be visible | What it proves |
| --- | --- | --- | --- |
| 01-lab-groups.png | Entra ID → Groups; include group settings if needed | Three LAB-JML groups, Assigned membership and marker | Defined access scope |
| 02-hr-source.png | Open joiner CSV in editor | All four fictional users and seven columns | HR source and stable employee IDs |
| 03-preview.png | PowerShell + preview execution CSV | Mode Preview; Planned operations | Review before writes |
| 04-provisioned-users.png | Entra ID → Users; filter lab names | Four distinct [LAB] users | Provisioning result |
| 05-joiner-memberships.png | Department groups → Members | Finance: Beyonce; HR: Rihanna/John; IT: Drake | Approved access assignment |
| 06-idempotent-rerun.png | Second onboarding report/log | Four NoChange results; no create/add events; compare users/counts | Rerun without duplicates |
| 07-before-change.png | Rihanna and Drake → Groups/Properties | Rihanna HR; Drake IT and enabled | Baseline |
| 08-mover-after.png | Rihanna → Groups and Properties | IT present, HR absent, Department IT | Old access removed/new access granted |
| 09-leaver-after.png | Drake → Properties and Groups | Account disabled; no designated group | Account blocking and access removal |
| 10-offboarding-log.png | Execution CSV; optionally Audit logs | Disable, RevokeSessions, Remove-IT with success and run/time | API operation sequence |
| 11-validation-failures.png | Invalid report + execution log | Missing department; both duplicate rows blocked; NeedsReview | Fail-safe validation |
| 12-injected-failure.png | John's Groups + report/log | HR absent, Finance absent, failed grant; NeedsReview | No grant after controlled failure |
| 13-recovery.png | John's Groups + recovery and rerun reports | Finance only; success followed by NoChange | Recoverable partial state |

For a concise portfolio, feature screenshots 03, 06, 08, 09–10, 11 and 12; retain the others as supporting evidence. Multiple images are appropriate where one screenshot cannot show the complete before/after proof.

Also retain CSV exports: screenshots help a recruiter scan, while machine-readable logs let a technical reviewer inspect individual operation outcomes.
