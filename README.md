# Automated Entra ID Joiner–Mover–Leaver Lab

**Status:** Initial live tenant testing completed. Four fictional users were successfully onboarded, and an identical onboarding rerun returned `NoChange` for all four. Invalid CSV testing returned three `NeedsReview` results for a missing department and duplicate employee IDs. Recovery after a controlled failure succeeded for John Jacob, but his final recovery rerun was not completed. Automated mover and leaver results remain unverified, and screenshots are pending publication.

This project uses a simulated HR CSV, PowerShell 7 and Microsoft Graph to provision fictional employees, reconcile department access and offboard a departing employee. It builds on manual JML work with automation, validation and evidence.

All celebrity-inspired names represent fictional test identities. No connection to those individuals is implied. Accounts use stable IDs (LAB001–LAB006), a `[LAB]` display-name prefix and `JML-LAB-ONLY` employee type. John Jacob is a new marked account, separate from any earlier lab account with that name.

| Identity | Joiner department | Later event |
| --- | --- | --- |
| Beyonce Carter | Finance | Unchanged |
| Rihanna Fenty | HR | Transfer to IT |
| Drake Graham | IT | Terminated: disable, revoke sessions, remove designated groups |
| John Jacob | HR | Separate failed-transfer test to Finance |


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

