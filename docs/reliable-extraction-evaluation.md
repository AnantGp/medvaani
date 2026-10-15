# Reliable extraction milestone — 14 October 2026

This is a local prototype milestone, not a general accuracy or clinical-validation claim.

## Architecture now in the app

Original PDF/photo bytes → per-page pdfplumber/Tesseract primitives → coordinate/header extraction → optional isolated offline Docling tables → field reconciliation → shared validation → reviewable measurement records → gated explanations, questions, translation and export.

The API does not import Docling or Torch. Setting `MEDIVAANII_DOCLING_PYTHON` enables a Python 3.12/Docling 2.138.0 child worker. It uses cached public models, CPU/four threads, disabled remote services/plugins and a 600-second conversion deadline. A fully resolved supported native layout avoids that slower fallback. Worker failure preserves native rows and marks partial coverage.

## Reviewed private benchmark

The evaluator read the original 33-page PDF before opening the expected inventory. Both stay outside Git. The actual `/upload` job path returned 95 unique patient measurements, 95 correct core name/value/unit associations, 95 complete reference fields, zero extra rows and zero duplicates. Physical source fields and collection-date context survived. The higher-values question returned three actual high comparisons, with stable source identities and no risk-group guidelines.

Standalone native extraction also passed this inventory. The final optional hybrid conversion passed all 95 core fields and references with zero extras/duplicates. It took 593 seconds while the release build and verification ran concurrently, versus 219 seconds in the earlier isolated conversion. Its local cost is substantial and approaches the 600-second deadline under load; keep it optional. A sparse anonymous Docling fixture converted successfully but produced zero tables. Native fallback preserved both rows. Those results do not establish that Docling always improves every report.

## Additional verification

- Anonymous alternative provider: two measurements retained with explicit partial/unsupported-layout coverage.
- Anonymous raster/photo: two candidate readings retained; output blocked until each OCR source field is checked. A repeated unchanged global confirmation cannot bypass that check.
- Regressions cover mixed digital/scanned pages, rotation, current versus historical results, multiline/qualitative/interval fields, printed flag conflicts, misleading metadata/guideline rows, missing or incompatible units, worker failures, immutable corrections and migration digest mismatches.
- Chrome: restored the actual legacy cached report, deliberately reread its saved original, searched/grouped measurements, selected creatinine/TSH/vitamin D on physical pages 17/21/22, used keyboard selection, continued review and preserved selected identity/page after refresh.
- Responsive Chrome viewport: approximately 391 CSS pixels, original browser zoom accounted for; result/inspector precedes the original document. Full-size list controls provide alternatives to small source-cell targets.
- Actual Chrome summary download created a nine-page PDF with every measurement name and micro symbols preserved. The current exact PDF builder also generated a source-page-labelled export in Downloads and a rendered anonymous Hindi export.
- Synthetic live Hindi translation returned Devanagari content. Private benchmark verification used local English processing.

## Final review fixes and checks

The one independent final review requested five Important fixes, with no Critical findings. Guideline inclusion, historical colon lines, silently omitted unreadable values, ignored flag overrides and omitted narrative summaries/exports were reproduced and fixed. Additional regressions cover delayed translation overwriting corrections and late source selection restoring a stale identity. The root retested the fixes; no second independent review is claimed. Detailed decisions are in `reliable-extraction-final-review.md`.

Final verification: **115 backend tests, 35 Flutter tests and 12 explorer tests passed**. Analyzer exited successfully with two informational vendor deprecations and no errors/warnings. The release JavaScript build passed; its WebAssembly dry run reports existing unsupported web imports, so WebAssembly support is not claimed. The final API benchmark recovered 95/95 core measurements, 95/95 complete references and zero extras/duplicates across all 33 source pages, retaining the collection date. It took 49 seconds during concurrent heavy verification; these timings are not a promised upload SLA.

The exact final PDF builder produced an 11-page export, verified all 95 core fields/references and 95 physical source-page labels, and preserved the Unicode micro sign. Notes-only and mixed notes/laboratory reports each retained all three supported narrative sections with source labels. Hindi export was regenerated and rendered. First/middle/last private PDF pages and the anonymous narrative/Hindi pages were visually checked. The final Chrome build restores all 95 results and identifies when the selected source belongs to another manually visited page.

After a server/session restart, the automatic initial source view could remain blank. Eligible reports now start in Overview and create the source viewer when Explorer is selected. Chrome verified that flow on the final release build and retained the selected source on physical page17. The revised startup test passes within the full35-test Flutter suite; the final JavaScript build passed in44.8 seconds. The observer/retry experiments were removed after failing the actual browser check.

## Concrete limitations

Chrome's extension refused synthetic file selection because its file-URL permission is disabled. No permission was changed. Synthetic browser upload/correction refresh and browser narration start/pause/stop remain unverified; anonymous API migration/correction tests passed instead. Physical phone camera capture remains unverified. OCR currently targets printed English; handwriting, multilingual source OCR and multi-photo uploads are not supported here.

Impeccable's executable/metadata tooling disappeared during the session. Direct browser inspection continued, but no completed mechanical detector or automatic metadata refresh is claimed.

Two informational deprecations remain inside the vendored flutter_tts plugin. The pre-existing `test_suggestions_api` returns False instead of asserting; pytest's green count is not proof of that legacy external script. New report endpoint tests use assertions.

## Before making this a product

Build a reviewed provider/scan/photo corpus with separate false-inclusion and missed-result metrics. Add supported layouts with physical fixtures and retain visible partial coverage for unknown layouts. Then address authenticated server-owned report records, private-data retention/provider controls, durable jobs, multi-report history and device testing. Arrange independent clinical/content review before presenting interpretations as a clinical product.
