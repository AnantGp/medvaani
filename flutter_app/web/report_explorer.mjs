import {getDocument, GlobalWorkerOptions, Util} from './vendor/pdfjs/pdf.mjs';
import {safeBox, resultLabel, educationForMeasurement, selectedMeasurement, sourceSelection, groupMeasurements, sourceAtPoint} from './report_explorer_core.mjs';
GlobalWorkerOptions.workerSrc = new URL('./vendor/pdfjs/pdf.worker.mjs', location.href).href;
const $ = selector => document.querySelector(selector);
const canvas = $('#document'), photo = $('#photo'), stage = $('#stage'), overlay = $('#highlights');
const inspector = $('#inspector'), status = $('#status'), scroller = $('#scroller');
const pageSelect = $('#page'), previous = $('#previous'), next = $('#next');
let report = {}, labs = [], sources = [], layout = [], pdf, current = 1, renderTask;
let lines = [], selection, zoom = 1, renderVersion = 0, selectionVersion = 0;
let recoveryAttempted = false, recoveryWork, sourceUrl;
const pageLines = new Map();
const sourceOnly = new URLSearchParams(location.search).get('mode') === 'source';
if(sourceOnly) document.documentElement.classList.add('source-only');
const photoMode = new URLSearchParams(location.search).get('type') === 'photo';
const text = (tag, value, className) => {
  const node = document.createElement(tag); node.textContent = String(value ?? '');
  if (className) node.className = className; return node;
};
function sendHeight() {
  if (parent !== window) parent.postMessage(JSON.stringify({type:'medivaanii-explorer-height',height:Math.ceil(document.body.scrollHeight)}), location.origin);
}
new ResizeObserver(sendHeight).observe(document.body);
addEventListener('message', event => {
  if (event.origin !== location.origin || event.source !== parent || typeof event.data !== 'string') return;
  let message; try { message = JSON.parse(event.data); } catch (_) { return; }
  if (message.type !== 'medivaanii-explorer-report' || !message.report || typeof message.report !== 'object') return;
  report = message.report;
  let parsed = report.parsed_data; try { if(typeof parsed === 'string') parsed = JSON.parse(parsed); } catch (_) { parsed = {}; }
  labs = report.extraction_version === 4 && parsed?.schema_version === 4 && Array.isArray(parsed?.lab_values) ? parsed.lab_values.filter(row=>row.record_type === 'measurement' && row.measurement_id) : [];
  sources = Array.isArray(report.source_evidence) ? report.source_evidence : [];
  const incomingLayout = Array.isArray(report.source_layout) ? report.source_layout.filter(line => safeBox(line.box)) : [];
  if (!layout.length || incomingLayout.length) layout = incomingLayout;
  $('#filename').textContent = message.filename || 'Your uploaded report';
  if (message.language && message.language !== 'English') {
    $('.intro p').textContent = 'Tap a number to explore its source. Test education is currently available in English.';
  } else $('.intro p').textContent = 'Tap a number in your report. See its source and what the test measures.';
  if(selection?.id && !selectedMeasurement(labs,selection.id)) selection=null;
  makeSelectors();
  const id=report.voice_cited_measurement_ids?.[0] || report.selected_measurement_id || selection?.id || labs[0]?.measurement_id;
  if(pdf || photo.naturalWidth){if(id)locateLab(id);else render();}else drawHighlights();
});
if(parent !== window) parent.postMessage(JSON.stringify({type:'medivaanii-explorer-ready'}),location.origin);

function makeSelectors() {
  $('#tests').replaceChildren();
  const quality=report.extraction_quality || {};
  $('#coverage').textContent = `${quality.state === 'partial' ? 'Partial extraction · ' : ''}${quality.eligible_count || 0} usable · ${quality.needs_review_count || 0} need review`;
  const groups=groupMeasurements(labs,$('#search').value,$('#filter').value);
  if(!groups.length)$('#tests').append(text('p',labs.length?'No measurements match this filter.':'No verified patient measurements are available. Read the original again.','list-empty'));
  for(const group of groups) {
    const heading = text('h3',`${group.name} · ${group.rows.length}`,'group-heading');$('#tests').append(heading);
    for(const lab of group.rows) {
      const button=text('button','', 'result-option'), name=text('span',lab.test_name,'test-name');
      const value=text('span',`${lab.value ?? ''} ${lab.unit ?? ''}`.trim(),'test-value');
      const flag=text('small',lab.acceptance_state==='eligible'?resultLabel(lab):'Needs source review','test-state');
      button.append(name,value,flag);button.dataset.measurementId=lab.measurement_id;
      button.setAttribute('aria-label',`Explore ${lab.test_name}`);button.setAttribute('aria-pressed',String(lab.measurement_id===selection?.id));
      button.onclick=()=>locateLab(lab.measurement_id,'value',true);$('#tests').append(button);
    }
  }
}
$('#search').oninput=makeSelectors;$('#filter').onchange=makeSelectors;
async function digitalLines(pageNumber) {
  if (pageLines.has(pageNumber)) return pageLines.get(pageNumber);
  const page = await pdf.getPage(pageNumber), viewport = page.getViewport({scale:1});
  const content = await page.getTextContent();
  const groups = [];
  for (const item of content.items) {
    if (!item.str?.trim() || !item.transform) continue;
    const transform = Util.transform(viewport.transform, item.transform);
    // Unsupported vertical/rotated text stays visible but is not given an
    // invented horizontal hit area.
    if (Math.abs(transform[1]) > Math.abs(transform[0]) * .15) continue;
    const height = Math.hypot(transform[2],transform[3]) || item.height || 10;
    // The PDF's glyph baseline and ascent determine the visible source row.
    const ascent = content.styles[item.fontName]?.ascent ?? .82;
    const x = transform[4], y = transform[5] - height * ascent;
    const width = Math.max(item.width, 1);
    let group = groups.find(group => Math.abs(group.baseline - transform[5]) < Math.max(2, height * .22));
    if (!group) { group = {baseline:transform[5],items:[]}; groups.push(group); }
    group.items.push({text:item.str,x,y,width,height});
  }
  const result = groups.sort((a,b) => a.baseline-b.baseline).map(group => {
    const words = group.items.sort((a,b) => a.x-b.x);
    const left = Math.min(...words.map(item=>item.x)), top = Math.min(...words.map(item=>item.y));
    const right = Math.max(...words.map(item=>item.x+item.width)), bottom = Math.max(...words.map(item=>item.y+item.height));
    return {page:pageNumber,method:'pdf_text',text:words.map(item=>item.text).join(' '),box:[left/viewport.width,top/viewport.height,(right-left)/viewport.width,(bottom-top)/viewport.height]};
  }).filter(line => safeBox(line.box));
  pageLines.set(pageNumber,result); return result;
}
async function linesFor(pageNumber) {
  if (photoMode) { await recoverLocations(); return layout.filter(line=>line.page === 1); }
  const digital = await digitalLines(pageNumber);
  if(digital.some(line=>/\d/.test(line.text))) return digital;
  await recoverLocations(); return layout.filter(line=>line.page === pageNumber);
}
async function recoverLocations() {
  if (recoveryWork) return recoveryWork;
  if (layout.length || recoveryAttempted || !sourceUrl || !report.parsed_data) return;
  recoveryAttempted = true;
  status.textContent = 'Locating text in the original image…';
  recoveryWork = (async () => { try {
    const source = await (await fetch(sourceUrl)).blob();
    const form = new FormData();
    form.append('file',source,photoMode?'original.jpg':'original.pdf');
    const response = await fetch('/api/report/source-layout',{method:'POST',body:form,signal:AbortSignal.timeout(120000)});
    if(!response.ok) throw new Error('Source unavailable');
    const result = await response.json();
    layout = Array.isArray(result.source_layout) ? result.source_layout.filter(line=>safeBox(line.box)) : [];
    if (layout.length && parent !== window) parent.postMessage(JSON.stringify({type:'medivaanii-explorer-layout',layout}),location.origin);
  } catch (_) {
    $('#source-note').textContent = 'Source locations could not be recovered. Upload a clearer photo or PDF to select its values.';
  } })().finally(() => { recoveryWork = null; });
  return recoveryWork;
}
async function locateLab(id, field='value', userInitiated=false) {
  const version = ++selectionVersion;
  const row=selectedMeasurement(labs,id), evidence=sources.find(source=>source.measurement_id===id);
  const source=sourceSelection(row);
  const selectedField=source?.fields[field];
  const canLocate=source && selectedField && safeBox(selectedField.box) && selectedField.page <= (pdf?.numPages || 1);
  selection={id,field,line:canLocate?{page:selectedField.page,box:selectedField.box,method:selectedField.method,
    text:evidence?.source_quote || row.source_quote || Object.values(source.fields).map(f=>f.text).join(' ')}:null};
  if(canLocate){current=selectedField.page;pageSelect.value=current;await render();if(version!==selectionVersion)return;scrollToSelection();}
  else drawHighlights();
  showInspector();makeSelectors();focusSection(inspector);
  if(parent!==window)parent.postMessage(JSON.stringify({type:'medivaanii-explorer-selection',measurement_id:id,user_initiated:userInitiated,page:canLocate?current:null,source_fields:row?.source_fields || {}}),location.origin);
}
function chooseLine(line) {
  ++selectionVersion;
  // Unmatched PDF text remains visible without an organ or result binding.
  selection={line};drawHighlights();showInspector();focusSection(inspector);
}
function focusSection(section) {
  if(matchMedia('(max-width:720px)').matches && parent !== window) {
    parent.postMessage(JSON.stringify({type:'medivaanii-explorer-focus',top:section.getBoundingClientRect().top+scrollY}),location.origin);
  }
}
function drawHighlights() {
  if(photoMode && photo.naturalWidth)lines=layout.filter(line=>line.page===1);
  overlay.replaceChildren();let count=0;
  for(const row of labs) {
    const source=sourceSelection(row);if(!source)continue;
    for(const [key,field] of Object.entries(source.fields)) {
      if(field.page!==current)continue;
      for(const box of field.boxes || [field.box]) {
        if(!safeBox(box))continue;
        const [x,y,w,h]=box;
        if(sourceAtPoint(labs,current,x+w/2,y+h/2)?.measurement_id!==row.measurement_id)continue;
        const button=document.createElement('button');button.className='source-line source-cell';
        button.style.left=x*100+'%';button.style.top=y*100+'%';button.style.width=w*100+'%';button.style.height=h*100+'%';
        button.dataset.measurementId=row.measurement_id;button.dataset.field=key;
        button.setAttribute('aria-label',`Select original ${row.test_name} ${key.replaceAll('_',' ')}: ${field.text}`);
        button.title=`${row.test_name} · ${key.replaceAll('_',' ')}`;
        const selected=selection?.id===row.measurement_id;button.setAttribute('aria-pressed',String(selected));if(selected)button.classList.add('selected');if(report.voice_cited_measurement_ids?.includes(row.measurement_id))button.classList.add('voice-cited');
        button.onclick=()=>locateLab(row.measurement_id,key,true);overlay.append(button);count++;
      }
    }
  }
  // Reading an unmatched line is allowed; it does not gain a clinical binding.
  if(!labs.length)for(const line of lines.filter(line=>/\d/.test(line.text) && safeBox(line.box))) {
    const button=document.createElement('button');button.className='source-line';const [x,y,w,h]=line.box;
    Object.assign(button.style,{left:x*100+'%',top:y*100+'%',width:w*100+'%',height:h*100+'%'});
    button.setAttribute('aria-label',`Read original source line: ${line.text}`);button.onclick=()=>chooseLine(line);overlay.append(button);
  }
  const vision=lines.some(line=>line.method==='groq_vision') || labs.some(row=>Object.values(row.source_fields||{}).some(field=>field.page===current && field.method==='groq_vision'));
  const ocr=lines.some(line=>line.method==='ocr');$('#method').textContent=vision?'AI-estimated row locations':ocr?'OCR locations':photoMode?'Photo':'PDF source';
  $('#source-note').textContent=vision?'AI estimates these row locations. Compare the original image and check each field before relying on it.':ocr?'OCR may misread characters. Check every photo field before using its explanation.':count?'Outlines mark exact original result cells; selecting a measurement highlights its name, value, unit and supplied reference.':'No source-backed measurement locations are available on this page.';
  for(const button of document.querySelectorAll('#tests button'))button.setAttribute('aria-pressed',String(button.dataset.measurementId===selection?.id));
}
function scrollToSelection() {
  const button = overlay.querySelector('.selected');
  if(button) scroller.scrollTop = Math.max(0,button.offsetTop-scroller.clientHeight*.35);
}

function illustration(organ, label) {
  const figure = document.createElement('figure'); figure.className = 'organ';
  const svg = document.createElementNS('http://www.w3.org/2000/svg','svg');
  svg.setAttribute('viewBox','0 0 320 170'); svg.setAttribute('role','img'); svg.setAttribute('aria-label',`Simplified ${label.toLowerCase()} illustration; not a diagnosis`);
  const art = {
    kidneys:`<path d="M148 12v76m24-76v76" stroke="#b68c86" stroke-width="5" stroke-linecap="round"/><path d="M149 60c-17-6-25-8-42-8m65 8c17-6 25-8 42-8" fill="none" stroke="#b68c86" stroke-width="4"/><path d="M101 27c-28-12-51 15-49 46 2 33 25 50 46 40 17-8 24-24 13-32-15-10-14-21-3-30 9-9 4-19-7-24z" fill="#d8e3d8" stroke="#4d6b5e" stroke-width="2.5"/><path d="M219 27c28-12 51 15 49 46-2 33-25 50-46 40-17-8-24-24-13-32 15-10 14-21 3-30-9-9-4-19 7-24z" fill="#d8e3d8" stroke="#4d6b5e" stroke-width="2.5"/><path d="M83 42c-17 7-23 31-10 52m164-52c17 7 23 31 10 52" fill="none" stroke="#a9bcaa" stroke-width="4" stroke-linecap="round"/><path d="M110 78c17 0 22 21 25 44 1 11 9 21 18 22m57-66c-17 0-22 21-25 44-1 11-9 21-18 22" fill="none" stroke="#839d87" stroke-width="2.5"/><path d="M145 142q15-14 30 0c5 18-6 24-15 24s-20-6-15-24z" fill="#e2e9df" stroke="#839d87" stroke-width="2"/><path d="M66 135h49m90 0h49" stroke="#c8d4c8"/>`,
    blood:`<path d="M15 50q140-45 290 0v72q-150 40-290 0z" fill="#f2e5df" stroke="#d8bdb3" stroke-width="2"/><g fill="#c98b82" stroke="#a76961" stroke-width="2"><ellipse cx="65" cy="86" rx="26" ry="17" transform="rotate(-20 65 86)"/><ellipse cx="151" cy="105" rx="25" ry="17" transform="rotate(15 151 105)"/><ellipse cx="248" cy="75" rx="25" ry="17" transform="rotate(-13 248 75)"/></g><g fill="#e7b3aa"><ellipse cx="65" cy="86" rx="12" ry="6"/><ellipse cx="151" cy="105" rx="11" ry="6"/><ellipse cx="248" cy="75" rx="11" ry="6"/></g><circle cx="188" cy="65" r="20" fill="#d9e2d9" stroke="#8caa95" stroke-width="2"/><path d="M179 58q16-10 17 6t-16 7q-9-7-1-13" fill="#9aafa0"/><g fill="#c9aa83"><circle cx="107" cy="67" r="4"/><circle cx="220" cy="110" r="4"/><circle cx="291" cy="95" r="4"/></g>`,
    cells:`<circle cx="210" cy="85" r="57" fill="#dce6da" stroke="#78977e" stroke-width="2.5"/><circle cx="216" cy="85" r="21" fill="#bfcebe" stroke="#78977e" stroke-width="2"/><g fill="#c6a978" stroke="#aa8b5d"><circle cx="42" cy="60" r="7"/><circle cx="70" cy="90" r="7"/><circle cx="45" cy="117" r="7"/><circle cx="97" cy="58" r="7"/></g><path d="M102 91h43m-9-8 9 8-9 8" fill="none" stroke="#839b88" stroke-width="2.5" stroke-linecap="round"/>`,
    circulation:`<path d="M159 40c-19-33-57-17-57 12 0 29 32 55 57 73 25-18 57-44 57-73 0-29-38-45-57-12z" fill="#d7a29a" stroke="#a56b62" stroke-width="2.5"/><path d="M159 8v20m-84 51H38m206 0h38m-124 55v26" stroke="#9eada1" stroke-width="2.5" stroke-linecap="round"/><circle cx="37" cy="79" r="7" fill="#d8e4d8" stroke="#839d87"/><circle cx="283" cy="79" r="7" fill="#d8e4d8" stroke="#839d87"/>`
  };
  // Only constant, locally authored SVG markup is inserted here.
  svg.innerHTML = art[organ] || art.blood;
  figure.append(svg,text('figcaption',label),text('small','Simplified illustration · General education')); return figure;
}
function showInspector() {
  inspector.replaceChildren(); inspector.classList.remove('reveal'); void inspector.offsetWidth; inspector.classList.add('reveal');
  const back = text('button','View selected source','back-source');
  back.onclick=()=>{if(selection?.id)locateLab(selection.id);focusSection($('.document-pane'));}; inspector.append(back);
  const row = selectedMeasurement(labs,selection?.id), evidence = sources.find(source=>source.measurement_id === selection?.id);
  const line = selection?.line;
  const original = evidence?.original_fields;
  const reviewed = row && (original && ['test_name','value','unit','reference_range','status'].some(key=>String(original[key]??'') !== String(row[key]??'')) || ['user_review','reviewed_range'].includes(row.status_source));
  const primary=original && line ? {...original,acceptance_state:row?.acceptance_state} : row;

  inspector.append(text('h2',primary?.test_name || 'Original source line','result-title'));
  if(row) {
    const value = text('div',primary.value,'result-value'); value.append(text('span',primary.unit)); inspector.append(value);
    const flag = text('div',resultLabel(primary),'flag'); if(['high','low','critical','abnormal'].includes(primary.status)) flag.classList.add('flagged'); inspector.append(flag);
    if(primary.reference_range) inspector.append(text('p',`Reference shown: ${primary.reference_range}`,'range'));
    if(reviewed) {
      const correction = document.createElement('div'); correction.className = 'reviewed-value';
      correction.append(text('div','Reviewed value','label'),text('p',`${row.test_name}: ${row.value} ${row.unit || ''}`.trim()),text('small',resultLabel(row)),text('small','Your correction is kept separately. The original document is unchanged.'));
      inspector.append(correction);
    }
  }
  const sourceBox = document.createElement('div'); sourceBox.className = 'source-box';
  sourceBox.append(text('div',line?`Report source · Page ${line.page}`:'Report source','label'));
  sourceBox.append(text('p',line?.text || evidence?.source_quote || 'No exact source quote is available for this result.','source-quote'));
  sourceBox.append(text('p',line ? line.page!==current ? `This source is on page ${line.page}. Select that page to see its highlight.` : line.method === 'groq_vision' ? 'AI-estimated row location. Confirm this text against the original image; this is not an exact source-cell match.' : line.method === 'ocr' ? 'Highlighted at its OCR location. Confirm the number in the image.' : 'This is the highlighted text in your original PDF.' : 'Extracted quote only. Its position in the original has not been confirmed.','source-detail'));
  inspector.append(sourceBox);
  if(!line) inspector.append(text('p','We could not uniquely match an exact source line. Check the original report; no highlight has been placed.','unmatched'));
  const qualityAllowed=['ready','partial'].includes(report.extraction_quality?.state);
  const education=qualityAllowed ? educationForMeasurement(row) : null;
  if(row) {
    const edit=text('button',row.acceptance_state==='eligible'?'Correct a field':'Check or correct source fields','edit-result');
    edit.onclick=()=>{if(parent!==window)parent.postMessage(JSON.stringify({type:'medivaanii-explorer-edit',measurement_id:row.measurement_id,page:line?.page,source_fields:row.source_fields}),location.origin);};
    inspector.append(edit);
    if(row.acceptance_state!=='eligible')inspector.append(text('p','This reading is excluded from explanations until its source fields are checked. A general confirmation does not resolve unreadable or incompatible fields.','unmatched'));
  }
  if(education) {
    inspector.append(illustration(education.organ,education.system));
    const title = document.createElement('div'); title.className = 'education-title'; title.append(text('h3','What this measures'),text('span','General education','label')); inspector.append(title);
    inspector.append(text('p',education.measures,'education-copy'));
    inspector.lastChild.style.cssText = 'font-size:16px;line-height:1.75;margin-top:7px';
    const context = document.createElement('div'); context.className = 'education-block'; context.append(text('h3','Why context matters'),text('p',education.context)); inspector.append(context);
    inspector.append(text('p','One result alone does not establish a diagnosis. The illustration explains the test, rather than showing the condition of your organs.','context-note'));
    const question = document.createElement('div'); question.className = 'doctor-question'; question.append(text('div','A question for your doctor','label'),text('p',education.question)); inspector.append(question);
    const reference = text('a','Education reference · MedlinePlus','reference'); reference.href=education.url; reference.target='_blank'; reference.rel='noopener noreferrer'; inspector.append(reference);
  } else {
    inspector.append(text('p',row ? 'A specific educational explanation is not available for this test yet. Your source value remains visible above.' : 'This line has not been matched to an extracted laboratory result. We have shown the source without inventing a test or interpretation.','unmatched'));
  }
  sendHeight();
}

async function render() {
  const version = ++renderVersion;
  if(renderTask) {renderTask.cancel();try{await renderTask.promise;}catch(_){} }
  const width = Math.max(220,scroller.clientWidth - (matchMedia('(max-width:720px)').matches?24:40)) * zoom;
  stage.style.width = width+'px';
  if(photoMode) {if(photo.naturalWidth){stage.style.height = width * photo.naturalHeight/photo.naturalWidth+'px';await recoverLocations();lines=layout.filter(line=>line.page===1);drawHighlights();status.textContent='';}return;}
  if(!pdf) return;
  previous.disabled=current<=1; next.disabled=current>=pdf.numPages;
  const page = await pdf.getPage(current); if(version!==renderVersion)return;
  const base = page.getViewport({scale:1}), viewport = page.getViewport({scale:width/base.width});
  const ratio=Math.min(devicePixelRatio||1,2); canvas.width=Math.floor(viewport.width*ratio); canvas.height=Math.floor(viewport.height*ratio);
  canvas.style.width=viewport.width+'px';canvas.style.height=viewport.height+'px';stage.style.height=viewport.height+'px';
  canvas.setAttribute('aria-label',`Page ${current} of ${pdf.numPages} of original report`);
  renderTask=page.render({canvasContext:canvas.getContext('2d'),viewport,transform:ratio===1?null:[ratio,0,0,ratio,0,0]});
  try {await renderTask.promise; if(version!==renderVersion)return;lines=await linesFor(current);if(version!==renderVersion)return;drawHighlights();status.textContent='';}
  catch(error){if(error.name!=='RenderingCancelledException')status.textContent='This page could not be displayed. Check the original report.';}
}
function setZoom(value) {zoom=Math.max(.7,Math.min(3,value));$('#zoom').textContent=Math.round(zoom*100)+'% · Fit';render().then(scrollToSelection);}
$('#zoom').onclick=()=>setZoom(1);
$('#zoom-in').onclick=()=>setZoom(zoom+.2);
$('#zoom-out').onclick=()=>setZoom(zoom-.2);
function changePage(page) {++selectionVersion;current=page;pageSelect.value=current;render();if(selection)showInspector();}
pageSelect.onchange=()=>changePage(Number(pageSelect.value));previous.onclick=()=>changePage(current-1);next.onclick=()=>changePage(current+1);
let oldWidth = 0;
new ResizeObserver(()=>{const width=scroller.clientWidth;if(width!==oldWidth){oldWidth=width;render();}}).observe(scroller);
try {
  const url=decodeURIComponent(location.hash.slice(1));
  if(!url.startsWith('blob:'+location.origin+'/'))throw new Error('Invalid local source');
  sourceUrl = url;
  if(photoMode) {
    canvas.hidden=true; photo.hidden=false; photo.onload=()=>{const id=selection?.id || report.selected_measurement_id || labs[0]?.measurement_id;id?locateLab(id):render();}; photo.onerror=()=>{status.textContent='The original photo could not be displayed. Upload the report again.';};photo.src=url;
    const option=text('option','Photo · Page 1');option.value=1;pageSelect.append(option);
  } else {
    pdf=await getDocument({url,isEvalSupported:false,cMapUrl:new URL('./vendor/pdfjs/cmaps/',location.href).href,cMapPacked:true,standardFontDataUrl:new URL('./vendor/pdfjs/standard_fonts/',location.href).href,wasmUrl:new URL('./vendor/pdfjs/wasm/',location.href).href}).promise;
    for(let i=1;i<=pdf.numPages;i++){const option=text('option',`Page ${i} of ${pdf.numPages}`);option.value=i;pageSelect.append(option);}pageSelect.disabled=false;const id=selection?.id || report.selected_measurement_id || labs[0]?.measurement_id;id?await locateLab(id):await render();
  }
} catch (_) {status.textContent='The original document is unavailable. Upload your report again to use the explorer.';}
