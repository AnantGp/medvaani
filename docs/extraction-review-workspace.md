# Review, cache and original migration

The browser retains the last report and original bytes in IndexedDB. Restoration suppresses version-3 cached interpretations immediately. Read original again sends the original bytes deliberately; text-only reparse is refused because saved text cannot restore reliable cell associations.

The migration endpoint compares a saved fingerprint where present. A mismatch refuses replacement. Corrections are rebound using stable source identity or a unique original-field match, never the old row index. Ambiguous edits remain labelled unapplied corrections. Failed migration leaves the saved report/edits untouched.

User corrections retain original text/geometry. Source name/value/unit/reference fields and OCR flags are checked individually, then backend validation runs again. Missing sources, unreadable values, incompatible units and conflicts cannot be repaired by an unchanged global confirmation.

The grouped explorer supplies correction controls at the selected source. Usable, needs-review and unresolved-region counts describe extraction, not health or numerical confidence. Source-backed measurements with no applicable comparison have a quiet No supported comparison label.

PDF export is rebuilt from eligible measurements and reported findings/diagnoses/impressions. It includes coverage, supplied references, original physical pages and separately labelled printed values for corrections. Translated prose is reused only when its recorded source revision matches the current extraction. A late translation cannot replace current corrections. Blocked/legacy reports cannot export result summaries.
