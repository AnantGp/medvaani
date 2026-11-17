// Source matching is deliberately literal. A reviewed value never replaces
// the number used to locate the original document.
export const normalize = value => String(value ?? '').normalize('NFKC').toLowerCase().replace(/\s+/g, ' ').trim();
const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
export function matchesSource(line, evidence) {
  const text = normalize(line);
  const quote = normalize(evidence?.source_quote);
  if (quote && text === quote) return true;
  const original = evidence?.original_fields;
  if (!original) return false;
  const name = normalize(original.test_name);
  const value = normalize(original.value);
  if (!name || !value) return false;
  return new RegExp(`(^|[^a-z0-9])${escape(name)}(?=$|[^a-z0-9])`).test(text) &&
    new RegExp(`(^|[^0-9.])${escape(value)}(?=$|[^0-9.])`).test(text);
}
export function sourceForLine(line, sources) {
  const matches = sources.filter(source => matchesSource(line, source));
  return matches.length === 1 ? matches[0] : null;
}
export function safeBox(box) {
  return Array.isArray(box) && box.length === 4 && box.every(Number.isFinite) &&
    box[0] >= 0 && box[1] >= 0 && box[2] > 0 && box[3] > 0 &&
    box[0] + box[2] <= 1.01 && box[1] + box[3] <= 1.01;
}
export function resultLabel(row) {
  const status = ['normal','high','low','critical','abnormal'].includes(row?.status) ? row.status : 'unknown';
  const flag = status[0].toUpperCase() + status.slice(1);
  if (status === 'unknown') return row?.acceptance_state === 'eligible' ? 'No supported comparison' : 'Needs source review';
  return ({report:`${flag} · report flag`, reference_range:`${flag} · report range`,
    source_summary:`${flag} · uploaded summary comparison`,
    user_review:`${flag} · reviewed flag`, reviewed_range:`${flag} · reviewed range`, reviewed_source:`${flag} · checked source`})[row.status_source] || `${flag} · unconfirmed source`;
}

export const selectedMeasurement = (rows, id) => rows.find(row => row.measurement_id === id) || null;
export function sourceSelection(row) {
  if (row?.record_type !== 'measurement') return null;
  const fields = row.source_fields || {}, value = fields.value;
  if (!safeBox(value?.box) || !Number.isInteger(value.page) || value.page < 1) return null;
  return {measurement_id: row.measurement_id, page: value.page, fields};
}
export function fieldFragments(field) {
  if (!field) return [];
  if (Array.isArray(field.fragments) && field.fragments.length) return field.fragments;
  return (field.boxes || [field.box]).map(box => ({...field, box}));
}
export function sourceAtPoint(rows, page, x, y) {
  const matches = rows.filter(row => {
    const selection = sourceSelection(row);
    return selection && Object.values(selection.fields).some(field => fieldFragments(field).some(fragment => {
      const box = fragment.box;
      return fragment.page === page && safeBox(box) && x >= box[0] && x <= box[0]+box[2] && y >= box[1] && y <= box[1]+box[3];
    }));
  });
  return matches.length === 1 ? matches[0] : null;
}
export function groupMeasurements(rows, query='', filter='all') {
  const groups = new Map();
  for (const row of rows) {
    if (row.record_type !== 'measurement' || !normalize(row.test_name).includes(normalize(query))) continue;
    if (filter === 'review' && row.acceptance_state === 'eligible') continue;
    if (filter === 'flagged' && (row.acceptance_state !== 'eligible' || !['high','low','abnormal','critical'].includes(row.status))) continue;
    const source = normalize(`${row.panel || ''} ${row.specimen || ''}`);
    let group = /urine|urinalysis/.test(source) ? 'Urine' : /blood count|cbc|hemogram|haematolog|hematolog/.test(source) ? 'Blood count' :
      /kidney|renal/.test(source) ? 'Kidney function' : /liver|hepatic/.test(source) ? 'Liver function' :
      /lipid/.test(source) ? 'Lipids' : /thyroid/.test(source) ? 'Thyroid' : /vitamin|iron/.test(source) ? 'Iron & vitamins' : 'Other results';
    if(group === 'Other results') {
      const name = normalize(row.canonical_test || row.test_name);
      if(/creatinine|egfr|urea|bun/.test(name))group='Kidney function';
      else if(/tsh|thyroid/.test(name))group='Thyroid';
      else if(/vitamin|ferritin|iron/.test(name))group='Iron & vitamins';
      else if(/hemoglobin|wbc|rbc|platelet|hematocrit/.test(name))group='Blood count';
    }
    if(!groups.has(group))groups.set(group,[]);
    groups.get(group).push(row);
  }
  return [...groups].map(([name,rows])=>({name,rows}));
}
// ---------------------------------------------------------------- body systems
// Names only: a number, unit or range can never choose an organ. Latin names
// are matched as whole words after accents are removed; other scripts by the
// printed term. The same table lives in lib/body_systems.dart.
const fold = value => normalize(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/ß/g, 'ss');
const SYSTEMS = [
  ['urine', 'specific gravity|ph|pus cells?|ketones?|nitrites?|leuko?cyte esterase|urobilinogen|epithelial cells?|casts?|crystals?|urinalysis|urine (?:protein|glucose|sugar|blood|ph|ketones?|albumin|rbc|wbc|culture)',
    ['मूत्र', 'पेशाब', '尿蛋白', '尿糖', '尿比重', '尿潜血', '요단백', '요비중']],
  ['kidneys', 'creatinine?|creatinina|kreatinin|e\\s*-?\\s*gfr|gfr|glomerular filtration(?: rate)?|urea|uree|ureia|harnstoff|ureico|bun|(?:blood )?urea nitrogen|uric acid|acido urico|acide urique|harnsaure|urine albumin|microalbumin(?:uria)?|cystatin c',
    ['क्रिएटिनिन', 'क्रिएटिनीन', 'यूरिया', 'यूरिक एसिड', '肌酐', '尿素', '尿酸', '肾小球滤过率', '크레아티닌', '요소질소', '요산', '사구체', 'クレアチニン', '糸球体']],
  ['salts', 'sodium|sodio|natrium|potassium|potasio|potassio|kalium|chlorides?|chlorid|cloruro|cloreto|bicarbonate|bicarbonato|magnesium|magnesio|phosphate|phosphorus|fosforo|fosfato|electrolytes?|anion gap',
    ['सोडियम', 'पोटैशियम', 'पोटेशियम', 'क्लोराइड', '钠', '钾', '氯', '나트륨', '칼륨', '염소', 'ナトリウム', 'カリウム', 'クロール']],
  ['bones', 'vitamin[ae]?[ -]?(?:b[ -]?12|d[ -]?(?:2|3)?)|(?:25[ -]?(?:oh|hydroxy)[ -]?)vitamin[ae]?[ -]?d|b[ -]?12|cobalamin|calcium|calcio|kalzium|calciferol|folate|folic acid|acido folico|folsaure',
    ['विटामिन', 'कैल्शियम', '维生素', '血钙', '钙', '비타민', '칼슘', 'ビタミン', 'カルシウム', '葉酸']],
  ['sugar', 'hba1c|hb[ -]?a1c|a1c|glycated (?:haemoglobin|hemoglobin)|glycosylated (?:haemoglobin|hemoglobin)|hemoglobin[ae]? (?:glicosilada|glucosilada|glicada|glyquee)|glucose|glucosa|glukose|glicose|glicemia|glucemia|glycemie|blood sugar|fasting (?:blood )?sugar|fbs|rbs|ppbs|sugar',
    ['शुगर', 'ग्लूकोज', 'ग्लूकोज़', '血糖', '葡萄糖', '糖化血红蛋白', '혈당', '당화혈색소', 'グルコース', 'ヘモグロビンa1c']],
  ['thyroid', 'tsh|t[ -]?[34]|ft[ -]?[34]|thyroid|thyroxine?|triiodothyronine|tirotropina|tiroxina|thyreotropin|thyrotropin|thyreoidea',
    ['थायरॉइड', 'थायराइड', '甲状腺', '促甲状腺激素', '갑상선', '甲狀腺']],
  ['heart', 'cholesterol|colesterol|cholesterin|hdl(?:[ -]c)?|ldl(?:[ -]c)?|non[- ]hdl|vldl|triglycerides?|triglyceride|trigliceridos|triglicerideos|triglicerides|apolipoprotein|lipoprotein|troponin|ck[- ]?mb|nt[- ]?probnp|bnp|blood pressure|bp|pulse(?: rate)?|heart rate',
    ['कोलेस्ट्रॉल', 'ट्राइग्लिसराइड', '胆固醇', '甘油三酯', '脂蛋白', '콜레스테롤', '중성지방', 'コレステロール', '中性脂肪']],
  ['lungs', 'respiratory rate|respiration|breaths?|spo2|oxygen saturation|frecuencia respiratoria',
    ['श्वसन', 'सांस', '呼吸', '血氧', '호흡']],
  ['liver', 'bilirubine?|bilirrubina|alt|ast|sgpt|sgot|gpt|got|tgo|tgp|asat|alat|albumine?|albumina|alp|alkaline phosphatase|fosfatasa alcalina|fosfatase alcalina|phosphatases? alcalines?|ggt|gamma[- ]?gt|gamma glutamyl|total protein|proteinas totales|globulin|liver',
    ['बिलीरुबिन', 'एल्बुमिन', 'लिवर', '胆红素', '转氨酶', '白蛋白', '碱性磷酸酶', '빌리루빈', '알부민', 'ビリルビン', 'アルブミン', 'γ-gt', 'γgt']],
  ['blood', 'ha?emoglobin[ae]?|hamoglobin|hgb|hb|rbc|wbc|platelets?|plaquetas|plaquettes|thrombozyten|ferritin[ae]?|iron|hierro|eisen|ferro|mcv|mchc?|rdw|ha?ematocrit[eo]?|hamatokrit|hct|pcv|leu[ck]o[cs]ytes?|leucocitos|leukozyten|erythrocytes?|eritrocitos|erythrozyten|hematies|neutrophils?|lymphocytes?|monocytes?|eosinophils?|basophils?|mpv|pdw|reticulocytes?|tibc|transferrin[ae]?|esr|crp|c[- ]reactive protein',
    ['हीमोग्लोबिन', 'हिमोग्लोबिन', 'प्लेटलेट', 'आयरन', 'खून', '血红蛋白', '红细胞', '白细胞', '血小板', '铁蛋白', '血清铁', '혈색소', '헤모글로빈', '백혈구', '적혈구', '혈소판', '페리틴', 'ヘモグロビン', '白血球', '赤血球', 'フェリチン', '血色素']],
].map(([organ, pattern, aliases]) => ({organ, pattern: new RegExp(`(?:^|[^a-z0-9])(?:${pattern})(?:$|[^a-z0-9])`), aliases: aliases.map(fold)}));

/** The body system a test name belongs to, or null when the name does not say. */
export function bodySystemFor(name, row) {
  const text = fold(name);
  if (!text) return null;
  const urineSample = /urine|urinalysis|urinary|orina|urina\b|harn\b/.test(fold(`${row?.specimen || ''} ${row?.panel || ''}`))
    || /(?:^|[^a-z])(?:urine|urinary|orina)(?:$|[^a-z])/.test(text) && !/albumin|creatinin/.test(text);
  if (urineSample) return 'urine';
  for (const system of SYSTEMS) {
    if (system.pattern.test(text) || system.aliases.some(alias => text.includes(alias))) return system.organ;
  }
  return null;
}

const SYSTEM_URLS = {
  kidneys: 'https://medlineplus.gov/lab-tests/creatinine-test/', blood: 'https://medlineplus.gov/lab-tests/complete-blood-count-cbc/',
  sugar: 'https://medlineplus.gov/lab-tests/blood-glucose-test/', heart: 'https://medlineplus.gov/cholesterollevelswhatyouneedtoknow.html',
  liver: 'https://medlineplus.gov/lab-tests/liver-function-tests/', thyroid: 'https://medlineplus.gov/thyroidtests.html',
  bones: 'https://medlineplus.gov/lab-tests/', lungs: 'https://medlineplus.gov/vitalsigns.html', salts: 'https://medlineplus.gov/lab-tests/electrolyte-panel/',
  urine: 'https://medlineplus.gov/urinalysis.html',
};
const SYSTEM_ART = {kidneys:'kidneys', blood:'blood', sugar:'cells', heart:'circulation', liver:'liver', thyroid:'thyroid', bones:'bones', salts:'salts', urine:'urine', lungs:'lungs'};
const SYSTEM_COPY = {
  kidneys: ['Kidneys', 'This test is one of the checks linked to the kidneys. They filter waste and extra water out of the blood and pass it out in urine.'],
  blood: ['Blood cells', 'This test looks at the blood itself: the cells that carry oxygen, fight infection and help blood clot, or the iron they need.'],
  sugar: ['Blood glucose', 'This test is about glucose, the sugar that fuels your cells, and how the body keeps its level steady.'],
  heart: ['Heart & blood vessels', 'This test is linked to the heart and blood vessels. Fats such as cholesterol travel in the blood that the heart pumps around the body.'],
  liver: ['Liver', 'This test is one of the checks linked to the liver. It cleans the blood, makes proteins and helps digest food.'],
  thyroid: ['Thyroid', 'This test is linked to the thyroid, a small gland in the neck that sets how fast the body uses energy.'],
  bones: ['Bones, nerves & vitamins', 'This test measures a vitamin or mineral the body uses to keep bones strong and nerves and blood working.'],
  salts: ['Salts & fluid balance', 'This test measures one of the body’s salts. They keep the amount of water steady and help nerves, muscles and the heart work.'],
  lungs: ['Lungs & breathing', 'This is about breathing. The lungs bring oxygen into the blood and remove carbon dioxide.'],
  urine: ['Kidneys & urine', 'This is a urine test. Urine is made by the kidneys, stored in the bladder and carries waste out of the body.'],
};

/** General education about the body system when no test-specific text exists. */
export function systemEducation(name, row) {
  const organ = bodySystemFor(name, row);
  if (!organ) return null;
  return {systemLevel: true, organKey: organ, organ: SYSTEM_ART[organ], system: SYSTEM_COPY[organ][0], title: SYSTEM_COPY[organ][0],
    terms: [`system_${organ}`], measures: SYSTEM_COPY[organ][1],
    context: 'This is general information about this part of the body, not a reading of your result. Your clinician looks at this test together with your other results and your history.',
    question: 'What does this result mean for me, together with my other results?', url: SYSTEM_URLS[organ]};
}

export function educationForMeasurement(row) {
  if (row?.record_type !== 'measurement' || row.acceptance_state !== 'eligible') return null;
  const system = systemEducation(row.test_name, row);
  // A urine sample never borrows a blood test's explanation.
  if (system?.organKey === 'urine') return system;
  return educationFor(row.test_name) || system;
}

const tests = [
  {terms:['creatinine'], organ:'kidneys', system:'Kidneys', title:'Creatinine',
    measures:'Creatinine is a waste product from muscle activity. The kidneys filter it from the blood and remove it in urine.',
    context:'A doctor may consider creatinine alongside eGFR, other tests and your history. Muscle mass, food, activity and medicines can affect the result.',
    question:'How does this result compare with my previous creatinine and eGFR results?',
    url:'https://medlineplus.gov/lab-tests/creatinine-test/'},
  {terms:['egfr','glomerular filtration rate','glomerular filtration'], organ:'kidneys', system:'Kidneys', title:'Estimated filtration',
    measures:'eGFR estimates how quickly the kidneys filter waste from blood. Creatinine is often used in this calculation.',
    context:'Your clinician considers the estimate with other kidney tests and your medical history.',
    question:'Which other kidney results should we consider with this estimate?',
    url:'https://medlineplus.gov/lab-tests/creatinine-test/'},
  {terms:['hba1c','a1c','hemoglobin a1c','glycated hemoglobin'], organ:'cells', system:'Blood glucose', title:'HbA1c',
    measures:'HbA1c measures glucose attached to hemoglobin and reflects average blood glucose over about three months.',
    context:'Your clinician interprets this with your history and other glucose tests.',
    question:'How does this relate to my other glucose results?', url:'https://medlineplus.gov/lab-tests/diabetes-tests/'},
  {terms:['glucose','blood sugar'], organ:'cells', system:'Blood glucose', title:'Glucose',
    measures:'Glucose is a sugar that supplies energy to your cells. This test measures how much is in your blood.',
    context:'The type of glucose test and whether you were fasting matter. Your clinician may compare this with other tests and your history.',
    question:'Was this a fasting or random test, and how does that affect its interpretation?', url:'https://medlineplus.gov/lab-tests/blood-glucose-test/'},
  {terms:['hemoglobin','haemoglobin','hgb','hb'], organ:'blood', system:'Blood cells', title:'Hemoglobin',
    measures:'Hemoglobin is the protein in red blood cells that carries oxygen around your body.',
    context:'A doctor considers it with other blood counts, symptoms and history.',
    question:'What do the other blood counts add to this result?', url:'https://medlineplus.gov/lab-tests/complete-blood-count-cbc/'},
  {terms:['wbc','white blood','leukocyte','leucocyte'], organ:'blood', system:'Blood cells', title:'White blood cells',
    measures:'White blood cells help the body fight infections and other diseases. This test counts those cells.',
    context:'Medicines and other factors can affect the count. Your clinician considers the other blood results and your symptoms.',
    question:'How does this count fit with the rest of my blood report?', url:'https://medlineplus.gov/lab-tests/complete-blood-count-cbc/'},
  {terms:['platelet','platelets','plt'], organ:'blood', system:'Blood cells', title:'Platelets',
    measures:'Platelets help blood clot and stop bleeding. This test measures their number.',
    context:'The count is interpreted with the rest of the report, symptoms and history.',
    question:'Do my other results change how you interpret this count?', url:'https://medlineplus.gov/lab-tests/complete-blood-count-cbc/'},
  {terms:['rbc','red blood','hematocrit','haematocrit','mcv'], organ:'blood', system:'Blood cells', title:'Blood cell measurement',
    measures:'These tests describe the number, size or proportion of red blood cells, which carry oxygen around the body.',
    context:'Your clinician considers these measurements together with hemoglobin and your history.',
    question:'What does the pattern of my blood counts show?', url:'https://medlineplus.gov/lab-tests/complete-blood-count-cbc/'},
  {terms:['cholesterol','ldl','hdl','triglyceride'], organ:'circulation', system:'Blood & circulation', title:'Blood lipids',
    measures:'A lipid panel measures cholesterol and other fats in the blood.',
    context:'A doctor considers the different lipid measurements with other factors affecting heart health.',
    question:'How do the different lipid results fit together in my situation?', url:'https://medlineplus.gov/cholesterollevelswhatyouneedtoknow.html'}
];
export function educationFor(name) {
  const text = fold(name).replace(/\([^)]*\)/g,' ').replace(/\s+/g,' ').trim();
  // Ratios, antibodies and receptors are different tests from the one named.
  if (!text || /ratio|\/|anti|receptor|urine|urinary/.test(text)) return null;
  return tests.find(test => test.terms.some(term => new RegExp(`(?:^|[^a-z0-9])${escape(term)}(?:$|[^a-z0-9])`).test(text))) || null;
}
