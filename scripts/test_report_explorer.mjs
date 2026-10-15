import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {matchesSource,sourceForLine,safeBox,educationFor,resultLabel} from '../flutter_app/web/report_explorer_core.mjs';
import {selectedMeasurement, sourceSelection, groupMeasurements, sourceAtPoint, educationForMeasurement} from '../flutter_app/web/report_explorer_core.mjs';
import {sourceMimeType} from '../flutter_app/web/source_document.mjs';
test('viewer routes raw PDF, PNG, JPEG and WebP bytes without a server URL', () => {
  assert.equal(sourceMimeType(new TextEncoder().encode('%PDF-1.7\n')), 'application/pdf');
  assert.equal(sourceMimeType(new Uint8Array([137,80,78,71,13,10,26,10])), 'image/png');
  assert.equal(sourceMimeType(new Uint8Array([255,216,255,224])), 'image/jpeg');
  assert.equal(sourceMimeType(new TextEncoder().encode('RIFF0000WEBP')), 'image/webp');
  assert.equal(sourceMimeType(new TextEncoder().encode('not a PDF')), null);
});
const row = {measurement_id:'physical-source',record_type:'measurement',acceptance_state:'eligible',test_name:'Creatinine',value:'0.9',unit:'mg/dL',panel:'Kidney function',source_fields:{test_name:{text:'Creatinine',page:17,box:[.1,.3,.2,.02]},value:{text:'1.8',page:17,box:[.4,.3,.08,.02]}}};
test('split reference highlights retain each original PDF page', () => {
  const split = {...row, source_fields:{...row.source_fields, reference_range:{page:17,box:[.1,.8,.7,.03],fragments:[
    {page:17,box:[.1,.8,.7,.03],text:'Desirable: <150'},
    {page:18,box:[.1,.1,.7,.03],text:'Borderline high: 150-199'}
  ]}}};
  assert.equal(sourceAtPoint([split],18,.2,.11)?.measurement_id, row.measurement_id);
  assert.equal(sourceAtPoint([split],17,.2,.11), null);
});
test('selection_survives_group_filter_and_reordering',()=>{
  const other = {...row,measurement_id:'other',test_name:'WBC',panel:'Blood count'};
  assert.equal(selectedMeasurement([other,row],row.measurement_id),row);
  assert.deepEqual(groupMeasurements([other,row],'WBC','all').flatMap(g=>g.rows),[other]);
  assert.equal(selectedMeasurement([row,other],row.measurement_id),row);
});
test('selection_navigates_to_physical_source_page',()=>{
  assert.equal(sourceSelection(row).page,17);
  assert.equal(sourceSelection({...row,source_fields:{}}),null);
});
test('late page rendering cannot restore a superseded source selection',async()=>{
  const messages=[], renders=[];
  const second={...row,measurement_id:'second',source_fields:{
    ...row.source_fields,value:{...row.source_fields.value,page:21}}};
  const context={selectionVersion:0,labs:[row,second],sources:[],pdf:{numPages:33},
    selectedMeasurement,sourceSelection,safeBox,pageSelect:{},current:1,selection:null,
    render:()=>new Promise(resolve=>renders.push(resolve)),scrollToSelection:()=>{},
    drawHighlights:()=>{},showInspector:()=>{},makeSelectors:()=>{},focusSection:()=>{},inspector:{},
    parent:{postMessage:message=>messages.push(JSON.parse(message))},window:{},location:{origin:'http://localhost:3001'}};
  const source=fs.readFileSync(new URL('../flutter_app/web/report_explorer.mjs',import.meta.url),'utf8');
  vm.runInNewContext(source.slice(source.indexOf('async function locateLab('),source.indexOf('function chooseLine(')),context);
  const firstPending=context.locateLab(row.measurement_id);
  const secondPending=context.locateLab(second.measurement_id);
  renders[1]();await secondPending;
  renders[0]();await firstPending;
  assert.deepEqual(messages.map(message=>message.measurement_id),['second']);
  assert.equal(context.selection.id,'second');
});
test('highlight_uses_original_boxes_after_user_edit',()=>{
  const selected=sourceSelection(row);
  assert.equal(selected.fields.value.text,'1.8');
  assert.deepEqual(selected.fields.value.box,[.4,.3,.08,.02]);
  assert.equal(sourceAtPoint([row],17,.44,.31),row);
  assert.equal(sourceAtPoint([row],18,.44,.31),null);
});
test('unmatched_source_does_not_bind_guideline_to_organ_explanation',()=>{
  const guideline={...row,record_type:'guideline'};
  assert.equal(educationForMeasurement(guideline),null);
  assert.equal(sourceAtPoint([guideline],17,.44,.31),null);
  assert.equal(educationForMeasurement({...row,acceptance_state:'needs_review'}),null);
  assert.equal(educationForMeasurement(row).organ,'kidneys');
  assert.equal(sourceAtPoint([row,{...row,measurement_id:'duplicate'}],17,.44,.31),null);
});
test('urine glucose cannot bind to blood-glucose education',()=>{
  assert.equal(educationForMeasurement({...row,test_name:'Glucose',canonical_test:'glucose',specimen:'Urine',value:'Negative'}),null);
});
const source={lab_id:0,source_quote:'Creatinine: 1.8 mg/dL',original_fields:{test_name:'Creatinine',value:'1.8'}};
test('source matching uses the original value and rejects similar numbers',()=>{
  assert.equal(matchesSource('Creatinine: 1.8 mg/dL 0.6–1.2',source),true);
  assert.equal(matchesSource('Creatinine: 11.8 mg/dL',source),false);
  assert.equal(matchesSource('Creatinine: 0.9 mg/dL',source),false);
});
test('legacy evidence requires the exact quote and ambiguous rows stay unmatched',()=>{
  assert.equal(matchesSource('Glucose: 145 mg/dL',{source_quote:'Glucose: 145 mg/dL'}),true);
  assert.equal(matchesSource('Glucose: 95 mg/dL',{source_quote:'Glucose: 145 mg/dL'}),false);
  assert.equal(sourceForLine('Creatinine: 1.8 mg/dL',[source,{...source,lab_id:1}]),null);
});
test('highlights reject invalid geometry',()=>{
  assert.equal(safeBox([.1,.2,.6,.03]),true);
  for(const box of [[.1,.2,NaN,.03],[-1,0,.3,.1],[.9,0,.5,.1],[0,0,0,.1]])assert.equal(safeBox(box),false);
});
test('test education is specific, referenced and does not diagnose the result',()=>{
  assert.equal(educationFor('Serum creatinine').organ,'kidneys');
  assert.match(educationFor('Creatinine').url,/medlineplus/);
  assert.equal(educationFor('HbA1c').title,'HbA1c');
  assert.equal(educationFor('Unknown test'),null);
  assert.equal(educationFor('Anti WBC receptor'),null);
});
test('a reviewed flag cannot be presented as an original report flag',()=>{
  assert.equal(resultLabel({status:'high',status_source:'user_review'}),'High · reviewed flag');
  assert.equal(resultLabel({status:'unknown'}),'Needs source review');
});
test('frame bridge rejects other origins and other windows',()=>{
  const listeners = new Set(), frame = {contentWindow:{},isConnected:true}, received=[];
  const context={window:{},location:{origin:'http://localhost:3001'},CSS:{escape:value=>value},
    document:{getElementById:()=>frame,querySelector:()=>null,querySelectorAll:()=>[]},
    addEventListener:(_,fn)=>listeners.add(fn),removeEventListener:(_,fn)=>listeners.delete(fn)};
  vm.runInNewContext(fs.readFileSync(new URL('../flutter_app/web/report_store.js',import.meta.url),'utf8'),context);
  const bridge=context.window.medivaaniiExplorerBridge;
  bridge.watch('frame',data=>received.push(data));
  const deliver=event=>{for(const fn of listeners)fn(event);};
  deliver({origin:'https://another.example',source:frame.contentWindow,data:'private'});
  deliver({origin:context.location.origin,source:{},data:'private'});
  deliver({origin:context.location.origin,source:frame.contentWindow,data:'accepted'});
  assert.deepEqual(received,['accepted']);
  bridge.stop('frame'); assert.equal(listeners.size,0);
});
