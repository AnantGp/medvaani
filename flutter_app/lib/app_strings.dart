/// Local UI copy only. Patient/source text never passes through this catalog.
class AppStrings {
  AppStrings(String language) : code = languageCode(language);
  final String code;
  static const supportedNames = ['English', 'Hindi', 'Spanish', 'Mandarin'];
  static String languageCode(String language) =>
      switch (language.toLowerCase()) {
        'hi' || 'hindi' => 'hi',
        'es' || 'spanish' => 'es',
        'zh' || 'mandarin' || 'mandarin chinese' || 'chinese' => 'zh',
        _ => 'en',
      };
  static String preferredName(String? preference, [String? legacy]) =>
      supportedNames.contains(preference)
          ? preference!
          : supportedNames.contains(legacy)
              ? legacy!
              : 'English';
  static Iterable<String> get keys => _translations.keys;
  static bool contains(String source) => _translations.containsKey(source);
  String t(String source, [Map<String, Object?> values = const {}]) {
    final entries = _translations[source];
    var result = code == 'en' || entries == null
        ? source
        : entries[{'hi': 0, 'es': 1, 'zh': 2}[code]!];
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return result;
  }

  String error(String message) {
    var source = message
        .trim()
        .replaceFirst(RegExp(r'^(?:Processing failed:|Exception:)\s*'), '');
    if (_translations.containsKey(source)) return t(source);
    if (source.startsWith('Error picking file:')) {
      return t('Unable to read file data. Please try again.');
    }
    if (source.startsWith('Failed to generate PDF:')) {
      return t('Could not create the PDF. Please try again.');
    }
    return code == 'en'
        ? source
        : t('We could not finish that. Please try again or choose another report.');
  }

  String progress(String message) => _translations.containsKey(message)
      ? t(message)
      : t('Reading your report…');
  static const Map<String, List<String>> _translations = {
    "Upload": ["अपलोड", "Subir", "上传"],
    "Report": ["रिपोर्ट", "Informe", "报告"],
    "Settings": ["सेटिंग्स", "Configuración", "设置"],
    "Upload report": ["रिपोर्ट जोड़ें", "Subir informe", "上传报告"],
    "Report workspace": ["रिपोर्ट समझें", "Tu informe", "报告工作区"],
    "Clarity, in your language.": [
      "अपनी भाषा में समझें।",
      "Claridad en tu idioma.",
      "用自己的语言读懂报告。"
    ],
    "App language": ["ऐप की भाषा", "Idioma de la aplicación", "应用语言"],
    "Medivaanii logo": [
      "Medivaanii का लोगो",
      "Logotipo de Medivaanii",
      "Medivaanii标志"
    ],
    "Your report": ["आपकी रिपोर्ट", "Tu informe", "你的报告"],
    "Your uploaded report": [
      "आपकी अपलोड की गई रिपोर्ट",
      "Tu informe subido",
      "你上传的报告"
    ],
    "Original uploaded report": [
      "अपलोड की गई मूल रिपोर्ट",
      "Informe original subido",
      "上传的原始报告"
    ],
    "Interactive report explorer": [
      "मूल रिपोर्ट में नतीजे देखें",
      "Explorador del informe",
      "交互式报告查看器"
    ],
    "Report text available · measurements are not yet mapped": [
      "रिपोर्ट पढ़ी गई है · अलग-अलग नतीजे अभी नहीं पहचाने गए",
      "Texto disponible · resultados aún sin identificar",
      "报告文本可用 · 尚未整理各项检测结果"
    ],
    "Partial extraction": [
      "रिपोर्ट का कुछ हिस्सा पढ़ा गया है",
      "Extracción parcial",
      "已读取部分内容"
    ],
    "{count} of {total} measurements": [
      "{total} में से {count} नतीजे",
      "{count} de {total} resultados",
      "已读取{total}项中的{count}项"
    ],
    "{count} to check": [
      "{count} नतीजे जांचें",
      "{count} por revisar",
      "{count}项待核对"
    ],
    "Save summary": ["सारांश सेव करें", "Guardar resumen", "保存摘要"],
    "Read results again": [
      "नतीजे फिर से पढ़ें",
      "Leer resultados de nuevo",
      "重新读取结果"
    ],
    "Re-read": ["फिर पढ़ें", "Releer", "重新读取"],
    "Upload another report": [
      "दूसरी रिपोर्ट जोड़ें",
      "Subir otro informe",
      "上传另一份报告"
    ],
    "Upload the original document to view its source.": [
      "नतीजे मूल रिपोर्ट में देखने के लिए वही रिपोर्ट जोड़ें।",
      "Sube el documento original para ver la fuente.",
      "请上传原始文件以查看结果出处。"
    ],
    "Close search": ["खोज बंद करें", "Cerrar búsqueda", "关闭搜索"],
    "Find a test": ["जांच का नाम खोजें", "Buscar una prueba", "搜索检测项目"],
    "Filter measurements": ["नतीजे छांटें", "Filtrar resultados", "筛选检测结果"],
    "All results": ["सभी नतीजे", "Todos los resultados", "全部结果"],
    "Flagged results": ["अलग नतीजे", "Resultados señalados", "已标记的结果"],
    "Within range": ["सीमा के अंदर", "Dentro del rango", "参考范围内"],
    "Unclassified": ["तुलना नहीं हुई", "Sin clasificar", "未分类"],
    "Needs review": ["मूल रिपोर्ट से जांचें", "Requiere revisión", "需要核对"],
    "High": ["ज़्यादा", "Alto", "偏高"],
    "Low": ["कम", "Bajo", "偏低"],
    "Flagged": ["अलग नतीजा", "Señalado", "已标记"],
    "Check source": ["मूल रिपोर्ट से जांचें", "Revisar fuente", "核对原文"],
    "The report text is available. Its results have not been mapped into individual measurements yet.":
        [
      "रिपोर्ट का लिखा हुआ हिस्सा पढ़ लिया गया है। अलग-अलग जांच के नतीजे अभी नहीं पहचाने गए हैं।",
      "El texto está disponible, pero los resultados aún no se han organizado por prueba.",
      "报告文本已读取，但尚未整理为各项检测结果。"
    ],
    "The assistant can explain the text, but cannot point to a measurement until it is mapped.":
        [
      "सहायक लिखी हुई बात समझा सकता है। किसी जांच की जगह दिखाने से पहले उसके नतीजे को पहचानना होगा।",
      "El asistente puede explicar el texto. Para señalar una prueba, primero hay que identificarla.",
      "助手可以解释文本；识别出具体检测结果后，才能指出其位置。"
    ],
    "No measurements match this filter.": [
      "इस छंटाई में कोई नतीजा नहीं मिला।",
      "No hay resultados con este filtro.",
      "此筛选条件下没有检测结果。"
    ],
    "Reference range": [
      "रिपोर्ट में दी हुई सीमा",
      "Rango de referencia",
      "参考范围"
    ],
    "Close": ["बंद करें", "Cerrar", "关闭"],
    "Reference not printed": [
      "रिपोर्ट में सीमा नहीं दी गई",
      "Referencia no indicada",
      "未注明参考范围"
    ],
    "Reference: {range}": [
      "रिपोर्ट में दी हुई सीमा: {range}",
      "Referencia: {range}",
      "参考范围：{range}"
    ],
    "Ref: {range}": ["सीमा: {range}", "Ref.: {range}", "参考：{range}"],
    "Not printed": ["नहीं दिया गया", "No indicado", "未注明"],
    "Listen to {test}": [
      "{test} का नतीजा सुनें",
      "Escuchar {test}",
      "收听{test}的讲解"
    ],
    "Correct {test}": [
      "{test} का नतीजा सुधारें",
      "Corregir {test}",
      "更正{test}"
    ],
    "Questions for your doctor": [
      "डॉक्टर से पूछने के लिए सवाल",
      "Preguntas para tu médico",
      "可以向医生询问的问题"
    ],
    "What could affect my {test} result of {value} {unit}?": [
      "मेरी {test} जांच में {value} {unit} आया है। किन बातों का इस पर असर हो सकता है?",
      "¿Qué podría influir en mi resultado de {test}: {value} {unit}?",
      "哪些因素可能影响我的{test}结果（{value} {unit}）？"
    ],
    "Ask whether follow-up is needed in your situation.": [
      "पूछें कि आपकी स्थिति में आगे कोई जांच या मुलाकात ज़रूरी है या नहीं।",
      "Pregunta si necesitas seguimiento en tu caso.",
      "询问你的情况是否需要复查或随访。"
    ],
    "How do these results fit with my symptoms and medical history?": [
      "मेरी तकलीफों और पहले की बीमारी के साथ इन नतीजों को कैसे समझें?",
      "¿Cómo se relacionan estos resultados con mis síntomas y antecedentes?",
      "结合我的症状和病史，应如何理解这些结果？"
    ],
    "Is there anything I should check or discuss at my next visit?": [
      "अगली मुलाकात में मुझे क्या जांचना या पूछना चाहिए?",
      "¿Qué debería revisar o comentar en mi próxima consulta?",
      "下次就诊时，我还需要核对或讨论什么？"
    ],
    "UNDERSTAND. ASK. FEEL INFORMED.": [
      "समझें। पूछें। जानकारी पाएं।",
      "COMPRENDE. PREGUNTA. INFÓRMATE.",
      "读懂报告，安心提问。"
    ],
    "Your report.\nA clearer conversation.": [
      "आपकी रिपोर्ट।\nअपनी भाषा में समझें।",
      "Tu informe.\nUna conversación más clara.",
      "你的报告。\n一起聊明白。"
    ],
    "Make sense of medical terms and numbers, in a language that feels like home.":
        [
      "मेडिकल रिपोर्ट के शब्दों और नंबरों को अपनी समझ की भाषा में जानें।",
      "Comprende los términos y las cifras médicas en un idioma cercano a ti.",
      "用你熟悉的语言，理解医疗术语和数值。"
    ],
    "Add your report": ["अपनी रिपोर्ट जोड़ें", "Añade tu informe", "添加你的报告"],
    "Upload a PDF, choose a photo, or use your camera.": [
      "PDF या फोटो जोड़ें, या कैमरे से तस्वीर लें।",
      "Sube un PDF, elige una foto o usa la cámara.",
      "上传PDF、选择照片，或用相机拍照。"
    ],
    "See it at the source": [
      "मूल रिपोर्ट में नतीजा देखें",
      "Comprueba la fuente",
      "对照原始报告"
    ],
    "Review the numbers alongside the original report.": [
      "मूल रिपोर्ट के साथ नंबरों को मिलाकर देखें।",
      "Compara las cifras con el informe original.",
      "将数值与原始报告逐项核对。"
    ],
    "Talk it through": ["बात करके समझें", "Conversemos", "通过对话来理解"],
    "Ask a question and hear a simple explanation.": [
      "सवाल पूछें और आसान भाषा में जवाब सुनें।",
      "Haz una pregunta y escucha una explicación sencilla.",
      "提出问题，听取简单易懂的讲解。"
    ],
    "An example explanation": [
      "समझाने का एक उदाहरण",
      "Un ejemplo de explicación",
      "讲解示例"
    ],
    "“What does hemoglobin measure?”": [
      "“हीमोग्लोबिन की जांच क्या बताती है?”",
      "“¿Qué mide la hemoglobina?”",
      "“血红蛋白检测测量什么？”"
    ],
    "Hemoglobin carries oxygen through your blood. Your doctor looks at this result alongside your other tests and how you feel.":
        [
      "हीमोग्लोबिन खून के ज़रिए शरीर तक ऑक्सीजन पहुंचाता है। डॉक्टर इस नतीजे को दूसरी जांचों और आपकी तकलीफों के साथ देखते हैं।",
      "La hemoglobina transporta oxígeno en la sangre. Tu médico considera este resultado junto con otras pruebas y cómo te sientes.",
      "血红蛋白通过血液运送氧气。医生会结合其他检查和你的身体感受来判断这一结果。"
    ],
    "Illustrative content · not your report": [
      "यह केवल उदाहरण है · आपकी रिपोर्ट नहीं",
      "Solo un ejemplo · no es tu informe",
      "仅为示例 · 并非你的报告"
    ],
    "Add your medical report": [
      "अपनी मेडिकल रिपोर्ट जोड़ें",
      "Añade tu informe médico",
      "添加医疗报告"
    ],
    "A PDF or a clear photo is all you need.": [
      "PDF या साफ फोटो जोड़ें।",
      "Solo necesitas un PDF o una foto clara.",
      "只需一份PDF或清晰照片。"
    ],
    "Drop your report here": [
      "रिपोर्ट यहां छोड़ें",
      "Suelta tu informe aquí",
      "将报告放在这里"
    ],
    "Drag your report here": [
      "अपनी रिपोर्ट यहां खींचकर लाएं",
      "Arrastra tu informe aquí",
      "将报告拖到这里"
    ],
    "PDF, JPG, PNG or WebP · under 4 MB": [
      "PDF, JPG, PNG या WebP · 4 MB से कम",
      "PDF, JPG, PNG o WebP · menos de 4 MB",
      "PDF、JPG、PNG或WebP · 小于4 MB"
    ],
    "Choose PDF": ["PDF चुनें", "Elegir PDF", "选择PDF"],
    "Take photo": ["फोटो लें", "Tomar foto", "拍照"],
    "Choose photo": ["फोटो चुनें", "Elegir foto", "选择照片"],
    "Keep the full page in view, with good light and no blur. For clear, printed English reports.":
        [
      "पूरा पन्ना साफ और अच्छी रोशनी में रखें। अभी साफ, अंग्रेज़ी में छपी रिपोर्ट के लिए है।",
      "Incluye la página completa, con buena luz y sin desenfoque. Para informes impresos en inglés y legibles.",
      "请拍到完整页面，确保光线充足、文字清晰。目前适用于清晰的英文打印报告。"
    ],
    "Reports and voice questions use Groq. Spoken answers use Microsoft Edge neural speech.":
        [
      "रिपोर्ट और आवाज़ के सवाल Groq पर प्रोसेस होते हैं। जवाब Microsoft Edge neural speech से सुनाए जाते हैं।",
      "Groq procesa los informes y las preguntas por voz. Microsoft Edge neural speech genera las respuestas habladas.",
      "Groq处理报告和语音提问，Microsoft Edge神经语音生成语音回答。"
    ],
    "Return to your current report": [
      "अपनी मौजूदा रिपोर्ट पर लौटें",
      "Volver a tu informe actual",
      "返回当前报告"
    ],
    "Reading your report…": [
      "आपकी रिपोर्ट पढ़ रहे हैं…",
      "Leyendo tu informe…",
      "正在读取报告…"
    ],
    "A clearer view starts with your report.": [
      "अपनी रिपोर्ट जोड़कर समझना शुरू करें।",
      "Empieza a entender tu informe.",
      "从添加报告开始，读得更明白。"
    ],
    "Upload a PDF or a clear photo to see your results and start a conversation.":
        [
      "नतीजे देखने और बात करके समझने के लिए PDF या साफ फोटो जोड़ें।",
      "Sube un PDF o una foto clara para ver tus resultados y conversar.",
      "上传PDF或清晰照片，查看结果并开始对话。"
    ],
    "Add a report": ["रिपोर्ट जोड़ें", "Añadir informe", "添加报告"],
    "PDF downloaded successfully": [
      "PDF डाउनलोड हो गई",
      "PDF descargado",
      "PDF已下载"
    ],
    "Could not create the PDF. Please try again.": [
      "PDF नहीं बन सकी। फिर कोशिश करें।",
      "No se pudo crear el PDF. Inténtalo de nuevo.",
      "无法生成PDF，请重试。"
    ],
    "Choose a report under 4 MB.": [
      "4 MB से छोटी रिपोर्ट चुनें।",
      "Elige un informe de menos de 4 MB.",
      "请选择小于4 MB的报告。"
    ],
    "Choose a photo smaller than 4 MB.": [
      "4 MB से छोटी फोटो चुनें।",
      "Elige una foto de menos de 4 MB.",
      "请选择小于4 MB的照片。"
    ],
    "Choose a file smaller than 4 MB.": [
      "4 MB से छोटी फाइल चुनें।",
      "Elige un archivo de menos de 4 MB.",
      "请选择小于4 MB的文件。"
    ],
    "Choose a PDF, JPG, PNG or WebP report.": [
      "PDF, JPG, PNG या WebP रिपोर्ट चुनें।",
      "Elige un informe PDF, JPG, PNG o WebP.",
      "请选择PDF、JPG、PNG或WebP报告。"
    ],
    "This file is empty. Choose another report.": [
      "यह फाइल खाली है। दूसरी रिपोर्ट चुनें।",
      "Este archivo está vacío. Elige otro informe.",
      "此文件为空，请选择另一份报告。"
    ],
    "The saved report could not be restored. You can upload it again.": [
      "सेव की गई रिपोर्ट नहीं खुल सकी। उसे फिर से जोड़ सकते हैं।",
      "No se pudo recuperar el informe guardado. Puedes subirlo de nuevo.",
      "无法恢复已保存的报告，你可以重新上传。"
    ],
    "This report could not be saved in this browser. Keep this tab open or download the summary.":
        [
      "इस ब्राउज़र में रिपोर्ट सेव नहीं हो सकी। यह टैब खुला रखें या सारांश डाउनलोड करें।",
      "No se pudo guardar el informe en este navegador. Mantén esta pestaña abierta o descarga el resumen.",
      "此浏览器无法保存报告。请保持此标签页打开，或下载摘要。"
    ],
    "The saved report could not be cleared. Try again.": [
      "सेव रिपोर्ट नहीं हट सकी। फिर कोशिश करें।",
      "No se pudo borrar el informe guardado. Inténtalo de nuevo.",
      "无法清除已保存的报告，请重试。"
    ],
    "Review could not be saved.": [
      "सुधार सेव नहीं हो सके।",
      "No se pudo guardar la revisión.",
      "无法保存核对内容。"
    ],
    "The results could not be updated. Check your connection and try again.": [
      "नतीजे अपडेट नहीं हो सके। इंटरनेट जांचकर फिर कोशिश करें।",
      "No se pudieron actualizar los resultados. Revisa tu conexión y vuelve a intentarlo.",
      "无法更新结果，请检查网络后重试。"
    ],
    "The source could not be read.": [
      "मूल रिपोर्ट नहीं पढ़ी जा सकी।",
      "No se pudo leer el documento original.",
      "无法读取原始报告。"
    ],
    "The source could not be re-read. Check your connection and try again.": [
      "मूल रिपोर्ट दोबारा नहीं पढ़ी जा सकी। इंटरनेट जांचकर फिर कोशिश करें।",
      "No se pudo volver a leer el documento. Revisa tu conexión e inténtalo otra vez.",
      "无法重新读取原始报告，请检查网络后重试。"
    ],
    "Unable to read file data. Please try again.": [
      "फाइल नहीं पढ़ी जा सकी। फिर कोशिश करें।",
      "No se pudo leer el archivo. Inténtalo de nuevo.",
      "无法读取文件，请重试。"
    ],
    "We could not open this photo. Try choosing it from your device.": [
      "यह फोटो नहीं खुल सकी। डिवाइस में सेव फोटो चुनकर कोशिश करें।",
      "No se pudo abrir la foto. Intenta elegirla desde tu dispositivo.",
      "无法打开照片，请尝试从设备中选择照片。"
    ],
    "Upload failed. Try another file.": [
      "रिपोर्ट अपलोड नहीं हुई। दूसरी फाइल चुनें।",
      "No se pudo subir el informe. Prueba otro archivo.",
      "上传失败，请尝试其他文件。"
    ],
    "We could not upload this report. Check your connection and try again.": [
      "रिपोर्ट अपलोड नहीं हो सकी। इंटरनेट जांचकर फिर कोशिश करें।",
      "No se pudo subir el informe. Revisa tu conexión e inténtalo otra vez.",
      "无法上传报告，请检查网络后重试。"
    ],
    "We could not read this report. Try a clearer photo or another PDF.": [
      "रिपोर्ट नहीं पढ़ी जा सकी। साफ फोटो या दूसरी PDF चुनें।",
      "No se pudo leer el informe. Prueba una foto más clara u otro PDF.",
      "无法读取报告，请尝试更清晰的照片或另一份PDF。"
    ],
    "We could not finish reading this report. Check your connection and try again.":
        [
      "रिपोर्ट पूरी नहीं पढ़ी जा सकी। इंटरनेट जांचकर फिर कोशिश करें।",
      "No se pudo terminar de leer el informe. Revisa tu conexión y vuelve a intentarlo.",
      "无法完成报告读取，请检查网络后重试。"
    ],
    "Narration unavailable. Check your connection and try Play again.": [
      "आवाज़ नहीं चल सकी। इंटरनेट जांचकर फिर सुनने की कोशिश करें।",
      "La narración no está disponible. Revisa tu conexión y vuelve a reproducirla.",
      "语音暂不可用，请检查网络后重新播放。"
    ],
    "Playback could not resume. Try Play again.": [
      "आवाज़ दोबारा नहीं चल सकी। सुनने का बटन फिर दबाएं।",
      "No se pudo reanudar el audio. Vuelve a reproducirlo.",
      "无法继续播放，请重新播放。"
    ],
    "Translation unavailable": [
      "अभी अनुवाद नहीं हो सका",
      "Traducción no disponible",
      "翻译暂不可用"
    ],
    "Uploading your photo": [
      "आपकी फोटो भेज रहे हैं",
      "Subiendo tu foto",
      "正在上传照片"
    ],
    "Uploading your PDF": [
      "आपकी PDF भेज रहे हैं",
      "Subiendo tu PDF",
      "正在上传PDF"
    ],
    "Reading text from your photo": [
      "आपकी फोटो में लिखा पढ़ रहे हैं",
      "Leyendo el texto de tu foto",
      "正在识别照片文字"
    ],
    "Reading your PDF": ["आपकी PDF पढ़ रहे हैं", "Leyendo tu PDF", "正在读取PDF"],
    "Preparing your explanation": [
      "आपके लिए जवाब तैयार कर रहे हैं",
      "Preparando tu explicación",
      "正在准备讲解"
    ],
    "Reading original document pages...": [
      "मूल रिपोर्ट के पन्ने पढ़ रहे हैं…",
      "Leyendo las páginas originales…",
      "正在读取原始报告页面…"
    ],
    "Extracting text from document...": [
      "रिपोर्ट में लिखा पढ़ रहे हैं…",
      "Extrayendo el texto…",
      "正在读取报告文字…"
    ],
    "Checking your report...": [
      "आपकी रिपोर्ट जांच रहे हैं…",
      "Comprobando tu informe…",
      "正在检查报告…"
    ],
    "Associating patient results with their source cells...": [
      "नतीजों को मूल रिपोर्ट से मिला रहे हैं…",
      "Vinculando los resultados con su fuente…",
      "正在将结果与原始内容对应…"
    ],
    "Checking source fields and extraction coverage...": [
      "नतीजे और पढ़े गए हिस्से जांच रहे हैं…",
      "Comprobando los campos y las páginas leídas…",
      "正在核对结果和读取范围…"
    ],
    "Preparing the source-validated explanation...": [
      "रिपोर्ट के आधार पर जवाब तैयार कर रहे हैं…",
      "Preparando la explicación con su fuente…",
      "正在根据原文准备讲解…"
    ],
    "Saving results...": [
      "नतीजे सेव कर रहे हैं…",
      "Guardando los resultados…",
      "正在保存结果…"
    ],
    "Processing complete": ["रिपोर्ट पढ़ ली गई", "Informe listo", "报告已就绪"],
    "Microphone unavailable. Allow microphone access, or type your question below.":
        [
      "माइक्रोफोन नहीं खुल सका। माइक्रोफोन की अनुमति दें या नीचे सवाल लिखें।",
      "El micrófono no está disponible. Permite el acceso o escribe tu pregunta abajo.",
      "麦克风不可用。请允许麦克风访问，或在下方输入问题。"
    ],
    "Keep each spoken question under 2 MB. Try a shorter recording.": [
      "छोटा सवाल रिकॉर्ड करें। हर रिकॉर्डिंग 2 MB से कम रखें।",
      "Graba una pregunta más corta, de menos de 2 MB.",
      "请录制较短的问题，每段录音小于2 MB。"
    ],
    "This report is too large for the free pilot. Try a shorter report.": [
      "यह रिपोर्ट इस पायलट के लिए बड़ी है। छोटी रिपोर्ट चुनें।",
      "Este informe es demasiado grande para la prueba gratuita. Elige uno más corto.",
      "此报告超出试用大小限制，请选择较短的报告。"
    ],
    "The voice service could not be reached. Check your connection and try again.":
        [
      "आवाज़ वाली सेवा से संपर्क नहीं हुआ। इंटरनेट जांचकर फिर कोशिश करें।",
      "No se pudo conectar con el servicio de voz. Revisa tu conexión e inténtalo otra vez.",
      "无法连接语音服务，请检查网络后重试。"
    ],
    "Please try your question again.": [
      "अपना सवाल फिर पूछें।",
      "Vuelve a hacer tu pregunta.",
      "请重新提问。"
    ],
    "We could not finish that. Please try again or choose another report.": [
      "यह काम पूरा नहीं हो सका। फिर कोशिश करें या दूसरी रिपोर्ट चुनें।",
      "No se pudo completar. Inténtalo de nuevo o elige otro informe.",
      "无法完成操作，请重试或选择另一份报告。"
    ],
    "This file does not appear to be a patient medical report. Please choose a lab report, scan result, prescription or clinical report.":
        [
      "यह मरीज की मेडिकल रिपोर्ट नहीं लगती। जांच की रिपोर्ट, स्कैन का नतीजा, पर्चा या डॉक्टर की रिपोर्ट चुनें।",
      "Este archivo no parece un informe médico de un paciente. Elige resultados de laboratorio, un informe de imagen, una receta o un informe clínico.",
      "此文件似乎不是患者医疗报告。请选择化验报告、影像结果、处方或临床报告。"
    ],
    "We could not verify that this is a patient medical report. Please choose the original report or a clearer photo showing its heading and results.":
        [
      "यह मरीज की मेडिकल रिपोर्ट है या नहीं, साफ नहीं हो सका। शीर्षक और नतीजे दिखाने वाली मूल रिपोर्ट या साफ फोटो चुनें।",
      "No se pudo confirmar que sea un informe médico. Elige el original o una foto más clara con el encabezado y los resultados.",
      "无法确认这是否为患者医疗报告。请选择原始报告，或标题和结果清晰可见的照片。"
    ],
    "The free AI quota is busy or exhausted. Please wait and try again.": [
      "अभी मुफ्त सेवा की सीमा पूरी हो गई है। कुछ देर बाद फिर कोशिश करें।",
      "Se alcanzó el límite gratuito de IA. Espera un momento y vuelve a intentarlo.",
      "免费AI额度暂已用尽，请稍后重试。"
    ],
    "This report exceeds the free AI request allowance. Try a shorter report or a single clear report page.":
        [
      "यह रिपोर्ट मुफ्त सेवा की सीमा से बड़ी है। छोटी रिपोर्ट या एक साफ पन्ना चुनें।",
      "Este informe supera el límite gratuito. Prueba uno más corto o una sola página clara.",
      "此报告超出免费请求限制，请尝试较短的报告或一张清晰页面。"
    ],
    "The AI service is temporarily unavailable. Please try again.": [
      "AI सेवा अभी नहीं चल रही है। कुछ देर बाद फिर कोशिश करें।",
      "El servicio de IA no está disponible por el momento. Inténtalo de nuevo.",
      "AI服务暂不可用，请稍后重试。"
    ],
    "The AI service did not return a complete answer. Please ask again.": [
      "पूरा जवाब नहीं मिल सका। अपना सवाल फिर पूछें।",
      "El servicio de IA no devolvió una respuesta completa. Vuelve a preguntar.",
      "AI未能返回完整回答，请重新提问。"
    ],
    "The hosted AI service could not be reached. Please try again.": [
      "AI सेवा से संपर्क नहीं हुआ। फिर कोशिश करें।",
      "No se pudo conectar con el servicio de IA. Inténtalo de nuevo.",
      "无法连接AI服务，请重试。"
    ],
    "The neural voice service is unavailable. Check your internet connection and try again. No substitute voice was used.":
        [
      "आवाज़ की सेवा अभी नहीं चल रही है। इंटरनेट जांचकर फिर कोशिश करें। दूसरी आवाज़ इस्तेमाल नहीं की गई।",
      "El servicio de voz no está disponible. Revisa tu conexión e inténtalo otra vez. No se usó otra voz.",
      "神经语音服务暂不可用，请检查网络后重试。未使用其他替代语音。"
    ],
    "I could not hear the question clearly. Please speak again or type it.": [
      "आपका सवाल साफ नहीं सुनाई दिया। फिर बोलें या लिखें।",
      "No pude oír bien la pregunta. Repítela o escríbela.",
      "没有听清问题，请重新说一遍或输入文字。"
    ],
    "Keep each spoken question under one minute.": [
      "हर सवाल एक मिनट से छोटा रखें।",
      "Cada pregunta debe durar menos de un minuto.",
      "每个语音问题请控制在一分钟内。"
    ],
    "This audio could not be read. Please record the question again.": [
      "यह रिकॉर्डिंग नहीं सुनी जा सकी। सवाल फिर रिकॉर्ड करें।",
      "No se pudo leer el audio. Graba la pregunta de nuevo.",
      "无法读取音频，请重新录制问题。"
    ],
    "The report was corrected. Ask again using the updated results.": [
      "रिपोर्ट में सुधार हुआ है। नए नतीजों के साथ सवाल फिर पूछें।",
      "El informe se corrigió. Vuelve a preguntar con los resultados actualizados.",
      "报告已更正，请根据更新后的结果重新提问。"
    ],
    "The model did not return an explanation. Try a shorter question.": [
      "जवाब नहीं मिल सका। छोटा सवाल पूछकर कोशिश करें।",
      "No se recibió una explicación. Prueba con una pregunta más corta.",
      "未收到讲解，请尝试更简短的问题。"
    ],
    "The model returned invalid source citations. Please ask again.": [
      "जवाब को रिपोर्ट से नहीं मिलाया जा सका। फिर पूछें।",
      "No se pudo comprobar la fuente de la respuesta. Vuelve a preguntar.",
      "无法核对回答的报告出处，请重新提问。"
    ],
    "Voice processing could not finish. Please ask again.": [
      "आवाज़ वाला जवाब पूरा नहीं हो सका। फिर पूछें।",
      "No se pudo completar la respuesta por voz. Vuelve a preguntar.",
      "无法完成语音回答，请重新提问。"
    ],
    "Choose a report of up to 100 pages.": [
      "100 पन्नों तक की रिपोर्ट चुनें।",
      "Elige un informe de hasta 100 páginas.",
      "请选择不超过100页的报告。"
    ],
    "We could not read the report. Choose a clearer photo or original PDF.": [
      "रिपोर्ट नहीं पढ़ी जा सकी। साफ फोटो या मूल PDF चुनें।",
      "No se pudo leer el informe. Elige una foto más clara o el PDF original.",
      "无法读取报告，请选择更清晰的照片或原始PDF。"
    ],
    "We could not read this PDF. Choose an unlocked original PDF or a clearer report photo.":
        [
      "यह PDF नहीं पढ़ी जा सकी। बिना पासवर्ड वाली मूल PDF या साफ फोटो चुनें।",
      "No se pudo leer el PDF. Elige el original sin contraseña o una foto más clara.",
      "无法读取PDF，请选择无密码的原始PDF或更清晰的报告照片。"
    ],
    "We could not read this page. Try a clearer report photo.": [
      "यह पन्ना नहीं पढ़ा जा सका। रिपोर्ट की साफ फोटो चुनें।",
      "No se pudo leer esta página. Prueba una foto más clara.",
      "无法读取此页面，请尝试更清晰的报告照片。"
    ],
    "Choose a nonempty report under 4 MB.": [
      "4 MB से छोटी और खाली न होने वाली रिपोर्ट चुनें।",
      "Elige un informe no vacío de menos de 4 MB.",
      "请选择非空且小于4 MB的报告。"
    ],
    "Source locations could not be read. Try a clearer photo or PDF.": [
      "नतीजों की जगह नहीं पहचानी गई। साफ फोटो या PDF चुनें।",
      "No se pudieron localizar los resultados. Prueba una foto más clara o un PDF.",
      "无法定位结果出处，请尝试更清晰的照片或PDF。"
    ],
    "This is a different source document. The saved corrections remain unchanged.":
        [
      "यह दूसरी मूल रिपोर्ट है। पहले सेव किए सुधार नहीं बदले हैं।",
      "Este es otro documento. Las correcciones guardadas se conservan.",
      "这不是同一份原始报告，已保存的更正保持不变。"
    ],
    "The question is too long. Try a shorter question.": [
      "सवाल लंबा है। छोटा सवाल पूछें।",
      "La pregunta es demasiado larga. Hazla más breve.",
      "问题过长，请简短提问。"
    ],
  };
}
