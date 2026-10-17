import {getDocument, GlobalWorkerOptions, Util} from './vendor/pdfjs/pdf.mjs';
import {safeBox, educationForMeasurement, selectedMeasurement, sourceSelection, groupMeasurements, sourceAtPoint, fieldFragments} from './report_explorer_core.mjs';
import {sourceMimeType} from './source_document.mjs';
import {viewerLocale, translateViewer, localizedResultLabel, localizedGroupLabel, localizedFieldLabel, localizedEducation} from './report_explorer_i18n.mjs';
GlobalWorkerOptions.workerSrc = new URL('./vendor/pdfjs/pdf.worker.mjs', location.href).href;
const $ = selector => document.querySelector(selector);
const canvas = $('#document'), photo = $('#photo'), stage = $('#stage'), overlay = $('#highlights');
const inspector = $('#inspector'), status = $('#status'), scroller = $('#scroller');
const pageSelect = $('#page'), previous = $('#previous'), next = $('#next');
let report = {}, labs = [], sources = [], layout = [], pdf, current = 1, renderTask;
let lines = [], selection, zoom = 1, renderVersion = 0, selectionVersion = 0;
let recoveryAttempted = false, recoveryWork, sourceUrl, sourceBlob, sourceIdentity;
let photoMode = false, sourceVersion = 0;
let locale = 'en', viewerDataKey, displayedFilename = '';
let statusMessage = 'loadingOriginal', methodMessage = 'methodPdf', sourceNoteMessage = 'sourceDefault', sourceRecoveryFailed = false;
const t = (key, parameters) => translateViewer(locale, key, parameters);
const resultLabel = row => localizedResultLabel(row, locale);
const pageLines = new Map();
const sourceOnly = new URLSearchParams(location.search).get('mode') === 'source';
if(sourceOnly) document.documentElement.classList.add('source-only');
const text = (tag, value, className) => {
  const node = document.createElement(tag); node.textContent = String(value ?? '');
  if (className) node.className = className; return node;
};
function setStatus(key) {statusMessage=key;status.textContent=key?t(key):'';}
function updatePageCopy() {
  for(const option of pageSelect.options) option.textContent=photoMode?t('photoPage'):t('pageOption',{page:option.value,total:pdf?.numPages || pageSelect.options.length});
  canvas.setAttribute('aria-label',photoMode?t('photoCanvas'):pdf?t('pdfCanvas',{page:current,total:pdf.numPages}):t('originalPage'));
  $('#zoom').textContent=t('zoomFit',{percent:Math.round(zoom*100)});
}
function applyViewerLocale(language) {
  locale=viewerLocale(language);document.documentElement.lang=locale;
  for(const [attribute, target] of [['data-i18n',null],['data-i18n-aria','aria-label'],['data-i18n-alt','alt'],['data-i18n-placeholder','placeholder']]) {
    for(const node of document.querySelectorAll(`[${attribute}]`)) {
      const copy=t(node.getAttribute(attribute));
      if(target)node.setAttribute(target,copy);else node.textContent=copy;
    }
  }
  $('#filename').textContent=displayedFilename || t('uploadedReport');
  $('#method').textContent=t(methodMessage);$('#source-note').textContent=t(sourceNoteMessage);
  status.textContent=statusMessage?t(statusMessage):'';updatePageCopy();
  // Updating copy must preserve the user's PDF page, zoom, selection and scroll.
  // In particular, do not call locateLab(), render() or loadSource() here.
  const documentScroll=[scroller.scrollLeft,scroller.scrollTop], listScroll=$('#tests').scrollTop;
  makeSelectors();drawHighlights();showInspector(false);
  [scroller.scrollLeft,scroller.scrollTop]=documentScroll;$('#tests').scrollTop=listScroll;
  sendHeight();
}
function sendHeight() {
  if (parent !== window) parent.postMessage(JSON.stringify({type:'medivaanii-explorer-height',height:Math.ceil(document.body.scrollHeight)}), location.origin);
}
new ResizeObserver(sendHeight).observe(document.body);
addEventListener('message', event => {
  if (event.origin !== location.origin || event.source !== parent) return;
  if (event.data?.type === 'medivaanii-explorer-source' && event.data.bytes instanceof Uint8Array) {
    if (sourceIdentity !== event.data.identity) {
      sourceIdentity = event.data.identity;
      loadSource(event.data.bytes, event.data.filename);
    }
    return;
  }
  if (typeof event.data !== 'string') return;
  let message; try { message = JSON.parse(event.data); } catch (_) { return; }
  if (message.type !== 'medivaanii-explorer-report' || !message.report || typeof message.report !== 'object') return;
  report = message.report;
  // Generated explanations and locale can change while immutable viewer data
  // remains the same. A locale update must not navigate back to a cited page.
  const incomingKey=JSON.stringify([report.extraction_version,report.parsed_data,report.source_evidence,report.source_layout,report.extraction_quality,report.selected_measurement_id,report.voice_cited_measurement_ids]);
  const dataChanged=incomingKey!==viewerDataKey;viewerDataKey=incomingKey;
  displayedFilename=message.filename || displayedFilename;
  const language=message.language ?? report.language;
  if(!dataChanged){applyViewerLocale(language);return;}
  let parsed = report.parsed_data; try { if(typeof parsed === 'string') parsed = JSON.parse(parsed); } catch (_) { parsed = {}; }
  labs = report.extraction_version === 4 && parsed?.schema_version === 4 && Array.isArray(parsed?.lab_values) ? parsed.lab_values.filter(row=>row.record_type === 'measurement' && row.measurement_id) : [];
  sources = Array.isArray(report.source_evidence) ? report.source_evidence : [];
  const incomingLayout = Array.isArray(report.source_layout) ? report.source_layout.filter(line => safeBox(line.box)) : [];
  if (!layout.length || incomingLayout.length) layout = incomingLayout;
  if(selection?.id && !selectedMeasurement(labs,selection.id)) selection=null;
  applyViewerLocale(language);
  const id=report.voice_cited_measurement_ids?.[0] || report.selected_measurement_id || selection?.id || labs[0]?.measurement_id;
  if(pdf || photo.naturalWidth){if(id)locateLab(id);else render();}else drawHighlights();
});
applyViewerLocale('English');
if(parent !== window) parent.postMessage(JSON.stringify({type:'medivaanii-explorer-ready'}),location.origin);

function makeSelectors() {
  $('#tests').replaceChildren();
  const quality=report.extraction_quality || {};
  $('#coverage').textContent = t(quality.state==='partial'?'partialCoverage':'coverage',{usable:quality.eligible_count || 0,review:quality.needs_review_count || 0});
  const groups=groupMeasurements(labs,$('#search').value,$('#filter').value);
  if(!groups.length)$('#tests').append(text('p',t(labs.length?'noFilter':'noMeasurements'),'list-empty'));
  for(const group of groups) {
    const heading = text('h3',t('groupCount',{group:localizedGroupLabel(group.name,locale),count:group.rows.length}),'group-heading');$('#tests').append(heading);
    for(const lab of group.rows) {
      const button=text('button','', 'result-option'), name=text('span',lab.test_name,'test-name');
      const value=text('span',`${lab.value ?? ''} ${lab.unit ?? ''}`.trim(),'test-value');
      const flag=text('small',lab.acceptance_state==='eligible'?resultLabel(lab):t('needsReview'),'test-state');
      button.append(name,value,flag);button.dataset.measurementId=lab.measurement_id;
      button.setAttribute('aria-label',t('exploreTest',{test:lab.test_name}));button.setAttribute('aria-pressed',String(lab.measurement_id===selection?.id));
      button.onclick=()=>locateLab(lab.measurement_id,'value',true);$('#tests').append(button);
    }
  }
}
$('#search').oninput=makeSelectors;$('#filter').onchange=makeSelectors;
$('#show-highlights').onchange=event=>{overlay.classList.toggle('selected-only',!event.target.checked);};
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
  setStatus('locatingText');
  recoveryWork = (async () => { try {
    const source = sourceBlob;
    if (!source) throw new Error('Original bytes unavailable');
    const form = new FormData();
    const extension = {'image/png':'png','image/webp':'webp','image/jpeg':'jpg'}[source.type] || 'pdf';
    form.append('file',source,`original.${extension}`);
    const response = await fetch('/api/report/source-layout',{method:'POST',body:form,signal:AbortSignal.timeout(120000)});
    if(!response.ok) throw new Error('Source unavailable');
    const result = await response.json();
    layout = Array.isArray(result.source_layout) ? result.source_layout.filter(line=>safeBox(line.box)) : [];
    if (layout.length && parent !== window) parent.postMessage(JSON.stringify({type:'medivaanii-explorer-layout',layout}),location.origin);
  } catch (_) {
    sourceRecoveryFailed=true;sourceNoteMessage='recoveryFailed';$('#source-note').textContent=t(sourceNoteMessage);
  } })().finally(() => { recoveryWork = null; });
  return recoveryWork;
}
async function locateLab(id, field='value', userInitiated=false, fragmentPage) {
  const version = ++selectionVersion;
  const row=selectedMeasurement(labs,id), evidence=sources.find(source=>source.measurement_id===id);
  const source=sourceSelection(row);
  const originalField=source?.fields[field];
  const selectedField=fragmentPage ? fieldFragments(originalField).find(fragment=>fragment.page===fragmentPage) || originalField : originalField;
  const canLocate=source && selectedField && safeBox(selectedField.box) && selectedField.page <= (pdf?.numPages || 1);
  selection={id,field,line:canLocate?{page:selectedField.page,box:selectedField.box,method:selectedField.method,
    text:fragmentPage ? selectedField.raw_cell_text || selectedField.text : evidence?.source_quote || row.source_quote || Object.values(source.fields).map(f=>f.text).join(' ')}:null};
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
  const drawnBoxes=new Set();
  for(const row of labs) {
    const source=sourceSelection(row);if(!source)continue;
    for(const [key,field] of Object.entries(source.fields)) {
      for(const fragment of fieldFragments(field)) {
        if(fragment.page!==current)continue;
        const box=fragment.box;
        if(!safeBox(box))continue;
        // A merged PDF token or an estimated OCR row may supply the same
        // rectangle for several fields. Draw it once so translucent fills
        // cannot stack into an opaque layer over the printed number.
        const boxKey=`${row.measurement_id}:${box.map(value=>value.toFixed(5)).join(':')}`;
        if(drawnBoxes.has(boxKey))continue;
        const [x,y,w,h]=box;
        if(sourceAtPoint(labs,current,x+w/2,y+h/2)?.measurement_id!==row.measurement_id)continue;
        const button=document.createElement('button');button.className='source-line source-cell';
        Object.assign(button.style,{left:`calc(${x*100}% - 4px)`,top:`calc(${y*100}% - 4px)`,width:`calc(${w*100}% + 8px)`,height:`calc(${h*100}% + 8px)`});
        button.dataset.measurementId=row.measurement_id;button.dataset.field=key;
        const fieldLabel=localizedFieldLabel(key,locale);
        button.setAttribute('aria-label',t('selectCell',{test:row.test_name,field:fieldLabel,value:field.text}));
        button.title=t('cellTitle',{test:row.test_name,field:fieldLabel});
        const selected=selection?.id===row.measurement_id;button.setAttribute('aria-pressed',String(selected));if(selected)button.classList.add('selected');if(report.voice_cited_measurement_ids?.includes(row.measurement_id))button.classList.add('voice-cited');
        button.onclick=()=>locateLab(row.measurement_id,key,true,fragment.page);overlay.append(button);drawnBoxes.add(boxKey);count++;
      }
    }
  }
  // Reading an unmatched line is allowed; it does not gain a clinical binding.
  if(!labs.length)for(const line of lines.filter(line=>/\d/.test(line.text) && safeBox(line.box))) {
    const button=document.createElement('button');button.className='source-line';const [x,y,w,h]=line.box;
    Object.assign(button.style,{left:`calc(${x*100}% - 4px)`,top:`calc(${y*100}% - 4px)`,width:`calc(${w*100}% + 8px)`,height:`calc(${h*100}% + 8px)`});
    button.setAttribute('aria-label',t('readLine',{source:line.text}));button.onclick=()=>chooseLine(line);overlay.append(button);
  }
  const vision=lines.some(line=>line.method==='groq_vision') || labs.some(row=>Object.values(row.source_fields||{}).some(field=>field.page===current && field.method==='groq_vision'));
  const ocr=lines.some(line=>line.method==='ocr');methodMessage=vision?'methodVision':ocr?'methodOcr':photoMode?'methodPhoto':'methodPdf';$('#method').textContent=t(methodMessage);
  sourceNoteMessage=sourceRecoveryFailed?'recoveryFailed':vision?'noteVision':ocr?'noteOcr':count?'noteCells':'noLocations';$('#source-note').textContent=t(sourceNoteMessage);
  for(const button of document.querySelectorAll('#tests button'))button.setAttribute('aria-pressed',String(button.dataset.measurementId===selection?.id));
}
function scrollToSelection() {
  const button = overlay.querySelector('.selected');
  if(button) scroller.scrollTop = Math.max(0,button.offsetTop-scroller.clientHeight*.35);
}

function illustration(organ, label) {
  const figure = document.createElement('figure'); figure.className = 'organ';
  const svg = document.createElementNS('http://www.w3.org/2000/svg','svg');
  svg.setAttribute('viewBox','0 0 320 170'); svg.setAttribute('role','img'); svg.setAttribute('aria-label',t('illustrationAria',{system:label}));
  const art = {
    kidneys:`<path d="M148 12v76m24-76v76" stroke="#b68c86" stroke-width="5" stroke-linecap="round"/><path d="M149 60c-17-6-25-8-42-8m65 8c17-6 25-8 42-8" fill="none" stroke="#b68c86" stroke-width="4"/><path d="M101 27c-28-12-51 15-49 46 2 33 25 50 46 40 17-8 24-24 13-32-15-10-14-21-3-30 9-9 4-19-7-24z" fill="#d8e3d8" stroke="#4d6b5e" stroke-width="2.5"/><path d="M219 27c28-12 51 15 49 46-2 33-25 50-46 40-17-8-24-24-13-32 15-10 14-21 3-30-9-9-4-19 7-24z" fill="#d8e3d8" stroke="#4d6b5e" stroke-width="2.5"/><path d="M83 42c-17 7-23 31-10 52m164-52c17 7 23 31 10 52" fill="none" stroke="#a9bcaa" stroke-width="4" stroke-linecap="round"/><path d="M110 78c17 0 22 21 25 44 1 11 9 21 18 22m57-66c-17 0-22 21-25 44-1 11-9 21-18 22" fill="none" stroke="#839d87" stroke-width="2.5"/><path d="M145 142q15-14 30 0c5 18-6 24-15 24s-20-6-15-24z" fill="#e2e9df" stroke="#839d87" stroke-width="2"/><path d="M66 135h49m90 0h49" stroke="#c8d4c8"/>`,
    blood:`<path d="M15 50q140-45 290 0v72q-150 40-290 0z" fill="#f2e5df" stroke="#d8bdb3" stroke-width="2"/><g fill="#c98b82" stroke="#a76961" stroke-width="2"><ellipse cx="65" cy="86" rx="26" ry="17" transform="rotate(-20 65 86)"/><ellipse cx="151" cy="105" rx="25" ry="17" transform="rotate(15 151 105)"/><ellipse cx="248" cy="75" rx="25" ry="17" transform="rotate(-13 248 75)"/></g><g fill="#e7b3aa"><ellipse cx="65" cy="86" rx="12" ry="6"/><ellipse cx="151" cy="105" rx="11" ry="6"/><ellipse cx="248" cy="75" rx="11" ry="6"/></g><circle cx="188" cy="65" r="20" fill="#d9e2d9" stroke="#8caa95" stroke-width="2"/><path d="M179 58q16-10 17 6t-16 7q-9-7-1-13" fill="#9aafa0"/><g fill="#c9aa83"><circle cx="107" cy="67" r="4"/><circle cx="220" cy="110" r="4"/><circle cx="291" cy="95" r="4"/></g>`,
    cells:`<circle cx="210" cy="85" r="57" fill="#dce6da" stroke="#78977e" stroke-width="2.5"/><circle cx="216" cy="85" r="21" fill="#bfcebe" stroke="#78977e" stroke-width="2"/><g fill="#c6a978" stroke="#aa8b5d"><circle cx="42" cy="60" r="7"/><circle cx="70" cy="90" r="7"/><circle cx="45" cy="117" r="7"/><circle cx="97" cy="58" r="7"/></g><path d="M102 91h43m-9-8 9 8-9 8" fill="none" stroke="#839b88" stroke-width="2.5" stroke-linecap="round"/>`,
    circulation:`<path d="M159 40c-19-33-57-17-57 12 0 29 32 55 57 73 25-18 57-44 57-73 0-29-38-45-57-12z" fill="#d7a29a" stroke="#a56b62" stroke-width="2.5"/><path d="M159 8v20m-84 51H38m206 0h38m-124 55v26" stroke="#9eada1" stroke-width="2.5" stroke-linecap="round"/><circle cx="37" cy="79" r="7" fill="#d8e4d8" stroke="#839d87"/><circle cx="283" cy="79" r="7" fill="#d8e4d8" stroke="#839d87"/>`
  };
  // Only constant, locally authored SVG markup is inserted here.
  svg.innerHTML = art[organ] || art.blood;
  figure.append(svg,text('figcaption',label),text('small',t('illustrationCaption'))); return figure;
}
function showInspector(animate=true) {
  inspector.replaceChildren();
  if(animate){inspector.classList.remove('reveal');void inspector.offsetWidth;inspector.classList.add('reveal');}
  if(!selection) {
    const empty=text('div','','empty-inspector');empty.append(text('h2',t('emptyTitle')),text('p',t('emptyChoose')),text('p',t('emptyBody'),'muted'));inspector.append(empty);return;
  }
  const back = text('button',t('selectedSource'),'back-source');
  back.onclick=()=>{if(selection?.id)locateLab(selection.id);focusSection($('.document-pane'));}; inspector.append(back);
  const row = selectedMeasurement(labs,selection?.id), evidence = sources.find(source=>source.measurement_id === selection?.id);
  const line = selection?.line;
  const original = evidence?.original_fields;
  const reviewed = row && (original && ['test_name','value','unit','reference_range','status'].some(key=>String(original[key]??'') !== String(row[key]??'')) || ['user_review','reviewed_range'].includes(row.status_source));
  const primary=original && line ? {...original,acceptance_state:row?.acceptance_state} : row;

  inspector.append(text('h2',primary?.test_name || t('originalLine'),'result-title'));
  if(row) {
    const value = text('div',primary.value,'result-value'); value.append(text('span',primary.unit)); inspector.append(value);
    const flag = text('div',resultLabel(primary),'flag'); if(['high','low','critical','abnormal'].includes(primary.status)) flag.classList.add('flagged'); inspector.append(flag);
    if(primary.reference_range) inspector.append(text('p',t('referenceShown',{range:primary.reference_range}),'range'));
    if(reviewed) {
      const correction = document.createElement('div'); correction.className = 'reviewed-value';
      correction.append(text('div',t('reviewedValue'),'label'),text('p',t('reviewedReading',{test:row.test_name,value:row.value,unit:row.unit || ''}).trim()),text('small',resultLabel(row)),text('small',t('correctionKept')));
      inspector.append(correction);
    }
  }
  const sourceBox = document.createElement('div'); sourceBox.className = 'source-box';
  sourceBox.append(text('div',line?t('sourcePage',{page:line.page}):t('source'),'label'));
  sourceBox.append(text('p',line?.text || evidence?.source_quote || t('sourceQuoteMissing'),'source-quote'));
  sourceBox.append(text('p',line?t(line.page!==current?'sourceOtherPage':line.method==='groq_vision'?'sourceVision':line.method==='ocr'?'sourceOcr':'sourcePdf',{page:line.page}):t('sourceUnconfirmed'),'source-detail'));
  inspector.append(sourceBox);
  if(!line) inspector.append(text('p',t('sourceUnmatched'),'unmatched'));
  const qualityAllowed=['ready','partial'].includes(report.extraction_quality?.state);
  const education=qualityAllowed ? localizedEducation(educationForMeasurement(row),locale) : null;
  if(row) {
    const edit=text('button',t(row.acceptance_state==='eligible'?'correctField':'checkFields'),'edit-result');
    edit.onclick=()=>{if(parent!==window)parent.postMessage(JSON.stringify({type:'medivaanii-explorer-edit',measurement_id:row.measurement_id,page:line?.page,source_fields:row.source_fields}),location.origin);};
    inspector.append(edit);
    if(row.acceptance_state!=='eligible')inspector.append(text('p',t('excluded'),'unmatched'));
  }
  if(education) {
    inspector.append(illustration(education.organ,education.system));
    const title = document.createElement('div'); title.className = 'education-title'; title.append(text('h3',t('whatMeasures')),text('span',t('generalEducation'),'label')); inspector.append(title);
    inspector.append(text('p',education.measures,'education-copy'));
    inspector.lastChild.style.cssText = 'font-size:16px;line-height:1.75;margin-top:7px';
    const context = document.createElement('div'); context.className = 'education-block'; context.append(text('h3',t('whyContext')),text('p',education.context)); inspector.append(context);
    inspector.append(text('p',t('contextNote'),'context-note'));
    const question = document.createElement('div'); question.className = 'doctor-question'; question.append(text('div',t('doctorQuestion'),'label'),text('p',education.question)); inspector.append(question);
    const reference = text('a',t('educationReference'),'reference'); reference.href=education.url; reference.target='_blank'; reference.rel='noopener noreferrer'; inspector.append(reference);
  } else {
    inspector.append(text('p',t(row?'noEducation':'noLabMatch'),'unmatched'));
  }
  sendHeight();
}

async function render() {
  const version = ++renderVersion;
  if(renderTask) {renderTask.cancel();try{await renderTask.promise;}catch(_){} }
  const width = Math.max(220,scroller.clientWidth - (matchMedia('(max-width:720px)').matches?24:40)) * zoom;
  stage.style.width = width+'px';
  if(photoMode) {
    if(photo.naturalWidth) {
      const height = width * photo.naturalHeight/photo.naturalWidth;
      const ratio = Math.min(devicePixelRatio || 1, 2);
      canvas.width = Math.floor(width * ratio); canvas.height = Math.floor(height * ratio);
      canvas.style.width = width+'px'; canvas.style.height = height+'px';
      stage.style.height = height+'px';
      canvas.setAttribute('aria-label',t('photoCanvas'));
      canvas.getContext('2d').drawImage(photo, 0, 0, canvas.width, canvas.height);
      // Reading the image never waits for OCR or a serverless source URL.
      setStatus(null);
      await recoverLocations();
      if(version !== renderVersion)return;
      lines=layout.filter(line=>line.page===1);drawHighlights();setStatus(null);
    }
    return;
  }
  if(!pdf) return;
  previous.disabled=current<=1; next.disabled=current>=pdf.numPages;
  const page = await pdf.getPage(current); if(version!==renderVersion)return;
  const base = page.getViewport({scale:1}), viewport = page.getViewport({scale:width/base.width});
  const ratio=Math.min(devicePixelRatio||1,2); canvas.width=Math.floor(viewport.width*ratio); canvas.height=Math.floor(viewport.height*ratio);
  canvas.style.width=viewport.width+'px';canvas.style.height=viewport.height+'px';stage.style.height=viewport.height+'px';
  canvas.setAttribute('aria-label',t('pdfCanvas',{page:current,total:pdf.numPages}));
  renderTask=page.render({canvasContext:canvas.getContext('2d'),viewport,transform:ratio===1?null:[ratio,0,0,ratio,0,0]});
  try {await renderTask.promise; if(version!==renderVersion)return;lines=await linesFor(current);if(version!==renderVersion)return;drawHighlights();setStatus(null);}
  catch(error){if(error.name!=='RenderingCancelledException')setStatus('pageRenderFailed');}
}
function setZoom(value) {zoom=Math.max(.7,Math.min(3,value));$('#zoom').textContent=t('zoomFit',{percent:Math.round(zoom*100)});render().then(scrollToSelection);}
$('#zoom').onclick=()=>setZoom(1);
$('#zoom-in').onclick=()=>setZoom(zoom+.2);
$('#zoom-out').onclick=()=>setZoom(zoom-.2);
function changePage(page) {++selectionVersion;current=page;pageSelect.value=current;render();if(selection)showInspector();}
pageSelect.onchange=()=>changePage(Number(pageSelect.value));previous.onclick=()=>changePage(current-1);next.onclick=()=>changePage(current+1);
let oldWidth = 0;
new ResizeObserver(()=>{const width=scroller.clientWidth;if(width!==oldWidth){oldWidth=width;render();}}).observe(scroller);
async function loadSource(bytes, filename) {
  const version = ++sourceVersion;
  try {
    const mime = sourceMimeType(bytes);
    if (!mime) throw new Error('Unsupported source');
    if (renderTask) {renderTask.cancel();try{await renderTask.promise;}catch(_){} }
    if (pdf) {await pdf.destroy();pdf = null;}
    if (sourceUrl) URL.revokeObjectURL(sourceUrl);
    sourceBlob = new Blob([bytes], {type:mime});
    sourceUrl = URL.createObjectURL(sourceBlob);
    photoMode = mime !== 'application/pdf';
    current = 1; zoom = 1; pageLines.clear(); pageSelect.replaceChildren();
    recoveryAttempted = false;sourceRecoveryFailed=false; canvas.hidden = false; photo.hidden = true;
    displayedFilename=filename || displayedFilename;$('#filename').textContent=displayedFilename || t('uploadedReport');
    methodMessage=photoMode?'methodPhoto':'methodPdf';$('#method').textContent=t(methodMessage);updatePageCopy();
    setStatus('loadingOriginal');
    if (photoMode) {
      const option = text('option',t('photoPage'));option.value=1;pageSelect.append(option);
      pageSelect.disabled=true;previous.disabled=true;next.disabled=true;
      photo.src = sourceUrl;
      await photo.decode();
    } else {
      // PDF.js may transfer its array to a worker. Keep a separate copy of the
      // uploaded bytes for source overlays/recovery and browser persistence.
      const loaded = await getDocument({data:bytes.slice(),isEvalSupported:false,cMapUrl:new URL('./vendor/pdfjs/cmaps/',location.href).href,cMapPacked:true,standardFontDataUrl:new URL('./vendor/pdfjs/standard_fonts/',location.href).href,wasmUrl:new URL('./vendor/pdfjs/wasm/',location.href).href}).promise;
      if (version !== sourceVersion) {await loaded.destroy();return;}
      pdf = loaded;
      for(let i=1;i<=pdf.numPages;i++){const option=text('option',t('pageOption',{page:i,total:pdf.numPages}));option.value=i;pageSelect.append(option);}
      pageSelect.disabled=false;
    }
    if (version !== sourceVersion)return;
    if (parent !== window) parent.postMessage(JSON.stringify({type:'medivaanii-document-metadata',page_count:pdf?.numPages || 1}),location.origin);
    const id=selection?.id || report.selected_measurement_id || labs[0]?.measurement_id;
    id?await locateLab(id):await render();
  } catch (_) {
    if (version === sourceVersion)setStatus('loadSourceFailed');
  }
}

// Compatibility for direct local preview links. Only browser-created blob
// URLs are allowed; /tmp or other remote document URLs are never used.
if (location.hash.length > 1) {
  try {
    const url = decodeURIComponent(location.hash.slice(1));
    if(!url.startsWith('blob:'+location.origin+'/'))throw new Error('Invalid local source');
    const response = await fetch(url);
    await loadSource(new Uint8Array(await response.arrayBuffer()));
  } catch (_) {setStatus('localSourceUnavailable');}
}
addEventListener('beforeunload', () => {if(sourceUrl)URL.revokeObjectURL(sourceUrl);});
