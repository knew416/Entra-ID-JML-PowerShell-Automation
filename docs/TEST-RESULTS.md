# Test results — record actual tenant outcomes

Preparation checks performed: input CSV structure reviewed (four files, seven columns). PowerShell runtime and tenant tests have NOT been executed by the package author. Expected outcomes below are a test plan, not completed results.

| Test | Expected result | Actual result | Run ID/evidence | Status |
| --- | --- | --- | --- | --- |
| Preview onboarding | Planned; no directory writes | Pending | Pending | Not run |
| Onboard four users | Four marked enabled users; one designated group each | Pending | Pending | Not run |
| Identical joiner rerun | Four NoChange; unchanged IDs/counts; no create/add | Pending | Pending | Not run |
| Move Rihanna HR → IT | HR absent; IT present; Department IT | Pending | Pending | Not run |
| Offboard Drake | Disabled; revoke accepted; designated access absent | Pending | Pending | Not run |
| Change rerun | No duplicate users/memberships; revocation repeats | Pending | Pending | Not run |
| Missing department | NeedsReview; LAB005 absent; no grant | Pending | Pending | Not run |
| Duplicate employee ID | Both LAB006 rows blocked; no account/grant | Pending | Pending | Not run |
| Injected Finance grant failure | John loses HR; no Finance grant; NeedsReview | Pending | Pending | Not run |
| Recovery and rerun | Finance only; success then NoChange | Pending | Pending | Not run |
| Unmarked UPN collision (optional) | Identity blocked; unrelated account untouched | Pending | Pending | Not run |
| Future start / Approved=No (optional) | Validation blocks before any grant | Pending | Pending | Not run |

Record failures as failures. If Graph replication produces an unverified state, record NeedsReview, inspect the tenant and retain follow-up evidence. Never rewrite the original log to hide a failure.
