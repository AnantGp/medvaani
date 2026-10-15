"""Extraction must preserve source units/ranges and exclude report metadata."""
from agents import extract_lab_values


def test_report_metadata_is_not_a_lab_result():
    rows = extract_lab_values("Report Date: 12 October 2026\nPatient ID: 12345\nAge: 35\nGlucose: 95 mg/dL (Normal: 70-100 mg/dL) - Normal")
    assert [row["test_name"] for row in rows] == ["Glucose"]


def test_reference_normal_label_does_not_override_report_low_flag():
    assert extract_lab_values("Hemoglobin: 11.2 g/dL (Normal: 12-16 g/dL) - Low") == [{
        "test_name": "Hemoglobin", "value": "11.2", "unit": "g/dL",
        "reference_range": "12-16 g/dL", "status": "low", "status_source": "report",
    }]


def test_scientific_count_units_are_preserved_with_reference_range():
    assert extract_lab_values("Platelets: 240 10^3/uL (Normal: 150-450 10^3/uL) - Normal") == [{
        "test_name": "Platelets", "value": "240", "unit": "10^3/uL",
        "reference_range": "150-450 10^3/uL", "status": "normal", "status_source": "report",
    }]


def test_unflagged_unreferenced_result_is_unknown_not_automatically_normal():
    row = extract_lab_values("Glucose: 5.2 mmol/L")[0]
    assert row["unit"] == "mmol/L"
    assert row["status"] == "unknown"


def test_explicit_report_flag_wins_over_generic_thresholds():
    row = extract_lab_values("Glucose: 145 mg/dL (Normal)")[0]
    assert row["status"] == "normal"


def test_thousands_separators_do_not_truncate_the_measurement():
    row = extract_lab_values("White blood cells: 6,800 /uL (Normal: 4,000-11,000 /uL)")[0]
    assert row["value"] == "6,800"
    assert row["unit"] == "/uL"
    assert row["reference_range"] == "4,000-11,000 /uL"
    assert row["status"] == "normal"
    assert row["status_source"] == "reference_range"


def test_bare_table_reference_range_is_retained():
    row = extract_lab_values("Hemoglobin: 11.2 g/dL 12-16")[0]
    assert row["reference_range"] == "12-16"
    assert row["status"] == "low"


def test_strict_upper_reference_limit_does_not_include_equality():
    row = extract_lab_values("Cholesterol: 200 mg/dL (Reference: <200 mg/dL)")[0]
    assert row["status"] == "high"
    assert row["status_source"] == "reference_range"


def test_multiline_summary_joins_reference_and_packed_pdf_flag():
    rows = extract_lab_values("""Results in this report
• Hemoglobin:11.2g/dL
Thereportmarksthisresultaslow.
Reference range:12-16g/dL
• WBC:7500cells/uL
The report marks this result as normal.
Reference range:4000-11000cells/uL
Medical summary
• Hemoglobin:11.2g/dL—low
• WBC:7500cells/uL—normal""")
    assert len(rows) == 2
    assert rows[0]["reference_range"] == "12-16g/dL"
    assert rows[0]["status"] == "low" and rows[0]["status_source"] == "report"
    assert rows[1]["reference_range"] == "4000-11000cells/uL"
    assert rows[1]["status"] == "normal"


def test_reference_heading_is_never_a_measurement_or_attached_across_sections():
    rows = extract_lab_values("Reference range: 12-16 g/dL\nGlucose: 95 mg/dL\nOther section\nReference range: 70-100 mg/dL")
    assert len(rows) == 1 and rows[0]["test_name"] == "Glucose"
    assert rows[0]["reference_range"] == "" and rows[0]["status"] == "unknown"


def test_multiline_range_comparison_does_not_override_report_flag():
    rows = extract_lab_values("Glucose: 95 mg/dL\nFlag: High\nReference range: 70-100 mg/dL")
    assert rows[0]["status"] == "high" and rows[0]["status_source"] == "report"


def test_repeated_measurements_keep_conflicting_values_ranges_and_flags():
    rows = extract_lab_values("Glucose: 95 mg/dL\nReference range: 70-100\nGlucose: 95 mg/dL\nReference range: 80-110\nGlucose: 145 mg/dL - High")
    assert len(rows) == 3
    assert [row["reference_range"] for row in rows] == ["70-100", "80-110", ""]
