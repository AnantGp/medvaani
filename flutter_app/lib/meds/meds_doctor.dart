// The doctor's follow-up view: what was prescribed, and what the patient
// says actually happened to every dose.
//
// A clinician reviewing adherence asks, in order: is the medicine being
// taken at all, at the right time, the right way with food, and if not, why.
// The page answers in that order and never infers a cause.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../report_workspace.dart' show ReportPalette, heading, serifStyle;
import 'med_engine.dart';
import 'meds_widgets.dart';

const _reviewDays = 14;

const _shown = [
  DoseOutcome.asPrescribed,
  DoseOutcome.offTime,
  DoseOutcome.wrongFood,
  DoseOutcome.notTaken,
  DoseOutcome.noReply,
];

String foodRuleLabel(Medicine m) => switch (m.mealRule) {
      MealRule.beforeFood => 'Before ${_meal(m)} · empty stomach, eat ${m.gapMinutes} min later',
      MealRule.afterFood => 'After ${_meal(m)}',
      MealRule.withFood => 'With ${_meal(m)}',
      MealRule.any => 'No food instruction',
    };

String _meal(Medicine m) => m.times.isEmpty
    ? _mealName(m.meal)
    : m.times.length > 1
    ? [
        for (final t in m.times)
          _mealName(mealAt(m, DateTime(2000, 1, 1, t ~/ 60, t % 60)))
      ].join(' / ')
    : _mealName(m.meal == Meal.none
        ? mealAt(m, DateTime(2000, 1, 1, m.times.first ~/ 60, m.times.first % 60))
        : m.meal);

String _mealName(Meal meal) => switch (meal) {
      Meal.breakfast => 'breakfast',
      Meal.lunch => 'lunch',
      Meal.dinner => 'dinner',
      Meal.none => 'food',
    };

String reasonLabel(String key) => switch (key) {
      'ran_out' => 'ran out of tablets',
      'unwell' => 'felt unwell',
      'away' => 'away from home',
      'forgot' => 'forgot',
      'ate_first' => 'had already eaten',
      'no_meal' => 'fasting or missed the meal',
      _ => 'other reason',
    };

String _capitalised(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String _date(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

class DoctorFollowUp extends StatefulWidget {
  const DoctorFollowUp(
      {super.key, required this.state, required this.now, required this.wide});
  final MedState state;
  final DateTime now;
  final bool wide;

  @override
  State<DoctorFollowUp> createState() => _DoctorFollowUpState();
}

class _DoctorFollowUpState extends State<DoctorFollowUp> {
  bool _allDays = false;

  MedState get _state => widget.state;
  DateTime get _now => widget.now;
  DateTime get _from => _now.subtract(const Duration(days: _reviewDays - 1));

  /// Every planned dose in the review window, tallied by what happened.
  Map<DoseOutcome, int> _tally({String? medicineId}) {
    final counts = {for (final o in _shown) o: 0};
    final meds = _state.medicines
        .where((m) => medicineId == null || m.id == medicineId)
        .toList();
    for (var back = _reviewDays - 1; back >= 0; back--) {
      final day = _now.subtract(Duration(days: back));
      for (final dose in dosesForDay(meds, _state.logs, day)) {
        if (dose.movedFrom != null || dose.scheduled.isAfter(_now)) continue;
        final outcome = outcomeOf(dose, _state.logs, _now);
        if (counts.containsKey(outcome)) counts[outcome] = counts[outcome]! + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final wide = widget.wide;
    final signals = followUpSignals(
        _state.medicines, _state.logs, _state.readings, _now);
    final fortnight =
        adherence(_state.medicines, _state.logs, _from, _now, _now);
    final chart = _bpCard();
    final attention = _attention(signals);
    final overview = _overview(fortnight);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _planHeader(),
      const SizedBox(height: 14),
      if (wide)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 3, child: overview),
            const SizedBox(width: 14),
            Expanded(flex: 2, child: attention),
          ]),
        )
      else ...[
        overview,
        const SizedBox(height: 14),
        attention,
      ],
      const SizedBox(height: 22),
      heading('Medicine by medicine · last $_reviewDays days',
          const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      if (wide)
        Wrap(spacing: 14, runSpacing: 14, children: [
          for (final m in _state.medicines)
            LayoutBuilder(
                builder: (context, _) => SizedBox(
                    width: (MediaQuery.sizeOf(context).width.clamp(900, 1168) -
                            48 -
                            14 * (math.min(3, _state.medicines.length) - 1)) /
                        math.min(3, _state.medicines.length),
                    child: _medicineCard(m))),
        ])
      else
        for (final m in _state.medicines)
          Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _medicineCard(m)),
      const SizedBox(height: 14),
      _doseLog(),
      if (chart != null) ...[const SizedBox(height: 14), chart],
      const SizedBox(height: 14),
      _patientReported(fortnight),
      const SizedBox(height: 14),
      const Text(
          'Check-ins are self-reported and can overstate doses actually taken; studies of phone-based dose reporting found it missed many non-adherent days. Confirm at the visit.',
          style: TextStyle(
              fontSize: 13, height: 1.5, color: ReportPalette.muted)),
    ]);
  }

  // ------------------------------------------------------------ the plan

  /// Who and what the doctor is looking at, before any numbers.
  Widget _planHeader() {
    final starts = _state.medicines.map((m) => m.start).whereType<DateTime>();
    final first =
        starts.isEmpty ? null : starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final days = first == null ? null : _now.difference(first).inDays;
    final prescriber = _state.medicines
        .map((m) => m.prescribedBy)
        .firstWhere((p) => p.isNotEmpty, orElse: () => '');
    return medCard(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
              color: ReportPalette.rose, shape: BoxShape.circle),
          child: const Icon(Icons.person_outline_rounded,
              color: ReportPalette.burgundy, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          heading(_state.demo ? 'Demo patient' : 'Patient on this device',
              serifStyle(22)),
          const SizedBox(height: 3),
          Text(
              [
                '${_state.medicines.length} medicines',
                if (days != null) 'plan started $days days ago',
                if (prescriber.isNotEmpty) 'prescribed by $prescriber',
                'self-reported check-ins',
              ].join(' · '),
              style:
                  const TextStyle(fontSize: 13.5, color: ReportPalette.muted)),
        ])),
      ]),
      const SizedBox(height: 16),
      const Text('PRESCRIBED',
          style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: ReportPalette.muted)),
      const SizedBox(height: 8),
      for (var i = 0; i < _state.medicines.length; i++) ...[
        if (i > 0) const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 190),
                  child: Text(
                      [
                        _state.medicines[i].name,
                        if (_state.medicines[i].dose.isNotEmpty)
                          _state.medicines[i].dose
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                medChip(
                    Icons.schedule_rounded,
                    _state.medicines[i].times.map(clockMinutes).join(' and '),
                    ReportPalette.sand,
                    ReportPalette.ink),
                medChip(
                    Icons.restaurant_rounded,
                    foodRuleLabel(_state.medicines[i]),
                    _state.medicines[i].mealSensitive
                        ? ReportPalette.rose
                        : ReportPalette.sand,
                    _state.medicines[i].mealSensitive
                        ? ReportPalette.burgundy
                        : ReportPalette.body),
              ]),
        ),
      ],
    ]));
  }

  // ------------------------------------------------------------ overview

  Widget _overview(Adherence a) {
    final counts = _tally();
    final total = counts.values.fold<int>(0, (sum, n) => sum + n);
    final percent = total == 0
        ? null
        : (counts[DoseOutcome.asPrescribed]! / total * 100).round();
    return medCard(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      heading('How doses were taken · last $_reviewDays days',
          const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      Wrap(
          spacing: 14,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(percent == null ? '—' : '$percent%', style: serifStyle(46)),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  total == 0
                      ? 'No doses were due yet'
                      : 'taken exactly as prescribed\n${counts[DoseOutcome.asPrescribed]} of $total planned doses',
                  style: const TextStyle(
                      fontSize: 14, height: 1.4, color: ReportPalette.body)),
            ),
          ]),
      const SizedBox(height: 14),
      outcomeBar(counts, height: 16),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final o in _shown) _legendCount(o, counts[o]!),
      ]),
      if (a.averageDelay != null) ...[
        const SizedBox(height: 14),
        Text(
            'On average, taken ${_delay(a.averageDelay!)}. "On time" means within $onTimeWindowMinutes minutes of the planned time.',
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: ReportPalette.muted)),
      ],
    ]));
  }

  String _delay(int minutes) => minutes.abs() < 5
      ? 'at the planned time'
      : minutes > 0
          ? '$minutes min after the planned time'
          : '${-minutes} min before the planned time';

  Widget _legendCount(DoseOutcome outcome, int count) {
    final style = outcomeStyle(outcome);
    return Semantics(
      container: true,
      label: '${style.label}: $count',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
          decoration: BoxDecoration(
              color: ReportPalette.blush,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ReportPalette.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 22, child: outcomeCell(outcome, size: 22)),
            const SizedBox(width: 8),
            Text('$count',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Flexible(
                child: Text(style.label,
                    style: const TextStyle(
                        fontSize: 13, color: ReportPalette.body))),
          ]),
        ),
      ),
    );
  }

  Widget _attention(List<FollowUpSignal> signals) => medCard(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading('Needs attention',
            const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (signals.isEmpty)
          const Text('Nothing flagged in the last 14 days.',
              style: TextStyle(fontSize: 15, color: ReportPalette.body))
        else
          for (final s in signals)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      label: s.priority >= 3 ? 'Important' : 'Note',
                      child: Icon(
                          s.priority >= 3
                              ? Icons.priority_high_rounded
                              : Icons.info_outline_rounded,
                          size: 18,
                          color: s.priority >= 3
                              ? ReportPalette.burgundy
                              : ReportPalette.highInk),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(s.message,
                            style:
                                const TextStyle(fontSize: 14.5, height: 1.45))),
                  ]),
            ),
      ]));

  // ------------------------------------------------------- per medicine

  Widget _medicineCard(Medicine m) {
    final counts = _tally(medicineId: m.id);
    final a = adherence(_state.medicines, _state.logs, _from, _now, _now,
        medicineId: m.id);
    final total = counts.values.fold<int>(0, (sum, n) => sum + n);
    final reasons = a.reasons.entries
        .map((e) => '${reasonLabel(e.key)} ×${e.value}')
        .join(', ');
    Widget fact(IconData icon, String text, {bool warn = false}) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon,
                size: 17,
                color: warn ? ReportPalette.highInk : ReportPalette.muted),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: warn ? FontWeight.w600 : FontWeight.w400,
                        color:
                            warn ? ReportPalette.highInk : ReportPalette.body))),
          ]),
        );
    final days = [
      for (var back = _reviewDays - 1; back >= 0; back--)
        _now.subtract(Duration(days: back))
    ];
    final marks = [
      for (final d in days) dayOutcome(m, _state.logs, d, _now)
    ];
    final strip = Semantics(
      container: true,
      label: '${m.name}, day by day: ${[
        for (final o in _shown)
          if (marks.where((x) => x == o).isNotEmpty)
            '${marks.where((x) => x == o).length} days ${outcomeStyle(o).label.toLowerCase()}'
      ].join(', ')}',
      child: ExcludeSemantics(
        child: Row(children: [
          for (var i = 0; i < marks.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                child: outcomeCell(marks[i], size: 20),
              ),
            ),
        ]),
      ),
    );
    return medCard(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.name,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
              [
                if (m.dose.isNotEmpty) m.dose,
                m.times.map(clockMinutes).join(' and '),
              ].join(' · '),
              style: const TextStyle(fontSize: 13, color: ReportPalette.muted)),
        ])),
        const SizedBox(width: 8),
        Text(
            total == 0
                ? '—'
                : '${(counts[DoseOutcome.asPrescribed]! / total * 100).round()}%',
            style: serifStyle(26)),
      ]),
      const SizedBox(height: 4),
      Text(foodRuleLabel(m),
          style: const TextStyle(fontSize: 13, color: ReportPalette.muted)),
      const SizedBox(height: 12),
      outcomeBar(counts, height: 10),
      const SizedBox(height: 4),
      fact(
          Icons.check_circle_outline_rounded,
          total == 0
              ? 'No doses were due yet'
              : 'As prescribed for ${counts[DoseOutcome.asPrescribed]} of $total doses'),
      if (a.averageDelay != null)
        fact(Icons.schedule_rounded,
            'Usually taken ${_delay(a.averageDelay!)}${counts[DoseOutcome.offTime]! > 0 ? ' · ${counts[DoseOutcome.offTime]} more than an hour off' : ''}',
            warn: counts[DoseOutcome.offTime]! >= 2),
      if (m.mealSensitive && a.foodAnswered > 0)
        fact(Icons.restaurant_rounded,
            'Food instruction followed ${a.foodFollowed} of ${a.foodAnswered} times',
            warn: a.foodFollowed < a.foodAnswered),
      if (counts[DoseOutcome.notTaken]! > 0)
        fact(Icons.close_rounded,
            '${counts[DoseOutcome.notTaken]} not taken${reasons.isEmpty ? '' : ' — $reasons'}',
            warn: true),
      if (counts[DoseOutcome.noReply]! > 0)
        fact(Icons.question_mark_rounded,
            '${counts[DoseOutcome.noReply]} with no reply — unknown whether taken'),
      if (m.supply != null)
        fact(Icons.inventory_2_outlined, '${m.supply} tablets left',
            warn: m.times.isNotEmpty && m.supply! <= m.times.length * 3),
      const SizedBox(height: 12),
      strip,
      const SizedBox(height: 4),
      ExcludeSemantics(
        child: Row(children: [
          Expanded(
              child: Text(_date(days.first),
                  style: const TextStyle(
                      fontSize: 11.5, color: ReportPalette.muted))),
          const Text('Today',
              style: TextStyle(fontSize: 11.5, color: ReportPalette.muted)),
        ]),
      ),
    ]));
  }

  // ----------------------------------------------------------- dose log

  /// Every dose, newest first: planned time, what happened, and the
  /// patient's own answers.
  Widget _doseLog() {
    final span = _allDays ? _reviewDays : 3;
    final rows = <Widget>[];
    for (var back = 0; back < span; back++) {
      final day = _now.subtract(Duration(days: back));
      final doses = dosesForDay(_state.medicines, _state.logs, day)
          .where((d) => d.movedFrom == null && !d.scheduled.isAfter(_now))
          .toList()
          .reversed
          .toList();
      if (doses.isEmpty) continue;
      rows.add(Padding(
        padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 14, bottom: 4),
        child: Text(back == 0 ? 'Today · ${_date(day)}' : _date(day),
            style: const TextStyle(
                fontSize: 12.5,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w700,
                color: ReportPalette.muted)),
      ));
      for (final dose in doses) {
        rows.add(_logRow(dose));
      }
    }
    return medCard(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      heading('Dose by dose',
          const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text(
          'Planned time, what the patient reported, and their own answers.',
          style: TextStyle(fontSize: 13, color: ReportPalette.muted)),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        const Text('No doses were due in this period.',
            style: TextStyle(fontSize: 14, color: ReportPalette.body))
      else
        ...rows,
      const SizedBox(height: 8),
      TextButton.icon(
          onPressed: () => setState(() => _allDays = !_allDays),
          icon: Icon(_allDays
              ? Icons.expand_less_rounded
              : Icons.expand_more_rounded),
          label: Text(_allDays ? 'Show last 3 days' : 'Show all $_reviewDays days')),
    ]));
  }

  Widget _logRow(ScheduledDose dose) {
    final outcome = outcomeOf(dose, _state.logs, _now);
    final style = outcomeStyle(outcome);
    final own = dose.log;
    final settled = settlingLog(dose, _state.logs);
    final details = <String>[];
    if (own?.status == DoseStatus.moved && own!.movedTo != null) {
      details.add('had eaten, moved to ${clock(own.movedTo!)} by the plan');
    }
    if (settled != null && settled.status == DoseStatus.taken) {
      final planned =
          own?.status == DoseStatus.moved ? own!.movedTo! : dose.scheduled;
      final off = minutesOff(settled, planned: planned);
      if (settled.at != null) {
        details.add('taken ${clock(settled.at!)}'
            '${off == null || off.abs() < 5 ? '' : off > 0 ? ' (+$off min)' : ' ($off min)'}');
      }
      if (dose.medicine.mealSensitive && settled.foodAnswer != null) {
        details.add(switch (settled.foodAnswer) {
          'before' => 'before food',
          'with' => 'with food',
          _ => 'after food',
        });
      }
      if (settled.feeling != null && settled.feeling != 'Fine') {
        details.add('felt ${settled.feeling!.toLowerCase()}');
      }
    }
    for (final log in {own, settled}) {
      final reason = log?.reason;
      if (log != null && reason != null && log.status != DoseStatus.taken) {
        details.add(reasonLabel(reason));
      }
    }
    if (outcome == DoseOutcome.open) details.add('awaiting check-in');
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 48,
              child: Text(clock(dose.scheduled),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ReportPalette.body))),
          Expanded(
            child: Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(dose.medicine.name,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  medChip(style.icon ?? Icons.more_horiz_rounded, style.label,
                      style.fill == ReportPalette.sage
                          ? ReportPalette.sageLight
                          : style.fill,
                      style.fill == ReportPalette.sage
                          ? ReportPalette.sage
                          : style.ink,
                      border: style.stroke),
                  if (details.isNotEmpty)
                    Text(details.join(' · '),
                        style: const TextStyle(
                            fontSize: 13.5, color: ReportPalette.body)),
                ]),
          ),
        ]),
      ),
    );
  }

  // ------------------------------------------------------ blood pressure

  Widget? _bpCard() {
    final bp = _state.readings.where((r) => r.kind == 'bp').toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    if (bp.isEmpty) return null;
    final window = bp
        .where((r) => r.at.isAfter(_now.subtract(const Duration(days: 22))))
        .toList();
    final missedDays = <int>{};
    for (var back = 0; back <= 21; back++) {
      final day = _now.subtract(Duration(days: back));
      final doses = dosesForDay(_state.medicines, _state.logs, day);
      if (doses.any((d) =>
          !d.scheduled.isAfter(_now) &&
          outcomeOf(d, _state.logs, _now) == DoseOutcome.notTaken)) {
        missedDays.add(back);
      }
    }
    final summary = window.isEmpty
        ? 'Home blood pressure chart: no readings yet.'
        : 'Home systolic blood pressure over the last 21 days: first reading '
            '${window.first.value.round()}, latest ${window.last.value.round()}, '
            '${window.length} readings. ${missedDays.length} days had a dose not taken.';
    return medCard(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      heading('Home blood pressure and doses not taken · 21 days',
          const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Semantics(
        image: true,
        label: summary,
        child: ExcludeSemantics(
          child: SizedBox(
              height: 220,
              width: double.infinity,
              child: CustomPaint(
                  painter: _BpPainter(
                      readings: window, missedDays: missedDays, now: _now))),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
          'Outlined boxes below the line mark days with a dose not taken. Shown together for review; any link between them is the clinician’s judgement.',
          style:
              TextStyle(fontSize: 13, height: 1.5, color: ReportPalette.muted)),
    ]));
  }

  // ---------------------------------------------------- patient's words

  /// What the patient said, in their own categories: why doses were not
  /// taken and how they felt when they confirmed one.
  Widget _patientReported(Adherence a) {
    Widget group(String title, IconData icon, Map<String, String> items,
            String empty) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: ReportPalette.muted),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(empty,
                style:
                    const TextStyle(fontSize: 14, color: ReportPalette.muted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in items.entries)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: ReportPalette.sand,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('${e.key}  ${e.value}',
                      style: const TextStyle(
                          fontSize: 13.5, color: ReportPalette.ink)),
                ),
            ]),
        ]);
    final reasons = {
      for (final e in a.reasons.entries)
        _capitalised(reasonLabel(e.key)): '×${e.value}',
      if (a.noReply > 0) 'No reply': '×${a.noReply}',
    };
    final feelings = {
      for (final e in a.feelings.entries) e.key: '×${e.value}',
    };
    return medCard(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      heading('What the patient told us · 14 days',
          const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, box) {
        final missedGroup = group('Why doses were not taken',
            Icons.help_outline_rounded, reasons, 'No doses reported as not taken.');
        final feelGroup = group('How they felt when taking a dose',
            Icons.sentiment_satisfied_outlined, feelings,
            'No feelings recorded.');
        return box.maxWidth >= 560
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: missedGroup),
                const SizedBox(width: 24),
                Expanded(child: feelGroup),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                missedGroup,
                const SizedBox(height: 18),
                feelGroup,
              ]);
      }),
    ]));
  }
}

class _BpPainter extends CustomPainter {
  _BpPainter(
      {required this.readings, required this.missedDays, required this.now});
  final List<Reading> readings;
  final Set<int> missedDays;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0, bottomStrip = 28.0;
    final chartH = size.height - bottomStrip - 12;
    const lo = 110.0, hi = 170.0;
    double y(double v) => 6 + (hi - v.clamp(lo, hi)) / (hi - lo) * chartH;
    double x(num back) => left + (21 - back) / 21 * (size.width - left - 8);
    final grid = Paint()..color = ReportPalette.border;
    final text = TextPainter(textDirection: TextDirection.ltr);
    for (final v in [120.0, 140.0, 160.0]) {
      canvas.drawLine(
          Offset(left, y(v)),
          Offset(size.width, y(v)),
          v == 140
              ? (Paint()
                ..color = ReportPalette.amber
                ..strokeWidth = 1)
              : grid);
      text.text = TextSpan(
          text: v.round().toString(),
          style: const TextStyle(fontSize: 12, color: ReportPalette.muted));
      text.layout();
      text.paint(canvas, Offset(0, y(v) - 8));
    }
    text.text = const TextSpan(
        text: 'Target 140',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ReportPalette.highInk));
    text.layout();
    text.paint(
        canvas, Offset(size.width - text.width, y(140) - text.height - 2));
    final points = <Offset>[
      for (final r in readings)
        Offset(x(now.difference(r.at).inHours / 24), y(r.value))
    ];
    final line = Paint()
      ..color = ReportPalette.ink
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], line);
    }
    for (final p in points) {
      canvas.drawCircle(p, 3, Paint()..color = ReportPalette.ink);
    }
    final stripY = size.height - bottomStrip + 4;
    final cellW = math.max(4.0, (size.width - left - 8) / 22 - 3);
    for (var back = 0; back <= 21; back++) {
      final missed = missedDays.contains(back);
      final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x(back) - cellW / 2, stripY, cellW, 16),
          const Radius.circular(4));
      canvas.drawRRect(
          rect,
          Paint()
            ..color = missed ? Colors.white : ReportPalette.sage
            ..style = PaintingStyle.fill);
      if (missed) {
        canvas.drawRRect(
            rect,
            Paint()
              ..color = ReportPalette.burgundy
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BpPainter old) => true;
}
