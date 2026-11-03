/// Medicine plan, meal-aware dose check-ins and adherence summaries.
///
/// Pure Dart (no Flutter or browser APIs) so the rules are unit-tested.
/// The app never invents timing rules: every rule here is entered or approved
/// by a clinician, and the engine only applies it.
library;

import 'dart:convert';

enum MealRule {
  /// No food requirement.
  any,

  /// Take on an empty stomach, [Medicine.gapMinutes] before eating.
  beforeFood,

  /// Take after eating.
  afterFood,

  /// Take with a meal.
  withFood,
}

/// What to do when a before-food dose is due but the patient has already eaten.
enum AteFirstRule {
  /// Skip this dose and wait for the next scheduled one.
  skip,

  /// Move this dose to bedtime (for example thyroxine), never doubling it.
  moveToBedtime,

  /// Take it now anyway.
  takeNow,

  /// Ask the doctor; the app records the question.
  askDoctor,
}

enum DoseStatus { due, taken, missed, skipped, moved, snoozed }

enum Meal { breakfast, lunch, dinner, none }

class Medicine {
  Medicine({
    required this.id,
    required this.name,
    required this.dose,
    required this.times,
    this.meal = Meal.none,
    this.mealRule = MealRule.any,
    this.gapMinutes = 30,
    this.ateFirstRule = AteFirstRule.askDoctor,
    this.supply,
    this.note = '',
    this.prescribedBy = '',
    this.start,
  });

  /// First day of the plan; earlier days are never counted as missed.
  final DateTime? start;

  final String id, name, dose, note, prescribedBy;

  /// Minutes after midnight for each daily dose.
  final List<int> times;
  final Meal meal;
  final MealRule mealRule;
  final int gapMinutes;
  final AteFirstRule ateFirstRule;

  /// Tablets left, if the patient tracks supply.
  final int? supply;

  bool get mealSensitive => mealRule != MealRule.any;

  Medicine copyWith({int? supply}) => Medicine(
      id: id,
      name: name,
      dose: dose,
      times: times,
      meal: meal,
      mealRule: mealRule,
      gapMinutes: gapMinutes,
      ateFirstRule: ateFirstRule,
      supply: supply ?? this.supply,
      note: note,
      prescribedBy: prescribedBy,
      start: start);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'times': times,
        'meal': meal.name,
        'mealRule': mealRule.name,
        'gapMinutes': gapMinutes,
        'ateFirstRule': ateFirstRule.name,
        'supply': supply,
        'note': note,
        'prescribedBy': prescribedBy,
        'start': start?.toIso8601String(),
      };

  static Medicine fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'] as String,
        name: j['name'] as String,
        dose: j['dose'] as String? ?? '',
        times: (j['times'] as List).map((e) => (e as num).toInt()).toList(),
        meal: Meal.values.byName(j['meal'] as String? ?? 'none'),
        mealRule: MealRule.values.byName(j['mealRule'] as String? ?? 'any'),
        gapMinutes: (j['gapMinutes'] as num?)?.toInt() ?? 30,
        ateFirstRule:
            AteFirstRule.values.byName(j['ateFirstRule'] as String? ?? 'askDoctor'),
        supply: (j['supply'] as num?)?.toInt(),
        note: j['note'] as String? ?? '',
        prescribedBy: j['prescribedBy'] as String? ?? '',
        start: j['start'] == null ? null : DateTime.parse(j['start'] as String),
      );
}

/// One scheduled dose and what happened to it.
class DoseLog {
  DoseLog({
    required this.medicineId,
    required this.scheduled,
    required this.status,
    this.at,
    this.reason,
    this.feeling,
    this.ateBefore,
    this.movedTo,
  });

  final String medicineId;
  final DateTime scheduled;
  final DoseStatus status;
  final DateTime? at;
  final String? reason, feeling;

  /// The patient's answer to "Have you eaten yet?", when it was asked.
  final bool? ateBefore;
  final DateTime? movedTo;

  String get key => doseKey(medicineId, scheduled);

  Map<String, dynamic> toJson() => {
        'medicineId': medicineId,
        'scheduled': scheduled.toIso8601String(),
        'status': status.name,
        'at': at?.toIso8601String(),
        'reason': reason,
        'feeling': feeling,
        'ateBefore': ateBefore,
        'movedTo': movedTo?.toIso8601String(),
      };

  static DoseLog fromJson(Map<String, dynamic> j) => DoseLog(
        medicineId: j['medicineId'] as String,
        scheduled: DateTime.parse(j['scheduled'] as String),
        status: DoseStatus.values.byName(j['status'] as String),
        at: j['at'] == null ? null : DateTime.parse(j['at'] as String),
        reason: j['reason'] as String?,
        feeling: j['feeling'] as String?,
        ateBefore: j['ateBefore'] as bool?,
        movedTo: j['movedTo'] == null ? null : DateTime.parse(j['movedTo'] as String),
      );
}

/// A home measurement such as blood pressure or blood sugar.
class Reading {
  Reading({required this.kind, required this.at, required this.value, this.value2});
  final String kind; // 'bp' (value=systolic, value2=diastolic) or 'glucose'
  final DateTime at;
  final double value;
  final double? value2;

  Map<String, dynamic> toJson() =>
      {'kind': kind, 'at': at.toIso8601String(), 'value': value, 'value2': value2};
  static Reading fromJson(Map<String, dynamic> j) => Reading(
      kind: j['kind'] as String,
      at: DateTime.parse(j['at'] as String),
      value: (j['value'] as num).toDouble(),
      value2: (j['value2'] as num?)?.toDouble());
}

String doseKey(String medicineId, DateTime scheduled) =>
    '$medicineId@${scheduled.toIso8601String()}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// A dose as shown on the patient's day list.
class ScheduledDose {
  ScheduledDose(this.medicine, this.scheduled, this.log);
  final Medicine medicine;
  final DateTime scheduled;
  final DoseLog? log;

  DoseStatus statusAt(DateTime now, {int graceMinutes = 120}) {
    if (log != null && log!.status != DoseStatus.snoozed) return log!.status;
    if (now.isAfter(scheduled.add(Duration(minutes: graceMinutes)))) {
      return DoseStatus.missed;
    }
    return DoseStatus.due;
  }
}

List<ScheduledDose> dosesForDay(
    List<Medicine> medicines, List<DoseLog> logs, DateTime day) {
  final byKey = {for (final log in logs) log.key: log};
  final start = _day(day);
  final doses = <ScheduledDose>[
    for (final m in medicines)
      if (m.start == null || !start.isBefore(_day(m.start!)))
      for (final t in m.times)
        ScheduledDose(m, start.add(Duration(minutes: t)),
            byKey[doseKey(m.id, start.add(Duration(minutes: t)))]),
  ];
  doses.sort((a, b) => a.scheduled.compareTo(b.scheduled));
  return doses;
}

/// The first question to ask before a dose, or null to ask "taken?" directly.
enum CheckInQuestion { haveYouEaten, takenIt }

CheckInQuestion firstQuestion(Medicine m) =>
    m.mealRule == MealRule.beforeFood ||
            m.mealRule == MealRule.afterFood ||
            m.mealRule == MealRule.withFood
        ? CheckInQuestion.haveYouEaten
        : CheckInQuestion.takenIt;

/// What the app tells the patient after the meal question.
enum CheckInAdvice {
  /// Take the dose now.
  takeNow,

  /// Take now, then wait [Medicine.gapMinutes] before eating.
  takeNowThenWait,

  /// Eat first, then take it (after-food or with-food medicines).
  eatFirst,

  /// Already eaten; follow the doctor's [AteFirstRule].
  followAteFirstRule,
}

CheckInAdvice adviceAfterMealAnswer(Medicine m, {required bool hasEaten}) {
  switch (m.mealRule) {
    case MealRule.any:
      return CheckInAdvice.takeNow;
    case MealRule.beforeFood:
      return hasEaten
          ? CheckInAdvice.followAteFirstRule
          : CheckInAdvice.takeNowThenWait;
    case MealRule.afterFood:
    case MealRule.withFood:
      return hasEaten ? CheckInAdvice.takeNow : CheckInAdvice.eatFirst;
  }
}

/// Bedtime used when a dose is moved; the doctor can change it per plan.
DateTime bedtimeFor(DateTime day, {int minutes = 22 * 60}) =>
    _day(day).add(Duration(minutes: minutes));

/// Adherence for one medicine or all medicines over a window, counting only
/// doses whose time has passed. Moved doses that were later taken count as
/// taken; skipped-by-rule doses are excluded from the denominator.
class Adherence {
  Adherence(this.taken, this.missed, this.skipped, this.reasons);
  final int taken, missed, skipped;
  final Map<String, int> reasons;
  int get counted => taken + missed;
  double? get rate => counted == 0 ? null : taken / counted;
  int? get percent => rate == null ? null : (rate! * 100).round();
}

Adherence adherence(List<Medicine> medicines, List<DoseLog> logs, DateTime from,
    DateTime to, DateTime now,
    {String? medicineId}) {
  var taken = 0, missed = 0, skipped = 0;
  final reasons = <String, int>{};
  final meds = medicines.where((m) => medicineId == null || m.id == medicineId);
  for (var d = _day(from); !d.isAfter(_day(to)); d = d.add(const Duration(days: 1))) {
    for (final dose in dosesForDay(meds.toList(), logs, d)) {
      if (dose.scheduled.isAfter(now)) continue;
      final status = dose.statusAt(now);
      final log = dose.log;
      if (status == DoseStatus.taken) {
        taken++;
      } else if (status == DoseStatus.skipped) {
        skipped++;
      } else if (status == DoseStatus.moved) {
        // A moved dose is judged by the follow-up log at its new time.
        final follow = logs.where((l) =>
            l.medicineId == dose.medicine.id &&
            l.movedTo == null &&
            log?.movedTo != null &&
            l.scheduled == log!.movedTo);
        if (follow.any((l) => l.status == DoseStatus.taken)) {
          taken++;
        } else if (log?.movedTo != null && now.isAfter(log!.movedTo!.add(const Duration(hours: 2)))) {
          missed++;
        }
      } else if (status == DoseStatus.missed) {
        missed++;
      }
      if (log?.reason != null && status != DoseStatus.taken) {
        reasons[log!.reason!] = (reasons[log.reason!] ?? 0) + 1;
      }
    }
  }
  return Adherence(taken, missed, skipped, reasons);
}

/// Something for the doctor to look at. The app only lines patterns up;
/// whether one causes the other is the clinician's judgement.
class FollowUpSignal {
  FollowUpSignal(this.priority, this.message);
  final int priority;
  final String message;
}

List<FollowUpSignal> followUpSignals(List<Medicine> medicines, List<DoseLog> logs,
    List<Reading> readings, DateTime now,
    {double bpTarget = 140, int alertPercent = 80}) {
  final signals = <FollowUpSignal>[];
  final recentFrom = now.subtract(const Duration(days: 14));
  final earlierFrom = now.subtract(const Duration(days: 28));
  final recent = adherence(medicines, logs, recentFrom, now, now);
  final earlier = adherence(medicines, logs, earlierFrom,
      recentFrom.subtract(const Duration(days: 1)), now);
  if (recent.percent != null && recent.percent! < alertPercent) {
    signals.add(FollowUpSignal(2,
        'Doses confirmed in the last 14 days: ${recent.percent}%${earlier.percent == null ? '' : ' (previous 14 days: ${earlier.percent}%)'}'));
  }
  double? avg(Iterable<Reading> r) =>
      r.isEmpty ? null : r.map((e) => e.value).reduce((a, b) => a + b) / r.length;
  final bp = readings.where((r) => r.kind == 'bp');
  final bpRecent = avg(bp.where((r) => r.at.isAfter(now.subtract(const Duration(days: 7)))));
  final bpBefore = avg(bp.where((r) =>
      r.at.isAfter(now.subtract(const Duration(days: 21))) &&
      !r.at.isAfter(now.subtract(const Duration(days: 7)))));
  if (bpRecent != null && bpRecent >= bpTarget) {
    final missedRecent = recent.missed;
    signals.add(FollowUpSignal(
        missedRecent > 0 ? 3 : 1,
        'Home systolic BP averaging ${bpRecent.round()} this week'
        '${bpBefore == null ? '' : ' (was ${bpBefore.round()})'}'
        '${missedRecent > 0 ? ' alongside $missedRecent missed doses' : ''}'));
  }
  final reasons = recent.reasons;
  if ((reasons['ran_out'] ?? 0) > 0) {
    signals.add(FollowUpSignal(2, 'Patient reported running out of tablets ${reasons['ran_out']} time(s)'));
  }
  if ((reasons['unwell'] ?? 0) > 0) {
    signals.add(FollowUpSignal(2, 'Patient reported feeling unwell after a dose ${reasons['unwell']} time(s)'));
  }
  for (final m in medicines) {
    if (m.supply != null && m.times.isNotEmpty && m.supply! <= m.times.length * 3) {
      signals.add(FollowUpSignal(1, '${m.name}: ${m.supply} tablets left'));
    }
  }
  signals.sort((a, b) => b.priority.compareTo(a.priority));
  return signals;
}

/// Serialises the whole follow-up state for browser storage.
class MedState {
  MedState({List<Medicine>? medicines, List<DoseLog>? logs, List<Reading>? readings})
      : medicines = medicines ?? [],
        logs = logs ?? [],
        readings = readings ?? [];
  final List<Medicine> medicines;
  final List<DoseLog> logs;
  final List<Reading> readings;

  String encode() => jsonEncode({
        'version': 1,
        'medicines': medicines.map((m) => m.toJson()).toList(),
        'logs': logs.map((l) => l.toJson()).toList(),
        'readings': readings.map((r) => r.toJson()).toList(),
      });

  static MedState decode(String? raw) {
    if (raw == null || raw.isEmpty) return MedState();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return MedState(
        medicines: [for (final m in j['medicines'] as List) Medicine.fromJson(Map<String, dynamic>.from(m as Map))],
        logs: [for (final l in j['logs'] as List) DoseLog.fromJson(Map<String, dynamic>.from(l as Map))],
        readings: [for (final r in (j['readings'] as List? ?? [])) Reading.fromJson(Map<String, dynamic>.from(r as Map))],
      );
    } catch (_) {
      return MedState();
    }
  }

  /// Records a log, replacing any earlier entry for the same dose.
  MedState record(DoseLog log) => MedState(
      medicines: medicines,
      logs: [...logs.where((l) => l.key != log.key), log],
      readings: readings);

  MedState withMedicines(List<Medicine> next) =>
      MedState(medicines: next, logs: logs, readings: readings);

  MedState addReading(Reading r) =>
      MedState(medicines: medicines, logs: logs, readings: [...readings, r]);
}

/// A clearly labelled sample plan so the flow can be tried without real data.
MedState sampleMedState(DateTime now) {
  final meds = [
    Medicine(
        id: 'thyroxine',
        name: 'Thyroxine',
        dose: '50 mcg · 1 tablet',
        times: [7 * 60 + 30],
        meal: Meal.breakfast,
        mealRule: MealRule.beforeFood,
        gapMinutes: 30,
        ateFirstRule: AteFirstRule.moveToBedtime,
        supply: 40,
        prescribedBy: 'Sample doctor',
        start: _day(now).subtract(const Duration(days: 21))),
    Medicine(
        id: 'metformin',
        name: 'Metformin',
        dose: '500 mg · 1 tablet',
        times: [8 * 60 + 45, 21 * 60],
        meal: Meal.breakfast,
        mealRule: MealRule.afterFood,
        supply: 6,
        prescribedBy: 'Sample doctor',
        start: _day(now).subtract(const Duration(days: 21))),
    Medicine(
        id: 'amlodipine',
        name: 'Amlodipine',
        dose: '5 mg · 1 tablet',
        times: [21 * 60],
        mealRule: MealRule.any,
        supply: 20,
        prescribedBy: 'Sample doctor',
        start: _day(now).subtract(const Duration(days: 21))),
  ];
  var state = MedState(medicines: meds);
  final today = _day(now);
  // 21 days of history with a deterioration pattern in the last 10 days.
  for (var back = 21; back >= 1; back--) {
    final day = today.subtract(Duration(days: back));
    for (final dose in dosesForDay(meds, const [], day)) {
      final late = back <= 10;
      final miss = late &&
          ((dose.medicine.id == 'amlodipine' && back % 2 == 0) ||
              (dose.medicine.id == 'metformin' && dose.scheduled.hour >= 20 && back % 3 == 0));
      state = state.record(DoseLog(
          medicineId: dose.medicine.id,
          scheduled: dose.scheduled,
          status: miss ? DoseStatus.missed : DoseStatus.taken,
          at: miss ? null : dose.scheduled.add(const Duration(minutes: 10)),
          reason: miss ? (dose.medicine.id == 'amlodipine' ? 'ran_out' : 'forgot') : null,
          ateBefore: dose.medicine.mealSensitive ? dose.medicine.mealRule != MealRule.beforeFood : null));
    }
    final systolic = back > 10 ? 132 + (back % 4) : 140 + (10 - back) * 1.2;
    state = state.addReading(Reading(
        kind: 'bp',
        at: day.add(const Duration(hours: 8)),
        value: systolic.toDouble(),
        value2: systolic * 0.62));
  }
  return state;
}
