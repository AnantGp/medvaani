import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/body_systems.dart';

void main() {
  test('required report tests map to the correct educational system', () {
    final cases = {
      BodySystem.kidneys: ['Creatinine', 'eGFR', 'Urea', 'BUN', 'Uric Acid'],
      BodySystem.blood: [
        'Hemoglobin',
        'RBC',
        'WBC',
        'Platelets',
        'Ferritin',
        'Iron',
        'MCV'
      ],
      BodySystem.sugar: ['HbA1c', 'Fasting Glucose', 'Blood Sugar'],
      BodySystem.heart: ['Total Cholesterol', 'HDL', 'LDL', 'Triglycerides'],
      BodySystem.liver: ['Bilirubin', 'ALT/SGPT', 'AST/SGOT', 'Albumin', 'ALP'],
      BodySystem.thyroid: ['TSH', 'T3', 'T4'],
      BodySystem.vitamins: ['Vitamin B12', 'Vitamin D', 'Calcium'],
    };
    for (final entry in cases.entries) {
      for (final name in entry.value) {
        expect(bodySystemForTest(name), entry.key, reason: name);
      }
    }
    expect(bodySystemForTest('Glycated Hemoglobin (HbA1c)'), BodySystem.sugar);
    expect(bodySystemForTest('Urine Albumin'), BodySystem.kidneys);
    expect(bodySystemForTest('Urine glucose'), BodySystem.general);
    expect(bodySystemForTest('Sodium'), BodySystem.general);
    expect(bodySystemForTest('Booking ID'), BodySystem.general);
    expect(bodySystemForTest('Basal temperature'), BodySystem.general);
    expect(bodySystemForTest('肌酐'), BodySystem.kidneys);
    expect(bodySystemForTest('Glucosa en ayunas'), BodySystem.sugar);
  });

  test('grouping preserves measurement identities and unknown results', () {
    final rows = [
      {'measurement_id': 'a', 'test_name': 'Creatinine'},
      {'measurement_id': 'b', 'test_name': 'TSH'},
      {'measurement_id': 'c', 'test_name': 'Urea'},
      {'measurement_id': 'd', 'test_name': 'Unfamiliar assay'},
    ];
    final grouped = groupMeasurementsByBodySystem(rows);
    expect(grouped[BodySystem.kidneys]!.map((r) => r['measurement_id']),
        ['a', 'c']);
    expect(grouped.values.expand((r) => r).length, rows.length);
    expect(grouped[BodySystem.general]!.single['measurement_id'], 'd');
  });

  testWidgets('every system has four-language copy and bundled renderable SVGs',
      (tester) async {
    for (final system in BodySystem.values) {
      for (final language in ['en', 'hi', 'es', 'zh']) {
        expect(system.title(language), isNotEmpty);
        expect(system.role(language), isNotEmpty);
        expect(system.location(language), isNotEmpty);
      }
      for (final asset in [
        system.iconName,
        system.illustrationName,
        'location-${system.name}'
      ]) {
        expect(await rootBundle.loadString('assets/body_systems/$asset.svg'),
            contains('<svg'));
      }
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 140,
                  child: ActiveBodyVisual(system: system, language: 'en')))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: system.name);
    }
  });
}
