/// Offline interface copy for report review, correction and questions.
/// Report content and source quotations are deliberately not translated here.
class ReviewStrings {
  const ReviewStrings(this.language);
  final String language;

  static String languageCode(String language) =>
      switch (language.toLowerCase()) {
        'hindi' || 'hi' || 'हिन्दी' || 'हिंदी' => 'hi',
        'spanish' || 'es' || 'español' => 'es',
        'mandarin' ||
        'mandarin chinese' ||
        'chinese' ||
        'zh' ||
        'zh-cn' ||
        '简体中文' ||
        '中文' =>
          'zh',
        _ => 'en',
      };

  String t(String key, [Map<String, Object?> values = const {}]) {
    var text = (_copy[languageCode(language)] ?? _copy['en']!)[key] ??
        _copy['en']![key] ??
        key;
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return text;
  }

  String checkedField(String key) => t('checkedField', {
        'field': t('check_$key'),
      });

  String resultDescription(Map row) {
    final status = (row['status'] ?? 'unknown').toString();
    final source = (row['status_source'] ?? 'unknown').toString();
    if (!['normal', 'high', 'low', 'critical', 'abnormal'].contains(status)) {
      return t('unclassifiedDescription');
    }
    final values = {
      'status': languageCode(language) == 'en'
          ? status
          : t('status_$status').toLowerCase(),
    };
    if (source == 'report') return t('reportStatus', values);
    if (source == 'source_summary') return t('summaryStatus', values);
    if (source == 'user_review') return t('reviewStatus', values);
    if (['normal', 'high', 'low'].contains(status)) {
      if (['reference_range', 'reviewed_source'].contains(source)) {
        return t('extracted_$status');
      }
      if (source == 'reviewed_range') return t('corrected_$status');
    }
    return t('unconfirmedStatus', values);
  }

  static const _copy = <String, Map<String, String>>{
    'en': {
      'originalDocument': 'Original document',
      'openOriginal': 'Open original document',
      'viewExtracted': 'View extracted text',
      'previewUnavailable': 'Original document preview unavailable',
      'sourceTextUnavailable':
          'Source text unavailable. Upload the original again.',
      'edited': 'Edited',
      'status_normal': 'Normal',
      'status_high': 'High',
      'status_low': 'Low',
      'status_critical': 'Critical',
      'status_abnormal': 'Abnormal',
      'check': 'Check',
      'noComparison': 'No comparison',
      'notShown': 'Not shown',
      'editTest': 'Edit {test}',
      'selectSource': 'Select {test} source',
      'reference': 'Reference',
      'extractedResults': 'Extracted results',
      'tests': '{count} tests',
      'selectRow':
          'Select a row to see its source. Edit only what needs correcting.',
      'allResults': 'All results',
      'needsCheck': 'Needs check · {count}',
      'findTest': 'Find a test',
      'testHeader': 'TEST',
      'resultHeader': 'RESULT',
      'referenceHeader': 'REFERENCE',
      'flagHeader': 'FLAG',
      'noValues':
          'No laboratory values were extracted. Read the source text before continuing.',
      'noUncertain':
          'No results need an uncertainty check. Compare the values with your original before continuing.',
      'noSearchMatches': 'No tests match your search.',
      'sourceTest': 'SOURCE · {test}',
      'missingSource':
          'A matching source line was not located. Check this result in the original document.',
      'correctionReady':
          'Correction ready. Range comparisons update when you continue.',
      'compareOriginal':
          'Check the value, unit, range and flag against the original.',
      'ready': 'Ready when you are.',
      'oneCorrection': '{count} correction ready.',
      'corrections': '{count} corrections ready.',
      'confirmExtracted':
          'Confirm the extracted text before reading your explanation.',
      'rereadSource': 'Re-read source',
      'updatingResults': 'Updating results…',
      'confirmContinue': 'Confirm & continue',
      'enterField': 'Enter the {field} from your report.',
      'copyExactly':
          'Copy the result exactly as it appears in the original document.',
      'testName': 'Test name',
      'value': 'Value',
      'unit': 'Unit',
      'referenceRange': 'Reference range',
      'checkPhotoFields':
          'Check each photo field against the original. These checks confirm the transcription, not a diagnosis.',
      'checkedField': 'Checked {field} in original',
      'check_test_name': 'test name',
      'check_value': 'value',
      'check_unit': 'unit',
      'check_reference_range': 'reference range',
      'check_flag': 'flag',
      'reportFlag': 'Flag shown on the report',
      'notShownUncertain': 'Not shown / uncertain',
      'cancel': 'Cancel',
      'saveCorrection': 'Save correction',
      'askAboutReport': 'Ask about this report',
      'questionIntro':
          'Ask about a test shown in your report. Answers use the extracted results and show their source.',
      'flaggedPrompt': 'Which results are flagged?',
      'summaryPrompt': 'Summarise my report',
      'yourQuestion': 'Your question',
      'questionExample': 'For example: What does my glucose result mean?',
      'checkingReport': 'Checking the report…',
      'askQuestion': 'Ask question',
      'answerUnavailable':
          'The answer is unavailable. Check your connection and try again.',
      'translationUnavailable':
          'Translation unavailable; the answer is shown in English.',
      'questionSource': 'Source: {test}',
      'questionMissingSource':
          'A matching original line was not located. Review this result against the document.',
      'reviewOriginal': 'Review original and extracted results',
      'unclassifiedDescription':
          'This result cannot be reliably classified from the available report flag and reference range. Check it against the original.',
      'reportStatus': 'The report marks this result as {status}.',
      'summaryStatus':
          'The uploaded summary lists this comparison as {status}. Check it against the laboratory report.',
      'reviewStatus':
          'You marked this result as {status} during extraction review.',
      'unconfirmedStatus':
          'The extracted status is {status}; its source has not been confirmed.',
      'extracted_normal':
          'The extracted value is within the reference range shown in this report.',
      'extracted_high':
          'The extracted value is above the reference range shown in this report.',
      'extracted_low':
          'The extracted value is below the reference range shown in this report.',
      'corrected_normal':
          'The corrected value is within the reference range you entered during review.',
      'corrected_high':
          'The corrected value is above the reference range you entered during review.',
      'corrected_low':
          'The corrected value is below the reference range you entered during review.',
    },
    'hi': {
      'originalDocument': 'मूल दस्तावेज़',
      'openOriginal': 'मूल दस्तावेज़ खोलें',
      'viewExtracted': 'निकाला गया पाठ देखें',
      'previewUnavailable': 'मूल दस्तावेज़ का पूर्वावलोकन उपलब्ध नहीं है',
      'sourceTextUnavailable':
          'मूल पाठ उपलब्ध नहीं है। मूल दस्तावेज़ फिर अपलोड करें।',
      'edited': 'सुधारा गया',
      'status_normal': 'सामान्य',
      'status_high': 'अधिक',
      'status_low': 'कम',
      'status_critical': 'गंभीर',
      'status_abnormal': 'असामान्य',
      'check': 'जाँचें',
      'noComparison': 'तुलना उपलब्ध नहीं',
      'notShown': 'दिया नहीं गया',
      'editTest': '{test} सुधारें',
      'selectSource': '{test} का मूल अंश चुनें',
      'reference': 'संदर्भ सीमा',
      'extractedResults': 'निकाले गए परिणाम',
      'tests': '{count} जाँचें',
      'selectRow':
          'मूल अंश देखने के लिए एक पंक्ति चुनें। जहाँ ज़रूरत हो, वहीं सुधार करें।',
      'allResults': 'सभी परिणाम',
      'needsCheck': 'जाँच ज़रूरी · {count}',
      'findTest': 'जाँच खोजें',
      'testHeader': 'जाँच',
      'resultHeader': 'परिणाम',
      'referenceHeader': 'संदर्भ सीमा',
      'flagHeader': 'चिह्न',
      'noValues':
          'कोई लैब मान नहीं निकाला गया। आगे बढ़ने से पहले मूल पाठ पढ़ें।',
      'noUncertain':
          'किसी परिणाम की अनिश्चितता जाँचने की ज़रूरत नहीं है। आगे बढ़ने से पहले मानों को मूल रिपोर्ट से मिलाएँ।',
      'noSearchMatches': 'आपकी खोज से कोई जाँच नहीं मिली।',
      'sourceTest': 'मूल अंश · {test}',
      'missingSource':
          'मिलती हुई मूल पंक्ति नहीं मिली। इस परिणाम को मूल दस्तावेज़ में जाँचें।',
      'correctionReady':
          'सुधार तैयार है। आगे बढ़ने पर संदर्भ सीमा से तुलना अपडेट होगी।',
      'compareOriginal':
          'मान, इकाई, संदर्भ सीमा और चिह्न को मूल रिपोर्ट से मिलाएँ।',
      'ready': 'जब आप तैयार हों, आगे बढ़ें।',
      'oneCorrection': '{count} सुधार तैयार है।',
      'corrections': '{count} सुधार तैयार हैं।',
      'confirmExtracted':
          'आसान व्याख्या पढ़ने से पहले निकाले गए पाठ की पुष्टि करें।',
      'rereadSource': 'मूल दस्तावेज़ फिर पढ़ें',
      'updatingResults': 'परिणाम अपडेट हो रहे हैं…',
      'confirmContinue': 'पुष्टि करें और आगे बढ़ें',
      'enterField': 'अपनी रिपोर्ट से {field} दर्ज करें।',
      'copyExactly':
          'परिणाम को ठीक वैसे ही लिखें जैसे वह मूल दस्तावेज़ में है।',
      'testName': 'जाँच का नाम',
      'value': 'मान',
      'unit': 'इकाई',
      'referenceRange': 'संदर्भ सीमा',
      'checkPhotoFields':
          'फ़ोटो से निकाले गए हर खाने को मूल रिपोर्ट से मिलाएँ। इससे केवल लिखे हुए पाठ की पुष्टि होती है, निदान की नहीं।',
      'checkedField': 'मूल रिपोर्ट से मिलाया: {field}',
      'check_test_name': 'जाँच का नाम',
      'check_value': 'मान',
      'check_unit': 'इकाई',
      'check_reference_range': 'संदर्भ सीमा',
      'check_flag': 'चिह्न',
      'reportFlag': 'रिपोर्ट में दिया गया चिह्न',
      'notShownUncertain': 'दिया नहीं गया / अनिश्चित',
      'cancel': 'रद्द करें',
      'saveCorrection': 'सुधार सहेजें',
      'askAboutReport': 'इस रिपोर्ट के बारे में पूछें',
      'questionIntro':
          'अपनी रिपोर्ट में दी गई किसी जाँच के बारे में पूछें। उत्तर निकाले गए परिणामों पर आधारित होते हैं और उनका मूल अंश दिखाते हैं।',
      'flaggedPrompt': 'किन परिणामों पर चिह्न लगा है?',
      'summaryPrompt': 'मेरी रिपोर्ट का सार बताएँ',
      'yourQuestion': 'आपका सवाल',
      'questionExample': 'जैसे: मेरे ग्लूकोज़ के परिणाम का क्या मतलब है?',
      'checkingReport': 'रिपोर्ट जाँची जा रही है…',
      'askQuestion': 'सवाल पूछें',
      'answerUnavailable':
          'उत्तर उपलब्ध नहीं है। अपना इंटरनेट कनेक्शन जाँचें और फिर कोशिश करें।',
      'translationUnavailable':
          'अनुवाद उपलब्ध नहीं है; उत्तर अंग्रेज़ी में दिखाया गया है।',
      'questionSource': 'मूल अंश: {test}',
      'questionMissingSource':
          'मिलती हुई मूल पंक्ति नहीं मिली। इस परिणाम को दस्तावेज़ से मिलाएँ।',
      'reviewOriginal': 'मूल दस्तावेज़ और निकाले गए परिणाम जाँचें',
      'unclassifiedDescription':
          'उपलब्ध चिह्न और संदर्भ सीमा से इस परिणाम का भरोसेमंद वर्गीकरण नहीं हो सकता। इसे मूल रिपोर्ट से मिलाएँ।',
      'reportStatus': 'रिपोर्ट में इस परिणाम को {status} बताया गया है।',
      'summaryStatus':
          'अपलोड किए गए सार में यह तुलना {status} दी गई है। इसे लैब रिपोर्ट से मिलाएँ।',
      'reviewStatus':
          'निकाले गए पाठ की समीक्षा के दौरान आपने इस परिणाम को {status} चिह्नित किया था।',
      'unconfirmedStatus':
          'निकाली गई स्थिति {status} है; इसके मूल अंश की पुष्टि नहीं हुई है।',
      'extracted_normal':
          'निकाला गया मान इस रिपोर्ट में दी गई संदर्भ सीमा के भीतर है।',
      'extracted_high':
          'निकाला गया मान इस रिपोर्ट में दी गई संदर्भ सीमा से अधिक है।',
      'extracted_low':
          'निकाला गया मान इस रिपोर्ट में दी गई संदर्भ सीमा से कम है।',
      'corrected_normal':
          'सुधारा गया मान समीक्षा के दौरान आपके द्वारा दर्ज की गई संदर्भ सीमा के भीतर है।',
      'corrected_high':
          'सुधारा गया मान समीक्षा के दौरान आपके द्वारा दर्ज की गई संदर्भ सीमा से अधिक है।',
      'corrected_low':
          'सुधारा गया मान समीक्षा के दौरान आपके द्वारा दर्ज की गई संदर्भ सीमा से कम है।',
    },
    'es': {
      'originalDocument': 'Documento original',
      'openOriginal': 'Abrir documento original',
      'viewExtracted': 'Ver texto extraído',
      'previewUnavailable':
          'La vista previa del documento original no está disponible',
      'sourceTextUnavailable':
          'El texto original no está disponible. Vuelve a subir el documento original.',
      'edited': 'Corregido',
      'status_normal': 'Normal',
      'status_high': 'Alto',
      'status_low': 'Bajo',
      'status_critical': 'Crítico',
      'status_abnormal': 'Anormal',
      'check': 'Revisar',
      'noComparison': 'Sin comparación',
      'notShown': 'No indicado',
      'editTest': 'Corregir {test}',
      'selectSource': 'Seleccionar el fragmento original de {test}',
      'reference': 'Referencia',
      'extractedResults': 'Resultados extraídos',
      'tests': '{count} pruebas',
      'selectRow':
          'Selecciona una fila para ver su fragmento original. Corrige lo que sea necesario.',
      'allResults': 'Todos los resultados',
      'needsCheck': 'Por revisar · {count}',
      'findTest': 'Buscar una prueba',
      'testHeader': 'PRUEBA',
      'resultHeader': 'RESULTADO',
      'referenceHeader': 'REFERENCIA',
      'flagHeader': 'MARCA',
      'noValues':
          'No se extrajeron valores de laboratorio. Lee el texto original antes de continuar.',
      'noUncertain':
          'No hay resultados que necesiten una revisión por incertidumbre. Compara los valores con el original antes de continuar.',
      'noSearchMatches': 'No hay pruebas que coincidan con tu búsqueda.',
      'sourceTest': 'ORIGINAL · {test}',
      'missingSource':
          'No se encontró una línea original que coincida. Comprueba este resultado en el documento original.',
      'correctionReady':
          'Corrección lista. Las comparaciones con el intervalo se actualizarán al continuar.',
      'compareOriginal':
          'Compara el valor, la unidad, el intervalo y la marca con el original.',
      'ready': 'Puedes continuar cuando quieras.',
      'oneCorrection': '{count} corrección lista.',
      'corrections': '{count} correcciones listas.',
      'confirmExtracted':
          'Confirma el texto extraído antes de leer la explicación.',
      'rereadSource': 'Volver a leer el original',
      'updatingResults': 'Actualizando resultados…',
      'confirmContinue': 'Confirmar y continuar',
      'enterField':
          'Introduce el campo «{field}» tal como aparece en tu informe.',
      'copyExactly':
          'Copia el resultado exactamente como aparece en el documento original.',
      'testName': 'Nombre de la prueba',
      'value': 'Valor',
      'unit': 'Unidad',
      'referenceRange': 'Intervalo de referencia',
      'checkPhotoFields':
          'Compara cada campo de la foto con el original. Estas comprobaciones confirman la transcripción, no un diagnóstico.',
      'checkedField': 'Comprobado en el original: {field}',
      'check_test_name': 'nombre de la prueba',
      'check_value': 'valor',
      'check_unit': 'unidad',
      'check_reference_range': 'intervalo de referencia',
      'check_flag': 'marca',
      'reportFlag': 'Marca indicada en el informe',
      'notShownUncertain': 'No indicada / incierta',
      'cancel': 'Cancelar',
      'saveCorrection': 'Guardar corrección',
      'askAboutReport': 'Pregunta sobre este informe',
      'questionIntro':
          'Pregunta sobre una prueba de tu informe. Las respuestas usan los resultados extraídos y muestran su fragmento original.',
      'flaggedPrompt': '¿Qué resultados están marcados?',
      'summaryPrompt': 'Resume mi informe',
      'yourQuestion': 'Tu pregunta',
      'questionExample': 'Por ejemplo: ¿Qué significa mi resultado de glucosa?',
      'checkingReport': 'Revisando el informe…',
      'askQuestion': 'Hacer pregunta',
      'answerUnavailable':
          'La respuesta no está disponible. Comprueba tu conexión e inténtalo de nuevo.',
      'translationUnavailable':
          'La traducción no está disponible; la respuesta se muestra en inglés.',
      'questionSource': 'Original: {test}',
      'questionMissingSource':
          'No se encontró una línea original que coincida. Compara este resultado con el documento.',
      'reviewOriginal': 'Revisar el original y los resultados extraídos',
      'unclassifiedDescription':
          'Este resultado no se puede clasificar con fiabilidad a partir de la marca y el intervalo de referencia disponibles. Compáralo con el original.',
      'reportStatus': 'El informe marca este resultado como {status}.',
      'summaryStatus':
          'El resumen subido indica esta comparación como {status}. Compárala con el informe de laboratorio.',
      'reviewStatus':
          'Durante la revisión del texto extraído, marcaste este resultado como {status}.',
      'unconfirmedStatus':
          'El estado extraído es {status}; no se ha confirmado su origen.',
      'extracted_normal':
          'El valor extraído está dentro del intervalo de referencia indicado en este informe.',
      'extracted_high':
          'El valor extraído está por encima del intervalo de referencia indicado en este informe.',
      'extracted_low':
          'El valor extraído está por debajo del intervalo de referencia indicado en este informe.',
      'corrected_normal':
          'El valor corregido está dentro del intervalo de referencia que introdujiste durante la revisión.',
      'corrected_high':
          'El valor corregido está por encima del intervalo de referencia que introdujiste durante la revisión.',
      'corrected_low':
          'El valor corregido está por debajo del intervalo de referencia que introdujiste durante la revisión.',
    },
    'zh': {
      'originalDocument': '原始文档',
      'openOriginal': '打开原始文档',
      'viewExtracted': '查看提取的文字',
      'previewUnavailable': '无法预览原始文档',
      'sourceTextUnavailable': '原文不可用。请重新上传原始文档。',
      'edited': '已修改',
      'status_normal': '正常',
      'status_high': '偏高',
      'status_low': '偏低',
      'status_critical': '危急',
      'status_abnormal': '异常',
      'check': '待核对',
      'noComparison': '无法比较',
      'notShown': '未提供',
      'editTest': '修改 {test}',
      'selectSource': '选择 {test} 的原文',
      'reference': '参考范围',
      'extractedResults': '提取的结果',
      'tests': '{count} 项检查',
      'selectRow': '选择一行查看对应原文。只修改需要更正的内容。',
      'allResults': '所有结果',
      'needsCheck': '待核对 · {count}',
      'findTest': '搜索检查项目',
      'testHeader': '检查项目',
      'resultHeader': '结果',
      'referenceHeader': '参考范围',
      'flagHeader': '标记',
      'noValues': '未提取到化验数值。请先阅读原文再继续。',
      'noUncertain': '没有因不确定而需要核对的结果。请先将数值与原始报告核对，再继续。',
      'noSearchMatches': '没有找到符合搜索条件的检查项目。',
      'sourceTest': '原文 · {test}',
      'missingSource': '未找到对应原文。请在原始文档中核对这项结果。',
      'correctionReady': '更正已准备好。继续后将更新参考范围比较。',
      'compareOriginal': '请将数值、单位、参考范围和标记与原文核对。',
      'ready': '准备好后即可继续。',
      'oneCorrection': '{count} 项更正已准备好。',
      'corrections': '{count} 项更正已准备好。',
      'confirmExtracted': '阅读说明前，请确认提取的文字。',
      'rereadSource': '重新读取原文',
      'updatingResults': '正在更新结果…',
      'confirmContinue': '确认并继续',
      'enterField': '请按报告原文填写{field}。',
      'copyExactly': '请完全按照原始文档填写结果。',
      'testName': '检查项目名称',
      'value': '数值',
      'unit': '单位',
      'referenceRange': '参考范围',
      'checkPhotoFields': '请将从照片提取的每个字段与原文核对。这些核对仅确认文字转录，不确认诊断。',
      'checkedField': '已与原文核对：{field}',
      'check_test_name': '检查项目名称',
      'check_value': '数值',
      'check_unit': '单位',
      'check_reference_range': '参考范围',
      'check_flag': '标记',
      'reportFlag': '报告中显示的标记',
      'notShownUncertain': '未显示 / 不确定',
      'cancel': '取消',
      'saveCorrection': '保存更正',
      'askAboutReport': '询问这份报告',
      'questionIntro': '可以询问报告中的检查项目。回答依据提取的结果，并显示对应原文。',
      'flaggedPrompt': '哪些结果带有标记？',
      'summaryPrompt': '概括我的报告',
      'yourQuestion': '你的问题',
      'questionExample': '例如：我的血糖结果是什么意思？',
      'checkingReport': '正在核查报告…',
      'askQuestion': '提问',
      'answerUnavailable': '暂时无法获取回答。请检查网络连接后重试。',
      'translationUnavailable': '翻译暂不可用；回答以英文显示。',
      'questionSource': '原文：{test}',
      'questionMissingSource': '未找到对应原文。请对照文档核对这项结果。',
      'reviewOriginal': '核对原文和提取的结果',
      'unclassifiedDescription': '现有报告标记和参考范围不足以可靠地判断这项结果。请与原文核对。',
      'reportStatus': '报告将这项结果标记为{status}。',
      'summaryStatus': '上传的摘要将这项比较列为{status}。请与化验报告核对。',
      'reviewStatus': '核对提取内容时，你将这项结果标记为{status}。',
      'unconfirmedStatus': '提取的状态为{status}；其来源尚未确认。',
      'extracted_normal': '提取的数值在报告所列的参考范围内。',
      'extracted_high': '提取的数值高于报告所列的参考范围。',
      'extracted_low': '提取的数值低于报告所列的参考范围。',
      'corrected_normal': '更正后的数值在核对时你填写的参考范围内。',
      'corrected_high': '更正后的数值高于核对时你填写的参考范围。',
      'corrected_low': '更正后的数值低于核对时你填写的参考范围。',
    },
  };
}
