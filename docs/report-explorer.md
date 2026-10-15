# Source-backed report explorer

The Flutter workspace embeds the local PDF.js explorer beside grouped, searchable measurements. Selection uses a stable `measurement_id`, physical page and original `source_fields` rather than a displayed array index or flattened text match. The selected identity persists in the browser snapshot.

Selecting a list result opens its physical source page and outlines its exact name/value/unit/reference cells. Each source field can also be selected directly. Missing/overlapping source locations remain unbound. Compact layouts place the result/inspector before the original, with a View selected source control. Keyboard-accessible list controls are the touch/focus alternative to small PDF cells.

Original printed fields remain immutable after correction. Current reviewed values appear in a separate block. Only eligible patient measurements can bind to the existing referenced neutral educational library; guidelines, unresolved readings and urine glucose cannot acquire blood-glucose education. Unavailable educational terms stay explicit.

The cross-frame bridge accepts the expected window and same origin only. Selection and correction messages carry the stable ID. Selecting Correct a field opens the existing editor; backend revalidation determines whether the correction is usable. OCR fields need individual checks against the image.

See [the evaluation record](reliable-extraction-evaluation.md) for verified Chrome pages and remaining device/browser limits.
