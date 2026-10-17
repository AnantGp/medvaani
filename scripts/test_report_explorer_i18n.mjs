import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {educationFor} from '../flutter_app/web/report_explorer_core.mjs';
import {viewerMessages, viewerLocale, translateViewer, localizedEducation, localizedResultLabel} from '../flutter_app/web/report_explorer_i18n.mjs';

test('all viewer locales contain the same complete messages and named parameters', () => {
  const parameters = message => [...message.matchAll(/\{(\w+)\}/g)].map(match=>match[1]).sort();
  const keys = Object.keys(viewerMessages.en).sort();
  for (const [locale, messages] of Object.entries(viewerMessages)) {
    assert.deepEqual(Object.keys(messages).sort(), keys, locale);
    for (const key of keys) {
      assert.ok(messages[key].trim(), `${locale}.${key}`);
      assert.deepEqual(parameters(messages[key]), parameters(viewerMessages.en[key]), `${locale}.${key}`);
      const values = Object.fromEntries(parameters(messages[key]).map(name=>[name,'145 mg/dL <original>']));
      assert.ok(!/\{\w+\}/.test(translateViewer(locale,key,values)), `${locale}.${key}`);
    }
  }
  assert.deepEqual(['English','Hindi','Spanish','Mandarin','en','hi-IN','es_ES','zh-CN'].map(viewerLocale), ['en','hi','es','zh','en','hi','es','zh']);
  assert.equal(viewerLocale('unsupported'), 'en');
});

test('educational copy and provenance are local while source parameters remain exact', () => {
  for (const locale of ['en','hi','es','zh']) {
    for (const name of ['Creatinine','eGFR','HbA1c','Glucose','Hemoglobin','WBC','Platelets','RBC','Cholesterol']) {
      const original = educationFor(name), localized = localizedEducation(original,locale);
      assert.equal(localized.url, original.url);assert.equal(localized.organ, original.organ);
      if (locale !== 'en') for (const key of ['measures','context','question']) assert.notEqual(localized[key],original[key]);
    }
    const source = 'Creatinine 1.80 mg/dL (0.60–1.20) {unaltered}';
    assert.ok(translateViewer(locale,'readLine',{source}).endsWith(source));
    assert.notEqual(localizedResultLabel({status:'high',status_source:'report'},locale), localizedResultLabel({status:'high',status_source:'user_review'},locale));
    assert.equal(localizedResultLabel({status:'unknown',acceptance_state:'eligible'},locale),translateViewer(locale,'noComparison'));
  }
});

test('language-only report messages do not navigate, render, or reload the source', () => {
  const original = {extraction_version:4, parsed_data:{schema_version:4,lab_values:[]}, selected_measurement_id:'selected', language:'English'};
  const signature = value => JSON.stringify([value.extraction_version,value.parsed_data,value.source_evidence,value.source_layout,value.extraction_quality,value.selected_measurement_id,value.voice_cited_measurement_ids]);
  let receive;const locales=[];
  const context = {addEventListener:(_,fn)=>{receive=fn;},location:{origin:'http://localhost'},parent:{}, Uint8Array,
    report:original,viewerDataKey:signature(original),displayedFilename:'original.pdf', current:17,zoom:1.8,selection:{id:'selected'},
    applyViewerLocale:language=>locales.push(viewerLocale(language)),
    loadSource:()=>assert.fail('source reloaded'),render:()=>assert.fail('page rendered'),locateLab:()=>assert.fail('selection navigated')};
  const source=fs.readFileSync(new URL('../flutter_app/web/report_explorer.mjs',import.meta.url),'utf8');
  vm.runInNewContext(source.slice(source.indexOf("addEventListener('message'"),source.indexOf("applyViewerLocale('English');")),context);
  for (const language of ['Hindi','Spanish','Mandarin','English']) receive({origin:context.location.origin,source:context.parent,data:JSON.stringify({type:'medivaanii-explorer-report',report:{...original,language}})});
  assert.deepEqual(locales,['hi','es','zh','en']);assert.equal(context.current,17);assert.equal(context.zoom,1.8);assert.equal(context.selection.id,'selected');
  receive({origin:context.location.origin,source:context.parent,data:JSON.stringify({type:'medivaanii-explorer-report',language:'Spanish',report:original})});
  assert.equal(locales.at(-1),'es');
});
