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
    user_review:`${flag} · reviewed flag`, reviewed_range:`${flag} · reviewed range`, reviewed_source:`${flag} · checked source`})[row.status_source] || `${flag} · unconfirmed source`;
}

export const selectedMeasurement = (rows, id) => rows.find(row => row.measurement_id === id) || null;
export function sourceSelection(row) {
  if (row?.record_type !== 'measurement') return null;
  const fields = row.source_fields || {}, value = fields.value;
  if (!safeBox(value?.box) || !Number.isInteger(value.page) || value.page < 1) return null;
  return {measurement_id: row.measurement_id, page: value.page, fields};
}
export function sourceAtPoint(rows, page, x, y) {
  const matches = rows.filter(row => {
    const selection = sourceSelection(row);
    return selection && Object.values(selection.fields).some(field => field.page === page &&
      (field.boxes || [field.box]).some(box => safeBox(box) && x >= box[0] && x <= box[0]+box[2] && y >= box[1] && y <= box[1]+box[3]));
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
export function educationForMeasurement(row) {
  if (/urine|urinalysis/i.test(`${row?.specimen || ''} ${row?.panel || ''}`)) return null;
  return row?.record_type === 'measurement' && row.acceptance_state === 'eligible' ? educationFor(row.test_name) : null;
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
  const text = normalize(name).replace(/\([^)]*\)/g,'').replace(/\s+/g,' ').trim();
  const prefix = '(?:(?:serum|plasma|fasting|random|total|absolute|blood|estimated) )*';
  const suffix = '(?: (?:level|levels|count|counts|test|cells|cell|blood|serum|plasma|total))*';
  return tests.find(test => test.terms.some(term => new RegExp(`^${prefix}${escape(term)}${suffix}$`).test(text))) || null;
}
