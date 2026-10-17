# App-wide language selection

The single header selector controls the interface and voice-answer language in
English, Hindi, Spanish and Mandarin, including before the first report upload.
The preference is saved separately from the report; an explicit preference wins
over an older report's saved language after refresh.

## Scope

- Upload introduction, instructions, example, file actions and progress.
- Navigation, report filters, measurement statuses, source labels and messages.
- Settings, correction dialogs and Flutter's built-in dialog controls.
- PDF/image viewer controls, tooltips, provenance and educational copy. A locale
  update retains the current page, zoom, source selection and scroll position.
- Voice UI and future answers use the selected language. Changing language stops
  current speech and clears the displayed answer, while keeping conversational
  history for follow-up questions about the same report.
- Generated summary-PDF headings, coverage, comparison labels and footers.

Original report pages, test names, quotations, exact values, units, reference
text and narrative findings remain verbatim. This does not add OCR support for
new source languages or certify the clinical accuracy of translations.

## Verification

- Flutter library analyzer: no issues.
- Four focused localization checks: catalog placeholders, preference precedence,
  exact source parameters and a 390 × 844 upload journey in all four languages.
- Existing report-data, source-document, body-system and review-widget checks.
- Seventeen viewer checks, including complete locale catalogs and retaining
  page/zoom/selection on language-only updates.
- Actual four-language summary PDFs plus multi-page Hindi/Mandarin renders.

## PDF implementation limit

The PDF package does not shape Devanagari. Generated Hindi runs use Flutter's
text shaper and are embedded at 3× resolution, so those runs are not selectable
or searchable. Latin source facts remain vector text. Mandarin uses the official
Noto Sans SC TrueType font; the font's OFL attribution is bundled with the app.

## Browser smoke check

The release build was served locally through a thin proxy to the existing cloud
API, without local models or a local application backend. At 390 × 844, changing
language updated upload copy and navigation in all four languages. Hindi remained
selected after refresh before any report existed. Spanish and Mandarin Settings
were inspected. A long translated example heading was changed to wrap correctly;
the Mandarin mobile hero was shortened to avoid an isolated final character.

At 1280 × 800, an anonymous PDF exercised the Mandarin correction dialog and
Spanish/Hindi report controls, results and original viewer. Creatinine stayed
`1.6 mg/dL` throughout, and a language change retained the viewer's 120% zoom and
selected source cells. Corrections were cancelled; no clinical values were edited.

This smoke check also exposed an existing extraction limitation: importing a
partial summary that contains correction provenance can misclassify an
“Originally printed value” line as a separate result and miss its surrounding
reference fields. The app marked extraction partial. This localization change
does not certify summary-PDF round-trip extraction; keep that example in the
extraction validation backlog.

Screenshots and generated PDFs are stored outside Git. Production is deployed
from the source branch after the final checks.
