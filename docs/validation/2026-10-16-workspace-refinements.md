# Report workspace refinements — 16 October 2026

The existing burgundy, ivory and sage workspace, Noto fonts, logo, report data and backend remain in place.

- PDF source rectangles expand outward by 4 CSS pixels at every zoom, use a 2px border and 0.10–0.14 translucent fill. Identical field rectangles draw once, preventing accumulated dark fill on merged PDF tokens and estimated photo rows. The visible checkbox hides/shows these overlays.
- Selected test name, exact value/unit, reference and classification appear in the assistant header. Long references remain available through an explicit details dialog. The supporting organ is a compact SVG beside the result, with one location pill.
- A selection request is delivered after the voice widget mounts, acknowledged once and superseded by newer requests. Speaker and measurement clicks start explanation immediately. Cancellation closes an old request and stops playback. Returning from another tab does not replay an already handled request.
- Measurement cards use two information rows and retain a distinct selected border/background. The fixed list header has an opaque divider; search stays within that header. On phone selection, keyboard/search close while the query remains available for reopening.
- All/flagged/within-range/unclassified counts filter the same list, clearing a previous search. Uncertain results cannot enter the within-range or flagged filters merely because a cached status says normal/high.
- The embedded PDF header omits the duplicate filename and bounds the page selector width. It preserves navigation and readable zoom controls.
- Two localized starter chips appear before the first answer. Repeat/Slower/Simpler appear once an answer exists.

## Verification

- Release web build succeeded; focused Flutter checks: 20 passed; explorer JavaScript checks: 14 passed.
- Mechanical layout scan: no findings. Independent read-only code review: no Important/Critical findings.
- Desktop 1440×900: three full cards and the beginning of a fourth; selected value and supporting organ visible without duplicated location text.
- Phone-sized 390×844: segmented source/list view, docked assistant, selected result, source range and readable 18px scrolling caption checked. This is a browser viewport check, not a physical-phone camera test.
- Actual count controls returned 8/95, 69/95 and 18/95 for the audited report.
- Clicking the ESR speaker immediately entered the reading state, opened source page 26, returned the exact printed 2 mm/1st hour and supplied 0–10 range, and produced audio. Stop returned immediately to Ready. (These fixture values are not hard-coded in the product.)
- Computed source styles confirmed 2px borders, 4px outer expansion and alpha 0.12; the checkbox removed/reinstated the boxes.

Private screenshots and report evidence are kept outside Git. Free AI quota limits still apply to hosted voice requests.
