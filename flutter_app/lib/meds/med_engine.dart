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

/// `missed` means the patient said so; `noReply` means nobody answered, so
/// whether the dose was taken is unknown.
enum DoseStatus { due, taken, missed, skipped, moved, snoozed, noReply }

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
    this.mealTiming,
    this.snoozedUntil,
  });

  final String medicineId;
  final DateTime scheduled;
  final DoseStatus status;
  final DateTime? at;
  final String? reason, feeling;

  /// The patient's answer to "Have you eaten yet?", when it was asked.
  final bool? ateBefore;
  final DateTime? movedTo;

  /// When the patient took it relative to the meal: 'before', 'with' or
  /// 'after'. Asked after a dose is confirmed.
  final String? mealTiming;

  /// "Remind me later": the dose stays open until this time.
  final DateTime? snoozedUntil;

  /// The food answer, including check-ins saved before [mealTiming] existed.
  String? get foodAnswer =>
      mealTiming ?? (ateBefore == null ? null : (ateBefore! ? 'after' : 'before'));

  DoseLog copyWith(
          {DateTime? at, String? feeling, String? mealTiming, String? reason}) =>
      DoseLog(
          medicineId: medicineId,
          scheduled: scheduled,
          status: status,
          at: at ?? this.at,
          reason: reason ?? this.reason,
          feeling: feeling ?? this.feeling,
          ateBefore: ateBefore,
          movedTo: movedTo,
          mealTiming: mealTiming ?? this.mealTiming,
          snoozedUntil: snoozedUntil);

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
        if (mealTiming != null) 'mealTiming': mealTiming,
        if (snoozedUntil != null) 'snoozedUntil': snoozedUntil!.toIso8601String(),
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
        mealTiming: j['mealTiming'] as String?,
        snoozedUntil: j['snoozedUntil'] == null
            ? null
            : DateTime.parse(j['snoozedUntil'] as String),
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
  ScheduledDose(this.medicine, this.scheduled, this.log, {this.movedFrom});
  final Medicine medicine;
  final DateTime scheduled;
  final DoseLog? log;

  /// Set when this is a dose the doctor's rule moved here from an earlier time.
  final DateTime? movedFrom;

  /// When the reminder for this dose should next appear.
  DateTime get remindAt {
    final until = log?.status == DoseStatus.snoozed ? log!.snoozedUntil : null;
    return until != null && until.isAfter(scheduled) ? until : scheduled;
  }

  DoseStatus statusAt(DateTime now, {int graceMinutes = 120}) {
    if (log != null && log!.status != DoseStatus.snoozed) return log!.status;
    if (now.isAfter(remindAt.add(Duration(minutes: graceMinutes)))) {
      return DoseStatus.noReply;
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
  // A dose moved by the doctor's rule is a real dose at its new time.
  for (final log in logs) {
    final to = log.movedTo;
    if (log.status != DoseStatus.moved || to == null || _day(to) != start) {
      continue;
    }
    final owner = medicines.where((m) => m.id == log.medicineId);
    if (owner.isEmpty ||
        doses.any((d) => d.medicine.id == log.medicineId && d.scheduled == to)) {
      continue;
    }
    doses.add(ScheduledDose(owner.first, to, byKey[doseKey(log.medicineId, to)],
        movedFrom: log.scheduled));
  }
  doses.sort((a, b) => a.scheduled.compareTo(b.scheduled));
  return doses;
}

/// A dose counts as on time within this many minutes of its planned time.
const onTimeWindowMinutes = 60;

/// Minutes between the planned time and when the patient says they took it.
int? minutesOff(DoseLog log, {DateTime? planned}) =>
    log.status != DoseStatus.taken || log.at == null
        ? null
        : log.at!.difference(planned ?? log.scheduled).inMinutes;

/// Whether the food answer matches the doctor's instruction; null when the
/// medicine has no food instruction or the question was not answered.
bool? foodAsPrescribed(Medicine m, DoseLog log) {
  final answer = log.foodAnswer;
  if (answer == null || log.status != DoseStatus.taken) return null;
  switch (m.mealRule) {
    case MealRule.any:
      return null;
    case MealRule.beforeFood:
      return answer == 'before';
    case MealRule.afterFood:
    case MealRule.withFood:
      return answer != 'before';
  }
}

/// What finally happened to a planned dose, as a doctor would sort it.
enum DoseOutcome {
  /// Taken within the hour and, where asked, correctly with or without food.
  asPrescribed,

  /// Taken, but more than an hour early or late.
  offTime,

  /// Taken, but not with/without food as instructed.
  wrongFood,

  /// The patient said they did not take it.
  notTaken,

  /// Nobody answered; whether it was taken is unknown.
  noReply,

  /// Skipped because the doctor's own rule said so.
  skippedByPlan,

  /// Not due yet, or still open.
  open,
}

/// The log that settles a dose: its own, or the bedtime follow-up of a moved one.
DoseLog? settlingLog(ScheduledDose dose, List<DoseLog> logs) {
  final log = dose.log;
  if (log?.status != DoseStatus.moved || log!.movedTo == null) return log;
  for (final l in logs) {
    if (l.medicineId == dose.medicine.id &&
        l.scheduled == log.movedTo &&
        l.status != DoseStatus.moved) {
      return l;
    }
  }
  return null;
}

DoseOutcome outcomeOf(ScheduledDose dose, List<DoseLog> logs, DateTime now) {
  final status = dose.statusAt(now);
  final own = dose.log;
  switch (status) {
    case DoseStatus.due:
    case DoseStatus.snoozed:
      return DoseOutcome.open;
    case DoseStatus.noReply:
      return DoseOutcome.noReply;
    case DoseStatus.missed:
      return DoseOutcome.notTaken;
    case DoseStatus.skipped:
      return DoseOutcome.skippedByPlan;
    case DoseStatus.moved:
      final follow = settlingLog(dose, logs);
      if (follow == null || follow.status == DoseStatus.snoozed) {
        final to = own?.movedTo;
        return to != null && now.isAfter(to.add(const Duration(hours: 2)))
            ? DoseOutcome.noReply
            : DoseOutcome.open;
      }
      if (follow.status == DoseStatus.missed) return DoseOutcome.notTaken;
      if (follow.status != DoseStatus.taken) return DoseOutcome.open;
      // The move itself was the doctor's instruction about food.
      final off = minutesOff(follow, planned: own!.movedTo);
      return off != null && off.abs() > onTimeWindowMinutes
          ? DoseOutcome.offTime
          : DoseOutcome.asPrescribed;
    case DoseStatus.taken:
      if (foodAsPrescribed(dose.medicine, own!) == false) {
        return DoseOutcome.wrongFood;
      }
      final off = minutesOff(own, planned: dose.scheduled);
      return off != null && off.abs() > onTimeWindowMinutes
          ? DoseOutcome.offTime
          : DoseOutcome.asPrescribed;
  }
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
/// The meal a dose is taken around. A medicine taken more than once a day,
/// or with no meal set, goes by the time of the dose.
Meal mealAt(Medicine m, DateTime scheduled) {
  if (m.meal != Meal.none && m.times.length <= 1) return m.meal;
  final minutes = scheduled.hour * 60 + scheduled.minute;
  return minutes < 11 * 60
      ? Meal.breakfast
      : minutes < 17 * 60
          ? Meal.lunch
          : Meal.dinner;
}

DateTime bedtimeFor(DateTime day, {int minutes = 22 * 60}) =>
    _day(day).add(Duration(minutes: minutes));

/// Adherence for one medicine or all medicines over a window, counting only
/// doses whose time has passed. Moved doses that were later taken count as
/// taken; skipped-by-rule doses are excluded from the denominator.
class Adherence {
  Adherence(this.taken, this.missed, this.skipped, this.reasons,
      {this.noReply = 0,
      Map<String, int>? feelings,
      this.asPrescribed = 0,
      this.offTime = 0,
      this.wrongFood = 0,
      this.foodAnswered = 0,
      this.foodFollowed = 0,
      this.averageDelay})
      : feelings = feelings ?? {};
  final int taken, missed, skipped, noReply;
  final Map<String, int> reasons;

  /// How the patient said they felt when confirming doses.
  final Map<String, int> feelings;

  /// Of the doses taken: how many were on time and correct with food, how
  /// many were more than an hour off, and how many broke the food instruction.
  final int asPrescribed, offTime, wrongFood;

  /// Doses where the food question was answered, and where the answer
  /// matched the instruction.
  final int foodAnswered, foodFollowed;

  /// Average minutes after the planned time, over taken doses with a time.
  final int? averageDelay;

  /// Scheduled doses so far. Unanswered ones count as not confirmed,
  /// never as taken.
  int get counted => taken + missed + noReply;
  double? get rate => counted == 0 ? null : taken / counted;
  int? get percent => rate == null ? null : (rate! * 100).round();

  /// Share of all planned doses that were taken exactly as prescribed.
  int? get asPrescribedPercent =>
      counted == 0 ? null : (asPrescribed / counted * 100).round();
}

Adherence adherence(List<Medicine> medicines, List<DoseLog> logs, DateTime from,
    DateTime to, DateTime now,
    {String? medicineId}) {
  var taken = 0, missed = 0, skipped = 0, noReply = 0;
  var asPrescribed = 0, offTime = 0, wrongFood = 0;
  var foodAnswered = 0, foodFollowed = 0, delaySum = 0, delayCount = 0;
  final reasons = <String, int>{};
  final feelings = <String, int>{};
  final meds =
      medicines.where((m) => medicineId == null || m.id == medicineId).toList();
  for (var d = _day(from); !d.isAfter(_day(to)); d = d.add(const Duration(days: 1))) {
    for (final dose in dosesForDay(meds, logs, d)) {
      // A moved dose is judged once, through its original time.
      if (dose.movedFrom != null || dose.scheduled.isAfter(now)) continue;
      final settled = settlingLog(dose, logs);
      final own = dose.log;
      switch (outcomeOf(dose, logs, now)) {
        case DoseOutcome.asPrescribed:
          taken++;
          asPrescribed++;
        case DoseOutcome.offTime:
          taken++;
          offTime++;
        case DoseOutcome.wrongFood:
          taken++;
          wrongFood++;
        case DoseOutcome.notTaken:
          missed++;
        case DoseOutcome.noReply:
          noReply++;
        case DoseOutcome.skippedByPlan:
          skipped++;
        case DoseOutcome.open:
          break;
      }
      if (settled != null && settled.status == DoseStatus.taken) {
        if (settled.feeling != null) {
          feelings[settled.feeling!] = (feelings[settled.feeling!] ?? 0) + 1;
        }
        final followed = foodAsPrescribed(dose.medicine, settled);
        if (followed != null && own?.status != DoseStatus.moved) {
          foodAnswered++;
          if (followed) foodFollowed++;
        }
        final off = minutesOff(settled,
            planned: own?.status == DoseStatus.moved ? own!.movedTo : dose.scheduled);
        if (off != null) {
          delaySum += off;
          delayCount++;
        }
      }
      for (final log in {own, settled}) {
        final reason = log?.reason;
        if (log != null && reason != null && log.status != DoseStatus.taken) {
          reasons[reason] = (reasons[reason] ?? 0) + 1;
        }
      }
    }
  }
  return Adherence(taken, missed, skipped, reasons,
      noReply: noReply,
      feelings: feelings,
      asPrescribed: asPrescribed,
      offTime: offTime,
      wrongFood: wrongFood,
      foodAnswered: foodAnswered,
      foodFollowed: foodFollowed,
      averageDelay: delayCount == 0 ? null : (delaySum / delayCount).round());
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
  final unwellFeelings = recent.feelings.entries
      .where((e) => e.key != 'Fine')
      .map((e) => '${e.key.toLowerCase()} ×${e.value}');
  if (unwellFeelings.isNotEmpty) {
    signals.add(FollowUpSignal(2, 'Patient said they felt ${unwellFeelings.join(', ')} when confirming doses'));
  }
  if (recent.wrongFood > 0) {
    signals.add(FollowUpSignal(2,
        'Food instruction not followed for ${recent.wrongFood} dose(s) in 14 days'));
  }
  if (recent.offTime >= 2) {
    signals.add(FollowUpSignal(1,
        '${recent.offTime} doses taken more than an hour off the planned time in 14 days'));
  }
  if (recent.noReply >= 3) {
    signals.add(FollowUpSignal(2,
        'No reply to ${recent.noReply} check-ins in 14 days — whether those doses were taken is unknown'));
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
  MedState(
      {List<Medicine>? medicines,
      List<DoseLog>? logs,
      List<Reading>? readings,
      this.demo = false})
      : medicines = medicines ?? [],
        logs = logs ?? [],
        readings = readings ?? [];
  final List<Medicine> medicines;
  final List<DoseLog> logs;
  final List<Reading> readings;

  /// A made-up demo patient. Demo plans are rebuilt around today's date on
  /// every visit, so they never go stale or mix with a real plan.
  final bool demo;

  String encode() => jsonEncode({
        'version': 1,
        if (demo) 'demo': true,
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
        demo: j['demo'] == true,
      );
    } catch (_) {
      return MedState();
    }
  }

  /// Records a log, replacing any earlier entry for the same dose.
  MedState record(DoseLog log) => MedState(
      medicines: medicines,
      logs: [...logs.where((l) => l.key != log.key), log],
      readings: readings,
      demo: demo);

  MedState withMedicines(List<Medicine> next) =>
      MedState(medicines: next, logs: logs, readings: readings, demo: demo);

  MedState addReading(Reading r) => MedState(
      medicines: medicines, logs: logs, readings: [...readings, r], demo: demo);
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
        prescribedBy: 'Dr Sample (demo)',
        start: _day(now).subtract(const Duration(days: 21))),
    Medicine(
        id: 'metformin',
        name: 'Metformin',
        dose: '500 mg · 1 tablet',
        times: [8 * 60 + 45, 21 * 60],
        meal: Meal.breakfast,
        mealRule: MealRule.afterFood,
        supply: 6,
        prescribedBy: 'Dr Sample (demo)',
        start: _day(now).subtract(const Duration(days: 21))),
    Medicine(
        id: 'amlodipine',
        name: 'Amlodipine',
        dose: '5 mg · 1 tablet',
        times: [21 * 60],
        mealRule: MealRule.any,
        supply: 20,
        prescribedBy: 'Dr Sample (demo)',
        start: _day(now).subtract(const Duration(days: 21))),
  ];
  var state = MedState(medicines: meds, demo: true);
  final today = _day(now);
  // 21 days of history with a deterioration pattern in the last 10 days.
  for (var back = 21; back >= 1; back--) {
    final day = today.subtract(Duration(days: back));
    for (final dose in dosesForDay(meds, const [], day)) {
      final late = back <= 10;
      final id = dose.medicine.id;
      // One evening with no answer, to show 'no reply' is not 'missed'.
      if (back == 5 && id == 'amlodipine') continue;
      final miss = late &&
          ((id == 'amlodipine' && back % 2 == 0) ||
              (id == 'metformin' && dose.scheduled.hour >= 20 && back % 3 == 0));
      // Thyroxine after breakfast on a few recent mornings, and the evening
      // metformin sometimes well after dinner time.
      final afterBreakfast = late && id == 'thyroxine' && back % 4 == 3;
      final veryLate =
          !miss && id == 'metformin' && dose.scheduled.hour >= 20 && back % 4 == 2;
      final delay = afterBreakfast
          ? 75
          : veryLate
              ? 95
              : 5 + (back * 7 + dose.scheduled.hour) % 25;
      state = state.record(DoseLog(
          medicineId: id,
          scheduled: dose.scheduled,
          status: miss ? DoseStatus.missed : DoseStatus.taken,
          at: miss ? null : dose.scheduled.add(Duration(minutes: delay)),
          reason: miss ? (id == 'amlodipine' ? 'ran_out' : 'forgot') : null,
          feeling: miss
              ? null
              : id == 'thyroxine'
                  ? (late && back % 4 == 1 ? 'Tired' : 'Fine')
                  : null,
          mealTiming: miss || !dose.medicine.mealSensitive
              ? null
              : id == 'thyroxine'
                  ? (afterBreakfast ? 'after' : 'before')
                  : 'after'));
    }
    final systolic = back > 10 ? 132 + (back % 4) : 140 + (10 - back) * 1.2;
    state = state.addReading(Reading(
        kind: 'bp',
        at: day.add(const Duration(hours: 8)),
        value: systolic.toDouble(),
        value2: systolic * 0.62));
  }
  // Today: the morning doses that are already past were confirmed.
  for (final dose in dosesForDay(meds, const [], today)) {
    if (dose.scheduled.isAfter(now.subtract(const Duration(minutes: 20)))) {
      continue;
    }
    state = state.record(DoseLog(
        medicineId: dose.medicine.id,
        scheduled: dose.scheduled,
        status: DoseStatus.taken,
        at: dose.scheduled.add(const Duration(minutes: 10)),
        feeling: dose.medicine.id == 'thyroxine' ? 'Fine' : null,
        mealTiming: !dose.medicine.mealSensitive
            ? null
            : dose.medicine.mealRule == MealRule.beforeFood
                ? 'before'
                : 'after'));
  }
  return state;
}
