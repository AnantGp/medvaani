"""Synthetic lab reports in the printed styles of 15 countries, with ground truth.

Every patient, lab and value is fictional. Layouts imitate common public
report conventions: column order, language, units (SI vs conventional),
decimal comma, flag symbols, bracketed ranges, previous-result columns.

Run:  python make_world_reports.py <out_dir>
Writes one PDF per country and truth.json in the evaluator's format.
"""
import json
import re
import sys
from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

CJK = '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc'
pdfmetrics.registerFont(TTFont('CJK', CJK, subfontIndex=0))
pdfmetrics.registerFont(TTFont('Sans', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('SansB', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))

W, H = A4

# Each report: header lines, column spec [(header, x, key)], rows.
# Row keys: name, value, unit, ref, flag, prev, vu (value+unit printed together).
# Truth: name/value/unit/reference/status as printed. 'unit' is the unit printed
# next to the value; a unit printed only inside the range is not the row's unit.
REPORTS = {
 'IN_india': dict(font='Sans', title='Sunrise Diagnostics, New Delhi', meta=[
    'Patient Name : Test Person   Age/Gender : 45 Y/Male', 'Collected : 12/11/2026 08:15   Reported : 12/11/2026 14:02',
    'Ref. By : Self   Lab No. : 2611120045'],
  cols=[('Test Name', 40, 'name'), ('Results', 250, 'value'), ('Units', 330, 'unit'), ('Bio. Ref. Interval', 420, 'ref')],
  section='COMPLETE BLOOD COUNT (CBC)',
  rows=[('Hemoglobin', '11.8', 'g/dL', '13.0 - 17.0', None, 'low'),
        ('Total Leukocyte Count', '7.40', 'thou/mm3', '4.00 - 10.00', None, 'normal'),
        ('Platelet Count', '182', 'thou/mm3', '150 - 410', None, 'normal'),
        ('Glucose, Fasting', '126', 'mg/dL', '70 - 100', None, 'high'),
        ('HbA1c', '6.9', '%', '4.0 - 5.6', None, 'high'),
        ('Creatinine', '1.02', 'mg/dL', '0.70 - 1.30', None, 'normal'),
        ('Cholesterol, Total', '214', 'mg/dL', '< 200', None, 'high'),
        ('Vitamin B12', '168', 'pg/mL', '211 - 911', None, 'low'),
        ('25 OH Vitamin D, Total', '18.4', 'ng/mL', '30.0 - 100.0', None, 'low'),
        ('TSH', '3.12', 'µIU/mL', '0.35 - 5.50', None, 'normal')]),

 'US_usa': dict(font='Sans', title='Riverside Clinical Laboratories, Ohio', meta=[
    'Patient: TEST, PERSON   DOB: 01/02/1979   Sex: F', 'Collected: 11/12/2026 7:42 AM   Reported: 11/12/2026 3:10 PM',
    'Ordering physician: Sample Doctor, MD'],
  cols=[('Test Name', 40, 'name'), ('In Range', 220, 'in'), ('Out Of Range', 300, 'out'), ('Reference Range', 400, 'ref'), ('Lab', 530, 'lab')],
  section='COMPREHENSIVE METABOLIC PANEL',
  rows=[('GLUCOSE', '112', '', '65-99 mg/dL', 'H', 'high'),
        ('UREA NITROGEN (BUN)', '14', '', '7-25 mg/dL', None, 'normal'),
        ('CREATININE', '0.88', '', '0.50-1.03 mg/dL', None, 'normal'),
        ('SODIUM', '133', '', '135-146 mmol/L', 'L', 'low'),
        ('POTASSIUM', '4.4', '', '3.5-5.3 mmol/L', None, 'normal'),
        ('CALCIUM', '9.6', '', '8.6-10.4 mg/dL', None, 'normal'),
        ('ALT', '58', '', '6-29 U/L', 'H', 'high'),
        ('CHOLESTEROL, TOTAL', '236', '', '<200 mg/dL', 'H', 'high'),
        ('HDL CHOLESTEROL', '52', '', '> OR = 50 mg/dL', None, 'normal'),
        ('HEMOGLOBIN A1c', '5.4', '', '<5.7 % of total Hgb', None, 'normal')]),

 'UK_uk': dict(font='Sans', title='Northgate NHS Foundation Trust · Clinical Biochemistry', meta=[
    'Patient: TEST PERSON   NHS No: 000 000 0000 (test)   DOB: 03/04/1970', 'Sample received: 12-Nov-2026 09:20   Requested by: Sample GP surgery'],
  cols=[('Test', 40, 'name'), ('Result', 230, 'value'), ('Flag', 290, 'flag'), ('Units', 330, 'unit'), ('Reference range', 430, 'ref')],
  section='Renal, liver and diabetes',
  rows=[('Serum sodium', '139', 'mmol/L', '(133 - 146)', None, 'normal'),
        ('Serum potassium', '5.6', 'mmol/L', '(3.5 - 5.3)', 'H', 'high'),
        ('Serum creatinine', '96', 'umol/L', '(59 - 104)', None, 'normal'),
        ('eGFR', '78', 'mL/min/1.73m2', '(>90)', 'L', 'low'),
        ('Serum ALT', '22', 'U/L', '(0 - 41)', None, 'normal'),
        ('HbA1c (IFCC)', '52', 'mmol/mol', '(20 - 41)', 'H', 'high'),
        ('Serum cholesterol', '5.9', 'mmol/L', '(< 5.0)', 'H', 'high'),
        ('Serum ferritin', '14', 'ug/L', '(30 - 400)', 'L', 'low'),
        ('Haemoglobin', '138', 'g/L', '(130 - 180)', None, 'normal'),
        ('Plasma glucose', '5.4', 'mmol/L', '(3.0 - 6.0)', None, 'normal')]),

 'CN_china': dict(font='CJK', title='华康医学检验中心 检验报告单', meta=[
    '姓名：测试人员   性别：男   年龄：52岁   科室：内科', '标本类型：血清   采集时间：2026-11-12 08:10   报告时间：2026-11-12 15:30'],
  cols=[('项目名称', 40, 'name'), ('结果', 220, 'value'), ('提示', 285, 'flag'), ('单位', 330, 'unit'), ('参考区间', 430, 'ref')],
  section='生化检验',
  rows=[('葡萄糖(GLU)', '7.8', 'mmol/L', '3.9-6.1', '↑', 'high'),
        ('总胆固醇(TC)', '5.12', 'mmol/L', '<5.2', None, 'normal'),
        ('甘油三酯(TG)', '2.35', 'mmol/L', '<1.7', '↑', 'high'),
        ('肌酐(Cr)', '78', 'μmol/L', '57-111', None, 'normal'),
        ('尿酸(UA)', '512', 'μmol/L', '208-428', '↑', 'high'),
        ('丙氨酸氨基转移酶(ALT)', '35', 'U/L', '9-50', None, 'normal'),
        ('血红蛋白(HGB)', '118', 'g/L', '130-175', '↓', 'low'),
        ('白细胞计数(WBC)', '6.2', '10^9/L', '3.5-9.5', None, 'normal'),
        ('糖化血红蛋白(HbA1c)', '6.8', '%', '4.0-6.0', '↑', 'high'),
        ('促甲状腺激素(TSH)', '2.10', 'mIU/L', '0.27-4.20', None, 'normal')]),

 'ES_spain': dict(font='Sans', title='Laboratorio Clínico Mediterráneo, Valencia', meta=[
    'Paciente: PERSONA DE PRUEBA   Fecha de nacimiento: 05/06/1968   Sexo: Mujer', 'Fecha de extracción: 12/11/2026   Médico solicitante: Dr. Ejemplo'],
  cols=[('Prueba', 40, 'name'), ('Resultado', 230, 'value'), ('', 290, 'flag'), ('Unidades', 320, 'unit'), ('Valores de referencia', 420, 'ref')],
  section='BIOQUÍMICA',
  rows=[('Glucosa', '104', 'mg/dL', '74 - 106', None, 'normal'),
        ('Hemoglobina glicosilada (HbA1c)', '6,1', '%', '4,0 - 5,6', '*', 'high'),
        ('Colesterol total', '241', 'mg/dL', '< 200', '*', 'high'),
        ('Triglicéridos', '132', 'mg/dL', '< 150', None, 'normal'),
        ('Creatinina', '0,74', 'mg/dL', '0,51 - 0,95', None, 'normal'),
        ('Hierro', '38', 'µg/dL', '50 - 170', '*', 'low'),
        ('Ferritina', '9,8', 'ng/mL', '15,0 - 150,0', '*', 'low'),
        ('Hemoglobina', '11,2', 'g/dL', '12,0 - 15,5', '*', 'low'),
        ('Vitamina B12', '412', 'pg/mL', '197 - 771', None, 'normal'),
        ('Tirotropina (TSH)', '2,85', 'µUI/mL', '0,38 - 5,33', None, 'normal')]),

 'DE_germany': dict(font='Sans', title='Labor Dr. Beispiel MVZ, Hamburg', meta=[
    'Patient: TESTPERSON, Max   Geb.-Datum: 07.08.1965   Geschlecht: m', 'Probeneingang: 12.11.2026 09:05   Befund: 12.11.2026'],
  cols=[('Untersuchung', 40, 'name'), ('Ergebnis', 230, 'value'), ('', 285, 'flag'), ('Einheit', 320, 'unit'), ('Referenzbereich', 420, 'ref')],
  section='Klinische Chemie',
  rows=[('Glucose nüchtern', '98', 'mg/dl', '70 - 100', None, 'normal'),
        ('HbA1c', '6,4', '%', '< 5,7', '+', 'high'),
        ('Kreatinin', '1,31', 'mg/dl', '0,67 - 1,17', '+', 'high'),
        ('GFR (CKD-EPI)', '58', 'ml/min', '> 60', '-', 'low'),
        ('Harnsäure', '6,2', 'mg/dl', '3,4 - 7,0', None, 'normal'),
        ('GPT (ALT)', '31', 'U/l', '< 50', None, 'normal'),
        ('Cholesterin gesamt', '228', 'mg/dl', '< 200', '+', 'high'),
        ('LDL-Cholesterin', '152', 'mg/dl', '< 116', '+', 'high'),
        ('Hämoglobin', '14,9', 'g/dl', '13,5 - 17,5', None, 'normal'),
        ('TSH basal', '0,21', 'mU/l', '0,27 - 4,20', '-', 'low')]),

 'FR_france': dict(font='Sans', title='Laboratoire de Biologie Médicale Exemple, Lyon', meta=[
    'Patient : PERSONNE TEST   Né(e) le : 09/10/1972   Sexe : F', 'Prélevé le : 12/11/2026 à 08h30   Prescripteur : Dr Exemple'],
  cols=[('Analyse', 40, 'name'), ('Résultat', 220, 'value'), ('Unités', 290, 'unit'), ('Valeurs de référence', 370, 'ref'), ('Antériorité', 500, 'prev')],
  section='BIOCHIMIE SANGUINE',
  rows=[('Glycémie à jeun', '1,08', 'g/L', '0,70 à 1,05', None, 'high', '0,98'),
        ('Créatinine', '68', 'µmol/L', '45 à 84', None, 'normal', '71'),
        ('Cholestérol total', '2,34', 'g/L', '< 2,00', None, 'high', '2,10'),
        ('Triglycérides', '0,92', 'g/L', '< 1,50', None, 'normal', '1,05'),
        ('Gamma GT', '18', 'UI/L', '< 38', None, 'normal', '20'),
        ('Ferritine', '12', 'µg/L', '15 à 150', None, 'low', '25'),
        ('Hémoglobine', '12,6', 'g/dL', '11,5 à 16,0', None, 'normal', '12,9'),
        ('Vitamine D (25-OH)', '17', 'ng/mL', '30 à 100', None, 'low', '22'),
        ('TSH', '1,92', 'mUI/L', '0,40 à 4,00', None, 'normal', '2,05'),
        ('HbA1c', '5,9', '%', '4,0 à 6,0', None, 'normal', '5,8')]),

 'JP_japan': dict(font='CJK', title='さくら臨床検査センター 検査結果報告書', meta=[
    '患者氏名：テスト 太郎   性別：男   年齢：58歳', '採取日：2026/11/12   報告日：2026/11/13   依頼医：見本 医師'],
  cols=[('検査項目', 40, 'name'), ('結果', 230, 'value'), ('判定', 290, 'flag'), ('単位', 330, 'unit'), ('基準値', 430, 'ref')],
  section='生化学検査',
  rows=[('AST(GOT)', '42', 'U/L', '13～30', 'H', 'high'),
        ('ALT(GPT)', '55', 'U/L', '10～42', 'H', 'high'),
        ('γ-GT', '88', 'U/L', '13～64', 'H', 'high'),
        ('クレアチニン', '0.95', 'mg/dL', '0.65～1.07', None, 'normal'),
        ('尿酸', '7.9', 'mg/dL', '3.7～7.0', 'H', 'high'),
        ('空腹時血糖', '96', 'mg/dL', '73～109', None, 'normal'),
        ('HbA1c(NGSP)', '5.6', '%', '4.9～6.0', None, 'normal'),
        ('LDLコレステロール', '148', 'mg/dL', '65～163', None, 'normal'),
        ('HDLコレステロール', '36', 'mg/dL', '38～90', 'L', 'low'),
        ('ヘモグロビン', '14.8', 'g/dL', '13.7～16.8', None, 'normal')]),

 'KR_korea': dict(font='CJK', title='한빛의료재단 진단검사의학센터 검사결과지', meta=[
    '성명: 테스트 환자   성별: 여   나이: 49세', '채취일: 2026-11-12   보고일: 2026-11-12   의뢰처: 견본 내과'],
  cols=[('검사명', 40, 'name'), ('결과', 230, 'value'), ('판정', 290, 'flag'), ('단위', 330, 'unit'), ('참고치', 430, 'ref')],
  section='일반화학',
  rows=[('공복혈당', '118', 'mg/dL', '70~99', 'H', 'high'),
        ('당화혈색소', '6.2', '%', '4.0~5.6', 'H', 'high'),
        ('총콜레스테롤', '186', 'mg/dL', '0~199', None, 'normal'),
        ('중성지방', '210', 'mg/dL', '0~149', 'H', 'high'),
        ('크레아티닌', '0.71', 'mg/dL', '0.50~0.90', None, 'normal'),
        ('혈색소', '11.4', 'g/dL', '12.0~16.0', 'L', 'low'),
        ('페리틴', '8.2', 'ng/mL', '13.0~150.0', 'L', 'low'),
        ('갑상선자극호르몬(TSH)', '3.40', 'uIU/mL', '0.35~4.94', None, 'normal'),
        ('AST', '21', 'IU/L', '0~32', None, 'normal'),
        ('ALT', '19', 'IU/L', '0~33', None, 'normal')]),

 'CA_canada': dict(font='Sans', title='Maple Community Laboratories, Ontario', meta=[
    'Patient: TEST, PERSON   Health card: TEST-0000   DOB: 1971-02-14   Sex: M', 'Collected: 2026-11-12 08:02   Reported: 2026-11-12 13:44'],
  cols=[('Test', 40, 'name'), ('Result', 230, 'value'), ('Flag', 285, 'flag'), ('Reference Range', 330, 'ref'), ('Units', 470, 'unit')],
  section='Chemistry',
  rows=[('Glucose Fasting', '6.4', 'mmol/L', '3.6 - 6.0', 'H', 'high'),
        ('Hemoglobin A1C', '0.061', 'fraction', '<0.060', 'H', 'high'),
        ('Creatinine', '88', 'umol/L', '60 - 110', None, 'normal'),
        ('eGFR', '84', 'mL/min/1.73m2', '>=60', None, 'normal'),
        ('Cholesterol', '5.6', 'mmol/L', '<5.2', 'H', 'high'),
        ('LDL Cholesterol', '3.7', 'mmol/L', '<3.5', 'H', 'high'),
        ('HDL Cholesterol', '1.2', 'mmol/L', '>1.0', None, 'normal'),
        ('Triglycerides', '1.6', 'mmol/L', '<1.7', None, 'normal'),
        ('TSH', '2.8', 'mU/L', '0.32 - 4.00', None, 'normal'),
        ('Ferritin', '22', 'ug/L', '30 - 400', 'L', 'low')]),

 'AU_australia': dict(font='Sans', title='Southern Cross Pathology, Melbourne', meta=[
    'Patient: TEST PERSON   DOB: 21/09/1966   Sex: F   Medicare: test only', 'Requested by: Dr Sample   Collected: 12/11/26 07:55'],
  cols=[('Test', 40, 'name'), ('12/11/26', 210, 'value'), ('', 255, 'flag'), ('03/05/26', 285, 'prev'), ('Units', 350, 'unit'), ('Ref. range', 470, 'ref')],
  section='BIOCHEMISTRY (cumulative)',
  rows=[('Sodium', '141', 'mmol/L', '(135-145)', None, 'normal', '139'),
        ('Potassium', '3.3', 'mmol/L', '(3.5-5.2)', 'L', 'low', '4.0'),
        ('Urea', '6.1', 'mmol/L', '(2.5-8.0)', None, 'normal', '5.8'),
        ('Creatinine', '71', 'umol/L', '(45-90)', None, 'normal', '69'),
        ('eGFR', '>90', 'mL/min/1.73m2', '(>59)', None, 'normal', '>90'),
        ('Glucose', '7.4', 'mmol/L', '(3.0-7.7)', None, 'normal', '6.2'),
        ('HbA1c', '6.6', '%', '(<6.0)', 'H', 'high', '6.1'),
        ('Total Cholesterol', '6.2', 'mmol/L', '(<5.5)', 'H', 'high', '5.9'),
        ('ALT', '24', 'U/L', '(<34)', None, 'normal', '27'),
        ('Ferritin', '210', 'ug/L', '(30-500)', None, 'normal', '180')]),

 'BR_brazil': dict(font='Sans', title='Laboratório Exemplo de Análises Clínicas, São Paulo', meta=[
    'Paciente: PESSOA DE TESTE   Data de nascimento: 11/12/1975   Sexo: F', 'Coleta: 12/11/2026 07:40   Médico: Dr. Exemplo'],
  cols=[('Exame', 40, 'name'), ('Resultado', 230, 'vu'), ('Valores de referência', 360, 'ref')],
  section='BIOQUÍMICA',
  rows=[('Glicose em jejum', '92', 'mg/dL', '70 a 99 mg/dL', None, 'normal'),
        ('Hemoglobina glicada (HbA1c)', '5,9', '%', '4,0 a 5,6 %', None, 'high'),
        ('Colesterol total', '231', 'mg/dL', 'Desejável: < 190 mg/dL', None, 'high'),
        ('Triglicerídeos', '128', 'mg/dL', '< 150 mg/dL', None, 'normal'),
        ('Creatinina', '0,82', 'mg/dL', '0,50 a 0,90 mg/dL', None, 'normal'),
        ('Ureia', '31', 'mg/dL', '15 a 40 mg/dL', None, 'normal'),
        ('TGP (ALT)', '18', 'U/L', '< 33 U/L', None, 'normal'),
        ('Ferritina', '11,4', 'ng/mL', '13,0 a 150,0 ng/mL', None, 'low'),
        ('Hemoglobina', '12,1', 'g/dL', '12,0 a 15,5 g/dL', None, 'normal'),
        ('TSH', '5,92', 'µUI/mL', '0,45 a 4,50 µUI/mL', None, 'high')]),

 'MX_mexico': dict(font='Sans', title='Laboratorio Clínico del Valle, Ciudad de México', meta=[
    'Paciente: PERSONA DE PRUEBA   Edad: 56 años   Sexo: Masculino', 'Fecha de toma: 12/11/2026   Médico: Dr. Ejemplo'],
  cols=[('Estudio', 40, 'name'), ('Resultado', 230, 'value'), ('Unidades', 300, 'unit'), ('Valores de referencia', 380, 'ref'), ('', 520, 'flag')],
  section='QUÍMICA SANGUÍNEA',
  rows=[('Glucosa', '142', 'mg/dL', '70 - 100', 'Alto', 'high'),
        ('Urea', '34', 'mg/dL', '15 - 45', None, 'normal'),
        ('Creatinina', '1.1', 'mg/dL', '0.7 - 1.3', None, 'normal'),
        ('Ácido úrico', '8.1', 'mg/dL', '3.5 - 7.2', 'Alto', 'high'),
        ('Colesterol total', '198', 'mg/dL', '< 200', None, 'normal'),
        ('Triglicéridos', '267', 'mg/dL', '< 150', 'Alto', 'high'),
        ('Colesterol HDL', '34', 'mg/dL', '> 40', 'Bajo', 'low'),
        ('Hemoglobina glucosilada', '7.6', '%', '4.0 - 5.6', 'Alto', 'high'),
        ('Hemoglobina', '15.2', 'g/dL', '13.5 - 17.5', None, 'normal'),
        ('TGP (ALT)', '29', 'U/L', '7 - 56', None, 'normal')]),

 'AE_uae': dict(font='Sans', title='Gulf Medical Laboratory, Dubai', meta=[
    'Patient: TEST PERSON   Age/Sex: 39 Y / M   MRN: TEST-000', 'Collected: 12-11-2026 08:30   Referred by: Sample Clinic'],
  cols=[('Test', 40, 'name'), ('Result', 230, 'value'), ('Flag', 285, 'flag'), ('Unit', 330, 'unit'), ('Reference Range', 430, 'ref')],
  section='CLINICAL CHEMISTRY',
  rows=[('Glucose (Fasting)', '5.9', 'mmol/L', '3.9 - 5.6', 'H', 'high'),
        ('HbA1c', '5.8', '%', '4.0 - 5.6', 'H', 'high'),
        ('Urea', '4.7', 'mmol/L', '2.8 - 8.1', None, 'normal'),
        ('Creatinine', '82', 'µmol/L', '62 - 106', None, 'normal'),
        ('Total Cholesterol', '4.6', 'mmol/L', '< 5.2', None, 'normal'),
        ('Triglycerides', '2.4', 'mmol/L', '< 1.7', 'H', 'high'),
        ('Vitamin D, 25-Hydroxy', '31', 'nmol/L', '75 - 250', 'L', 'low'),
        ('Vitamin B12', '310', 'pmol/L', '138 - 652', None, 'normal'),
        ('TSH', '1.9', 'mIU/L', '0.27 - 4.20', None, 'normal'),
        ('Hemoglobin', '15.1', 'g/dL', '13.0 - 17.0', None, 'normal')]),

 'SG_singapore': dict(font='Sans', title='Lion City Clinical Laboratory, Singapore', meta=[
    'Patient: TEST PERSON   NRIC: TEST0000   DOB: 15/03/1963   Sex: F', 'Collected: 12/11/2026 08:10   Clinic: Sample Family Clinic'],
  cols=[('Test', 40, 'name'), ('Result', 230, 'value'), ('Units', 300, 'unit'), ('Ref Range', 400, 'ref')],
  section='DIABETES & LIPIDS',
  rows=[('Glucose, Fasting', '*H 7.2', 'mmol/L', '3.9 - 6.0', None, 'high'),
        ('HbA1c', '*H 7.1', '%', '4.0 - 5.6', None, 'high'),
        ('Cholesterol, Total', '4.9', 'mmol/L', '< 5.2', None, 'normal'),
        ('LDL Cholesterol', '*H 3.1', 'mmol/L', '< 2.6', None, 'high'),
        ('HDL Cholesterol', '1.4', 'mmol/L', '> 1.0', None, 'normal'),
        ('Triglycerides', '1.3', 'mmol/L', '< 1.7', None, 'normal'),
        ('Creatinine', '64', 'umol/L', '45 - 84', None, 'normal'),
        ('eGFR', '89', 'mL/min/1.73m2', '>= 90', None, 'low'),
        ('Microalbumin/Creatinine Ratio', '*H 4.8', 'mg/mmol', '< 3.0', None, 'high'),
        ('ALT', '17', 'U/L', '7 - 36', None, 'normal')]),
}


def draw(path, spec):
    c = canvas.Canvas(str(path), pagesize=A4)
    font = spec['font']
    c.setFont(font if font != 'Sans' else 'SansB', 13)
    c.drawString(40, H - 50, spec['title'])
    c.setFont(font, 8)
    c.drawString(40, H - 64, 'SYNTHETIC TEST REPORT · fictional patient and values · not for clinical use')
    c.setFont(font, 9.5)
    y = H - 88
    for line in spec['meta']:
        c.drawString(40, y, line)
        y -= 14
    y -= 10
    c.setFont(font if font != 'Sans' else 'SansB', 10)
    for header, x, _ in spec['cols']:
        if header:
            c.drawString(x, y, header)
    c.line(40, y - 5, W - 40, y - 5)
    y -= 24
    c.setFont(font if font != 'Sans' else 'SansB', 10.5)
    c.drawString(40, y, spec['section'])
    y -= 20
    c.setFont(font, 10)
    for row in spec['rows']:
        name, value, unit, ref, flag, _status = row[:6]
        prev = row[6] if len(row) > 6 else ''
        for _, x, key in spec['cols']:
            text = {'name': name, 'value': value, 'unit': unit, 'ref': ref, 'flag': flag or '',
                    'prev': prev, 'vu': f'{value} {unit}', 'lab': 'RL',
                    'in': '' if flag else value, 'out': f'{value} {flag}' if flag else ''}[key]
            if text:
                c.drawString(x, y, text)
        y -= 20
    c.setFont(font, 8)
    c.drawString(40, 60, 'End of report · results relate only to the sample tested.')
    c.save()


def truth_rows(spec):
    keys = {k for _, _, k in spec['cols']}
    out = []
    for row in spec['rows']:
        name, value, unit, ref, _flag, status = row[:6]
        printed_unit = unit if keys & {'unit', 'vu'} else ''
        if not printed_unit and keys & {'in', 'out'}:
            # US style: the unit is printed only after the range ("65-99 mg/dL");
            # it is still the result's unit.
            m = re.search(r'[\d.]\s*([^\d\s][^\d]*)$', ref)
            printed_unit = m[1].strip() if m else ''
        value = value.split(' ')[-1]  # "*H 7.2" prints a flag before the number
        out.append({'name': name, 'value': value, 'unit': printed_unit, 'reference': ref, 'status': status})
    return out


if __name__ == '__main__':
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    truth = {}
    for key, spec in REPORTS.items():
        name = f'{key}.pdf'
        draw(out / name, spec)
        truth[name] = truth_rows(spec)
    (out / 'truth.json').write_text(json.dumps(truth, indent=1, ensure_ascii=False))
    print(len(truth), 'reports,', sum(len(v) for v in truth.values()), 'results')
