# Medivaanii UI Implementation Plan

> **For agentic workers:** Execute natively in this session using superpowers:executing-plans. An Impeccable finish review follows the built result.

**Goal:** Replace the existing visual presentation with the burgundy/ivory Medivaanii concept while retaining the local report workflow.

**Architecture:** Keep backend APIs and browser audio/PDF adapters. Extract presentation into testable Flutter widgets and report-display utilities; HomePage connects existing state to those widgets.

**Tech Stack:** Flutter Material 3, bundled Noto Sans fonts, lucide_icons_flutter, existing http/file_picker/pdf packages. Use built-in state transition animations with reduced-motion support.

**Spec:** PRODUCT.md and the UI surface brief, with ../../outputs/medivaanii-ui-concept.png as the design reference.

## Global Constraints
Keep Medivaanii and the exact logo. Four navigation destinations. Retain language, upload, playback and download functions. No invented clinical, security or compliance claims. Preserve the user's open report tab while testing a separate preview.

## Review Focus
390px mobile and 1440px desktop; large text; full report content; JSON-string lab payloads; busy/failed/empty states; keyboard actions and reduced motion.

## Task 1: Report presentation and visual system
- [x] Add regression tests for paragraph preservation and full content.
- [x] Add typed-safe display normalization for API map/JSON-string lab values.
- [x] Replace monochrome tokens and register bundled fonts; add Lucide icons.

## Task 2: Responsive workspace and existing actions
- [x] Build upload, explanation, suggestions and settings screens as reusable widgets.
- [x] Connect existing callbacks, progress and error states.
- [x] Keep loading active through job completion, decode lab values, preserve full content.
- [x] Verify responsive navigation, content, busy states and action callbacks with widget tests.

## Task 3: Local verification and delivery
- [x] Run Flutter tests, analyzer and a release web build against the local API.
- [x] Inspect desktop, mobile and the user's viewport in one batch; correct discovered defects together.
- [ ] Run Impeccable finish review and document the shipped visual system.
- [x] Open and leave the updated frontend running locally.

## Authorized extension —13October2026
Saved-photo and live phone-camera intake now join PDF upload. Add capped/typed intake, EXIF-aware Tesseract OCR, clear retake failures, extracted-text review and source-preserving parser regressions. Physical camera behavior remains to be tested on a supported phone browser. See PRODUCT.md and the SDD ledger for boundaries and verification.

Delivery note: the reviewer correction batch is implemented and verification passed. Final independent scoring was interrupted by the reviewer's account usage limit; it remains unclaimed. The plugin files became unavailable before the documenter handoff. DESIGN.md, a local token snapshot and a surface brief were instead documented from implemented source. The review checkbox intentionally remains open for that final independent pass; it does not block local evaluation.
