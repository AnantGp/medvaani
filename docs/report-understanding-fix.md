# Report-grounded understanding

Version 4 reports persist page dimensions, document fingerprint, candidates, full original source fields and quality inside `parsed_data`. One backend policy recomputes eligibility before report answers, summary/translation generation, review and historical output. Old records are `legacy_unverified`; global review confirmation does not promote them.

Supported reference comparisons describe supplied intervals or explicit source flags. Bounded values and contextual/category references without an applicable rule remain unknown. Unknown does not mean normal or abnormal. A partial report visibly limits outputs to eligible rows; blocked reports retain source access and correction controls without result interpretations.

Questions resolve higher/lower/flagged intent and named-test aliases against eligible patient measurements. A word inside a complete test name, such as High sensitivity CRP, is not a high-results filter. Diagnosis/treatment requests are not inferred from individual results. Every supported measurement answer carries stable source identity and immutable fields.

The upload path reads native and scanned physical pages independently. An optional offline Docling worker consumes tables directly, not Markdown regex output. Printed flag/reference conflicts, OCR source checks and engine disagreements stay reviewable.

The private 95-row benchmark passed the actual upload API; expected inventory and private evidence are not committed. See [evaluation](reliable-extraction-evaluation.md).
