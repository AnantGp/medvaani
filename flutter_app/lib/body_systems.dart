import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Educational associations, never diagnoses or interpretations of a number.
enum BodySystem {
  kidneys,
  blood,
  sugar,
  heart,
  liver,
  thyroid,
  vitamins,
  salts,
  urine,
  general
}

String bodyCopy(String language, String en, String hi, String es, String zh) =>
    switch (language) { 'hi' => hi, 'es' => es, 'zh' => zh, _ => en };

extension BodySystemGuide on BodySystem {
  String title(String language) => switch (this) {
        BodySystem.kidneys =>
          bodyCopy(language, 'Kidneys', 'गुर्दे', 'Riñones', '肾脏'),
        BodySystem.blood => bodyCopy(language, 'Blood & immunity',
            'खून और रोगों से बचाव', 'Sangre y defensas', '血液与免疫'),
        BodySystem.sugar => bodyCopy(language, 'Blood sugar & energy',
            'खून में शुगर और ऊर्जा', 'Azúcar y energía', '血糖与能量'),
        BodySystem.heart => bodyCopy(language, 'Heart & blood vessels',
            'दिल और खून की नसें', 'Corazón y vasos', '心脏与血管'),
        BodySystem.liver => bodyCopy(language, 'Liver', 'लिवर', 'Hígado', '肝脏'),
        BodySystem.thyroid =>
          bodyCopy(language, 'Thyroid', 'थायरॉइड', 'Tiroides', '甲状腺'),
        BodySystem.vitamins => bodyCopy(
            language,
            'Bones, nerves & vitamins',
            'हड्डियां, नसें और विटामिन',
            'Huesos, nervios y vitaminas',
            '骨骼、神经与维生素'),
        BodySystem.salts => bodyCopy(language, 'Salts & fluid balance',
            'नमक और पानी का संतुलन', 'Sales y líquidos', '电解质与水分'),
        BodySystem.urine => bodyCopy(language, 'Kidneys & urine',
            'गुर्दे और पेशाब', 'Riñones y orina', '肾脏与尿液'),
        BodySystem.general => bodyCopy(language, 'Other report results',
            'रिपोर्ट की दूसरी जांचें', 'Otros resultados', '其他检测结果'),
      };

  String role(String language) => switch (this) {
        BodySystem.kidneys => bodyCopy(
            language,
            'Like a filter: removes waste from blood into urine.',
            'छन्नी की तरह खून से बेकार पदार्थ छानकर पेशाब में निकालते हैं।',
            'Como un filtro: eliminan los desechos de la sangre por la orina.',
            '像过滤器一样，把血液中的废物通过尿液排出。'),
        BodySystem.blood => bodyCopy(
            language,
            'Carries oxygen for strength and helps fight infection.',
            'शरीर को ताकत देने के लिए ऑक्सीजन पहुंचाता है और संक्रमण से लड़ता है।',
            'Lleva oxígeno para dar fuerza y ayuda a combatir infecciones.',
            '运送氧气，让身体有力气，并帮助抵抗感染。'),
        BodySystem.sugar => bodyCopy(
            language,
            'Like fuel for a stove: shows how your body uses food for energy.',
            'चूल्हे के ईंधन की तरह, खाना शरीर को ऊर्जा देता है; यह जांच उसी का हाल बताती है।',
            'Como combustible: muestra cómo tu cuerpo usa los alimentos para obtener energía.',
            '就像燃料一样，食物给身体能量；这类检查帮助了解身体如何使用它。'),
        BodySystem.heart => bodyCopy(
            language,
            'Like a pump and pipes: keeps blood moving around your body.',
            'पंप और पाइप की तरह दिल और नसें पूरे शरीर में खून पहुंचाते हैं।',
            'Como una bomba y tuberías: mantienen la sangre circulando por el cuerpo.',
            '像水泵和管道一样，让血液在全身流动。'),
        BodySystem.liver => bodyCopy(
            language,
            'Like a processing centre: cleans blood and helps digest food.',
            'सफाई और काम करने वाले केंद्र की तरह खून साफ करता है और खाना पचाने में मदद करता है।',
            'Como un centro de trabajo: limpia la sangre y ayuda a digerir los alimentos.',
            '像处理中心一样，帮助清理血液，也帮助消化食物。'),
        BodySystem.thyroid => bodyCopy(
            language,
            'A small gland in your neck, like a dial for your body’s energy speed.',
            'गले की छोटी ग्रंथि, जो शरीर में ऊर्जा के इस्तेमाल की रफ्तार संभालती है।',
            'Una pequeña glándula en el cuello, como un regulador de la energía del cuerpo.',
            '颈部的一小块腺体，像调速器一样调节身体使用能量的速度。'),
        BodySystem.vitamins => bodyCopy(
            language,
            'Like building blocks and message wires: supports strong bones and steady nerves.',
            'ईंटों और संदेश पहुंचाने वाले तारों की तरह, हड्डियों को मजबूत और नसों को काम करने में मदद मिलती है।',
            'Como piezas de construcción y cables: ayudan a tener huesos fuertes y nervios que funcionan bien.',
            '像建筑材料和传信电线一样，帮助骨骼强壮、神经正常工作。'),
        BodySystem.salts => bodyCopy(
            language,
            'Like the right amount of salt in a soup: keeps water balanced and helps nerves, muscles and the heart work.',
            'दाल में सही नमक की तरह: शरीर में पानी का संतुलन रखते हैं और नसों, मांसपेशियों और दिल के काम में मदद करते हैं।',
            'Como la sal justa en una sopa: mantienen el equilibrio del agua y ayudan a nervios, músculos y corazón.',
            '就像汤里放得刚好的盐：保持体内水分平衡，并帮助神经、肌肉和心脏工作。'),
        BodySystem.urine => bodyCopy(
            language,
            'Urine is made by the kidneys and stored in the bladder; it carries waste out of the body.',
            'पेशाब गुर्दों में बनता है और मूत्राशय में जमा होता है; यह शरीर से बेकार पदार्थ बाहर निकालता है।',
            'La orina se produce en los riñones y se guarda en la vejiga; saca los desechos del cuerpo.',
            '尿液由肾脏生成，储存在膀胱中，并把废物带出体外。'),
        BodySystem.general => bodyCopy(
            language,
            'We can discuss this result using the words and values in your report.',
            'आपकी रिपोर्ट में लिखे नाम और नंबर से इस जांच को समझ सकते हैं।',
            'Podemos hablar de este resultado usando las palabras y valores de tu informe.',
            '我们可以根据报告中的文字和数值来了解这项结果。'),
      };

  String location(String language) => switch (this) {
        BodySystem.kidneys => bodyCopy(
            language,
            'Lower back · both sides',
            'पीठ के निचले हिस्से में, दोनों ओर',
            'Espalda baja · ambos lados',
            '腰背部两侧'),
        BodySystem.blood => bodyCopy(language, 'Throughout your body',
            'पूरे शरीर में', 'Por todo el cuerpo', '遍布全身'),
        BodySystem.sugar => bodyCopy(
            language,
            'Pancreas · upper belly',
            'अग्न्याशय · पेट का ऊपरी हिस्सा',
            'Páncreas · abdomen superior',
            '胰腺 · 上腹部'),
        BodySystem.heart => bodyCopy(language, 'Chest & blood vessels',
            'छाती और पूरे शरीर की नसें', 'Pecho y vasos sanguíneos', '胸部与全身血管'),
        BodySystem.liver => bodyCopy(language, 'Upper right belly',
            'पेट में ऊपर, दाईं ओर', 'Abdomen · arriba a la derecha', '右上腹部'),
        BodySystem.thyroid => bodyCopy(language, 'Front of your neck',
            'गले के सामने का हिस्सा', 'Parte delantera del cuello', '颈部前方'),
        BodySystem.vitamins => bodyCopy(
            language,
            'Bones & nerves throughout the body',
            'पूरे शरीर की हड्डियां और नसें',
            'Huesos y nervios de todo el cuerpo',
            '全身骨骼与神经'),
        BodySystem.salts => bodyCopy(language, 'In blood and body fluids',
            'खून और शरीर के तरल में', 'En la sangre y los líquidos', '血液和体液中'),
        BodySystem.urine => bodyCopy(
            language,
            'Kidneys to bladder · lower belly',
            'गुर्दों से मूत्राशय तक · पेट का निचला हिस्सा',
            'De los riñones a la vejiga',
            '从肾脏到膀胱 · 下腹部'),
        BodySystem.general => bodyCopy(
            language,
            'A guide to your report',
            'आपकी रिपोर्ट को समझने में मदद',
            'Una guía de tu informe',
            '报告阅读指南'),
      };

  String get iconName => switch (this) {
        BodySystem.kidneys => 'kidneys',
        BodySystem.blood => 'blood-cells',
        BodySystem.sugar => 'pancreas',
        BodySystem.heart => 'heart-organ',
        BodySystem.liver => 'liver',
        BodySystem.thyroid => 'thyroid',
        BodySystem.vitamins => 'skeleton',
        BodySystem.salts => 'drop',
        BodySystem.urine => 'bladder',
        BodySystem.general => 'body',
      };

  String get illustrationName => switch (this) {
        BodySystem.kidneys => 'neutral-kidneys',
        BodySystem.blood => 'neutral-blood',
        BodySystem.heart => 'neutral-circulation',
        _ => iconName,
      };
}

/// Match names only: numbers, units and reference guidance cannot choose an organ.
/// Latin names are matched as whole words with accents removed; other scripts
/// by the printed term. The same table lives in web/report_explorer_core.mjs.
const _bodySystemTable = <(BodySystem, String, List<String>)>[
  (
    BodySystem.urine,
    r'specific gravity|ph|pus cells?|ketones?|nitrites?|leuko?cyte esterase|urobilinogen|epithelial cells?|casts?|crystals?|urinalysis|urine (?:protein|glucose|sugar|blood|ph|ketones?|rbc|wbc|culture)',
    ['मूत्र', 'पेशाब', '尿蛋白', '尿糖', '尿比重', '尿潜血', '요단백', '요비중']
  ),
  (
    BodySystem.kidneys,
    r'creatinine?|creatinina|kreatinin|e\s*-?\s*gfr|gfr|glomerular filtration(?: rate)?|urea|uree|ureia|harnstoff|ureico|bun|(?:blood )?urea nitrogen|uric acid|acido urico|acide urique|harnsaure|urine albumin|microalbumin(?:uria)?|cystatin c',
    ['क्रिएटिनिन', 'क्रिएटिनीन', 'यूरिया', 'यूरिक एसिड', '肌酐', '尿素', '尿酸', '肾小球滤过率', '크레아티닌', '요소질소', '요산', '사구체', 'クレアチニン', '糸球体']
  ),
  (
    BodySystem.salts,
    r'sodium|sodio|natrium|potassium|potasio|potassio|kalium|chlorides?|chlorid|cloruro|cloreto|bicarbonate|bicarbonato|magnesium|magnesio|phosphate|phosphorus|fosforo|fosfato|electrolytes?|anion gap',
    ['सोडियम', 'पोटैशियम', 'पोटेशियम', 'क्लोराइड', '钠', '钾', '氯', '나트륨', '칼륨', '염소', 'ナトリウム', 'カリウム', 'クロール']
  ),
  (
    BodySystem.vitamins,
    r'vitamin[ae]?[ -]?(?:b[ -]?12|d[ -]?(?:2|3)?)|(?:25[ -]?(?:oh|hydroxy)[ -]?)vitamin[ae]?[ -]?d|b[ -]?12|cobalamin|calcium|calcio|kalzium|calciferol|folate|folic acid|acido folico|folsaure',
    ['विटामिन', 'कैल्शियम', '维生素', '血钙', '钙', '비타민', '칼슘', 'ビタミン', 'カルシウム', '葉酸']
  ),
  (
    BodySystem.sugar,
    r'hba1c|hb[ -]?a1c|a1c|glycated (?:haemoglobin|hemoglobin)|glycosylated (?:haemoglobin|hemoglobin)|hemoglobin[ae]? (?:glicosilada|glucosilada|glicada|glyquee)|glucose|glucosa|glukose|glicose|glicemia|glucemia|glycemie|blood sugar|fasting (?:blood )?sugar|fbs|rbs|ppbs|sugar',
    ['शुगर', 'ग्लूकोज', 'ग्लूकोज़', '血糖', '葡萄糖', '糖化血红蛋白', '혈당', '당화혈색소', 'グルコース', 'ヘモグロビンa1c']
  ),
  (
    BodySystem.thyroid,
    r'tsh|t[ -]?[34]|ft[ -]?[34]|thyroid|thyroxine?|triiodothyronine|tirotropina|tiroxina|thyreotropin|thyrotropin|thyreoidea',
    ['थायरॉइड', 'थायराइड', '甲状腺', '促甲状腺激素', '갑상선', '甲狀腺']
  ),
  (
    BodySystem.heart,
    r'cholesterol|colesterol|cholesterin|hdl(?:[ -]c)?|ldl(?:[ -]c)?|non[- ]hdl|vldl|triglycerides?|triglyceride|trigliceridos|triglicerideos|triglicerides|apolipoprotein|lipoprotein|troponin|ck[- ]?mb|nt[- ]?probnp|bnp|blood pressure|pulse(?: rate)?|heart rate',
    ['कोलेस्ट्रॉल', 'ट्राइग्लिसराइड', '胆固醇', '甘油三酯', '脂蛋白', '콜레스테롤', '중성지방', 'コレステロール', '中性脂肪']
  ),
  (
    BodySystem.liver,
    r'bilirubine?|bilirrubina|alt|ast|sgpt|sgot|gpt|got|tgo|tgp|asat|alat|albumine?|albumina|alp|alkaline phosphatase|fosfatasa alcalina|fosfatase alcalina|phosphatases? alcalines?|ggt|gamma[- ]?gt|gamma glutamyl|total protein|proteinas totales|globulin|liver',
    ['बिलीरुबिन', 'एल्बुमिन', 'लिवर', '胆红素', '转氨酶', '白蛋白', '碱性磷酸酶', '빌리루빈', '알부민', 'ビリルビン', 'アルブミン', 'γ-gt', 'γgt']
  ),
  (
    BodySystem.blood,
    r'ha?emoglobin[ae]?|hamoglobin|hgb|hb|rbc|wbc|platelets?|plaquetas|plaquettes|thrombozyten|ferritin[ae]?|iron|hierro|eisen|ferro|mcv|mchc?|rdw|ha?ematocrit[eo]?|hamatokrit|hct|pcv|leu[ck]o[cs]ytes?|leucocitos|leukozyten|erythrocytes?|eritrocitos|erythrozyten|hematies|neutrophils?|lymphocytes?|monocytes?|eosinophils?|basophils?|mpv|pdw|reticulocytes?|tibc|transferrin[ae]?|esr|crp|c[- ]reactive protein',
    ['हीमोग्लोबिन', 'हिमोग्लोबिन', 'प्लेटलेट', 'आयरन', 'खून', '血红蛋白', '红细胞', '白细胞', '血小板', '铁蛋白', '血清铁', '혈색소', '헤모글로빈', '백혈구', '적혈구', '혈소판', '페리틴', 'ヘモグロビン', '白血球', '赤血球', 'フェリチン', '血色素']
  ),
];

BodySystem bodySystemForTest(String testName) {
  final name = testName
      .toLowerCase()
      .replaceAll(RegExp('[áàâäã]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôöõ]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n')
      .replaceAll('ß', 'ss');
  bool word(String pattern) =>
      RegExp('(?:^|[^a-z0-9])(?:$pattern)(?:\$|[^a-z0-9])').hasMatch(name);
  // A urine sample is never presented as a blood measurement.
  if (word('urine|urinary|orina') &&
      !RegExp('albumin|creatinin').hasMatch(name)) {
    return BodySystem.urine;
  }
  for (final (system, pattern, aliases) in _bodySystemTable) {
    if (word(pattern) || aliases.any(name.contains)) return system;
  }
  return BodySystem.general;
}

Map<BodySystem, List<Map<String, dynamic>>> groupMeasurementsByBodySystem(
    Iterable<Map<String, dynamic>> rows) {
  final groups = <BodySystem, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final system = bodySystemForTest((row['test_name'] ?? '').toString());
    groups.putIfAbsent(system, () => []).add(row);
  }
  // Preserve every measurement and source order within each system.
  return {
    for (final system in BodySystem.values)
      if (groups.containsKey(system)) system: groups[system]!
  };
}

class BodySystemIcon extends StatelessWidget {
  const BodySystemIcon(this.system, {super.key, this.size = 26});
  final BodySystem system;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
      'assets/body_systems/${system.iconName}.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
      colorFilter: const ColorFilter.mode(Color(0xff1d5c3a), BlendMode.srcIn));
}

/// Shares the active selection with citations and the original source viewer.
/// The neutral tint is independent of the result's normal/high/low status.
class ActiveBodyVisual extends StatelessWidget {
  const ActiveBodyVisual(
      {super.key,
      required this.system,
      required this.language,
      this.compact = false});
  final BodySystem system;
  final String language;
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label:
            '${system.title(language)}. ${bodyCopy(language, 'Educational body illustration', 'शरीर को समझाने वाला चित्र', 'Ilustración educativa del cuerpo', '身体部位示意图')}',
        child: ExcludeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              height: compact ? 48 : 56,
              width: compact ? 54 : 64,
              child: SvgPicture.asset(
                  'assets/body_systems/${system.illustrationName}.svg',
                  colorFilter: system.illustrationName.startsWith('neutral-')
                      ? null
                      : const ColorFilter.mode(
                          Color(0xff1d5c3a), BlendMode.srcIn))),
          // A front-view body with this system lit, so the reader sees
          // where in the body the result belongs.
          const SizedBox(width: 8),
          SizedBox(
              key: const ValueKey('anatomy-figure'),
              height: compact ? 96 : 120,
              width: compact ? 46 : 57,
              child: SvgPicture.asset(
                  'assets/body_systems/anatomy-${system.name}.svg')),
        ])),
      );
}
