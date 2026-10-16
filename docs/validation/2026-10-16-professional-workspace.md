# Workspace and Settings refinement

The source document, spoken explanation, and result list previously competed
for one fixed-height workspace. A long answer could shrink into a clipped
paragraph while the result list lost most of its useful height. Settings did
not provide listening or reading preferences.

## Interaction model

- Keep the original document beside one companion panel on desktop.
- Give Results and Conversation separate views in that panel. Selecting a
  measurement opens its explanation and corresponding source. Results retains
  a small voice dock so browsing does not interrupt playback.
- On mobile, expose Report, Results, and Conversation views. The source and
  conversation retain their state across view changes and visits to Settings.
  Mobile Conversation hides the filename/filter toolbar and keeps compact
  organ, test, value, status, and reference context without the secondary
  system/location row.
- Scroll explanation content within the conversation view, with its selected
  result context and composer outside that scrolling area.
- Show selected/cited source boxes by default. An explicit checkbox reveals
  all source boxes. Retain the existing padded, translucent source geometry.

## Settings

The centred panel is capped at 720 px. It includes the single global language
selection summary, persistent 1.0x/0.85x voice speed, automatic speech, and
standard/large reading text. Reading size changes measurement names, values,
references, and explanation captions; PDF zoom remains an independent control.

Automatic speech governs result selection and typed questions. Explicit Listen,
Repeat, and spoken questions still play audio. A slower default is applied to
audio playback without stacking it on the existing Slower action.

Stored-report details show available measurement/page counts. The date added is
recorded for new uploads; no historical date is fabricated. Clearing requires
confirmation and removes this browser's document and corrections, while keeping
downloaded files. About, version, privacy information, and a return action are
integrated into the same panel. Account settings are not invented for this MVP.

## Verification

- Flutter analysis: no issues. Release web build passes.
- Existing focused Flutter checks: 20 passed. Explorer checks: 14 passed.
- Browser checks cover the source/result/conversation transitions, exact cited
  values, continuing playback in Results, Stop, typed answers with autoplay off,
  explicit Repeat, saved preferences, and cancelling report removal.
- Desktop 1280x800 and mobile 390x844 captures remain outside Git because the
  test report is private. A physical phone keyboard/camera test is not claimed.

The mobile check exposed a detached PDF platform view throwing during citation
delivery after a valid voice answer. Delivery now waits for a connected viewer;
the existing load/ready handlers deliver the current report on return.

Design checks retain the user-requested burgundy/ivory/sage palette. Narrow
detector exceptions cover that pinned ivory background and the existing hidden
photo element, whose source is assigned from the uploaded report before display.
Pre-existing design-document drift is outside this refinement.

Documentation comparison: sampled workspace and voice code retain the exact
Medivaanii logo, Noto Sans identity, and documented burgundy/ivory/sage tokens.
The companion views and centred 720 px Settings extend that system. Existing
metadata still contains earlier layout and font-fallback snapshots, prohibits
autoplay, and labels report Q&A as conceptual. DESIGN.md, the local token
sidecar, and the surface brief remain unchanged. This is a source comparison;
it adds no browser or visual-approval claim.
