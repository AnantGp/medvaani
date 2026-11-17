// Medicine follow-up: meal-aware dose check-ins for the patient and a
// follow-up summary for the doctor. Prototype: data stays in this browser.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_strings.dart';
import '../report_workspace.dart' show ReportPalette, heading, serifStyle;
import 'med_engine.dart';
import 'meds_checkin.dart';
import 'meds_doctor.dart';
import 'meds_widgets.dart';

class MedsPage extends StatefulWidget {
  const MedsPage(
      {super.key, required this.language, this.now, this.load, this.store});
  final String language;

  /// Browser storage is injected so this widget also runs in VM tests.
  final String? Function()? load;
  final void Function(String value)? store;

  /// Injected clock for tests.
  final DateTime Function()? now;

  @override
  State<MedsPage> createState() => _MedsPageState();
}

class _MedsPageState extends State<MedsPage> {
  late MedState _state;
  bool _doctorView = false;
  bool _noticeOpen = false;
  Timer? _tick;

  DateTime get _now => widget.now?.call() ?? DateTime.now();
  String _t(String s, [Map<String, Object?> v = const {}]) =>
      AppStrings(widget.language).t(s, v);

  @override
  void initState() {
    super.initState();
    String? raw;
    try {
      raw = widget.load?.call();
    } catch (_) {}
    _state = MedState.decode(raw);
    // A demo is always shown as of today, so it never goes stale. Demos saved
    // before the demo flag existed are recognised by their sample prescriber.
    final legacyDemo = _state.medicines.isNotEmpty &&
        _state.medicines.every((m) => m.prescribedBy == 'Sample doctor');
    if (_state.demo || legacyDemo) {
      _state = sampleMedState(_now);
      if (legacyDemo) {
        try {
          widget.store?.call(_state.encode());
        } catch (_) {}
      }
    }
    // Re-evaluate due/missed doses while the page is open.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _save(MedState next) {
    setState(() => _state = next);
    try {
      widget.store?.call(next.encode());
    } catch (_) {/* Works for this visit if storage is blocked. */}
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth >= 900;
        return SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 24 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _doctorView ? 1120 : 720),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _modeSwitch(),
                    const SizedBox(height: 16),
                    if (_state.demo) ...[
                      _demoBanner(),
                      const SizedBox(height: 12),
                    ],
                    _previewNotice(),
                    const SizedBox(height: 20),
                    if (_state.medicines.isEmpty)
                      _empty()
                    else if (_doctorView)
                      _doctor(wide)
                    else
                      _today(),
                  ]),
            ),
          ),
        );
      });

  Widget _modeSwitch() => LayoutBuilder(builder: (context, box) {
        final title = heading(
            _t(_doctorView ? 'Doctor follow-up' : 'My medicines'),
            serifStyle(30));
        final toggle = SegmentedButton<bool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
              selectedBackgroundColor: ReportPalette.rose,
              selectedForegroundColor: ReportPalette.burgundy,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          segments: [
            ButtonSegment(value: false, label: Text(_t('Patient'))),
            ButtonSegment(value: true, label: Text(_t('Doctor'))),
          ],
          selected: {_doctorView},
          onSelectionChanged: (s) => setState(() => _doctorView = s.first),
        );
        return box.maxWidth < 460
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                title,
                const SizedBox(height: 12),
                toggle,
              ])
            : Row(children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                toggle,
              ]);
      });

  /// Both limits that matter stay visible; the rest sits one tap away.
  Widget _previewNotice() => Material(
        color: ReportPalette.warnBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: ReportPalette.warnBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _noticeOpen = !_noticeOpen),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.science_outlined,
                            size: 20, color: ReportPalette.highInk)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            _t('Preview · saved only in this browser; reminders work only while this page is open.'),
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5A2E04)))),
                    Icon(
                        _noticeOpen
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: ReportPalette.highInk),
                  ]),
                  if (_noticeOpen)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(30, 8, 24, 0),
                        child: Text(
                            _t('Preview feature. Medicines and check-ins are stored only in this browser, reminders appear only while this page is open, and the doctor view shows this browser’s data. Timing rules must come from a doctor.'),
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Color(0xFF5A2E04)))),
                ]),
          ),
        ),
      );

  // ---------------------------------------------------------------- patient

  Widget _empty() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        medCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          heading(_t('No medicines yet'), serifStyle(24)),
          const SizedBox(height: 8),
          Text(
              _t('Add the medicines your doctor prescribed, with their timing and food instructions.'),
              style: const TextStyle(
                  fontSize: 16, height: 1.55, color: ReportPalette.body)),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: _addMedicine,
              icon: const Icon(Icons.add_rounded),
              label: Text(_t('Add a medicine'))),
        ])),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ReportPalette.blush, ReportPalette.rose]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ReportPalette.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.play_circle_outline_rounded,
                  color: ReportPalette.burgundy, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  heading(_t('Want to see how it works?'),
                      const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                      _t('The demo uses a made-up patient with three medicines and three weeks of check-ins. It starts fresh each time and never mixes with a real plan.'),
                      style: const TextStyle(
                          fontSize: 15, height: 1.55, color: ReportPalette.body)),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                      onPressed: () => _save(sampleMedState(_now)),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(_t('See a demo'))),
                ])),
          ]),
        ),
      ]);

  /// Always visible while the demo is on, with a one-tap way out.
  Widget _demoBanner() => Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          decoration: BoxDecoration(
              color: ReportPalette.lowBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ReportPalette.lowInk.withValues(alpha: 0.35))),
          child: Row(children: [
            const Icon(Icons.play_circle_outline_rounded,
                color: ReportPalette.lowInk, size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_t('Demo plan · made-up patient, not real data'),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ReportPalette.lowInk))),
            TextButton(
                onPressed: () => _save(MedState()),
                style: TextButton.styleFrom(
                    foregroundColor: ReportPalette.lowInk),
                child: Text(_t('Exit demo'))),
          ]),
        ),
      );


  // ---------------------------------------------------------------- patient

  /// Parts of the day a patient thinks in, each anchored to a meal.
  static const _parts = [
    ('Morning', Icons.wb_twilight_rounded, 0, 12 * 60),
    ('Afternoon', Icons.wb_sunny_outlined, 12 * 60, 17 * 60),
    ('Evening', Icons.nights_stay_outlined, 17 * 60, 21 * 60 + 30),
    ('Night', Icons.bedtime_outlined, 21 * 60 + 30, 24 * 60),
  ];

  Widget _today() {
    final now = _now;
    final doses = dosesForDay(_state.medicines, _state.logs, now);
    final open = doses.where((d) => d.statusAt(now) == DoseStatus.due).toList();
    final due = open
        .where((d) => !d.remindAt.isAfter(now.add(const Duration(minutes: 30))))
        .toList();
    final done = doses
        .where((d) => !{DoseStatus.due, DoseStatus.noReply}
            .contains(d.statusAt(now)))
        .length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _summary(doses.length, done, due.isEmpty ? null : due.first,
          open.isEmpty ? null : open.first),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
            child: heading(_t('Today'),
                const TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
        Text(MaterialLocalizations.of(context).formatMediumDate(now),
            style: const TextStyle(fontSize: 14, color: ReportPalette.muted)),
      ]),
      const SizedBox(height: 10),
      for (final part in _parts)
        if (doses.any((d) => _inPart(d, part)))
          _partSection(part, [for (final d in doses) if (_inPart(d, part)) d],
              now),
      const SizedBox(height: 8),
      medCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: heading(_t('This week'),
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 4),
        Text(_t('Each square is one day. Tap a dose above to update it.'),
            style: const TextStyle(fontSize: 13.5, color: ReportPalette.muted)),
        const SizedBox(height: 14),
        _weekGrid(now),
      ])),
      const SizedBox(height: 16),
      _planCard(),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        OutlinedButton.icon(
            onPressed: _addReading,
            icon: const Icon(Icons.monitor_heart_outlined),
            label: Text(_t('Add blood pressure'))),
        OutlinedButton.icon(
            onPressed: _addMedicine,
            icon: const Icon(Icons.add_rounded),
            label: Text(_t('Add a medicine'))),
        TextButton.icon(
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_outline_rounded),
            style: TextButton.styleFrom(foregroundColor: ReportPalette.burgundy),
            label: Text(_t('Clear medicines'))),
      ]),
    ]);
  }

  bool _inPart(ScheduledDose d,
      (String, IconData, int, int) part) {
    final minutes = d.scheduled.hour * 60 + d.scheduled.minute;
    return minutes >= part.$3 && minutes < part.$4;
  }

  /// Progress for the day and the one thing to do next.
  Widget _summary(int total, int done, ScheduledDose? due, ScheduledDose? next) {
    final ring = SizedBox(
      width: 64,
      height: 64,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
              value: total == 0 ? 0 : done / total,
              strokeWidth: 6,
              backgroundColor: const Color(0x33FFFFFF),
              color: Colors.white,
              strokeCap: StrokeCap.round),
        ),
        Text('$done/$total',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
    final String title, body;
    if (due != null) {
      title = _t('Time for {name}', {'name': due.medicine.name});
      body = [
        due.medicine.dose,
        _ruleLabel(due.medicine, due.scheduled),
      ].where((s) => s.isNotEmpty).join(' · ');
    } else if (next != null) {
      title = _t('Next: {name} at {time}',
          {'name': next.medicine.name, 'time': clock(next.remindAt)});
      body = _ruleLabel(next.medicine, next.scheduled);
    } else {
      title = total == 0 ? _t('No doses today') : _t('All done for today');
      body = _t('{done} of {total} doses checked in',
          {'done': done, 'total': total});
    }
    return Semantics(
      container: true,
      liveRegion: due != null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ReportPalette.burgundy, ReportPalette.burgundyDark]),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x338B1A1A), blurRadius: 24, offset: Offset(0, 10))
            ],
            borderRadius: BorderRadius.circular(20)),
        child: LayoutBuilder(builder: (context, box) {
          final text = Row(children: [
            Semantics(
                label: _t('{done} of {total} doses checked in today',
                    {'done': done, 'total': total}),
                child: ExcludeSemantics(child: ring)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(
                          fontSize: 14, height: 1.4, color: Color(0xFFF7E3E0))),
                ])),
          ]);
          if (due == null) return text;
          final button = _checkInButton(due,
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ReportPalette.burgundy,
                  minimumSize: const Size(120, 48)));
          return box.maxWidth < 440
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [text, const SizedBox(height: 16), button])
              : Row(children: [
                  Expanded(child: text),
                  const SizedBox(width: 12),
                  button
                ]);
        }),
      ),
    );
  }

  Widget _partSection((String, IconData, int, int) part,
          List<ScheduledDose> doses, DateTime now) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(children: [
              Icon(part.$2, size: 18, color: ReportPalette.muted),
              const SizedBox(width: 8),
              Text(_t(part.$1).toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12.5,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w700,
                      color: ReportPalette.muted)),
            ]),
          ),
          for (final d in doses)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _doseCard(d, now)),
        ]),
      );

  /// A button that tells a screen reader which medicine it is for.
  Widget _checkInButton(ScheduledDose dose,
          {ButtonStyle? style, String? label}) =>
      Semantics(
        button: true,
        excludeSemantics: true,
        label: _t('Check in for {name} at {time}',
            {'name': dose.medicine.name, 'time': clock(dose.scheduled)}),
        onTap: () => _checkIn(dose),
        child: FilledButton(
            style: style,
            onPressed: () => _checkIn(dose),
            child: Text(label ?? _t('Check in'))),
      );

  String _mealWord(Meal meal) => switch (meal) {
        Meal.breakfast => _t('breakfast'),
        Meal.lunch => _t('lunch'),
        Meal.dinner => _t('dinner'),
        Meal.none => _t('your meal'),
      };

  /// The food instruction for one dose, named by its meal.
  String _ruleLabel(Medicine m, DateTime at) {
    final meal = _mealWord(mealAt(m, at));
    return switch (m.mealRule) {
      MealRule.beforeFood => _t('Before {meal} · empty stomach, eat {min} min later',
          {'meal': meal, 'min': m.gapMinutes}),
      MealRule.afterFood => _t('After {meal}', {'meal': meal}),
      MealRule.withFood => _t('With {meal}', {'meal': meal}),
      MealRule.any => _t('Any time, same time daily'),
    };
  }

  String _foodWord(String? timing) => switch (timing) {
        'before' => _t('before food'),
        'with' => _t('with food'),
        'after' => _t('after food'),
        _ => '',
      };

  Widget _doseCard(ScheduledDose dose, DateTime now) {
    final m = dose.medicine;
    final status = dose.statusAt(now);
    final log = dose.log;
    final outcome = outcomeOf(dose, _state.logs, now);
    final open = status == DoseStatus.due;
    final soon = open &&
        !dose.remindAt.isAfter(now.add(const Duration(minutes: 30)));

    // What happened, in the patient's words.
    String? result;
    var resultInk = ReportPalette.sage;
    IconData resultIcon = Icons.check_circle_rounded;
    if (status == DoseStatus.taken && log != null) {
      final off = minutesOff(log, planned: dose.scheduled) ?? 0;
      result = [
        _t('Taken at {time}', {'time': clock(log.at ?? dose.scheduled)}),
        if (off.abs() > onTimeWindowMinutes)
          off > 0
              ? _t('{min} min late', {'min': off})
              : _t('{min} min early', {'min': -off}),
        if (m.mealSensitive && log.foodAnswer != null) _foodWord(log.foodAnswer),
      ].join(' · ');
      if (outcome == DoseOutcome.wrongFood) {
        resultInk = ReportPalette.highInk;
        resultIcon = Icons.restaurant_rounded;
        result = '$result · ${_t('not as prescribed')}';
      } else if (outcome == DoseOutcome.offTime) {
        resultInk = ReportPalette.lowInk;
        resultIcon = Icons.schedule_rounded;
      }
    } else if (status == DoseStatus.moved && log?.movedTo != null) {
      result = _t('Moved to {time} by your doctor’s plan',
          {'time': clock(log!.movedTo!)});
      resultInk = ReportPalette.lowInk;
      resultIcon = Icons.bedtime_outlined;
    } else if (status == DoseStatus.skipped) {
      result = _t('Skipped, as your doctor’s plan says');
      resultInk = ReportPalette.body;
      resultIcon = Icons.remove_circle_outline_rounded;
    } else if (status == DoseStatus.missed) {
      result = _t('Not taken');
      resultInk = ReportPalette.burgundy;
      resultIcon = Icons.cancel_outlined;
    } else if (status == DoseStatus.noReply) {
      result = _t('No reply yet — did you take it?');
      resultInk = ReportPalette.body;
      resultIcon = Icons.help_outline_rounded;
    } else if (log?.status == DoseStatus.snoozed) {
      result = _t('Reminder at {time}', {'time': clock(dose.remindAt)});
      resultInk = ReportPalette.lowInk;
      resultIcon = Icons.notifications_active_outlined;
    }

    final Widget? action = open
        ? (soon
            ? _checkInButton(dose)
            : Semantics(
                button: true,
                excludeSemantics: true,
                label: _t('Check in for {name} at {time}',
                    {'name': m.name, 'time': clock(dose.scheduled)}),
                onTap: () => _checkIn(dose),
                child: OutlinedButton(
                    onPressed: () => _checkIn(dose),
                    child: Text(_t('Check in early')))))
        : status == DoseStatus.noReply || status == DoseStatus.missed
            ? TextButton(
                onPressed: () => _checkIn(dose),
                child: Text(_t('Update')))
            : null;

    final highlight = soon
        ? ReportPalette.burgundy
        : status == DoseStatus.noReply
            ? ReportPalette.controlBorder
            : ReportPalette.border;
    final body = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Text(clock(dose.scheduled),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: soon ? ReportPalette.burgundy : ReportPalette.ink)),
        if (dose.movedFrom != null)
          Text(_t('was {time}', {'time': clock(dose.movedFrom!)}),
              style: const TextStyle(fontSize: 11.5, color: ReportPalette.muted)),
      ]),
      const SizedBox(width: 14),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.name,
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
        if (m.dose.isNotEmpty)
          Text(m.dose,
              style: const TextStyle(fontSize: 14, color: ReportPalette.body)),
        const SizedBox(height: 8),
        medChip(
            m.mealRule == MealRule.beforeFood
                ? Icons.no_meals_rounded
                : m.mealSensitive
                    ? Icons.restaurant_rounded
                    : Icons.schedule_rounded,
            _ruleLabel(m, dose.scheduled),
            m.mealSensitive ? ReportPalette.rose : ReportPalette.sand,
            m.mealSensitive ? ReportPalette.burgundy : ReportPalette.body),
        if (result != null) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(resultIcon, size: 18, color: resultInk),
            const SizedBox(width: 6),
            Expanded(
                child: Text(result,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: resultInk))),
          ]),
        ],
      ])),
    ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
      decoration: BoxDecoration(
          color: status == DoseStatus.taken ? const Color(0xFFFCFDFB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: soon ? ReportPalette.cardShadow : null,
          border: Border.all(color: highlight, width: soon ? 1.6 : 1)),
      child: LayoutBuilder(
          builder: (context, box) => action == null
              ? body
              : box.maxWidth < 440
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          body,
                          const SizedBox(height: 12),
                          Padding(
                              padding: const EdgeInsets.only(left: 58),
                              child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: action)),
                        ])
                  : Row(children: [
                      Expanded(child: body),
                      const SizedBox(width: 10),
                      action,
                    ])),
    );
  }

  /// What the doctor prescribed, in one place.
  Widget _planCard() => medCard(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading(_t('My plan'),
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(_t('As your doctor prescribed. Only your doctor changes it.'),
            style: const TextStyle(fontSize: 13.5, color: ReportPalette.muted)),
        const SizedBox(height: 10),
        for (var i = 0; i < _state.medicines.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          Builder(builder: (context) {
            final m = _state.medicines[i];
            final low = m.supply != null &&
                m.times.isNotEmpty &&
                m.supply! <= m.times.length * 3;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        [m.name, if (m.dose.isNotEmpty) m.dose].join(' · '),
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in m.times)
                        medChip(
                            Icons.schedule_rounded,
                            '${clockMinutes(t)} · ${_ruleLabel(m, DateTime(2000, 1, 1, t ~/ 60, t % 60))}',
                            ReportPalette.sand,
                            ReportPalette.ink),
                      if (m.supply != null)
                        medChip(
                            Icons.inventory_2_outlined,
                            low
                                ? _t('{count} left — ask for a refill',
                                    {'count': m.supply})
                                : _t('{count} tablets left',
                                    {'count': m.supply}),
                            low ? ReportPalette.highBg : ReportPalette.sand,
                            low ? ReportPalette.highInk : ReportPalette.body),
                    ]),
                    if (m.mealRule == MealRule.beforeFood &&
                        m.ateFirstRule != AteFirstRule.askDoctor) ...[
                      const SizedBox(height: 8),
                      Text(
                          _t('If you have already eaten: {rule}', {
                            'rule': switch (m.ateFirstRule) {
                              AteFirstRule.moveToBedtime =>
                                _t('take it at bedtime instead'),
                              AteFirstRule.skip => _t('skip that dose'),
                              _ => _t('take it anyway'),
                            }
                          }),
                          style: const TextStyle(
                              fontSize: 13.5, color: ReportPalette.body)),
                    ],
                  ]),
            );
          }),
        ],
      ]));

  Widget _weekGrid(DateTime now) {
    final days = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    final loc = MaterialLocalizations.of(context);
    const weekday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const legend = [
      DoseOutcome.asPrescribed,
      DoseOutcome.offTime,
      DoseOutcome.wrongFood,
      DoseOutcome.notTaken,
      DoseOutcome.noReply,
      DoseOutcome.open,
    ];
    return Column(children: [
      ExcludeSemantics(
        child: Row(children: [
          const SizedBox(width: 104),
          for (final d in days)
            Expanded(
                child: Center(
                    child: Text(weekday[d.weekday - 1],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: d.day == now.day
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: d.day == now.day
                                ? ReportPalette.ink
                                : ReportPalette.muted)))),
        ]),
      ),
      const SizedBox(height: 6),
      for (final m in _state.medicines)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(
                width: 104,
                child: Text(m.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: ReportPalette.body))),
            for (final d in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Builder(builder: (context) {
                    final o = dayOutcome(m, _state.logs, d, now);
                    return Semantics(
                      container: true,
                      label: o == null
                          ? null
                          : _t('{name}, {day}: {status}', {
                              'name': m.name,
                              'day': loc.formatFullDate(d),
                              'status': _t(outcomeStyle(o).label)
                            }),
                      child: ExcludeSemantics(child: outcomeCell(o)),
                    );
                  }),
                ),
              ),
          ]),
        ),
      const SizedBox(height: 10),
      ExcludeSemantics(
        child: Wrap(spacing: 14, runSpacing: 8, children: [
          for (final o in legend)
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 18, child: outcomeCell(o, size: 18)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(_t(outcomeStyle(o).label),
                    style: const TextStyle(
                        fontSize: 12.5, color: ReportPalette.muted)),
              ),
            ]),
        ]),
      ),
    ]);
  }

  // ------------------------------------------------------------- check-in

  /// Each answer is saved as soon as it is given.
  void _checkIn(ScheduledDose dose) => showCheckIn(context,
          dose: dose, language: widget.language, now: () => _now,
          onSave: (log) {
        if (!mounted) return;
        DoseStatus? previous;
        for (final l in _state.logs) {
          if (l.key == log.key) previous = l.status;
        }
        var next = _state.record(log);
        final m = dose.medicine;
        // One tablet used, counted once per dose however many answers follow.
        if (log.status == DoseStatus.taken &&
            previous != DoseStatus.taken &&
            m.supply != null &&
            m.supply! > 0) {
          next = next.withMedicines([
            for (final x in next.medicines)
              x.id == m.id ? x.copyWith(supply: x.supply! - 1) : x
          ]);
        }
        _save(next);
      });


  // ------------------------------------------------------------- dialogs

  Future<void> _addReading() async {
    final sys = TextEditingController(), dia = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                  title: Text(_t('Add blood pressure')),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: sys,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                            labelText: _t('Systolic (top number)'),
                            errorText: error)),
                    const SizedBox(height: 8),
                    TextField(
                        controller: dia,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: _t('Diastolic (bottom number)'))),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(_t('Cancel'))),
                    FilledButton(
                        onPressed: () {
                          final value = double.tryParse(sys.text.trim());
                          if (value == null || value <= 50 || value >= 260) {
                            setLocal(() => error =
                                _t('Enter a number between 50 and 260.'));
                            return;
                          }
                          Navigator.pop(context, true);
                        },
                        child: Text(_t('Save'))),
                  ],
                )));
    final s = double.tryParse(sys.text.trim()), d = double.tryParse(dia.text.trim());
    if (ok == true && s != null && s > 50 && s < 260) {
      _save(_state.addReading(Reading(kind: 'bp', at: _now, value: s, value2: d)));
    }
  }

  Future<void> _addMedicine() async {
    final medicine = await showDialog<Medicine>(
        context: context,
        builder: (_) => _AddMedicineDialog(language: widget.language));
    if (medicine != null) {
      _save(_state.withMedicines([..._state.medicines, medicine]));
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(_t('Clear medicines?')),
              content: Text(_t('This removes the medicine plan, check-ins and readings from this browser.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(_t('Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(_t('Clear'))),
              ],
            ));
    if (ok == true) _save(MedState());
  }

  // ---------------------------------------------------------------- doctor

  Widget _doctor(bool wide) =>
      DoctorFollowUp(state: _state, now: _now, wide: wide);
}

// ------------------------------------------------------- add medicine dialog

class _AddMedicineDialog extends StatefulWidget {
  const _AddMedicineDialog({required this.language});
  final String language;
  @override
  State<_AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<_AddMedicineDialog> {
  final _name = TextEditingController(), _dose = TextEditingController();
  final _supply = TextEditingController();
  final _times = <TimeOfDay>[const TimeOfDay(hour: 8, minute: 0)];
  MealRule _rule = MealRule.any;
  Meal _meal = Meal.breakfast;
  AteFirstRule _ateFirst = AteFirstRule.askDoctor;
  int _gap = 30;
  String? _nameError;

  String _t(String s, [Map<String, Object?> v = const {}]) =>
      AppStrings(widget.language).t(s, v);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_t('Add a medicine')),
        content: SizedBox(
          width: math.min(440, MediaQuery.sizeOf(context).width - 112),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_t('Enter exactly what your doctor prescribed.'),
                  style: const TextStyle(fontSize: 13, color: ReportPalette.muted)),
              TextField(
                  controller: _name,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                  decoration: InputDecoration(
                      labelText: _t('Medicine name'), errorText: _nameError)),
              TextField(controller: _dose, decoration: InputDecoration(labelText: _t('Dose (for example 500 mg, 1 tablet)'))),
              const SizedBox(height: 12),
              Text(_t('Times'), style: const TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing: 8, children: [
                for (var i = 0; i < _times.length; i++)
                  InputChip(
                      label: Text(_times[i].format(context)),
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: _times[i]);
                        if (t != null) setState(() => _times[i] = t);
                      },
                      onDeleted: _times.length > 1 ? () => setState(() => _times.removeAt(i)) : null),
                ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(_t('Add time')),
                    onPressed: () => setState(() => _times.add(const TimeOfDay(hour: 21, minute: 0)))),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<MealRule>(
                  isExpanded: true,
                  value: _rule,
                  decoration: InputDecoration(labelText: _t('Food instruction')),
                  items: [
                    DropdownMenuItem(value: MealRule.any, child: Text(_t('No food instruction'))),
                    DropdownMenuItem(value: MealRule.beforeFood, child: Text(_t('Before food (empty stomach)'))),
                    DropdownMenuItem(value: MealRule.afterFood, child: Text(_t('After food'))),
                    DropdownMenuItem(value: MealRule.withFood, child: Text(_t('With food'))),
                  ],
                  onChanged: (v) => setState(() => _rule = v ?? MealRule.any)),
              if (_rule != MealRule.any)
                DropdownButtonFormField<Meal>(
                    isExpanded: true,
                    value: _meal,
                    decoration: InputDecoration(labelText: _t('Which meal')),
                    items: [
                      DropdownMenuItem(value: Meal.breakfast, child: Text(_t('Breakfast'))),
                      DropdownMenuItem(value: Meal.lunch, child: Text(_t('Lunch'))),
                      DropdownMenuItem(value: Meal.dinner, child: Text(_t('Dinner'))),
                    ],
                    onChanged: (v) => setState(() => _meal = v ?? Meal.breakfast)),
              if (_rule == MealRule.beforeFood) ...[
                DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _gap,
                    decoration: InputDecoration(labelText: _t('Minutes before eating')),
                    items: [for (final m in [15, 30, 45, 60]) DropdownMenuItem(value: m, child: Text('$m'))],
                    onChanged: (v) => setState(() => _gap = v ?? 30)),
                DropdownButtonFormField<AteFirstRule>(
                    isExpanded: true,
                    value: _ateFirst,
                    decoration: InputDecoration(labelText: _t('If already eaten (doctor’s rule)')),
                    items: [
                      DropdownMenuItem(value: AteFirstRule.askDoctor, child: Text(_t('Ask the doctor'))),
                      DropdownMenuItem(value: AteFirstRule.moveToBedtime, child: Text(_t('Take at bedtime instead'))),
                      DropdownMenuItem(value: AteFirstRule.skip, child: Text(_t('Skip this dose'))),
                      DropdownMenuItem(value: AteFirstRule.takeNow, child: Text(_t('Take it anyway'))),
                    ],
                    onChanged: (v) => setState(() => _ateFirst = v ?? AteFirstRule.askDoctor)),
              ],
              TextField(
                  controller: _supply,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _t('Tablets left (optional)'))),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('Cancel'))),
          FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                if (name.isEmpty) {
                  setState(() => _nameError = _t('Enter the medicine name.'));
                  return;
                }
                Navigator.pop(
                    context,
                    Medicine(
                        id: '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        dose: _dose.text.trim(),
                        times: (_times.map((t) => t.hour * 60 + t.minute).toSet().toList()..sort()),
                        meal: _rule == MealRule.any ? Meal.none : _meal,
                        mealRule: _rule,
                        gapMinutes: _gap,
                        ateFirstRule: _ateFirst,
                        supply: int.tryParse(_supply.text.trim()),
                        start: DateTime.now()));
              },
              child: Text(_t('Save'))),
        ],
      );
}
