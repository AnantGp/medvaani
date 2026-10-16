# Extraction MVP verification — 16 October 2026

This is a bounded release check, not a claim that arbitrary medical reports are fully supported. Private documents and detailed extracted medical data remain outside this repository.

## Extraction and source evidence

- Private 33-page laboratory report: 95/95 audited names, values, units and references; original physical pages matched; no extra or duplicate measurements. All 353 available source fields intersected their actual printed text.
- Nine-page exported summary of the same report: 95/95 audited names, values, units and references; no extra or duplicate measurements. All 434 source fragments intersected their actual printed text, including references continuing onto another page.
- Both inputs: 8 flagged, 69 within the supplied range, 18 unclassified. A missing or categorical reference is not counted as normal. An exported summary comparison is distinguished from an original laboratory flag.
- Anonymous three-row table as JPG, PNG and raster-only scanned PDF: all three names, values, units and references recovered through hosted vision. These remain **needs source review**, with AI-estimated row locations; they are not automatically promoted to verified measurements.
- Reproduced and fixed numeric follow-up prose being appended to references and vitamin D reference categories being emitted as measurements.
- A declared total that disagrees with recovered rows makes extraction partial. It is a coverage hint, not proof of completeness for other reports.

## Voice

An anonymous 95-row report was used with the unified voice endpoint, actual Groq ASR/LLM calls and the four configured Edge neural voices.

- Audio question and cited exact creatinine value/unit in English, Hindi, Spanish and Mandarin.
- Hindi low-result explanation; edited value superseding an old answer; absent test acknowledged in Spanish; off-topic coding request redirected in Mandarin with no measurement citations.
- The last measurement in the 95-row report remained answerable.
- Successful model calls were approximately 0.8–1.5 seconds, with the full audio-question/answer/speech path approximately 3.4–7.5 seconds. Free-quota waits are additional.
- A separate contract check verifies audible correction attribution in all four languages when the model omits it. A final Hindi prompt check uses everyday wording and separates the measurement's purpose from an assessment of organ function.

ASR is fallible: the Mandarin synthetic question's homophone for creatinine was transcribed incorrectly, although the model selected and cited the intended report result. Real speakers, accents and background noise still need a native-speaker pilot. Neural voice selection and nonempty audio were checked; subjective naturalness was not independently scored.

## Build and bounded regressions

- Focused backend checks: 67 passed.
- Browser explorer checks: 14 passed.
- Focused Flutter checks and release web build passed. Analysis has no errors or warnings; existing informational notices remain.

## Hosted/free-tier limits

Repeated verbose JSON keys and duplicated raw report text exceeded Groq's free request allowance. Model input now uses a column table, retains every measurement and limits supplementary passages/recent history with disclosure. OCR output is bounded to the tested free allowance. Large/dense scans can exceed it and must fail visibly rather than silently count as complete. A crop/chunk OCR strategy for dense pages is future work.

Rapid full-report conversations can still exhaust the free per-minute quota. Waiting and retrying was necessary during acceptance. This release does not guarantee unlimited simultaneous public usage or a 1–3 second complete spoken round trip.

Physical camera capture, low-bandwidth phones, other providers and dense multi-page scans remain outside this release's acceptance evidence.

## Hosted upload boundary

The original 33-page file is 8.3 MB and is rejected by Vercel's function payload limit; the app advertises/enforces a 4 MB upload cap. A separately named image-compressed copy (approximately 1.5 MB, original untouched) retains all 33 pages. Its 95 audited measurements/references and statuses matched locally and on the hosted backend with zero field differences. Images were recompressed; this is not a lossless copy of the entire document. The nine-page summary also matched all 95 rows on the hosted backend.
