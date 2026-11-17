// Small pieces shared by the patient list, the check-in sheet and the
// doctor's follow-up view.
import 'package:flutter/material.dart';

import '../report_workspace.dart' show ReportPalette;
import 'med_engine.dart';

Widget medCard(Widget child,
        {EdgeInsetsGeometry padding = const EdgeInsets.all(20),
        Color color = Colors.white}) =>
    Container(
      padding: padding,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: ReportPalette.cardShadow,
          border: Border.all(color: ReportPalette.border)),
      child: child,
    );

String clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String clockMinutes(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// A rounded label with an icon; wraps instead of overflowing at large text.
Widget medChip(IconData icon, String label, Color background, Color ink,
        {Color? border}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: border == null ? null : Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: ink),
        const SizedBox(width: 5),
        Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: ink))),
      ]),
    );

/// How one outcome is drawn everywhere: a fill, an outline and a glyph, so
/// it never depends on colour alone.
class OutcomeStyle {
  const OutcomeStyle(this.label, this.icon, this.fill, this.ink, {this.stroke});
  final String label;
  final IconData? icon;
  final Color fill, ink;
  final Color? stroke;
}

OutcomeStyle outcomeStyle(DoseOutcome outcome) => switch (outcome) {
      DoseOutcome.asPrescribed => const OutcomeStyle('Taken as prescribed',
          Icons.check_rounded, ReportPalette.sage, Colors.white),
      DoseOutcome.offTime => const OutcomeStyle('Taken off time',
          Icons.schedule_rounded, ReportPalette.lowBg, ReportPalette.lowInk,
          stroke: ReportPalette.lowInk),
      DoseOutcome.wrongFood => const OutcomeStyle('Food instruction not followed',
          Icons.restaurant_rounded, ReportPalette.highBg, ReportPalette.highInk,
          stroke: ReportPalette.amber),
      DoseOutcome.notTaken => const OutcomeStyle('Not taken',
          Icons.close_rounded, Colors.white, ReportPalette.burgundy,
          stroke: ReportPalette.burgundy),
      DoseOutcome.noReply => const OutcomeStyle('No reply',
          Icons.question_mark_rounded, Colors.white, ReportPalette.body,
          stroke: ReportPalette.controlBorder),
      DoseOutcome.skippedByPlan => const OutcomeStyle('Skipped by plan',
          Icons.remove_rounded, ReportPalette.sand, ReportPalette.body,
          stroke: ReportPalette.controlBorder),
      DoseOutcome.open => const OutcomeStyle(
          'Upcoming', null, ReportPalette.sand, ReportPalette.muted),
    };

/// A small square for calendars and legends.
Widget outcomeCell(DoseOutcome? outcome, {double size = 28}) {
  if (outcome == null) {
    return Container(
        height: size,
        decoration: BoxDecoration(
            color: ReportPalette.blush,
            borderRadius: BorderRadius.circular(7)));
  }
  final style = outcomeStyle(outcome);
  return Container(
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: style.fill,
          border: style.stroke == null
              ? null
              : Border.all(color: style.stroke!, width: 2),
          borderRadius: BorderRadius.circular(7)),
      child: style.icon == null
          ? null
          : Icon(style.icon, size: size * 0.56, color: style.ink));
}

/// The worst thing that happened to a medicine on one day, for a calendar.
DoseOutcome? dayOutcome(
    Medicine medicine, List<DoseLog> logs, DateTime day, DateTime now) {
  const order = [
    DoseOutcome.notTaken,
    DoseOutcome.noReply,
    DoseOutcome.wrongFood,
    DoseOutcome.offTime,
    DoseOutcome.skippedByPlan,
    DoseOutcome.asPrescribed,
    DoseOutcome.open,
  ];
  final outcomes = [
    for (final dose in dosesForDay([medicine], logs, day))
      if (dose.movedFrom == null) outcomeOf(dose, logs, now)
  ];
  if (outcomes.isEmpty) return null;
  for (final candidate in order) {
    if (outcomes.contains(candidate)) return candidate;
  }
  return null;
}

/// One bar split by outcome. Each part is also listed in a legend by the
/// caller, so the bar is decoration for a screen reader.
Widget outcomeBar(Map<DoseOutcome, int> counts, {double height = 14}) {
  final parts = [
    for (final entry in counts.entries)
      if (entry.value > 0) entry
  ];
  return ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: parts.isEmpty
            ? Container(color: ReportPalette.sand)
            : Row(children: [
                for (var i = 0; i < parts.length; i++)
                  Expanded(
                    flex: parts[i].value,
                    child: Container(
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                        color: _barColor(parts[i].key)),
                  ),
              ]),
      ),
    ),
  );
}

Color _barColor(DoseOutcome outcome) => switch (outcome) {
      DoseOutcome.asPrescribed => ReportPalette.sage,
      DoseOutcome.offTime => ReportPalette.lowInk,
      DoseOutcome.wrongFood => ReportPalette.amber,
      DoseOutcome.notTaken => ReportPalette.burgundy,
      DoseOutcome.noReply => ReportPalette.controlBorder,
      _ => ReportPalette.strongBorder,
    };

Color outcomeBarColor(DoseOutcome outcome) => _barColor(outcome);
