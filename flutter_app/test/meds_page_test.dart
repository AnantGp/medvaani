import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/meds/med_engine.dart';
import 'package:medical_cdss/meds/meds_page.dart';
import 'package:medical_cdss/report_workspace.dart' show medivaaniiTheme;

void main() {
  testWidgets('before-food dose asks about breakfast and applies the doctor rule',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 11, 3, 7, 35);
    String? saved;
    await tester.pumpWidget(MaterialApp(
        theme: medivaaniiTheme(),
        home: Scaffold(
            body: MedsPage(
                language: 'English',
                now: () => now,
                load: () => sampleMedState(now).encode(),
                store: (value) => saved = value))));
    await tester.pumpAndSettle();

    expect(find.text('Time for Thyroxine'), findsOneWidget);
    await tester.tap(find.text('Check in').first);
    await tester.pumpAndSettle();
    expect(find.text('Have you had breakfast yet?'), findsOneWidget);

    await tester.tap(find.text('Yes, I have eaten'));
    await tester.pumpAndSettle();
    expect(find.text('This medicine works best on an empty stomach.'),
        findsOneWidget);
    await tester.tap(find.text('Remind me at bedtime'));
    await tester.pumpAndSettle();

    final state = MedState.decode(saved);
    final today = state.logs.where((l) =>
        l.medicineId == 'thyroxine' && l.scheduled.day == now.day);
    expect(today.single.status, DoseStatus.moved);
    expect(today.single.ateBefore, isTrue);
    expect(find.text('Moved to bedtime'), findsOneWidget);
  });

  testWidgets('doctor view lists follow-up signals from sample history',
      (tester) async {
    tester.view.physicalSize = const Size(1300, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 11, 3, 9);
    await tester.pumpWidget(MaterialApp(
        theme: medivaaniiTheme(),
        home: Scaffold(
            body: MedsPage(
                language: 'English',
                now: () => now,
                load: () => sampleMedState(now).encode()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doctor'));
    await tester.pumpAndSettle();
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.textContaining('Home systolic BP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
