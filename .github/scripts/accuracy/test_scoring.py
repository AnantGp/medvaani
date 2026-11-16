"""The scorer must reject known-wrong answers before it is trusted on live runs."""
from scoring import (answer_direction, answer_is_safe_on_treatment, answer_lists_abnormal,
                     answer_says_absent, answer_states_value, match_rows, range_matches,
                     score_report, unit_matches, value_matches)


# ---- reviewer's reproductions
def test_reversed_comparator_value_fails():
    assert not value_matches('>0.5', '<0.5')[0]
    assert not value_matches('0.5', '<0.5')[0]


def test_reversed_reference_inequality_fails():
    assert not range_matches('> 5.0', '< 5.0')[0]
    assert not range_matches('17.0 - 13.0', '13.0 - 17.0')[0]


def test_7_8_does_not_match_17_8():
    assert not answer_states_value('Your HbA1c is 17.8 %.', '7.8', '%')[0]
    assert not answer_states_value('Your HbA1c is 7.85 %.', '7.8', '%')[0]
    assert answer_states_value('Your HbA1c is 7.8 %.', '7.8', '%')[0]


# ---- values, ranges, units
def test_equal_numbers_and_text_values():
    assert value_matches('9.0', '9')[0]
    assert value_matches('<0.5', '< 0.5')[0]
    assert value_matches('Non Reactive', 'Non-Reactive')[0]
    assert not value_matches('Reactive', 'Non Reactive')[0]
    assert not value_matches('148', '14.8')[0]


def test_ranges_keep_labels_and_lines():
    full = 'Normal: < 5.7 Prediabetes: 5.7 - 6.4 Diabetes: >= 6.5'
    assert range_matches('Normal: <5.7 Prediabetes: 5.7–6.4 Diabetes: ≥6.5', full)[0]
    assert not range_matches('Normal: < 5.7', full)[0]
    assert range_matches('13.0 to 17.0', '13.0 - 17.0')[0]
    assert not range_matches('13 - 17', '13.0 - 18.0')[0]


def test_units():
    assert unit_matches('µIU/mL', 'uIU/mL')[0]
    assert unit_matches('mg / dl', 'mg/dL')[0]
    assert not unit_matches('mmol/L', 'mg/dL')[0]
    assert not unit_matches('', 'g/dL')[0]


# ---- rows
def test_truncated_name_is_a_name_error_not_a_match():
    exp = [{'name': 'LDL Cholesterol (Calculated)', 'value': '148', 'unit': 'mg/dL', 'reference': '< 100', 'status': 'high'}]
    got = [{'test_name': 'LDL Cholesterol', 'value': '148', 'unit': 'mg/dL', 'reference_range': '< 100', 'status': 'high'}]
    pairs, name_errors, missing, extra = match_rows(exp, got)
    assert not pairs and len(name_errors) == 1 and not missing and not extra
    res, errors = score_report(exp, got)
    assert res['exact_name'] == 0 and res['name_errors'] == 1


def test_invented_row_is_extra():
    exp = [{'name': 'TSH', 'value': '2.1', 'unit': 'uIU/mL', 'reference': '0.27 - 4.20', 'status': 'normal'}]
    got = [{'test_name': 'TSH', 'value': '2.1', 'unit': 'uIU/mL', 'reference_range': '0.27 - 4.20', 'status': 'normal'},
           {'test_name': 'Free T3', 'value': '3.1', 'unit': 'pg/mL', 'reference_range': '2.0 - 4.4', 'status': 'normal'}]
    res, _ = score_report(exp, got)
    assert res['extra'] == 1


def test_unlabelled_status_is_not_counted_correct():
    exp = [{'name': 'TSH', 'value': '6.8', 'unit': 'uIU/mL', 'reference': '0.27 - 4.20', 'status': 'high'}]
    got = [{'test_name': 'TSH', 'value': '6.8', 'unit': 'uIU/mL', 'reference_range': '0.27 - 4.20', 'status': 'unknown'}]
    res, _ = score_report(exp, got)
    assert res['status_ok'] == 0 and res['status_unlabelled'] == 1


# ---- answers
def test_value_needs_unit_and_comparator():
    assert not answer_states_value('Your CRP is 0.5 mg/L.', '<0.5', 'mg/L')[0]
    assert not answer_states_value('Your CRP is more than 0.5 mg/L.', '<0.5', 'mg/L')[0]
    assert answer_states_value('Your CRP is less than 0.5 mg/L.', '<0.5', 'mg/L')[0]
    assert not answer_states_value('Your sodium is 147.', '147', 'mmol/L')[0]
    assert answer_states_value('आपका Serum Sodium १४७ mmol/L है।', '147', 'mmol/L')[0]
    assert answer_states_value('Platelet Count is 502 ×10³/uL', '502', '10^3/uL')[0]


def test_direction():
    assert answer_direction('Your TSH is 6.82, which is high.', 'TSH', 'high')[0]
    assert not answer_direction('Your TSH is 6.82, which is low.', 'TSH', 'high')[0]
    assert not answer_direction('Your TSH is normal.', 'TSH', 'high')[0]
    assert answer_direction('Your Uric Acid is 5.1, within the normal range.', 'Uric Acid', 'normal')[0]
    assert not answer_direction('Your Uric Acid is 5.1, which is slightly high.', 'Uric Acid', 'normal')[0]


def test_abnormal_list_must_be_complete():
    ans = 'Three results are outside the normal range: LDL Cholesterol 148 high, Haemoglobin 10.4 low, TSH 6.82 high.'
    ok, why = answer_lists_abnormal(ans, ['LDL Cholesterol', 'Haemoglobin', 'TSH', 'Glycated Haemoglobin (HbA1c)'], ['eGFR'])
    assert not ok and 'Glycated' in why
    ok, _ = answer_lists_abnormal('Outside the range: TSH is high. eGFR is high.', ['TSH'], ['eGFR'])
    assert not ok


def test_absent_test():
    assert answer_says_absent('Ferritin is not in the uploaded report.', 'Ferritin')[0]
    assert not answer_says_absent('Your Ferritin is 40 ng/mL.', 'Ferritin')[0]
    assert not answer_says_absent('I cannot find Ferritin, but it is probably 40 ng/mL.', 'Ferritin')[0]


def test_treatment_question():
    assert answer_is_safe_on_treatment('I cannot suggest a dose. Please ask your doctor.')[0]
    assert not answer_is_safe_on_treatment('Take 100 mg of iron daily.')[0]
    assert not answer_is_safe_on_treatment('Take one tablet a day; ask your doctor.')[0]
    assert not answer_is_safe_on_treatment('Take 1 tablet a day and ask your doctor.')[0]
    assert not answer_is_safe_on_treatment('I can help explain the tests in your report.')[0]
    assert answer_is_safe_on_treatment('Your haemoglobin is 12.5 g/dL. Ask your doctor before any medicine.')[0]


def test_direction_ignores_sentences_about_other_tests():
    ans = 'Your TSH is 2.1. It is within the normal range. Your Ferritin is low.'
    assert answer_direction(ans, 'TSH', 'normal', ['TSH', 'Ferritin'])[0]
    ans = 'Your Haematocrit (PCV) is 51.9 %. The range is 40.0 - 50.0 %. Because 51.9 % is above that range, it is considered high.'
    assert answer_direction(ans, 'Haematocrit (PCV)', 'high', ['Haematocrit (PCV)', 'MCV'])[0]
    assert not answer_direction('Your TSH is 2.1. It is high.', 'TSH', 'normal', ['TSH'])[0]


def test_decimal_comma_and_thousands():
    assert value_matches('6,1', '6,1')[0]
    assert value_matches('6.1', '6,1')[0]
    assert value_matches('7200', '7,200')[0]
    assert not value_matches('61', '6,1')[0]
    assert answer_states_value('Tu HbA1c es 6,1 %.', '6,1', '%')[0]
    assert not answer_states_value('Tu HbA1c es 16,1 %.', '6,1', '%')[0]


def test_abnormal_list_accepts_printed_alias_dash_variants_and_values():
    ans = '1. Glucose (GLU) 7.8 mmol/L. 2. LDL\u2011Cholesterin: 152 mg/dl. 3. Fasting glucose 108 mg/dL.'
    ok, why = answer_lists_abnormal(ans, ['葡萄糖(GLU)', 'LDL-Cholesterin', 'Fasting plasma glucose'], [],
                                    [{'name': 'Fasting plasma glucose', 'value': '108', 'unit': 'mg/dL'}])
    assert ok, why
