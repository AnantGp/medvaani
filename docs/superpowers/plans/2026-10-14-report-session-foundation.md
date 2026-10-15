> SUPERSEDED by the user’s explicit MVP steering: no auth or revision-locking subsystem. See docs/VOICE_MVP.md for the implemented scope.

# Report session foundation implementation plan

> **For agentic workers:** Use superpowers:executing-plans and test-driven-development. This implements the first milestone of the reviewed voice-agent plan; audio and multilingual generation follow after the trusted context exists.

**Goal:** Ensure report questions and corrections use durable, authorized server snapshots, with immutable revisions and a session boundary suitable for the voice agent.

**Architecture:** Preserve Flutter and Starlette. Add a separate SQLite report store containing hashed report capabilities, original source bytes, immutable revisions, durable job status and expiring conversation sessions. Upload returns the secret capability once; Flutter keeps it in its existing local report cache and sends it as a bearer credential. Questions/reviews use report ID and expected revision, never browser report contents as authoritative data.

**Tech stack:** Python stdlib SQLite/secrets/hashlib, existing Starlette/httpx/pytest, Flutter http and IndexedDB.

**Spec:** `/Users/anant/Downloads/Medivaanii-Second-Opinion-2026-10-14/assessment-and-next-steps.md`, first engineering task. User requested continuation after reviewing the assessment.

## Global constraints

- Work in the existing `codex/medivaanii-ui` checkout, consistent with the user's approved “implement here” method; preserve unrelated untracked files.
- No model downloads, paid services, cloud deployment or external patient-data transmission in this foundation milestone.
- Reuse current extraction eligibility, review and provenance behavior.
- Source and job/result access require a report capability; stored credentials are hashed.
- A stale expected revision returns 409; wrong/missing credentials cannot reveal report content.
- Old cached reports without credentials remain readable locally, but need a new upload for server-backed questions/review.
- Conversation sessions support exactly en, hi, es, zh and expire after 30 minutes. This is context preparation, not a working voice agent.

## Review focus

Tampered client report JSON must not affect answers. Concurrent corrections must not overwrite each other. Jobs must survive restart as complete or explicitly interrupted. Source responses and caches must not leak a report. Session context must become unusable after revision change, expiry or deletion.

### Task 1: Durable report store

Files: create `backend/report_store.py`, `backend/test_report_store.py`.

Interfaces: `ReportStore(path)`; `create_job(job_id, source, filename, media_type) -> token`; `update_job(job_id, **fields)`; `complete_job(job_id, report) -> report identity`; `job(job_id, token)`; `read(report_id, token, revision_id)`; `revise(report_id, token, revision_id, report)`; `source(report_id, token)`; `create_session(...)`; `session_context(...)`; `delete(report_id, token)`; `recover_interrupted_jobs()`.

- [ ] Write failing tests for durability, denied credentials, immutable revisions, compare-and-swap, session expiry/invalidation, source ownership, deletion and interrupted jobs.
- [ ] Run the tests and observe the missing store failure.
- [ ] Implement SQLite transactions, hashed capabilities and explicit errors.
- [ ] Run tests until green. Expected: all foundation store regressions pass.

### Task 2: API integration

Files: modify `backend/main.py`; create `backend/test_report_sessions_api.py`; adjust existing API regressions to use authenticated upload receipts.

Consumes Task 1 store. Produces authenticated job/question/review/re-extraction routes, original-source route and session/context preparation routes.

- [ ] Write failing API tests proving authentication, server-owned question data, stale corrections, revision-bound contexts and restart-safe job responses.
- [ ] Run tests and observe missing/unsafe route failures.
- [ ] Integrate persistent receipts and revisions; retain in-memory temporary worker control only. Reject legacy client-only report data for protected operations with a useful re-upload message.
- [ ] Run all backend tests. Expected: new and existing extraction/source regressions pass.

### Task 3: Flutter integration and final review

Files: create `flutter_app/lib/report_session.dart`, `flutter_app/test/report_session_test.dart`; modify `flutter_app/lib/main.dart`.

Consumes upload `report_access_token`, result `report_id`/`revision_id`. Produces reference-only bodies, bearer headers, credential preservation across review/re-extraction and clear stale/legacy errors.

- [ ] Write failing Flutter tests for request construction and credential preservation without accepting changed report identity.
- [ ] Implement request helpers and use them for polling/questions/review/re-extraction. Existing local speech cancellation and generation guards remain active.
- [ ] Run Flutter tests/analyze and build the frontend. Expected: tests and analysis pass; web assets build.
- [ ] Start the local app and verify an anonymous upload/question/correction path in Chrome. Save a proof screenshot and run one independent final review. Document any limitations.

## Execution ledger

Pre-flight: Task 1 identity uses `report_id`, `revision_id`; Tasks 2–3 must preserve those names. The secret is `report_access_token`, excluded from persistent report payloads and sent in Authorization.

Ruling: This pass completes the first engineering milestone in the approved assessment. Model selection, multilingual text dialogue and microphone UX are separate next milestones; no foundation endpoint will claim that audio conversation works.


Implementation evidence:
- Existing baseline: 114 backend tests passed before changes.
- Store/API red tests reproduced missing identity, unprotected jobs, client-owned answers, stale revisions and failed restart recovery. Store/API implementation passed those checks.
- Additional red tests caught duplicate completion overwriting a revision, OS-readable source DB permissions and completed payload retention in worker memory. These paths were fixed; backend suite now passes 135 tests.
- Flutter receipt/request/revision helper tests failed before implementation, then passed; full Flutter suite passes 42 tests.
- Ruling: old byte-backed re-extraction remains a migration path. It creates a new capability only after uploading original bytes, and preserves edits as user-correction provenance. It cannot alter another owned report.
- Ruling: read operations use SQLite snapshot transactions; WAL initialization runs outside them. This avoids mixed-revision reads without breaking initialization.
- Ruling: the existing development branch is reused, and unrelated untracked design/research files remain untouched. No external services or model downloads are added by this milestone.
- Build, Chrome verification and independent final review are in progress.
