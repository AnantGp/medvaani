// Medicine follow-up: meal-aware dose check-ins for the patient and a
// follow-up summary for the doctor. Prototype: data stays in this browser.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_strings.dart';
import '../report_workspace.dart' show ReportPalette, serifStyle;
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
              constraints: BoxConstraints(maxWidth: _doctorView ? 1240 : 720),
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

  Widget _modeSwitch() => Row(children: [
        Expanded(
            child: Text(_t(_doctorView ? 'Doctor follow-up' : 'My medicines'),
                style: serifStyle(30))),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
              selectedBackgroundColor: ReportPalette.rose,
              selectedForegroundColor: ReportPalette.burgundy,
              backgroundColor: Colors.white),
          segments: [
            ButtonSegment(value: false, label: Text(_t('Patient'))),
            ButtonSegment(value: true, label: Text(_t('Doctor'))),
          ],
          selected: {_doctorView},
          onSelectionChanged: (s) => setState(() => _doctorView = s.first),
        ),
      ]);

  Widget _previewNotice() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: ReportPalette.warnBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ReportPalette.warnBorder)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.science_outlined,
              size: 20, color: ReportPalette.highInk),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  _t('Preview feature. Medicines and check-ins are stored only in this browser, reminders appear only while this page is open, and the doctor view shows this browser’s data. Timing rules must come from a doctor.'),
                  style: const TextStyle(
                      fontSize: 14, height: 1.5, color: Color(0xFF5A2E04)))),
        ]),
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
        Text(_t('Today'), style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600)),
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
              child: Text(_t('This week'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600))),
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

  Widget _dueBanner(ScheduledDose dose) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: ReportPalette.burgundy,
            borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const Icon(Icons.notifications_active_outlined,
              color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_t('Time for {name}', {'name': dose.medicine.name}),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 2),
            Text(dose.medicine.dose,
                style: const TextStyle(fontSize: 14, color: Color(0xFFF7E3E0))),
          ])),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ReportPalette.burgundy),
              onPressed: () => _checkIn(dose),
              child: Text(_t('Check in'))),
        ]),
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
          child: Text(_t('Missed · update'),
              style: const TextStyle(color: ReportPalette.highInk))),
      _ => dose.scheduled.isAfter(now.add(const Duration(minutes: 30)))
          ? Text(_t('Later'),
              style: const TextStyle(fontSize: 14, color: ReportPalette.muted))
          : FilledButton(
              onPressed: () => _checkIn(dose), child: Text(_t('Check in'))),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        SizedBox(
            width: 56,
            child: Text(_time(dose.scheduled),
                style: const TextStyle(fontSize: 14, color: ReportPalette.muted))),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${dose.medicine.name} · ${dose.medicine.dose}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(_ruleLabel(dose.medicine),
              style: const TextStyle(fontSize: 13, color: ReportPalette.muted)),
        ])),
        const SizedBox(width: 8),
        trailing,
      ]),
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
    Color cell(Medicine m, DateTime day) {
      final doses = dosesForDay([m], _state.logs, day)
          .where((d) => !d.scheduled.isAfter(now))
          .toList();
      if (doses.isEmpty) return ReportPalette.sand;
      final statuses = doses.map((d) => d.statusAt(now)).toList();
      if (statuses.any((s) => s == DoseStatus.missed)) return Colors.white;
      if (statuses.every((s) => s == DoseStatus.due)) return ReportPalette.sand;
      return ReportPalette.sage;
    }

    Border? border(Color c) => c == Colors.white
        ? Border.all(color: const Color(0xFFB45309), width: 2)
        : null;
    const weekday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(children: [
      Row(children: [
        const SizedBox(width: 104),
        for (final d in days)
          Expanded(
              child: Center(
                  child: Text(weekday[d.weekday - 1],
                      style: const TextStyle(fontSize: 12, color: ReportPalette.muted)))),
      ]),
      const SizedBox(height: 6),
      for (final m in _state.medicines)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(
                width: 104,
                child: Text(m.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: ReportPalette.body))),
            for (final d in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                          color: cell(m, d),
                          border: border(cell(m, d)),
                          borderRadius: BorderRadius.circular(6))),
                ),
              ),
          ]),
        ),
      const SizedBox(height: 6),
      Wrap(spacing: 16, children: [
        _legend(ReportPalette.sage, null, _t('Taken')),
        _legend(Colors.white, const Color(0xFFB45309), _t('Missed')),
        _legend(ReportPalette.sand, null, _t('Upcoming')),
      ]),
    ]);
  }

  Widget _legend(Color fill, Color? stroke, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(3),
                border: stroke == null ? null : Border.all(color: stroke, width: 2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: ReportPalette.muted)),
      ]);

  // ------------------------------------------------------------- check-in

  Future<void> _checkIn(ScheduledDose dose) async {
    final log = await showModalBottomSheet<DoseLog>(
      context: context,
      isScrollControlled: true,
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
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(_t('Add blood pressure')),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: sys,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: _t('Systolic (top number)'))),
                TextField(
                    controller: dia,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: _t('Diastolic (bottom number)'))),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(_t('Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(_t('Save'))),
              ],
            ));
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
    Widget stat(String label, String value, String? note) => _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: ReportPalette.muted)),
              const SizedBox(height: 6),
              Text(value, style: serifStyle(32)),
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(note, style: const TextStyle(fontSize: 13, color: ReportPalette.highInk)),
              ],
            ]));
    final stats = [
      stat('Doses confirmed · 28 days', month.percent == null ? '—' : '${month.percent}%',
          '${month.missed} missed'),
      stat('Home BP · 7-day average', avgBp == null ? '—' : avgBp.round().toString(),
          avgBp != null && avgBp >= 140 ? 'Above 140 target' : null),
      stat('Medicines', '${_state.medicines.length}', null),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Sample data from this browser · self-reported check-ins',
          style: const TextStyle(fontSize: 14, color: ReportPalette.muted)),
      const SizedBox(height: 14),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Needs attention', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (signals.isEmpty)
          const Text('Nothing flagged in the last 14 days.',
              style: TextStyle(fontSize: 15, color: ReportPalette.body))
        else
          for (final s in signals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(s.priority >= 3 ? Icons.priority_high_rounded : Icons.info_outline_rounded,
                    size: 18,
                    color: s.priority >= 3 ? ReportPalette.burgundy : ReportPalette.highInk),
                const SizedBox(width: 8),
                Expanded(child: Text(s.message, style: const TextStyle(fontSize: 15, height: 1.45))),
              ]),
            ),
      ])),
      const SizedBox(height: 14),
      wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: stats[i]),
              ]
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in stats) Padding(padding: const EdgeInsets.only(bottom: 12), child: s)
            ]),
      const SizedBox(height: 14),
      if (bp.isNotEmpty)
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Doses and home blood pressure · 21 days',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
              height: 220,
              width: double.infinity,
              child: CustomPaint(
                  painter: _BpPainter(
                      readings: bp.where((r) => r.at.isAfter(now.subtract(const Duration(days: 22)))).toList(),
                      missedDays: _missedDays(now),
                      now: now))),
          const SizedBox(height: 8),
          const Text(
              'Bars below the line mark days with a missed dose. Shown together for review; any link between them is the clinician’s judgement.',
              style: TextStyle(fontSize: 13, height: 1.5, color: ReportPalette.muted)),
        ])),
      const SizedBox(height: 14),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('By medicine · 28 days', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (final m in _state.medicines) _medBar(m, now),
      ])),
      const SizedBox(height: 14),
      Text(
          'Check-ins are self-reported and can overstate doses actually taken; studies of phone-based dose reporting found it missed many non-adherent days. Confirm at the visit.',
          style: const TextStyle(fontSize: 13, height: 1.5, color: ReportPalette.muted)),
    ]);
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
              color: pct >= 90 ? ReportPalette.sage : const Color(0xFFB45309)),
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
          v == 140 ? (Paint()..color = const Color(0xFFB45309)..strokeWidth = 1) : grid);
      text.text = TextSpan(
          text: v.round().toString(),
          style: const TextStyle(fontSize: 11, color: ReportPalette.muted));
      text.layout();
      text.paint(canvas, Offset(0, y(v) - 7));
    }
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
              ..color = const Color(0xFFB45309)
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
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${_m.name} · ${_m.dose}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: ReportPalette.burgundy)),
              const SizedBox(height: 10),
              ...switch (_step) {
                _Step.meal => _mealStep(),
                _Step.advice => _adviceStep(),
                _Step.taken => _takenStep(),
                _Step.cant => _cantStep(),
              },
            ]),
      );

  List<Widget> _mealStep() {
    final question = switch (_m.meal) {
      Meal.lunch => 'Have you had lunch yet?',
      Meal.dinner => 'Have you had dinner yet?',
      _ => 'Have you had breakfast yet?',
    };
    return [
      Text(_t(question), style: serifStyle(26, height: 1.2)),
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
        Text(_t('This medicine works best on an empty stomach.'), style: serifStyle(24, height: 1.2)),
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
      Text(title, style: serifStyle(26, height: 1.2)),
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
      Text(_t('How are you feeling today?'), style: serifStyle(22)),
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
      Text(_t('That’s okay. What’s stopping you?'), style: serifStyle(24, height: 1.2)),
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

  String _t(String s, [Map<String, Object?> v = const {}]) =>
      AppStrings(widget.language).t(s, v);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_t('Add a medicine')),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_t('Enter exactly what your doctor prescribed.'),
                  style: const TextStyle(fontSize: 13, color: ReportPalette.muted)),
              TextField(controller: _name, decoration: InputDecoration(labelText: _t('Medicine name'))),
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
                if (name.isEmpty) return;
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
