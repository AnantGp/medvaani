"""Source section/identity exclusions shared by both table engines.

A numeric cell beneath clinical headers is insufficient evidence that a row is
a patient's current measurement. These rules classify explicit source labels;
they do not supply medical cutoffs or infer missing collection dates.
"""
import re


def nonmeasurement_identity(name):
    return bool(re.match(
        r'^(?:(?:very |extreme |moderate |low |high )*risk\s*(?:group|category)|'
        r'(?:very |extreme |moderate |low |high )+risk|adults?\s+(?:above|below)|'
        r'booking\s*(?:id|details)|patient\s*(?:id|age)|reference\s*(?:range|interval|guideline)|'
        r'pregnan(?:t|cy)|no\.?\s*of\s*tests?)\b', str(name), re.I))


def result_context(texts):
    """Nearest explicit section heading wins; no heading is unknown."""
    context = 'unknown'
    for text in texts:
        text = str(text).strip()
        if re.match(r'^(?:historical|previous|prior|past)\s+(?:summary|results?|measurements?|reports?)\b', text, re.I):
            context = 'historical'
        elif re.match(r'^(?:reference\s+guideline|guideline|reference\s+target)\b', text, re.I):
            context = 'guideline'
        elif re.match(r'^(?:laboratory\s+(?:test\s+)?results?|current\s+(?:results?|measurements?)|test\s+results?|results\s+in\s+this\s+report)\s*[:.]?\s*$', text, re.I):
            context = 'current'
    return context
