// Medicine follow-up: meal-aware dose check-ins for the patient and a
// follow-up summary for the doctor. Prototype: data stays in this browser.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_strings.dart';
import '../report_workspace.dart' show ReportPalette, heading, serifStyle;
import 'med_engine.dart';

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

  Widget _empty() => _card(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_t('No medicines yet'), style: serifStyle(24)),
        const SizedBox(height: 8),
        Text(
            _t('Add the medicines your doctor prescribed, with their timing and food instructions, or try a sample plan to see how check-ins work.'),
            style: const TextStyle(
                fontSize: 16, height: 1.55, color: ReportPalette.body)),
        const SizedBox(height: 18),
        Wrap(spacing: 12, runSpacing: 12, children: [
          FilledButton.icon(
              onPressed: _addMedicine,
              icon: const Icon(Icons.add_rounded),
              label: Text(_t('Add a medicine'))),
          OutlinedButton.icon(
              onPressed: () => _save(sampleMedState(_now)),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(_t('Try a sample plan'))),
        ]),
      ]));

  Widget _today() {
    final now = _now;
    final doses = dosesForDay(_state.medicines, _state.logs, now);
    final due = doses
        .where((d) =>
            d.statusAt(now) == DoseStatus.due &&
            !d.scheduled.isAfter(now.add(const Duration(minutes: 30))))
        .toList();
    final week = adherence(_state.medicines, _state.logs,
        now.subtract(const Duration(days: 6)), now, now);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (due.isNotEmpty) ...[
        _dueBanner(due.first),
        const SizedBox(height: 16),
      ],
      _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        heading(_t('Today'),
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (var i = 0; i < doses.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _doseRow(doses[i], now),
        ],
      ])),
      const SizedBox(height: 16),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: heading(_t('This week'),
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          Text(
              week.percent == null
                  ? ''
                  : _t('{taken} of {total} doses',
                      {'taken': week.taken, 'total': week.counted}),
              style: const TextStyle(fontSize: 14, color: ReportPalette.muted)),
        ]),
        const SizedBox(height: 12),
        _weekGrid(now),
      ])),
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
      for (final m in _state.medicines)
        if (m.supply != null && m.times.isNotEmpty && m.supply! <= m.times.length * 3)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
                _t('{name}: {count} tablets left — ask for a refill soon.',
                    {'name': m.name, 'count': m.supply}),
                style: const TextStyle(fontSize: 14, color: ReportPalette.highInk)),
          ),
    ]);
  }

  Widget _dueBanner(ScheduledDose dose) => Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ReportPalette.burgundy, ReportPalette.burgundyDark]),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x338B1A1A),
                    blurRadius: 24,
                    offset: Offset(0, 10))
              ],
              borderRadius: BorderRadius.circular(18)),
          child: LayoutBuilder(builder: (context, box) {
            final text = Row(children: [
              const ExcludeSemantics(
                  child: Icon(Icons.notifications_active_outlined,
                      color: Colors.white, size: 26)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_t('Time for {name}', {'name': dose.medicine.name}),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(dose.medicine.dose,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFFF7E3E0))),
                  ])),
            ]);
            final button = _checkInButton(dose,
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ReportPalette.burgundy));
            return box.maxWidth < 380
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [text, const SizedBox(height: 14), button])
                : Row(children: [
                    Expanded(child: text),
                    const SizedBox(width: 12),
                    button
                  ]);
          }),
        ),
      );

  /// A button that tells a screen reader which medicine it is for.
  Widget _checkInButton(ScheduledDose dose, {ButtonStyle? style}) => Semantics(
        button: true,
        excludeSemantics: true,
        label: _t('Check in for {name} at {time}',
            {'name': dose.medicine.name, 'time': _time(dose.scheduled)}),
        onTap: () => _checkIn(dose),
        child: FilledButton(
            style: style,
            onPressed: () => _checkIn(dose),
            child: Text(_t('Check in'))),
      );

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _ruleLabel(Medicine m) => switch (m.mealRule) {
        MealRule.beforeFood => _t('Before food · wait {min} min to eat',
            {'min': m.gapMinutes}),
        MealRule.afterFood => _t('After food'),
        MealRule.withFood => _t('With food'),
        MealRule.any => _t('Any time, same time daily'),
      };

  Widget _doseRow(ScheduledDose dose, DateTime now) {
    final status = dose.statusAt(now);
    final (Widget trailing) = switch (status) {
      DoseStatus.taken => _chip(Icons.check_rounded, _t('Taken'),
          ReportPalette.sageLight, ReportPalette.sage),
      DoseStatus.moved => _chip(Icons.schedule_rounded, _t('Moved to bedtime'),
          ReportPalette.lowBg, ReportPalette.lowInk),
      DoseStatus.skipped => _chip(Icons.remove_rounded, _t('Skipped'),
          ReportPalette.sand, ReportPalette.muted),
      DoseStatus.missed => TextButton(
          onPressed: () => _checkIn(dose),
          style: TextButton.styleFrom(
                  foregroundColor: ReportPalette.highInk,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14))
              .copyWith(
                  side: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.focused)
                          ? const BorderSide(
                              color: ReportPalette.focusRing, width: 3)
                          : const BorderSide(color: ReportPalette.amber))),
          child: Text(_t('Missed · update'),
              style: const TextStyle(fontWeight: FontWeight.w600))),
      _ => dose.scheduled.isAfter(now.add(const Duration(minutes: 30)))
          ? Text(_t('Later'),
              style: const TextStyle(fontSize: 14, color: ReportPalette.muted))
          : _checkInButton(dose),
    };
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${dose.medicine.name} · ${dose.medicine.dose}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(_ruleLabel(dose.medicine),
          style: const TextStyle(fontSize: 13, color: ReportPalette.muted)),
    ]);
    final time = SizedBox(
        width: 56,
        child: Text(_time(dose.scheduled),
            style: const TextStyle(fontSize: 14, color: ReportPalette.muted)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
          builder: (context, box) => box.maxWidth < 420 && trailing is! Text
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        time,
                        Expanded(child: details),
                      ]),
                      const SizedBox(height: 10),
                      Padding(
                          padding: const EdgeInsets.only(left: 56),
                          child: Align(
                              alignment: Alignment.centerLeft, child: trailing)),
                    ])
              : Row(children: [
                  time,
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  trailing,
                ])),
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
        ]),
      );

  Widget _weekGrid(DateTime now) {
    final days = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    // Status is shown by fill, outline and a glyph, never by colour alone.
    ({Color fill, Color? stroke, IconData? icon, String? status}) cell(
        Medicine m, DateTime day) {
      final doses = dosesForDay([m], _state.logs, day)
          .where((d) => !d.scheduled.isAfter(now))
          .toList();
      if (doses.isEmpty) {
        return (fill: ReportPalette.sand, stroke: null, icon: null, status: null);
      }
      final statuses = doses.map((d) => d.statusAt(now)).toList();
      if (statuses.any((s) => s == DoseStatus.missed)) {
        return (
          fill: Colors.white,
          stroke: ReportPalette.amber,
          icon: Icons.close_rounded,
          status: 'Missed'
        );
      }
      if (statuses.every((s) => s == DoseStatus.due)) {
        return (
          fill: ReportPalette.sand,
          stroke: null,
          icon: null,
          status: 'Upcoming'
        );
      }
      return (
        fill: ReportPalette.sage,
        stroke: null,
        icon: Icons.check_rounded,
        status: 'Taken'
      );
    }

    final loc = MaterialLocalizations.of(context);
    const weekday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(children: [
      ExcludeSemantics(
        child: Row(children: [
          const SizedBox(width: 104),
          for (final d in days)
            Expanded(
                child: Center(
                    child: Text(weekday[d.weekday - 1],
                        style: const TextStyle(
                            fontSize: 12, color: ReportPalette.muted)))),
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
                    final c = cell(m, d);
                    return Semantics(
                      container: true,
                      label: c.status == null
                          ? null
                          : _t('{name}, {day}: {status}', {
                              'name': m.name,
                              'day': loc.formatFullDate(d),
                              'status': _t(c.status!)
                            }),
                      child: ExcludeSemantics(
                        child: Container(
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: c.fill,
                                border: c.stroke == null
                                    ? null
                                    : Border.all(color: c.stroke!, width: 2),
                                borderRadius: BorderRadius.circular(7)),
                            child: c.icon == null
                                ? null
                                : Icon(c.icon,
                                    size: 16,
                                    color: c.stroke ?? Colors.white)),
                      ),
                    );
                  }),
                ),
              ),
          ]),
        ),
      const SizedBox(height: 8),
      ExcludeSemantics(
        child: Wrap(spacing: 16, runSpacing: 6, children: [
          _legend(ReportPalette.sage, null, Icons.check_rounded, Colors.white,
              _t('Taken')),
          _legend(Colors.white, ReportPalette.amber, Icons.close_rounded,
              ReportPalette.amber, _t('Missed')),
          _legend(ReportPalette.sand, null, null, null, _t('Upcoming')),
        ]),
      ),
    ]);
  }

  Widget _legend(Color fill, Color? stroke, IconData? icon, Color? iconColor,
          String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(4),
                border: stroke == null ? null : Border.all(color: stroke, width: 1.6)),
            child: icon == null ? null : Icon(icon, size: 11, color: iconColor)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 13, color: ReportPalette.muted)),
      ]);

  // ------------------------------------------------------------- check-in

  Future<void> _checkIn(ScheduledDose dose) async {
    final log = await showModalBottomSheet<DoseLog>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ReportPalette.ground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CheckInSheet(
          dose: dose, language: widget.language, now: _now),
    );
    if (log == null || !mounted) return;
    var next = _state.record(log);
    if (log.status == DoseStatus.taken) {
      final m = dose.medicine;
      if (m.supply != null && m.supply! > 0) {
        next = next.withMedicines([
          for (final x in next.medicines) x.id == m.id ? x.copyWith(supply: m.supply! - 1) : x
        ]);
      }
    }
    if (log.status == DoseStatus.moved && log.movedTo != null) {
      // The moved dose becomes its own reminder at bedtime.
      next = next.withMedicines(next.medicines);
    }
    _save(next);
  }

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

  Widget _doctor(bool wide) {
    final now = _now;
    final signals =
        followUpSignals(_state.medicines, _state.logs, _state.readings, now);
    final month = adherence(_state.medicines, _state.logs,
        now.subtract(const Duration(days: 27)), now, now);
    final bp = _state.readings.where((r) => r.kind == 'bp').toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final recentBp = bp.where((r) => r.at.isAfter(now.subtract(const Duration(days: 7))));
    final avgBp = recentBp.isEmpty
        ? null
        : recentBp.map((r) => r.value).reduce((a, b) => a + b) / recentBp.length;
    Widget stat(IconData icon, String label, String value, String? note,
            {bool alert = false, IconData? noteIcon}) =>
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: ReportPalette.muted),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: ReportPalette.muted))),
          ]),
          const SizedBox(height: 8),
          Text(value, style: serifStyle(36)),
          const SizedBox(height: 6),
          if (note != null)
            Row(children: [
              Icon(noteIcon ?? (alert ? Icons.info_outline_rounded : Icons.check_rounded),
                  size: 16,
                  color: alert ? ReportPalette.highInk : ReportPalette.sage),
              const SizedBox(width: 4),
              Text(note,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: alert ? ReportPalette.highInk : ReportPalette.sage)),
            ])
          else
            const SizedBox(height: 16),
        ]));
    final stats = [
      stat(Icons.fact_check_outlined, 'Doses confirmed · 28 days',
          month.percent == null ? '—' : '${month.percent}%',
          '${month.missed} missed',
          alert: month.missed > 0, noteIcon: Icons.error_outline_rounded),
      stat(Icons.monitor_heart_outlined, 'Home BP · 7-day average',
          avgBp == null ? '—' : avgBp.round().toString(),
          avgBp != null && avgBp >= 140 ? 'Above 140 target' : null,
          alert: true, noteIcon: Icons.trending_up_rounded),
      stat(Icons.medication_outlined, 'Medicines', '${_state.medicines.length}', null),
    ];
    final bpWindow =
        bp.where((r) => r.at.isAfter(now.subtract(const Duration(days: 22)))).toList();
    final missedDays = _missedDays(now);
    final chartCard = bp.isEmpty
        ? null
        : _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            heading('Doses and home blood pressure · 21 days',
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Semantics(
              image: true,
              label: _bpSummary(bpWindow, missedDays),
              child: ExcludeSemantics(
                child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: CustomPaint(
                        painter: _BpPainter(
                            readings: bpWindow, missedDays: missedDays, now: now))),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
                'Bars below the line mark days with a missed dose. Shown together for review; any link between them is the clinician’s judgement.',
                style: TextStyle(fontSize: 13, height: 1.5, color: ReportPalette.muted)),
          ]));
    final byMedicine =
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      heading('By medicine · 28 days',
          const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      for (final m in _state.medicines) _medBar(m, now),
    ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Sample data from this browser · self-reported check-ins',
          style: const TextStyle(fontSize: 14, color: ReportPalette.muted)),
      const SizedBox(height: 14),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading('Needs attention',
            const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (signals.isEmpty)
          const Text('Nothing flagged in the last 14 days.',
              style: TextStyle(fontSize: 15, color: ReportPalette.body))
        else
          for (final s in signals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                Expanded(child: Text(s.message, style: const TextStyle(fontSize: 15, height: 1.45))),
              ]),
            ),
      ])),
      const SizedBox(height: 14),
      wide
          ? IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: stats[i]),
                ]
              ]),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in stats) Padding(padding: const EdgeInsets.only(bottom: 12), child: s)
            ]),
      const SizedBox(height: 14),
      if (wide && chartCard != null)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: chartCard),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: byMedicine),
        ])
      else ...[
        if (chartCard != null) ...[chartCard, const SizedBox(height: 14)],
        byMedicine,
      ],
      const SizedBox(height: 14),
      const Text(
          'Check-ins are self-reported and can overstate doses actually taken; studies of phone-based dose reporting found it missed many non-adherent days. Confirm at the visit.',
          style: TextStyle(fontSize: 13, height: 1.5, color: ReportPalette.muted)),
    ]);
  }

  /// Text alternative for the chart: what a sighted clinician reads off it.
  String _bpSummary(List<Reading> readings, Set<int> missedDays) {
    if (readings.isEmpty) return 'Home blood pressure chart: no readings yet.';
    final first = readings.first.value.round();
    final last = readings.last.value.round();
    return 'Home systolic blood pressure over the last 21 days: first reading '
        '$first, latest $last, ${readings.length} readings. '
        '${missedDays.length} days had a missed dose.';
  }

  Set<int> _missedDays(DateTime now) {
    final out = <int>{};
    for (var back = 0; back <= 21; back++) {
      final day = now.subtract(Duration(days: back));
      final doses = dosesForDay(_state.medicines, _state.logs, day);
      if (doses.any((d) => !d.scheduled.isAfter(now) && d.statusAt(now) == DoseStatus.missed)) {
        out.add(back);
      }
    }
    return out;
  }

  Widget _medBar(Medicine m, DateTime now) {
    final a = adherence(_state.medicines, _state.logs,
        now.subtract(const Duration(days: 27)), now, now, medicineId: m.id);
    final pct = a.percent ?? 0;
    final reasons = a.reasons.entries
        .map((e) => '${_reasonLabel(e.key)} ×${e.value}')
        .join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${m.name} · ${m.dose}', style: const TextStyle(fontSize: 15))),
          Text(a.percent == null ? '—' : '$pct%',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: ReportPalette.sand,
              color: pct >= 90 ? ReportPalette.sage : ReportPalette.amber),
        ),
        const SizedBox(height: 4),
        Text(
            '${a.missed} missed${reasons.isEmpty ? '' : ' · $reasons'}${m.mealSensitive ? ' · ${_ruleLabel(m)}' : ''}',
            style: const TextStyle(fontSize: 12, color: ReportPalette.muted)),
      ]),
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: ReportPalette.cardShadow,
            border: Border.all(color: ReportPalette.border)),
        child: child,
      );
}

String _reasonLabel(String key) => switch (key) {
      'ran_out' => 'ran out',
      'unwell' => 'felt unwell',
      'away' => 'away from home',
      'forgot' => 'forgot',
      _ => 'other',
    };

class _BpPainter extends CustomPainter {
  _BpPainter({required this.readings, required this.missedDays, required this.now});
  final List<Reading> readings;
  final Set<int> missedDays;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0, bottomStrip = 28.0;
    final chartH = size.height - bottomStrip - 12;
    const lo = 110.0, hi = 170.0;
    double y(double v) => 6 + (hi - v.clamp(lo, hi)) / (hi - lo) * chartH;
    double x(int back) => left + (21 - back) / 21 * (size.width - left - 8);
    final grid = Paint()..color = ReportPalette.border;
    final text = TextPainter(textDirection: TextDirection.ltr);
    for (final v in [120.0, 140.0, 160.0]) {
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)),
          v == 140 ? (Paint()..color = ReportPalette.amber..strokeWidth = 1) : grid);
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
    text.paint(canvas, Offset(size.width - text.width, y(140) - text.height - 2));
    final points = <Offset>[];
    for (final r in readings) {
      final back = now.difference(r.at).inHours / 24;
      points.add(Offset(left + (21 - back) / 21 * (size.width - left - 8), y(r.value)));
    }
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
          Rect.fromLTWH(x(back) - cellW / 2, stripY, cellW, 16), const Radius.circular(4));
      canvas.drawRRect(
          rect,
          Paint()
            ..color = missed ? Colors.white : ReportPalette.sage
            ..style = PaintingStyle.fill);
      if (missed) {
        canvas.drawRRect(
            rect,
            Paint()
              ..color = ReportPalette.amber
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BpPainter old) => true;
}

// ------------------------------------------------------------ check-in sheet

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet({required this.dose, required this.language, required this.now});
  final ScheduledDose dose;
  final String language;
  final DateTime now;

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

enum _Step { meal, advice, taken, cant }

class _CheckInSheetState extends State<_CheckInSheet> {
  late _Step _step = firstQuestion(widget.dose.medicine) == CheckInQuestion.haveYouEaten
      ? _Step.meal
      : _Step.advice;
  bool? _ate;
  String? _feeling;
  DoseLog? _pending;

  Medicine get _m => widget.dose.medicine;
  String _t(String s, [Map<String, Object?> v = const {}]) =>
      AppStrings(widget.language).t(s, v);

  DoseLog _log(DoseStatus status, {String? reason, DateTime? movedTo}) => DoseLog(
      medicineId: _m.id,
      scheduled: widget.dose.scheduled,
      status: status,
      at: status == DoseStatus.taken ? widget.now : null,
      reason: reason,
      feeling: _feeling,
      ateBefore: _ate,
      movedTo: movedTo);

  void _finish(DoseLog log) => Navigator.pop(context, log);

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${_m.name} · ${_m.dose}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ReportPalette.burgundy)),
                const SizedBox(height: 10),
                ...switch (_step) {
                  _Step.meal => _mealStep(),
                  _Step.advice => _adviceStep(),
                  _Step.taken => _takenStep(),
                  _Step.cant => _cantStep(),
                },
              ]),
        ),
      );

  /// Each step's question is announced when it appears.
  Widget _title(String text, double size) => Semantics(
      header: true,
      liveRegion: true,
      child: Text(text, style: serifStyle(size, height: 1.2)));

  List<Widget> _mealStep() {
    final question = switch (_m.meal) {
      Meal.lunch => 'Have you had lunch yet?',
      Meal.dinner => 'Have you had dinner yet?',
      _ => 'Have you had breakfast yet?',
    };
    return [
      _title(_t(question), 26),
      const SizedBox(height: 18),
      FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
          onPressed: () => setState(() {
                _ate = false;
                _step = _Step.advice;
              }),
          child: Text(_t('Not yet'))),
      const SizedBox(height: 10),
      OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
          onPressed: () => setState(() {
                _ate = true;
                _step = _Step.advice;
              }),
          child: Text(_t('Yes, I have eaten'))),
    ];
  }

  List<Widget> _adviceStep() {
    final advice = _ate == null
        ? CheckInAdvice.takeNow
        : adviceAfterMealAnswer(_m, hasEaten: _ate!);
    if (advice == CheckInAdvice.followAteFirstRule) {
      final (String body, String action, DoseLog Function() result) = switch (_m.ateFirstRule) {
        AteFirstRule.moveToBedtime => (
            'Your doctor’s plan: take it at bedtime instead, at least 2 hours after dinner. Do not take two doses.',
            'Remind me at bedtime',
            () => _log(DoseStatus.moved, movedTo: bedtimeFor(widget.now))),
        AteFirstRule.skip => (
            'Your doctor’s plan: skip this dose and take the next one at its usual time. Do not take two doses.',
            'Skip this dose',
            () => _log(DoseStatus.skipped, reason: 'ate_first')),
        AteFirstRule.takeNow => (
            'Your doctor’s plan: take it now anyway.',
            'I have taken it',
            () => _log(DoseStatus.taken)),
        AteFirstRule.askDoctor => (
            'Your doctor has not set a plan for this. Do not take an extra dose; ask your doctor or pharmacist.',
            'Note it for my doctor',
            () => _log(DoseStatus.missed, reason: 'ate_first')),
      };
      return [
        _title(_t('This medicine works best on an empty stomach.'), 24),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: ReportPalette.warnBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ReportPalette.warnBorder)),
          child: Text(_t(body),
              style: const TextStyle(fontSize: 16, height: 1.5, color: ReportPalette.body)),
        ),
        const SizedBox(height: 16),
        FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: () => _finish(result()),
            child: Text(_t(action))),
        const SizedBox(height: 8),
        Text(_t('Medivaanii only follows the instructions your doctor set. It never changes a dose.'),
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
    return [
      _title(title, 26),
      if (body.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(fontSize: 16, height: 1.5, color: ReportPalette.body)),
      ],
      const SizedBox(height: 18),
      if (advice != CheckInAdvice.eatFirst)
        FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                backgroundColor: ReportPalette.sage),
            onPressed: () => setState(() {
                  _pending = _log(DoseStatus.taken);
                  _step = _Step.taken;
                }),
            child: Text(_t('I have taken it'))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: () => _finish(_log(DoseStatus.snoozed)),
                child: Text(_t('Remind me later')))),
        const SizedBox(width: 10),
        Expanded(
            child: OutlinedButton(
                onPressed: () => setState(() => _step = _Step.cant),
                child: Text(_t('I can’t take it')))),
      ]),
    ];
  }

  List<Widget> _takenStep() {
    final feelings = ['Fine', 'Tired', 'Dizzy or shaky', 'Something else'];
    return [
      Row(children: [
        const Icon(Icons.check_circle_rounded, color: ReportPalette.sage),
        const SizedBox(width: 8),
        Text(_t('Logged'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 14),
      _title(_t('How are you feeling today?'), 22),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final f in feelings)
          ChoiceChip(
              label: Text(_t(f)),
              selected: _feeling == f,
              selectedColor: ReportPalette.rose,
              onSelected: (_) => setState(() => _feeling = f)),
      ]),
      const SizedBox(height: 16),
      FilledButton(
          onPressed: () => _finish(_log(DoseStatus.taken)),
          child: Text(_t(_feeling == null ? 'Skip' : 'Done'))),
      const SizedBox(height: 6),
      Text(_t('Shared with your doctor so they can see how this medicine suits you.'),
          style: const TextStyle(fontSize: 13, color: ReportPalette.muted)),
    ];
  }

  List<Widget> _cantStep() {
    final reasons = {
      'ran_out': 'I have run out of tablets',
      'unwell': 'It makes me feel unwell',
      'away': 'I am away from home',
      'other': 'Something else',
    };
    return [
      _title(_t('That’s okay. What’s stopping you?'), 24),
      const SizedBox(height: 6),
      Text(_t('Your answer helps your doctor, not to blame you.'),
          style: const TextStyle(fontSize: 14, color: ReportPalette.muted)),
      const SizedBox(height: 14),
      for (final e in reasons.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  alignment: Alignment.centerLeft),
              onPressed: () => _finish(_log(DoseStatus.missed, reason: e.key)),
              child: Text(_t(e.value))),
        ),
    ];
  }

  // Keep analyzer quiet about the pending log used for future undo.
  DoseLog? get pending => _pending;
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
                    value: _gap,
                    decoration: InputDecoration(labelText: _t('Minutes before eating')),
                    items: [for (final m in [15, 30, 45, 60]) DropdownMenuItem(value: m, child: Text('$m'))],
                    onChanged: (v) => setState(() => _gap = v ?? 30)),
                DropdownButtonFormField<AteFirstRule>(
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
