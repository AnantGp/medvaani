// The patient's dose check-in: one question per screen, saved as it goes.
//
// What a doctor needs from each dose: was it taken, when, and how it sat
// with food; if not, why. Every answer is stored the moment it is given, so
// closing the sheet early never loses a confirmed dose.
import 'package:flutter/material.dart';

import '../app_strings.dart';
import '../report_workspace.dart' show ReportPalette, serifStyle;
import 'med_engine.dart';
import 'meds_widgets.dart';

Future<void> showCheckIn(BuildContext context,
        {required ScheduledDose dose,
        required String language,
        required DateTime Function() now,
        required void Function(DoseLog log) onSave}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ReportPalette.ground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => CheckInSheet(
          dose: dose, language: language, now: now, onSave: onSave),
    );

enum _Step { ask, when, food, feel, done, meal, advice, reason }

class CheckInSheet extends StatefulWidget {
  const CheckInSheet(
      {super.key,
      required this.dose,
      required this.language,
      required this.now,
      required this.onSave});
  final ScheduledDose dose;
  final String language;
  final DateTime Function() now;

  /// Called after every answer with the dose's record so far.
  final void Function(DoseLog log) onSave;

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  _Step _step = _Step.ask;
  bool? _ate;
  DoseLog? _log;

  Medicine get _m => widget.dose.medicine;
  String _t(String s, [Map<String, Object?> v = const {}]) =>
      AppStrings(widget.language).t(s, v);

  void _save(DoseLog log) {
    _log = log;
    widget.onSave(log);
  }

  DoseLog _new(DoseStatus status,
          {String? reason,
          DateTime? movedTo,
          String? mealTiming,
          DateTime? snoozedUntil}) =>
      DoseLog(
          medicineId: _m.id,
          scheduled: widget.dose.scheduled,
          status: status,
          at: status == DoseStatus.taken ? widget.now() : null,
          reason: reason,
          ateBefore: _ate,
          movedTo: movedTo,
          mealTiming: mealTiming,
          snoozedUntil: snoozedUntil);

  void _close() => Navigator.pop(context);

  String get _mealName => switch (mealAt(_m, widget.dose.scheduled)) {
        Meal.lunch => _t('lunch'),
        Meal.dinner => _t('dinner'),
        Meal.breakfast => _t('breakfast'),
        Meal.none => _t('your meal'),
      };

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 16),
                ...switch (_step) {
                  _Step.ask => _askStep(),
                  _Step.when => _whenStep(),
                  _Step.food => _foodStep(),
                  _Step.feel => _feelStep(),
                  _Step.done => _doneStep(),
                  _Step.meal => _mealStep(),
                  _Step.advice => _adviceStep(),
                  _Step.reason => _reasonStep(),
                },
              ]),
        ),
      );

  /// Which medicine this is about, and how far through the questions we are.
  Widget _header() {
    const order = [_Step.ask, _Step.when, _Step.food, _Step.feel, _Step.done];
    final steps = [
      for (final s in order)
        if (s != _Step.food || _m.mealSensitive) s
    ];
    final at = steps.indexOf(_step);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
              color: ReportPalette.rose, shape: BoxShape.circle),
          child: const Icon(Icons.medication_rounded,
              color: ReportPalette.burgundy, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(_m.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Text(
                  [
                    if (_m.dose.isNotEmpty) _m.dose,
                    _t('planned for {time}',
                        {'time': clock(widget.dose.scheduled)}),
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 13.5, color: ReportPalette.muted)),
            ])),
      ]),
      if (at >= 0) ...[
        const SizedBox(height: 14),
        ExcludeSemantics(
          child: Row(children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  decoration: BoxDecoration(
                      color: i <= at
                          ? ReportPalette.burgundy
                          : ReportPalette.strongBorder,
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
          ]),
        ),
      ],
    ]);
  }

  /// Each step's question is announced when it appears.
  Widget _title(String text, [double size = 25]) => Semantics(
      header: true,
      liveRegion: true,
      child: Text(text, style: serifStyle(size, height: 1.2)));

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 15, height: 1.5, color: ReportPalette.body)),
      );

  /// A full-width answer with an icon, large enough for an unsteady thumb.
  Widget _answer(String label, IconData icon, VoidCallback onPressed,
      {bool primary = false, String? detail}) {
    final content = Row(children: [
      Icon(icon, size: 22),
      const SizedBox(width: 12),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (detail != null)
              Text(detail,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: primary
                          ? const Color(0xFFE3F0E8)
                          : ReportPalette.muted)),
          ])),
    ]);
    const padding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: primary
          ? FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: ReportPalette.sage,
                  minimumSize: const Size.fromHeight(60),
                  padding: padding,
                  shape: shape),
              onPressed: onPressed,
              child: content)
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: ReportPalette.ink,
                  backgroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(60),
                  padding: padding,
                  shape: shape),
              onPressed: onPressed,
              child: content),
    );
  }

  // ------------------------------------------------------------ taken path

  List<Widget> _askStep() => [
        _title(_t('Did you take your {name}?', {'name': _m.name})),
        const SizedBox(height: 18),
        _answer(_t('Yes, I took it'), Icons.check_circle_outline_rounded, () {
          _save(_new(DoseStatus.taken));
          setState(() => _step = _Step.when);
        }, primary: true),
        _answer(
            _t('Not yet'),
            Icons.hourglass_empty_rounded,
            () => setState(
                () => _step = _m.mealSensitive ? _Step.meal : _Step.advice)),
        _answer(_t('I am not taking this dose'), Icons.block_rounded,
            () => setState(() => _step = _Step.reason)),
      ];

  void _afterWhen() => setState(() => _step =
      _m.mealSensitive && _log?.mealTiming == null ? _Step.food : _Step.feel);

  List<Widget> _whenStep() {
    final now = widget.now();
    final planned = widget.dose.scheduled;
    return [
      _saved(_t('Saved as taken')),
      const SizedBox(height: 12),
      _title(_t('When did you take it?')),
      const SizedBox(height: 18),
      _answer(_t('Just now'), Icons.bolt_rounded, () {
        _save(_log!.copyWith(at: now));
        _afterWhen();
      }, detail: clock(now)),
      if (!planned.isAfter(now))
        _answer(_t('At the planned time'), Icons.schedule_rounded, () {
          _save(_log!.copyWith(at: planned));
          _afterWhen();
        }, detail: clock(planned)),
      _answer(_t('At another time'), Icons.edit_calendar_outlined, () async {
        final picked = await showTimePicker(
            context: context, initialTime: TimeOfDay.fromDateTime(now));
        if (picked == null || !mounted) return;
        _save(_log!.copyWith(
            at: DateTime(
                now.year, now.month, now.day, picked.hour, picked.minute)));
        _afterWhen();
      }),
    ];
  }

  List<Widget> _foodStep() {
    void choose(String timing) {
      _save(_log!.copyWith(mealTiming: timing));
      setState(() => _step = _Step.feel);
    }

    return [
      _title(_t('Was that before or after {meal}?', {'meal': _mealName})),
      _hint(_t('Your doctor set a food instruction for this medicine.')),
      const SizedBox(height: 16),
      _answer(_t('Before eating'), Icons.no_meals_rounded,
          () => choose('before'),
          detail: _t('On an empty stomach')),
      _answer(_t('With the meal'), Icons.restaurant_rounded,
          () => choose('with')),
      _answer(_t('After eating'), Icons.dinner_dining_rounded,
          () => choose('after')),
    ];
  }

  List<Widget> _feelStep() {
    const feelings = [
      'Fine',
      'Tired',
      'Dizzy or shaky',
      'Sick or stomach upset',
      'Something else'
    ];
    return [
      _title(_t('How are you feeling?')),
      _hint(_t(
          'Shared with your doctor so they can see how this medicine suits you.')),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final f in feelings)
          ChoiceChip(
              label: Text(_t(f)),
              selected: _log?.feeling == f,
              selectedColor: ReportPalette.rose,
              onSelected: (_) {
                _save(_log!.copyWith(feeling: f));
                setState(() {});
              }),
      ]),
      const SizedBox(height: 18),
      FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: () => setState(() => _step = _Step.done),
          child: Text(_t(_log?.feeling == null ? 'Skip' : 'Done'))),
    ];
  }

  List<Widget> _doneStep() {
    final log = _log!;
    final off = minutesOff(log, planned: widget.dose.scheduled) ?? 0;
    final followed = foodAsPrescribed(_m, log);
    final timing = off.abs() <= onTimeWindowMinutes
        ? _t('on time')
        : off > 0
            ? _t('{min} min late', {'min': off})
            : _t('{min} min early', {'min': -off});
    Widget line(IconData icon, String text, {bool warn = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon,
                size: 20,
                color: warn ? ReportPalette.highInk : ReportPalette.sage),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 15.5, height: 1.4))),
          ]),
        );
    return [
      _title(_t('All saved for your doctor')),
      const SizedBox(height: 16),
      medCard(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            line(
                Icons.schedule_rounded,
                _t('Taken at {time} · {timing}',
                    {'time': clock(log.at ?? widget.now()), 'timing': timing}),
                warn: off.abs() > onTimeWindowMinutes),
            if (followed != null)
              line(
                  Icons.restaurant_rounded,
                  followed
                      ? _t('Food: as your doctor asked')
                      : _t('Food: not as your doctor asked'),
                  warn: !followed),
            if (log.feeling != null)
              line(Icons.sentiment_satisfied_outlined,
                  _t('Feeling: {feeling}', {'feeling': _t(log.feeling!)}),
                  warn: log.feeling != 'Fine'),
          ]),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6)),
      if (followed == false) ...[
        const SizedBox(height: 12),
        _notice(_t(
            'Do not take an extra dose to make up for it. Your doctor will see this and can advise you.')),
      ],
      const SizedBox(height: 18),
      FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: _close,
          child: Text(_t('Close'))),
    ];
  }

  Widget _saved(String text) => Row(children: [
        const Icon(Icons.check_circle_rounded,
            color: ReportPalette.sage, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: ReportPalette.sage))),
      ]);

  Widget _notice(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: ReportPalette.warnBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ReportPalette.warnBorder)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 15.5, height: 1.5, color: ReportPalette.body)),
      );

  // ---------------------------------------------------------- not-yet path

  List<Widget> _mealStep() => [
        _title(_t('Have you had {meal} yet?', {'meal': _mealName})),
        const SizedBox(height: 18),
        _answer(_t('No, not yet'), Icons.no_meals_rounded, () {
          setState(() {
            _ate = false;
            _step = _Step.advice;
          });
        }),
        _answer(_t('Yes, I have eaten'), Icons.restaurant_rounded, () {
          setState(() {
            _ate = true;
            _step = _Step.advice;
          });
        }),
      ];

  /// "Remind me later" is a real reminder: the dose stays open until then.
  Widget _remind() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(_t('Remind me in'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final minutes in const [15, 30, 60])
                OutlinedButton(
                    onPressed: () {
                      _save(_new(DoseStatus.snoozed,
                          snoozedUntil: widget
                              .now()
                              .add(Duration(minutes: minutes))));
                      _close();
                    },
                    child: Text(minutes == 60
                        ? _t('1 hour')
                        : _t('{min} min', {'min': minutes}))),
            ]),
          ]);

  void _takenNow(String? mealTiming) {
    _save(_new(DoseStatus.taken, mealTiming: mealTiming));
    setState(() => _step = _Step.feel);
  }

  List<Widget> _adviceStep() {
    final advice = _ate == null
        ? CheckInAdvice.takeNow
        : adviceAfterMealAnswer(_m, hasEaten: _ate!);
    if (advice == CheckInAdvice.followAteFirstRule) {
      final (String body, String action, IconData icon, VoidCallback act) =
          switch (_m.ateFirstRule) {
        AteFirstRule.moveToBedtime => (
            'Your doctor’s plan: take it at bedtime instead, at least 2 hours after dinner. Do not take two doses.',
            'Remind me at bedtime',
            Icons.bedtime_outlined,
            () {
              _save(_new(DoseStatus.moved,
                  movedTo: bedtimeFor(widget.dose.scheduled)));
              _close();
            }
          ),
        AteFirstRule.skip => (
            'Your doctor’s plan: skip this dose and take the next one at its usual time. Do not take two doses.',
            'Skip this dose',
            Icons.skip_next_rounded,
            () {
              _save(_new(DoseStatus.skipped, reason: 'ate_first'));
              _close();
            }
          ),
        AteFirstRule.takeNow => (
            'Your doctor’s plan: take it now anyway.',
            'I have taken it now',
            Icons.check_circle_outline_rounded,
            () => _takenNow('after')
          ),
        AteFirstRule.askDoctor => (
            'Your doctor has not set a plan for this. Do not take an extra dose; ask your doctor or pharmacist.',
            'Note it for my doctor',
            Icons.edit_note_rounded,
            () {
              _save(_new(DoseStatus.missed, reason: 'ate_first'));
              _close();
            }
          ),
      };
      return [
        _title(_t('This medicine works best on an empty stomach.'), 24),
        const SizedBox(height: 12),
        _notice(_t(body)),
        const SizedBox(height: 16),
        _answer(_t(action), icon, act, primary: true),
        Text(
            _t('Medivaanii only follows the instructions your doctor set. It never changes a dose.'),
            style: const TextStyle(fontSize: 13, color: ReportPalette.muted)),
      ];
    }
    final title = switch (advice) {
      CheckInAdvice.takeNowThenWait => _t('Good timing. Take it now.'),
      CheckInAdvice.eatFirst => _t('Have your meal first, then take it.'),
      _ => _t('Time to take it.'),
    };
    final body = switch (advice) {
      CheckInAdvice.takeNowThenWait =>
        _t('Then wait about {min} minutes before eating.', {'min': _m.gapMinutes}),
      CheckInAdvice.eatFirst => _t('Check in again after you have eaten.'),
      _ => '',
    };
    final timing = switch (advice) {
      CheckInAdvice.takeNowThenWait => 'before',
      CheckInAdvice.takeNow => _ate == null ? null : 'after',
      _ => null,
    };
    return [
      _title(title),
      if (body.isNotEmpty) _hint(body),
      const SizedBox(height: 18),
      if (advice != CheckInAdvice.eatFirst)
        _answer(_t('I have taken it now'), Icons.check_circle_outline_rounded,
            () => _takenNow(timing),
            primary: true),
      _remind(),
    ];
  }

  // ------------------------------------------------------------- skip path

  List<Widget> _reasonStep() {
    const reasons = {
      'forgot': ('I forgot until it was too late', Icons.history_toggle_off_rounded),
      'ran_out': ('I have run out of tablets', Icons.inventory_2_outlined),
      'unwell': ('It makes me feel unwell', Icons.sick_outlined),
      'away': ('I am away from home', Icons.luggage_outlined),
      'no_meal': ('I am fasting or missed the meal', Icons.no_meals_rounded),
      'other': ('Something else', Icons.more_horiz_rounded),
    };
    return [
      _title(_t('That’s okay. What’s the reason?'), 24),
      _hint(_t('Your answer helps your doctor, not to blame you.')),
      const SizedBox(height: 14),
      for (final e in reasons.entries)
        _answer(_t(e.value.$1), e.value.$2, () {
          _save(_new(DoseStatus.missed, reason: e.key));
          _close();
        }),
    ];
  }
}
