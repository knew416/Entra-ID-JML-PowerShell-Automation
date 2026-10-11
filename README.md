# Automated Entra ID Joiner–Mover–Leaver Lab

**Status: prepared for tenant execution. Live test results and screenshots are pending.**

This project uses a simulated HR CSV, PowerShell 7 and Microsoft Graph to provision fictional employees, reconcile department access and offboard a departing employee. It builds on manual JML work with automation, validation and evidence.

All celebrity-inspired names represent fictional test identities. No connection to those individuals is implied. Accounts use stable IDs (LAB001–LAB006), a `[LAB]` display-name prefix and `JML-LAB-ONLY` employee type. John Jacob is a new marked account, separate from any earlier lab account with that name.

| Identity | Joiner department | Later event |
| --- | --- | --- |
| Beyonce Carter | Finance | Unchanged |
| Rihanna Fenty | HR | Transfer to IT |
| Drake Graham | IT | Terminated: disable, revoke sessions, remove designated groups |
| John Jacob | HR | Separate failed-transfer test to Finance |
| Bruno Mars | Missing | Reject before provisioning |
| Alicia Keys | Conflicting duplicate ID | Reject both occurrences |

## Start here

Follow [the walkthrough](docs/WALKTHROUGH.md) one stage at a time. Use [the screenshot checklist](docs/SCREENSHOTS.md) during each stage. Record observed outcomes in [the test-results template](docs/TEST-RESULTS.md).

## Controls

- Preview is the default; only `-Apply` permits directory writes.
- Tenant ID, managed domain, identity markers and explicit group IDs constrain the target.
- Only three static cloud security groups marked `JML-LAB-ONLY` are managed.
- Missing departments, unapproved rows, future starts, invalid IDs/dates and duplicate employee IDs are blocked.
- Employee ID and deterministic UPN identify accounts; existing identities are checked before creation.
- New users remain disabled until their approved group assignment succeeds.
- Transfers remove old designated access before granting new designated access. Failure stops that record; other records can proceed.
- Existing disabled accounts require manual review before reactivation.
- Offboarding disables the account first, revokes sessions and removes designated direct memberships.
- Each Graph operation has an outcome; the per-user report includes observed before/after memberships and verification status.

## Scope and limitations

The CSV is a trusted simulated HR source, not a tamper-resistant approval system. `Approved=Yes` demonstrates a validation gate, not a real approval workflow. Manager is retained as HR metadata in reports; Entra manager relationships are not assigned. No licensing, downstream SCIM provisioning, application-role removal, nested-group reconciliation or privileged-role removal is implemented. Designated department groups represent access; this lab does not prove downstream application access was removed.

Session revocation is deliberately repeated on offboarding reruns to recover from partial failures. Idempotency means no duplicate users or group memberships; it does not mean zero API calls. Revoking refresh tokens does not guarantee immediate termination of every application's existing session/access token. See Microsoft's revocation documentation below.

Do not run concurrent instances. There is no distributed lock, rollback or write retry. A partially provisioned disabled account needs manual review. A transfer that removes old access but fails to grant new access can leave the user with no department group; this is intentional and reported. Graph replication delays can produce `NeedsReview`; inspect current state and rerun only after review.

## Portfolio evidence

Commit the sanitized script, fictional CSVs, example group map, sanitized reports, completed tests and actual screenshots. Keep local configuration and raw reports private. Do not claim completed automation until the live runs are documented.

This project connects to my previous account creation, access approvals, monthly audits and employee-change responsibilities. It demonstrates how I translated that process into repeatable identity automation and exception reporting.

## Microsoft references

- [Create users](https://learn.microsoft.com/en-us/graph/api/user-post-users?view=graph-rest-1.0)
- [Update users and disable accounts](https://learn.microsoft.com/en-us/graph/api/user-update?view=graph-rest-1.0)
- [Add group members](https://learn.microsoft.com/en-us/graph/api/group-post-members?view=graph-rest-1.0)
- [Remove membership using $ref](https://learn.microsoft.com/en-us/graph/api/group-delete-members?view=graph-rest-1.0)
- [Revoke sign-in sessions](https://learn.microsoft.com/en-us/graph/api/user-revokesigninsessions?view=graph-rest-1.0)
