import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/meds/med_engine.dart';

Medicine _med(MealRule rule,
        {AteFirstRule ateFirst = AteFirstRule.askDoctor,
        List<int> times = const [450]}) =>
    Medicine(
        id: 'm',
        name: 'Test',
        dose: '1 tablet',
        times: times,
        mealRule: rule,
        ateFirstRule: ateFirst);

void main() {
  group('meal-aware check-in', () {
    test('before-food medicine asks about the meal first', () {
      expect(firstQuestion(_med(MealRule.beforeFood)),
          CheckInQuestion.haveYouEaten);
      expect(firstQuestion(_med(MealRule.any)), CheckInQuestion.takenIt);
    });

    test('not eaten yet: take now, then wait before eating', () {
      expect(adviceAfterMealAnswer(_med(MealRule.beforeFood), hasEaten: false),
          CheckInAdvice.takeNowThenWait);
    });

    test('already eaten: follow the doctor rule, never take a double dose', () {
      expect(adviceAfterMealAnswer(_med(MealRule.beforeFood), hasEaten: true),
          CheckInAdvice.followAteFirstRule);
    });

    test('after-food medicine waits for the meal', () {
      expect(adviceAfterMealAnswer(_med(MealRule.afterFood), hasEaten: false),
          CheckInAdvice.eatFirst);
      expect(adviceAfterMealAnswer(_med(MealRule.afterFood), hasEaten: true),
          CheckInAdvice.takeNow);
    });
  });

  group('adherence', () {
    final day = DateTime(2026, 11, 1);
    final med = _med(MealRule.any, times: [8 * 60, 20 * 60]);

    test('counts taken and missed past doses only', () {
      final logs = [
        DoseLog(
            medicineId: 'm',
            scheduled: day.add(const Duration(hours: 8)),
            status: DoseStatus.taken),
      ];
      // Evening dose of the same day passed its grace period untaken.
      final now = day.add(const Duration(hours: 23));
      final result = adherence([med], logs, day, day, now);
      expect(result.taken, 1);
      expect(result.missed, 1);
      expect(result.percent, 50);
    });

    test('future doses are not counted', () {
      final now = day.add(const Duration(hours: 9));
      final logs = [
        DoseLog(
            medicineId: 'm',
            scheduled: day.add(const Duration(hours: 8)),
            status: DoseStatus.taken),
      ];
      expect(adherence([med], logs, day, day, now).percent, 100);
    });

    test('a dose moved to bedtime and taken counts as taken', () {
      final morning = _med(MealRule.beforeFood,
          ateFirst: AteFirstRule.moveToBedtime, times: [450]);
      final scheduled = day.add(const Duration(minutes: 450));
      final bedtime = bedtimeFor(day);
      final logs = [
        DoseLog(
            medicineId: 'm',
            scheduled: scheduled,
            status: DoseStatus.moved,
            ateBefore: true,
            movedTo: bedtime),
        DoseLog(
            medicineId: 'm',
            scheduled: bedtime,
            status: DoseStatus.taken,
            at: bedtime),
      ];
      final result = adherence([morning], logs, day, day,
          day.add(const Duration(hours: 23, minutes: 30)));
      expect(result.taken, 1);
      expect(result.missed, 0);
    });

    test('reasons for missed doses are tallied', () {
      final logs = [
        DoseLog(
            medicineId: 'm',
            scheduled: day.add(const Duration(hours: 8)),
            status: DoseStatus.missed,
            reason: 'ran_out'),
      ];
      final result =
          adherence([med], logs, day, day, day.add(const Duration(hours: 10)));
      expect(result.reasons['ran_out'], 1);
    });
  });

  test('sample history surfaces missed doses alongside rising BP', () {
    final now = DateTime(2026, 11, 3, 9);
    final state = sampleMedState(now);
    final signals =
        followUpSignals(state.medicines, state.logs, state.readings, now);
    expect(signals, isNotEmpty);
    expect(signals.first.message, contains('Home systolic BP'));
    expect(signals.any((s) => s.message.contains('running out')), isTrue);
  });

  test('days before a plan starts are never counted as missed', () {
    final start = DateTime(2026, 11, 2);
    final med = Medicine(
        id: 'm', name: 'Test', dose: '1', times: [480], start: start);
    final result = adherence([med], const [], DateTime(2026, 10, 20),
        DateTime(2026, 11, 2), DateTime(2026, 11, 2, 23));
    expect(result.missed, 1);
  });

  test('state survives a storage round trip', () {
    final state = sampleMedState(DateTime(2026, 11, 3, 9));
    final restored = MedState.decode(state.encode());
    expect(restored.medicines.length, state.medicines.length);
    expect(restored.logs.length, state.logs.length);
    expect(restored.readings.length, state.readings.length);
    expect(MedState.decode('not json').medicines, isEmpty);
  });
}
