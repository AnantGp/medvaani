"""Versioned source-backed report records; source geometry never follows edits."""
import hashlib
from typing import TypedDict


class SourceField(TypedDict, total=False):
    text: str
    page: int
    box: list[float]
    boxes: list[list[float]]
    method: str


class PagePrimitives(TypedDict, total=False):
    page: int
    width: float
    height: float
    words: list[dict]
    lines: list[dict]
    regions: list[dict]


class Measurement(TypedDict, total=False):
    measurement_id: str
    record_type: str
    test_name: str
    canonical_test: str
    panel: str
    value: str
    value_kind: str
    unit: str
    normalized_unit: str
    reference_range: str
    reference_kind: str
    sample_date: str | None
    specimen: str | None
    status: str
    status_source: str
    acceptance_state: str
    issues: list[dict]
    source_fields: dict[str, SourceField]


class QualityReport(TypedDict, total=False):
    state: str
    eligible_count: int
    needs_review_count: int
    unresolved_result_regions: int
    processed_pages: list[int]
    failed_pages: list[int]
    issues: list[dict]
    coverage_basis: str


class ExtractedDocument(TypedDict, total=False):
    source_digest: str
    input_type: str
    extracted_text: str
    pages: list[PagePrimitives]
    candidates: list[Measurement]
    diagnostics: list[dict]


def measurement_id(source_digest: str, page: int, block_id: str, row_box: list[float]) -> str:
    anchor = f'{source_digest}:{page}:{block_id}:' + ','.join(f'{v:.5f}' for v in row_box)
    return hashlib.sha256(anchor.encode()).hexdigest()[:24]


def project_lab_values(measurements: list[Measurement]) -> list[dict]:
    return [dict(row) for row in measurements if row.get('record_type') == 'measurement'
            and row.get('acceptance_state') != 'rejected']
