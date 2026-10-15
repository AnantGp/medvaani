# Medivaanii

<!-- impeccable:product-schema 1 -->

## Platform
web

## Users
People reading medical reports in English or a selected Indian language, especially rural patients and people with limited English, medical knowledge or technical literacy. The owner is evaluating the local prototype before making it a product.

## Product Purpose
Accept a PDF or report photo, present a simpler explanation and suggestions, translate generated content, narrate it, and export a summary PDF.

The user explicitly added saved-photo and live phone-camera intake to the running build. JPG, JPEG, PNG and WebP uploads now use Pillow preprocessing and Tesseract OCR, then the existing report parser. Camera capture uses the native browser capture input on supporting phones; computers fall back to a file chooser. Photos are limited to one page per upload and 10 MB. The local OCR engine reads printed English reports; the explanation language is independent of the source report language. Extracted text is available for checking against the original, and unreadable photos fail with retake instructions.

The report workspace now opens an extraction-review step with the original document and editable results. Corrections regenerate the explanation using only supplied flags/ranges and carry their own provenance. A report question box answers bounded questions about extracted results and reported findings with source text; it does not infer diagnoses or prescribe treatment. The last report and original document are stored locally in IndexedDB and restored after refresh, with an explicit clear action in Settings.

The interactive report explorer lets users select a numeric source row in the original PDF or OCR photo, highlights its actual location, and opens a referenced educational detail panel. Reviewed values remain separate from the unchanged original source. Creatinine uses a neutral kidney illustration; supported blood-cell, glucose and lipid tests use their own educational visuals. Unmatched tests/locations are explicit. The educational library is currently English, with no new diagnosis or treatment inference.

Pasted-text input, multilingual source OCR, broader term coverage, broad conversational reasoning and a full report history remain future requirements. The current question box is an evidence-based lookup, rather than a general medical chatbot.

## Operating Context
Existing Flutter web frontend and Python Starlette backend. The updated local evaluation is at 127.0.0.1:3001 with API at 127.0.0.1:8001; the user's original report tab at 3000 is preserved. The user has explicitly asked for the UI to be improved first, with a Google Stitch design before implementation, appropriate colour and subtle animation.

## Capabilities and Constraints
Preserve working PDF selection, processing, explanation, suggestions, language switching, speech controls, settings and PDF export. The active pipeline now gives report-grounded status descriptions instead of disease/treatment templates. Unknown results stay unclassified; normal results are not described as abnormal; an abnormal flag without direction stays abnormal. Unvalidated risk percentages are no longer generated in the active pipeline. Authentication, server ownership, durable multi-report history and production privacy still need separate work. There is no established clinical validation or privacy certification.

## Brand Commitments
Keep the name Medivaanii and the exact existing logo: flutter_app/assets/images/arogya_pandit_logo.png. The generated mockup in ../../outputs/medivaanii-ui-concept.png supplies the burgundy/ivory direction and desktop/mobile structure for this UI work.

The current design workspace is https://stitch.google.com/projects/6730460791281099330?pli=1. Warm ivory, charcoal and burgundy remain the visual direction. Colour communicates action and reported status with accompanying text. Motion acknowledges actions and preserves reading context; reduced motion removes unnecessary movement. PDF originals are rendered with a vendored local PDF.js viewer, including page navigation, rather than relying on a browser PDF plugin.

## Evidence on Hand
Existing source code and synthetic demo PDF. Sample explanation content must be explicitly labeled as an example. Real report content comes from the API.

## Product Principles
Make the next action clear. Keep explanations readable. Show processing and failure states honestly. Preserve report content rather than silently truncating it. Keep controls usable on desktop and mobile.

Choose language early. Preserve source values, units and reference ranges. Attribute flags to the report and communicate uncertainty. Support an informed conversation with a clinician; do not present generated explanations as confirmed diagnoses.

## Open Decisions
Production deployment, clinical validation and patient account strategy are outside this UI task.

## Reliable extraction milestone — 14 October 2026

The version-4 upload flow now uses coordinate-aware native extraction, per-page OCR and an optional offline isolated Docling worker. Measurements carry immutable source fields/physical pages, full references, date context and stable IDs. Shared acceptance policy gates all result interpretations. The selected measurement can be explored and corrected at its exact source cells. OCR needs individual source checks; legacy cache needs deliberate original-byte migration. Current local UI is 127.0.0.1:3001, API 127.0.0.1:8001. See docs/reliable-extraction-evaluation.md for measured outcomes and unverified flows. The milestone does not establish clinical or multi-provider product readiness.
