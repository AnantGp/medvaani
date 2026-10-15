# Final review and implementation decisions — 14 October 2026

The one fresh review of `d56be07` requested five Important fixes and found no Critical issues. The root implemented the fixes together, added anonymous regression tests and reran verification. This document records that review and the root's decisions; it does not represent a second independent review.

## Resolved findings

1. **F1, guideline inclusion:** native and Docling adapters share source identity/section exclusions. Guideline and booking rows beneath clinical headers are excluded before reconciliation. Reconciliation refuses nonmeasurement records; the output policy also rejects an incorrectly labelled guideline in a saved report.
2. **F2, historical inclusion:** explicit historical sections are excluded from current results in both engines. The colon-line fallback requires a current results heading; absent context becomes an unresolved region. Current collection dates and physical source pages remain attached to their own measurements.
3. **F3, unreadable coverage:** a multiword unreadable patient value remains a candidate requiring source review. Numbered interpretation prose remains excluded. Coverage becomes partial rather than silently ready.
4. **F4, ignored correction:** a confirmed flag correction takes precedence over the immutable printed flag. The original flag remains evidence; a correction that conflicts with an applicable reference range still needs review.
5. **F5, omitted narratives:** eligible findings, diagnoses and impressions enter both the explanation and PDF export, labelled as reported content with physical source pages. Unchecked OCR narratives remain excluded. Anonymous notes-only and mixed laboratory/narrative reports were processed through the upload API and exported with the exact app PDF builder.

Two additional preservation issues were resolved in the same fix pass. Translation responses now merge only language fields into the current report for the matching extraction revision; starting review invalidates an outstanding translation request. Late PDF page rendering cannot persist a superseded selection, and manually visiting another page no longer claims the selected result is highlighted there. Regression tests reproduce the old translation snapshot replacement and delayed selection completion.

The final handoff after a server/session restart exposed a blank automatically opened source frame. The shipped startup opens eligible reports in Overview and mounts Explorer when the user chooses it; the saved measurement identity/page remain available. The startup regression failed with the old default and passes with the new one. Chrome verified refresh → Overview → Explorer, restored all 95 results and selected source page17. Experiments with attachment observers/automatic retries did not resolve the browser behavior and were removed; they are not part of the shipped app.

## Root rulings, including matters the reviewer declined to judge

- **Existing checkout:** continue in the human-approved feature checkout. Preserve the exact original baseline outside Git; the cost is weaker isolation and a larger inherited UI diff.
- **Fixture timing:** the reusable anonymous factory arrived with table extraction rather than primitives; physical fixtures still verified the primitive contract. No runtime impact.
- **Sparse Docling output:** zero detected tables on a sparse fixture is a valid fallback case, not success for ML detection. Verify native retention and the full hybrid benchmark; unknown sparse layouts still need visible uncertainty.
- **OCR confirmation:** require individual source-field checks even for plausible values/units. A global confirmation cannot validate OCR; the cost is an extra review step for scans/photos.
- **Browser timing:** batch migration/refresh checks with the completed workspace. The cost was later UI feedback; API and unit gates remained active.
- **Inherited assets:** include the existing PDF.js, font/store and UI dependencies required by the changed workspace. Preserve baseline attribution; accept the larger commit.
- **Removed plugins:** use manual workflow records and direct browser inspection after Superpowers/Impeccable files disappeared. Automatic detector/metadata refresh is unavailable; no automatic Impeccable pass is claimed.
- **Chrome file access:** do not alter extension permissions after synthetic selection was refused. Saved-report Chrome migration/source/export checks remain valid; synthetic browser upload/correction refresh and browser audio remain unverified.
- **Server ownership:** authenticated, server-owned records and adversarial report-object protection remain product work. The current gate is a prototype reliability policy, not an authentication boundary.
- **General accuracy:** claims are limited to the reviewed report and anonymous regressions. Unseen providers, handwriting and multilingual source OCR require a reviewed corpus and explicit support; fixture counts are not population accuracy.
- **Legacy identity:** enforce a prior digest when present. Without prior digest/original bytes, a chosen source and unique correction match are recovery evidence, not cryptographic identity proof. Ambiguous overlays remain unapplied; a stronger identity policy remains product work.
- **Worker/vendor scope:** optional Docling availability and sparse-table fallback retain the bounded failure policy. Vendored viewer/model internals are not independently audited here.
- **Narrative OCR editing:** keep unchecked OCR narratives blocked; clearer source/native PDF recovery remains available. A dedicated narrative correction editor is deferred, so some scanned narrative reports cannot yet become usable through the measurement editor.
- **Device/provider limits:** physical phone camera, browser narration and private live translation remain unverified. Synthetic Hindi translation/PDF evidence does not establish those flows.
- **Translation overwrite:** treat correction loss as material despite its preexisting origin. Resolve it now with request invalidation and revision-aware merging, rather than deferring it on attribution grounds.
- **Viewer startup:** start eligible reports in Overview and load the original viewer on demand. This is the verified Chrome path and preserves the selected source; the cost is one explicit Explorer action and no automatic source-first landing after refresh.

## Deferred minor observations

Two informational deprecations remain in vendored `flutter_tts`. A long result can split across PDF pages; inspected pages retain their text without overflow, but grouped pagination can be refined later. The PDF subtitle shows the report collection date alongside the generator name without an explicit collection-date label. Impeccable metadata remains stale because its tooling was removed. These do not promote uncertain data into eligible outputs.

## Verification and remaining release work

Final exact counts, benchmark timing and artifact contents are recorded in `reliable-extraction-evaluation.md` and the local Downloads evidence package. Chrome file permission, narration and physical-camera limits remain explicit. Before release, expand the labelled provider/scan/photo corpus, establish private-data/retention controls and server ownership, make jobs durable, test actual devices, and obtain clinical/content review.
