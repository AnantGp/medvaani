# Reliable Report Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recover source-backed patient measurements, prevent uncertain extraction from producing confident interpretations, and connect grouped results to exact original source fields.

**Architecture:** Fast page-coordinate extraction and an optional isolated local Docling worker feed one typed measurement contract. A shared validation policy determines eligibility for every downstream output and preserves uncertain rows for correction. The existing Flutter/PDF.js workspace reads the same identities and source boxes.

**Tech Stack:** Python/Starlette; pdfplumber 0.11.9; existing Pillow/pdf2image/Tesseract; optional Docling 2.138.0 in a Python 3.12 worker; Flutter/Dart; vendored PDF.js; pytest and Node's test runner.

**Spec:** `docs/superpowers/specs/2026-10-14-report-extraction-design.md`.

**Status:** Approved for inline execution and implemented. Final review requested five Important fixes; those fixes and verification are recorded in `docs/reliable-extraction-final-review.md` and `docs/reliable-extraction-evaluation.md`. Device and browser-permission limitations remain explicit.

## Global Constraints

- Preserve the Medivaanii name, exact logo, bundled Noto Sans, burgundy/ivory palette, Lucide icons, and reduced-motion-aware transitions.
- `extraction_version` becomes 4; retain existing compatibility fields while consumers migrate.
- Original source fields/boxes and stable measurement IDs survive user corrections and display reordering.
- Docling 2.138.0 stays in an optional isolated Python 3.12 worker; remote services and external plugins are disabled.
- Prefetch public models; cached report conversion uses offline flags, one warm worker, CPU/four threads, and a 600-second hard deadline.
- No private PDF, identifying text, screenshot, or benchmark inventory enters Git; expected benchmark data is used only by evaluators.
- Do not manufacture values, units, ranges, source locations, diagnosis, or numerical confidence scores.
- Partial coverage is visible; blocked/legacy reports cannot produce result interpretations; unchanged review confirmation cannot bypass validation.
- Existing external translation/narration verification uses synthetic data unless private-data transmission to a specific destination is explicitly authorized.

## Review Focus

- A digital first page followed by a scanned results page must not silently discard the scan: Task 2.
- A repeated test in 2024/2025 history must not replace the current detailed measurement or its 2026 collection date: Task 3.
- A malformed table or timeout must leave explicit partial coverage, clean temporary uploads, and retain usable native results: Tasks 4 and 6.
- A user-edited or legacy report must preserve its original evidence and refuse source migration onto another file: Tasks 5 and 7.
- Browser filtering/grouping/refresh must preserve result identity and highlight the correct physical page, including absent source locations: Task 8.

## File and interface map

New backend units:

- `backend/report_records.py`: TypedDicts `SourceField`, `PagePrimitives`, `Measurement`, `ExtractedDocument`, `QualityReport`; stable-ID and compatibility serialization helpers.
- `backend/report_quality.py`: candidate validation, eligible-row selection and output policy.
- `backend/digital_results.py`: source-header/column/section extraction for supported digital layouts.
- `backend/docling_adapter.py`: structured Docling table mapping and native/Docling reconciliation.
- `backend/docling_worker.py`: single warm local worker, offline model configuration and bounded conversion.

Public interfaces locked for later tasks:

```python
# report_records.py
def measurement_id(source_digest: str, page: int, block_id: str, row_box: list[float]) -> str: ...
def project_lab_values(measurements: list[Measurement]) -> list[dict]: ...

# ocr.py (new primitive API; keep extract_text as a compatibility wrapper)
def read_document(file_path: str) -> ExtractedDocument: ...

# digital_results.py
def extract_digital_results(pages: list[PagePrimitives], source_digest: str) -> tuple[list[Measurement], list[dict]]: ...

# docling_worker.py and docling_adapter.py
class DoclingWorker:
    def convert(self, file_path: str, page_numbers: list[int], deadline_seconds: int = 600) -> dict: ...
    def close(self) -> None: ...
def extract_docling_results(document_json: dict, source_digest: str) -> tuple[list[Measurement], list[dict]]: ...
def reconcile_measurements(native: list[Measurement], docling: list[Measurement]) -> list[Measurement]: ...

# report_quality.py
def validate_document(document: ExtractedDocument) -> tuple[list[Measurement], QualityReport]: ...
def eligible_measurements(parsed: dict) -> list[Measurement]: ...
def report_quality(report: dict) -> QualityReport: ...
def can_generate_report_output(report: dict) -> bool: ...
```

`ExtractedDocument` contains `source_digest`, `input_type`, `extracted_text`, `pages`, `candidates`, and `diagnostics`. `PagePrimitives` contains physical `page`, `width`, `height`, `words`, `lines`, and `regions`; boxes use normalized top-left coordinates. The other fields/enums are specified in the design contract. `report_quality()` recomputes policy from source-backed candidates/validation issues and treats missing version-4 proof as legacy; it does not trust a client eligibility boolean.

Existing units to modify: `backend/ocr.py`, `backend/agents.py`, `backend/main.py`, `backend/report_review.py`, both requirements files, the report restoration/data/workspace/PDF Dart files, and the existing explorer modules. Keep changes confined to the report flow; do not rewrite unrelated patient/account features.

---

### Task 1: Measurement contract and fail-closed quality policy

**Files:** Create `backend/report_records.py`, `backend/report_quality.py`, `backend/test_report_quality.py`.

**Interfaces:** Produce the record/quality types, stable IDs, compatibility projection, and quality policy functions declared above. Consume only structured source evidence, not the old nonempty-name test.

- [ ] **Write failing tests:** `test_guideline_is_never_eligible` asserts a source-quoted `High risk group` target is rejected; `test_legacy_report_cannot_generate_outputs` asserts a version-3 report returns `legacy_unverified` and false output permission; `test_confirmed_does_not_resolve_unit_issue` asserts a confirmed measurement with a `unit_unreadable` issue remains `needs_review`; `test_missing_reference_keeps_valid_measurement_comparison_unknown` permits a source-backed PLR value while leaving status unknown.

```python
def test_legacy_report_cannot_generate_outputs():
    report = {"extraction_version": 3, "review": {"confirmed": True},
              "parsed_data": {"lab_values": [{"test_name": "High risk group", "value": "70"}]}}
    assert report_quality(report)["state"] == "legacy_unverified"
    assert can_generate_report_output(report) is False
```
- [ ] **Run red:** `python -m pytest -q backend/test_report_quality.py`. Confirm failures are missing behavior/imports, then make fixture imports valid before implementing policy bodies.
- [ ] **Implement:** define enums/fields exactly from the spec; evaluate identity, field association, unit issues and coverage; classify ready/partial/blocked/legacy. Keep collection-date uncertainty explicit. Stable IDs derive from immutable source geometry/digest.
- [ ] **Run green:** the same command; assert no unresolved or legacy row can enter `eligible_measurements`. Add a stable-ID test proving a changed display order/value leaves IDs unchanged.
- [ ] **Record the checkpoint:** review the diff; stage only these files and commit the contract/policy when the chosen execution workflow calls for commits.

### Task 2: Preserve digital and OCR page primitives

**Files:** Modify `backend/ocr.py`, `backend/requirements.txt`, `requirements.txt`; create `backend/test_document_primitives.py`, `backend/test_fixtures/report_layout.py`.

**Interfaces:** Implement `read_document(file_path) -> ExtractedDocument`. Keep existing `extract_text(..., layout=...)` callers functional. Use `PagePrimitives` from Task 1; candidates remain empty until a layout adapter runs.

- [ ] **Write failing tests:** `test_digital_pdf_preserves_physical_page_and_word_boxes` uses a generated two-page anonymous PDF and asserts known words/boxes on their actual pages; `test_mixed_pdf_retains_scanned_second_page` asserts source tokens and OCR provenance survive; `test_invalid_pdf_raises_instead_of_becoming_report_text` asserts a typed exception; `test_exif_photo_boxes_match_corrected_orientation` verifies locations after rotation.

```python
def test_invalid_pdf_raises_instead_of_becoming_report_text(tmp_path):
    source = tmp_path / "invalid.pdf"
    source.write_bytes(b"This is not a PDF")
    with pytest.raises(ValueError):
        read_document(str(source))
```
- [ ] **Run red:** `python -m pytest -q backend/test_document_primitives.py backend/test_photo_upload.py`.
- [ ] **Implement:** read digital words with pdfplumber 0.11.9, retain page dimensions/normalized boxes, and invoke existing local Tesseract only on image-based pages. Separate errors from raw content. Pin the small digital dependency in both API requirements files; leave ML dependencies out.
- [ ] **Run green:** the same command. Inspect one generated PDF render and compare a known value location against its box; retain existing image-size/upload limits.
- [ ] **Record the checkpoint:** isolate the primitive-reader/dependency changes from later parser work.

### Task 3: Extract real digital result rows and full reference fields

**Files:** Create `backend/digital_results.py`, `backend/test_digital_results.py`, `scripts/evaluate_private_report.py`; extend the anonymous fixture builder.

**Interfaces:** Implement `extract_digital_results(pages, source_digest)`. Return source-backed candidates plus rejected/nonmeasurement diagnostics. Consume actual headers, words, panel/section regions and metadata from Task 2.

- [ ] **Write failing tests:** `test_single_result_panel_is_a_measurement` checks name/value/unit/reference boxes; `test_multiline_lipid_reference_stays_one_field` checks every supplied category and inequality; `test_guideline_beside_results_is_not_a_measurement` checks pregnancy/lipid-risk/adult-pediatric tables; `test_qualitative_and_interval_urine_values_keep_units` covers Negative, Nil, Pale Yellow and 1–2 /HPF; `test_machine_method_metadata_never_becomes_test_name` checks contamination; `test_history_columns_do_not_replace_current_result` checks current collection date and separate historical records.
- [ ] **Run red:** `python -m pytest -q backend/test_digital_results.py`.
- [ ] **Implement:** supported Healthians result-header/section profile, single-row coordinate fallback, full reference-column continuation, explicit record types and date/specimen assignment. Use source geometry/section rules rather than a whitelist of the benchmark names or page numbers. Unknown profiles remain partial.
- [ ] **Build evaluator:** `evaluate_private_report.py` accepts `--source`, `--expected`, `--output`, and optional `--docling-python`. Read expected data only after extraction. Compare unique primary rows, values/units/full references, date context, rejected extras and source boxes; print counts/issues without patient identifiers. Save detailed evidence outside Git.
- [ ] **Run green:** unit tests, then evaluate the actual private PDF against the reviewed local inventory. The target is 95 rows, zero nonmeasurement extras, no missing core fields/full references and valid physical source boxes. Until every target passes, report partial progress rather than claiming recovery is complete.
- [ ] **Record the checkpoint:** keep original report and benchmark files outside the checkout.

### Task 4: Optional isolated Docling worker and reconciliation

**Files:** Create `backend/docling_worker.py`, `backend/docling_adapter.py`, `backend/test_docling_adapter.py`, `scripts/setup_docling_worker.py`, `requirements-docling.txt`; extend the evaluator's optional path.

**Interfaces:** Implement `DoclingWorker.convert/close`, `extract_docling_results`, and `reconcile_measurements` from the interface map. The API process never imports Torch/Docling. Worker absence must leave the native supported-layout path usable.

- [ ] **Write failing adapter tests:** `test_multiline_reference_is_preserved_from_docling_json`; `test_headerless_table_needs_source_header_association`; `test_machine_prefix_does_not_shift_cbc_measurement`; `test_split_urine_value_and_unit_is_uncertain_until_geometry_resolves_it`; `test_guideline_table_is_rejected`; `test_conflicting_unit_is_quarantined`. Use anonymized structured table fixtures with original-style schema/boxes, not a benchmark-driven name map.
- [ ] **Run red:** `python -m pytest -q backend/test_docling_adapter.py`.
- [ ] **Implement adapter:** retain physical pages/native cell boxes and combined cells; match candidate fields by page/geometry and compatible content. Do not feed Markdown to the regex parser. Preserve contradictions as issues instead of picking the more confident engine.
- [ ] **Implement worker/setup:** isolated Python 3.12, Docling 2.138.0, prefetched models, offline execution, accurate mode/cell matching, local Tesseract for image inputs, remote/plugins disabled. One persistent worker and four CPU threads; enforce 600 seconds and close/replace failed workers. Log status/errors without private content. Reuse a supplied trial environment only when version/configuration checks pass; never mutate the global installation.
- [ ] **Run green:** adapter tests plus actual local worker conversion of an anonymous fixture. Verify config/offline behavior and a timeout/failure path; no skip can be described as a passed integration test. Run the private evaluator with the configured worker; native/Docling disagreement must remain visible.
- [ ] **Record the checkpoint:** optional requirements/setup stay separate from the API dependency graph.

### Task 5: Validation, corrections and question intents

**Files:** Modify `backend/report_quality.py`, `backend/report_review.py`; extend `backend/test_report_quality.py`, `backend/test_report_review.py`.

**Interfaces:** `apply_review`, `content`, `overview`, `evidence`, and `answer_question` retain their public call shapes but consume version-4 candidates/eligibility. `source_evidence` carries stable IDs and immutable `source_fields` alongside the existing `lab_id` projection.

- [ ] **Write failing tests:** `test_higher_question_never_matches_guideline_high` includes both actual source-backed high results and guideline targets; `test_partial_question_mentions_coverage`; `test_unknown_rows_are_not_abnormal_by_default`; `test_changed_measurement_retains_original_source_boxes`; `test_review_confirmation_cannot_bypass_missing_source`; `test_image_tsh_unit_wu_is_not_accepted_as_uiu`; `test_inequality_interval_and_contextual_references_are_not_scalar_ranges`.
- [ ] **Run red:** `python -m pytest -q backend/test_report_review.py backend/test_report_quality.py`.
- [ ] **Implement:** infer supported reference comparisons only with applicable units/context; keep absent/ambiguous comparisons unknown. Resolve higher/lower/flagged intent first, then whole-token/canonical test aliases. Supported answers include stable measurement IDs and source fields. Preserve labelled user corrections and immutable original fields; revalidate each change. Existing fixtures should gain genuine synthetic source proof rather than a fabricated `eligible: true` flag.
- [ ] **Run green:** the same suite. Confirm legacy/missing tests and treatment/diagnosis requests remain unsupported. Confirm an edited row never highlights its edited value as if it were the original source.
- [ ] **Record the checkpoint:** inspect every count/answer path for use of the shared eligibility helper.

### Task 6: Wire version-4 extraction into the API and all outputs

**Files:** Modify `backend/main.py`, `backend/agents.py`, `backend/report_review.py`; create `backend/test_extraction_pipeline.py`; extend existing upload/review tests.

**Interfaces:** `agents.parse_agent(state, document: ExtractedDocument | None = None)` accepts typed extraction for uploaded documents; legacy flat-text parsing is not an eligible measurement path. Format responses with candidates, quality, version 4, physical source fields and existing compatibility fields. `process_report_async` remains the upload job entry point.

- [ ] **Write failing tests:** `test_upload_guidelines_only_is_blocked`; `test_upload_real_result_and_guideline_separates_counts`; `test_review_and_question_endpoints_enforce_quality`; `test_failed_page_is_partial_not_all_normal`; `test_worker_timeout_cleans_upload_and_preserves_native_rows`; `test_legacy_history_cannot_generate_current_interpretation`. Provider calls use synthetic fixtures/stubs and assert that blocked result content is never sent.
- [ ] **Run red:** `python -m pytest -q backend/test_extraction_pipeline.py backend/test_photo_upload.py backend/test_report_review.py`.
- [ ] **Implement:** invoke primitive reader/adapters/validation before summary/simplify/translation; retain unknown regions and source metadata; project lab values for the current UI. Attach quality before saving, not after producing summaries. Gate history-derived interpretation as well. Use extraction-specific progress messages and remove the unsupported fixed 30–60-second promise. Upload cleanup must run for success, error and deadline paths.
- [ ] **Persist the contract:** embed the version-4 schema marker, digest, candidates/evidence and quality in the serialized parsed data already stored by `MedicalDatabase.save_report`. History responses restore this policy data; old entries remain legacy. Do not introduce a database column that loses source proof on older records.
- [ ] **Run green:** endpoint/job tests and the private evaluator through the actual API processing path. Inspect responses for nonmeasurement row leaks, date replacement and stale translations. Run the backend's full test command and report any pre-existing failures by name.
- [ ] **Record the checkpoint:** the first milestone is reached only when API output meets the 95-row/zero-junk benchmark with the shared gate active.

### Task 7: Legacy cache and output controls in Flutter

**Files:** Modify `flutter_app/lib/main.dart`, `flutter_app/lib/report_data.dart`, `flutter_app/lib/report_workspace.dart`, `flutter_app/lib/report_pdf.dart`; extend Dart data/workspace tests and backend migration tests.

**Interfaces:** Add Dart `reportOutputAllowed(Map report) -> bool`, `reportQualityState(Map report) -> String`, and `eligibleReportLabValues(Map report) -> List<Map<String,dynamic>>`. Restore persists version-4 quality/evidence; old saved records become legacy immediately. Keep original bytes and labelled user edits.

- [ ] **Write failing tests:** legacy restores hide cached summary/narration/export while retaining original access; partial results show exact usable/review counts; unchanged confirmation leaves an uncertain unit unresolved; original-byte migration preserves confirmed edits; digest mismatch refuses migration; export model contains eligible rows and partial coverage only.

```dart
test('confirmed legacy reports cannot generate report outputs', () {
  final report = <String, dynamic>{
    'extraction_version': 3,
    'review': {'confirmed': true},
  };
  expect(reportQualityState(report), 'legacy_unverified');
  expect(reportOutputAllowed(report), isFalse);
});
```
- [ ] **Run red:** targeted Flutter tests and backend migration tests. Use small synthetic reports rather than the user's PDF.
- [ ] **Implement:** gate every reading/audio/download/translation entry point with the same quality state; restore version-3 data safely without text-only reparse. Re-extract original bytes deliberately; absence prompts for the original, not invented recovery. Keep reviewed overlays separate and invalid edits unresolved. Do not call live private-data translation during verification.
- [ ] **Handle ambiguous legacy edits:** uniquely match source identities when possible; otherwise preserve labelled unapplied corrections for manual resolution. Never attach a correction by its old array index, and never discard it on migration failure.
- [ ] **Run green:** Dart tests and browser refresh/recovery checks with synthetic data. Verify a failed migration does not restore confident output or overwrite the saved draft.
- [ ] **Record the checkpoint:** one user correction must remain identifiable after refresh and a second review.

### Task 8: Grouped source workspace and exact field selection

**Files:** Modify `flutter_app/lib/report_review_widgets.dart`, `flutter_app/lib/report_workspace.dart`, `flutter_app/lib/browser_explorer_bridge.dart`, `flutter_app/web/report_explorer.mjs`, `flutter_app/web/report_explorer_core.mjs`, `flutter_app/web/report_explorer.css`; extend Dart review tests and `scripts/test_report_explorer.mjs`.

**Interfaces:** selection messages carry `measurement_id`, physical `page`, and immutable `source_fields`; numeric `lab_id` remains a compatibility field only. One selected identity drives review list, PDF navigation, field highlights and inspector. Use eligibility for education binding.

- [ ] **Write failing tests:** `selection_survives_group_filter_and_reordering`; `selection_navigates_to_physical_source_page`; `highlight_uses_original_boxes_after_user_edit`; `unmatched_source_does_not_bind_guideline_to_organ_explanation`; keyboard/touch alternatives and compact-width result-first behavior.
- [ ] **Run red:** `node --test scripts/test_report_explorer.mjs` and the Dart review/workspace tests.
- [ ] **Implement:** replace chip overload with grouped bounded/searchable lists; distinguish usable results from needs review. Show original beside the inspector on desktop, selected result before source on compact screens. Use actual normalized per-field/combined-cell boxes and source zoom; no guessed highlight for missing/rotated/ambiguous geometry. Preserve existing neutral SVG education, logo/type/color/reduced-motion rules.
- [ ] **Run green:** JS/Dart tests and actual Chrome checks. On the private report, select creatinine, TSH and vitamin D and confirm physical pages 17, 21 and 22 with correct field locations. Use synthetic data for repeated edit/refresh and keyboard tests. Record actual screenshots and distinguish browser/device evidence from widget renders.
- [ ] **Record the checkpoint:** use Impeccable audit for clarity/readability and refresh its design metadata only after the implementation is stable; preserve documented product choices.

### Task 9: Verify the milestone, package evidence and assess remaining release work

**Files:** Update `docs/report-explorer.md`, `docs/report-understanding-fix.md`, `docs/extraction-review-workspace.md`, `DESIGN.md`, and Impeccable metadata where supported; add an anonymized evaluation summary under `docs/`.

**Interfaces:** Consume actual API responses, evaluator output, quality state and browser behavior from Tasks 1–8. Do not create a second acceptance policy.

- [ ] **Run backend verification:** full pytest suite from the configured API environment. Report external-script/fixture failures explicitly rather than claiming a selectively green suite.
- [ ] **Run frontend verification:** Flutter tests, `flutter analyze`, release web build, and Node explorer tests. Distinguish analyzer information messages from a clean exit code.
- [ ] **Run private acceptance:** evaluator/API route, 95 unique primary measurements, zero junk, complete fields/references/source coordinates, source collection date, source-digest continuity and higher-values question. Save private detailed results/screenshots in Downloads/ignored outputs; commit only anonymous counts and method.
- [ ] **Run broader synthetic/provider checks:** at least one differently structured anonymous digital layout and one raster scan; include qualitative/missing-range/scale/history cases. Explicitly record unsupported layouts as partial. Do not convert fixture success into a general accuracy claim.
- [ ] **Inspect Chrome:** upload/review/grouping/search/edit/explorer/questions/refresh, desktop and compact viewport, visible focus, source page selection and partial/blocked states. Use the real local app URL; do not circumvent the previously blocked automatic local-file HTML navigation.
- [ ] **Check remaining user flows:** verify generated PDF contents/Unicode/source/coverage; browser narration start/pause/stop; live translation only with synthetic data; actual phone camera only on an available physical device. Mark any untested flow unverified rather than claiming product readiness.
- [ ] **Self-review and final review:** compare implementation against every spec requirement, then follow the selected execution workflow's final review requirement. Resolve blockers before proposing deployment; do not merge/deploy merely because the fixture passes.

## Proposed execution and checkpoints

Implement sequentially in the existing task using native execution unless the human selects subagent-driven work. Preserve current uncommitted work. Decide checkout isolation with the using-git-worktrees skill at execution time; if a new checkout is used, it must retain the relevant existing implementation without resetting the user's work.

Checkpoint A: Tasks 1–6 produce a source-backed API and pass the private 95-row benchmark with output gates. Checkpoint B: Tasks 7–8 make the workspace use that data correctly. Checkpoint C: Task 9 records release evidence and remaining limits. A failed checkpoint triggers investigation, not automatic progression.

## Plan self-review

The interfaces/types are named once above and reused in each task. Every spec requirement maps to a task: extraction/geometry 2–4; validation and question intent 1/5; outputs and cleanup 6; cache/corrections 5/7; source workspace 8; acceptance/privacy/evidence 3/9. The five Review Focus classes each have an explicit regression in their owning task. No unspecified confidence threshold, clinical cutoff, fixture count, page number, or benchmark name is part of the production extraction policy.
