# Medivaanii design system

This describes the implemented Flutter web workspace as of 13 October 2026. Source of truth: `flutter_app/lib/report_workspace.dart`, `flutter_app/lib/main.dart` and `flutter_app/pubspec.yaml`. The Google Stitch project is a design exploration, not an approved pixel specification.

## Direction and identity

Warm ivory reading space, burgundy actions and charcoal text. Keep the Medivaanii name and the exact `arogya_pandit_logo.png` asset. Use Lucide outline icons alongside explicit labels. The interface helps a patient upload and understand a report; decorative motion must not compete with reading.

## Colour tokens

| Token | Value | Use |
|---|---|---|
| ground | #F7F5F1 | Page background |
| ink | #242C2B | Primary text |
| muted | #626A67 | Supporting text |
| burgundy | #A32E35 | Primary actions, selection |
| border | #E5E0D8 | Surface boundaries |
| rose | #F9EBEC | Soft action/error context |
| sage | #3F6050 | Secondary information |
| sageLight | #EDF3EF | Informational panels |
| surface | #FFFFFF | Content surfaces |
| error | #9E2930 | Material error role |

Status always has a text label; colour alone conveys no diagnosis or extracted certainty.

## Typography

Theme family: bundled Noto Sans. Script fallbacks: Noto Devanagari, Bengali, Tamil, Telugu, Gujarati, Kannada and Malayalam. PDF export additionally uses bundled Arabic coverage. Primary, outlined and sidebar button styles explicitly use Noto Sans for consistent controls.

Page titles: 38 px desktop, 28 px compact, weight 700, line height 1.18. Generated reading paragraphs: 16 px, line height 1.65, with zero tracking; section headings: 19 px, weight 600. General body: 16–17 px, line height 1.6–1.65. Control labels: 16 px, weight 600. Panel titles: 22 px. Preserve all paragraphs; do not truncate generated explanations. Source/OCR text retains its original characters and 17 px reading style.

## Layout and controls

At 1000 px and above, use a 236 px sidebar. Below that, retain brand/language in the 80 px top bar and four destinations in a 76 px bottom navigation bar. Main content is capped at 1120 px. The upload/example pair becomes two columns at 760 px available content width. Lab rows use two columns at 620 px available row width.

Reading panels are capped at 700 px including their 24 px padding, giving 652 px text width. Main horizontal padding is 36 px desktop and 20 px compact. Surfaces use a 14 px radius and a thin border; buttons use a 12 px radius. Minimum button area is 44×48 px; audio controls are at least 48×48 px. Use visible keyboard focus and semantic labels.

## Behaviour and states

Choose an explanation language before uploading. Three inputs share the processing path: PDF, saved JPG/JPEG/PNG/WebP photo and native phone camera capture. Show the printed-English source limitation before the choices, the 10 MB limit and the one-photo-per-upload constraint. Unsupported desktop camera capture falls back to a file chooser.

After upload, the extraction-review view displays the original PDF/photo alongside editable names, values, units, ranges and source flags. At 900 px of available content it uses two columns; compact layouts stack source and fields. Original PDF pages render in a local PDF.js frame with previous/next/page selection. Missing source matches are labelled rather than fabricated. Confirming review regenerates content and keeps corrected-field provenance separate from original report flags.

The reading workspace gives a concise report overview and an evidence-based question box. Each supported answer includes extracted source text; unsupported questions receive an explicit limitation. Diagnosis and medication decisions are not answered from these results. The current report/source persist locally through refresh, with a Settings action to clear them. This is a single-report browser cache, not a patient account or full history.

After selection, acknowledge the filename and keep progress visible through processing completion. Empty, corrupt and unreadable photo errors ask the user to choose or retake a clear report. Translation failures preserve English content and offer retry. Overview, lab values and extracted source text remain inspectable. Distinguish a report flag from a comparison against its extracted reference range; missing flags/ranges stay visibly unavailable.

Narration follows the language of the text being read. Expose preparing, playing, paused and stopped states, plus a recoverable error. Never autoplay. Download exports the available summary; it does not establish clinical correctness.

Generated explanations use a typed document model: section headings, paragraphs, bullet lists, numbered steps, labelled fields and restrained notes. Decorative emoji and redundant all-capitals document titles are removed from generated display/narration/export, while medical symbols, measurements and original source text remain unchanged. PDF export shares this document model and starts with the simple explanation; it uses an 11 pt body and clear section hierarchy.

## Motion

The Explorer tab uses a responsive source/inspector workspace: two columns above 720 px of available width, stacked document and detail below it. Mobile selection scrolls to the explanation and provides a Back to original report control. Digital PDF hit areas follow glyph positions; scans/photos use normalized OCR line boxes from the same recognition pass. A selected source has a thin sage outline and pale fill, a page attribution and exact source quote. Extracted-test buttons provide 44 px keyboard/touch alternatives; inline source rows can be enlarged with Zoom in. Ambiguous and unmatched locations receive no fabricated highlight. Original fields remain immutable after review; the inspector gives the selected original value priority and puts any correction in a separate Reviewed value block.

The inspector uses tabular numerals, quiet flag attribution, neutral locally authored SVG illustrations and short referenced educational copy. No illness or damaged organ is inferred from a flag. Unsupported test meanings remain explicit. Education currently stays in English and is labelled when another explanation language is selected. External reference links do not include report content and suppress referrers.

Built-in AnimatedSwitcher transitions last 190 ms, with easeOutCubic entry and easeOut exit. When reduced motion is requested, the transition duration becomes zero. Progress indicators run only during active work. Avoid decorative loops and delayed text reveals.

## Evidence and limitations

Browser checks use synthetic documents at localhost:3001, separate from the user's 127.0.0.1 report cache. Actual browser file-chooser uploads, digital/scanned PDF rendering and original-value selections are verified. A deliberately corrected glucose result preserves the original 145 mg/dL source while displaying the reviewed 95 mg/dL separately. The source quote, page attribution and neutral organ illustration are visible in browser captures. Twenty-one Flutter tests, the backend regression suite and six source/bridge JavaScript tests pass; the release JavaScript build succeeds. Physical phone camera capture and clinical validation remain unverified.

The independent reviewer identified seven fixes; the correction batch was implemented and checked, but the final reviewer turn ended at an account usage limit. No final independent approval is claimed. Initial supplementary widget images had test-font blocks; later user-directed font corrections explicitly pin the app controls to Noto Sans, and the current supplementary renders show the updated actual widget layout with a synthetic API fixture. They remain distinct from browser/device evidence. No approved quality board or formal surface contract was provided. The token JSON is a local snapshot, not a verified plugin schema.

## Future work

Multilingual source OCR, multiple photos, pasted-text input, wider educational term coverage and broader conversational reasoning require additional product work. Clinical validation, production privacy, identity, server report ownership, full history and durable jobs need their own implementation and validation.

## Reliable extraction workspace — 14 October 2026

The approved burgundy/ivory, exact logo and Noto Sans system is retained. The result workspace uses available desktop width (maximum 1480), a bounded grouped/searchable list, one selected inspector, and exact source-cell outlines. At compact width the result list and explanation precede the original PDF. Primary controls remain at least 48 pixels high; body text is 16 pixels and secondary text 14 pixels in the HTML explorer. Source micro-targets have keyboard/touch alternatives in the full-size list.

The page communicates extraction quality separately from reference-range comparisons. Missing comparisons do not receive the same label as invalid OCR. Corrections are labelled separately from original printed values. Current browser evidence and product limits are recorded in docs/reliable-extraction-evaluation.md; earlier evidence above describes prior iterations. Automatic Impeccable metadata/detector refresh was unavailable after the plugin was removed from this session; no refreshed sidecar is claimed.


## Final reliability handoff — 14 October 2026

The current final build retains the same identity, typography and colors. It exports eligible reported findings/diagnoses/impressions alongside laboratory measurements and source-page labels. Late translation and source-page rendering are guarded against overwriting a current correction or selection. Verification: 115 backend, 35 Flutter and 12 explorer tests passed; release JavaScript build passed, analyzer has two vendor infos. The one independent whole-branch review found five Important issues, all fixed and retested by the implementer; no second independent approval is claimed. The exact current export has eleven pages and all 95 source-backed measurements. Current limitations and every implementation decision are in docs/reliable-extraction-final-review.md.

Impeccable/Superpowers tools reappeared at final handoff. Earlier tooling failures remain part of the record. The existing untracked local sidecar was preserved; a schema-valid metadata refresh and mechanical detector remain deferred. PDF pagination/date-label/narrative-heading refinements are recorded separately from the completed reliability fixes.

Eligible reports start in Overview. Explorer is one explicit action away, preserving the saved source selection while avoiding an initial automatic viewer load that stalled after a server/session restart. The final Chrome build verified this startup flow; source review for blocked/legacy reports remains the required recovery path.
