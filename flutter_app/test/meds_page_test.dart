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

  Future<void> pumpPage(WidgetTester tester, DateTime now, String? stored,
      {void Function(String)? store}) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: medivaaniiTheme(),
        home: Scaffold(
            body: MedsPage(
                language: 'English',
                now: () => now,
                load: () => stored,
                store: store))));
    await tester.pumpAndSettle();
  }

  testWidgets('a new patient starts empty; the demo is opt-in and can be left',
      (tester) async {
    final now = DateTime(2026, 11, 16, 9);
    String? saved;
    await pumpPage(tester, now, null, store: (v) => saved = v);
    expect(find.text('No medicines yet'), findsOneWidget);
    expect(find.text('Thyroxine'), findsNothing);

    await tester.tap(find.text('See a demo'));
    await tester.pumpAndSettle();
    expect(find.text('Demo plan · made-up patient, not real data'), findsOneWidget);
    expect(MedState.decode(saved).demo, isTrue);

    await tester.tap(find.text('Exit demo'));
    await tester.pumpAndSettle();
    expect(find.text('No medicines yet'), findsOneWidget);
    expect(MedState.decode(saved).medicines, isEmpty);
  });

  testWidgets('an old saved demo is rebuilt around today, not shown as missed',
      (tester) async {
    final now = DateTime(2026, 11, 16, 9);
    final old = sampleMedState(DateTime(2026, 11, 3, 9)).encode();
    await pumpPage(tester, now, old);
    expect(find.textContaining(RegExp(r'^[1-9][0-9]* of [0-9]+ doses')),
        findsOneWidget);
    expect(find.text('No reply · update'), findsNothing);
  });

  testWidgets('doctor view shows the plan and what the patient reported',
      (tester) async {
    final now = DateTime(2026, 11, 16, 9);
    tester.view.physicalSize = const Size(1300, 2600);
    await pumpPage(tester, now, sampleMedState(now).encode());
    tester.view.physicalSize = const Size(1300, 2600);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doctor'));
    await tester.pumpAndSettle();
    expect(find.text('Demo patient'), findsOneWidget);
    expect(find.text('What the patient told us · 14 days'), findsOneWidget);
    expect(find.textContaining('no reply'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
