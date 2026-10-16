import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'report_data.dart';
import 'report_snapshot.dart';
import 'body_systems.dart';

class VoicePanel extends StatefulWidget {
  const VoicePanel(
      {super.key,
      required this.report,
      required this.language,
      required this.onLanguage,
      required this.apiUrl,
      required this.onCitations,
      required this.onReportId,
      this.expanded = true,
      this.active = true,
      this.autoplay = true,
      this.playbackRate = 1,
      this.largeText = false,
      this.forceExplanationAudio = false,
      this.onExpand,
      this.explainRequest = 0,
      this.explainMeasurementId,
      this.onExplanationStarted});
  final int explainRequest;
  final String? explainMeasurementId;
  final ValueChanged<int>? onExplanationStarted;
  final bool expanded, autoplay, active;
  final double playbackRate;
  final bool largeText, forceExplanationAudio;
  final VoidCallback? onExpand;
  final Map<String, dynamic> report;
  final String language;
  final ValueChanged<String> onLanguage;
  final Uri Function(String) apiUrl;
  final ValueChanged<List<String>> onCitations;
  final ValueChanged<String> onReportId;
  @override
  State<VoicePanel> createState() => _VoicePanelState();
}

class _VoicePanelState extends State<VoicePanel> {
  final _question = TextEditingController();
  final _answerScroll = ScrollController();
  String _lastQuestion = '';
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  html.AudioElement? _audio;
  http.Client? _client;
  String? _audioUrl, _error;
  String _answer = '';
  List<String> _citations = [];
  final List<Map<String, String>> _history = [];
  Map<String, dynamic>? _lastAnswer;
  final List<html.Blob> _chunks = [];
  Timer? _recordLimit;
  StreamSubscription<html.BlobEvent>? _recordData;
  bool _recording = false, _checking = false, _speaking = false;
  int _generation = 0;

  static const labels = {
    'en': [
      'Talk through your report',
      'Ready to help',
      'Listening',
      'Reading your report',
      'Speaking',
      'Ask a question',
      'Tap to speak',
      'Stop',
      'Repeat',
      'Slower',
      'Simpler',
      'Ask about any test or section in your report.',
      'Send question'
    ],
    'hi': [
      'अपनी रिपोर्ट को समझें',
      'बात करने के लिए तैयार',
      'सुन रहे हैं',
      'आपकी रिपोर्ट देख रहे हैं',
      'बोल रहे हैं',
      'अपना सवाल लिखें',
      'बोलने के लिए दबाएं',
      'रोकें',
      'फिर से',
      'धीरे',
      'आसान भाषा',
      'रिपोर्ट की किसी भी जांच या हिस्से के बारे में पूछें।',
      'सवाल भेजें'
    ],
    'es': [
      'Hablemos de tu informe',
      'Listo para ayudarte',
      'Escuchando',
      'Leyendo tu informe',
      'Hablando',
      'Escribe tu pregunta',
      'Toca para hablar',
      'Detener',
      'Repetir',
      'Más lento',
      'Más simple',
      'Pregunta sobre cualquier prueba o sección de tu informe.',
      'Enviar pregunta'
    ],
    'zh': [
      '一起读懂你的报告',
      '准备好了',
      '正在聆听',
      '正在查看报告',
      '正在讲解',
      '输入你的问题',
      '点击说话',
      '停止',
      '重听',
      '慢一点',
      '更简单',
      '你可以询问报告中的任何检查或内容。',
      '发送问题'
    ],
  };
  List<String> get _copy => labels[widget.language] ?? labels['en']!;

  @override
  void initState() {
    super.initState();
    _scheduleExplanation();
  }

  void _scheduleExplanation() {
    final request = widget.explainRequest;
    final id = widget.explainMeasurementId;
    if (request == 0 || id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.explainRequest != request ||
          widget.explainMeasurementId != id) {
        return;
      }
      final matches = workspaceMeasurements(widget.report)
          .where((row) => row['measurement_id'] == id);
      if (matches.isNotEmpty) {
        widget.onExplanationStarted?.call(request);
        _explainRow(matches.first, forceAudio: widget.forceExplanationAudio);
      }
    });
  }

  Future<void> _explainRow(Map<String, dynamic> row,
      {bool forceAudio = false}) async {
    // Do not pair a newly selected organ with the previous test's answer.
    setState(() {
      _answer = '';
      _citations = [];
    });
    final name = row['test_name'];
    final question = {
      'en':
          'Explain my $name result in simple words. Give its exact value and unit, compare only with the supplied reference, and explain what the test measures.',
      'hi':
          'मेरी $name जांच का नतीजा आसान हिन्दी में समझाएं। रिपोर्ट का सही नंबर और इकाई बताएं, सिर्फ दी हुई सीमा से तुलना करें और जांच क्या मापती है वह समझाएं।',
      'es':
          'Explica mi resultado de $name con palabras sencillas, su valor y unidad exactos y qué mide la prueba. Compara solo con la referencia del informe.',
      'zh': '请用简单的话解释我的$name检测结果，说明报告中的确切数值、单位和检测用途，只与报告给出的参考范围比较。',
    }[widget.language]!;
    await _ask(
        prompt: question,
        displayQuestion: bodyCopy(
            widget.language,
            'Explain my $name result',
            'मेरी $name जांच समझाएं',
            'Explica mi resultado de $name',
            '解释我的$name检测结果'),
        forceAudio: forceAudio);
  }

  @override
  void didUpdateWidget(covariant VoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.report['parsed_data'] != widget.report['parsed_data']) {
      _stop(notify: false);
      _answer = '';
      _lastQuestion = '';
      _citations = [];
      _history.clear();
      _lastAnswer = null;
      _error = null;
    }
    if (oldWidget.explainRequest != widget.explainRequest) {
      _scheduleExplanation();
    }
    if (oldWidget.autoplay && !widget.autoplay) _stop(notify: false);
    if (oldWidget.active && !widget.active) _stop(notify: false);
  }

  void _stop({bool notify = true}) {
    ++_generation;
    _client?.close();
    _client = null;
    _recordLimit?.cancel();
    if (_recorder?.state == 'recording') _recorder?.stop();
    _recordData?.cancel();
    for (final track in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
    _recorder = null;
    _audio?.pause();
    _audio = null;
    if (_audioUrl != null) html.Url.revokeObjectUrl(_audioUrl!);
    _audioUrl = null;
    _recording = false;
    _checking = false;
    _speaking = false;
    if (notify && mounted) setState(() {});
  }

  Future<void> _record() async {
    widget.onExpand?.call();
    _stop();
    final generation = _generation;
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true},
        'video': false
      });
      if (!mounted || generation != _generation) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        return;
      }
      _stream = stream;
      final type = html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
          ? 'audio/webm;codecs=opus'
          : 'audio/mp4';
      _recorder = html.MediaRecorder(stream, {'mimeType': type});
      _chunks.clear();
      _recordData =
          const html.EventStreamProvider<html.BlobEvent>('dataavailable')
              .forTarget(_recorder!)
              .listen((event) {
        final data = event.data;
        if (data != null && data.size > 0) _chunks.add(data);
      });
      _recorder!.start();
      _recordLimit = Timer(const Duration(seconds: 45), _finishRecording);
      setState(() {
        _recording = true;
        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _stop();
      setState(() => _error =
          'Microphone unavailable. Allow microphone access, or type your question below.');
    }
  }

  Future<void> _finishRecording() async {
    final recorder = _recorder;
    if (recorder == null || !_recording) return;
    final generation = _generation;
    _recordLimit?.cancel();
    final stopped = const html.EventStreamProvider<html.Event>('stop')
        .forTarget(recorder)
        .first;
    recorder.stop();
    await stopped;
    for (final track in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
    _recorder = null;
    if (!mounted || generation != _generation) return;
    final blob = html.Blob(_chunks, recorder.mimeType);
    final reader = html.FileReader();
    final loaded = reader.onLoadEnd.first;
    reader.readAsArrayBuffer(blob);
    await loaded;
    if (!mounted || generation != _generation) return;
    final result = reader.result;
    final bytes =
        result is ByteBuffer ? result.asUint8List() : result as Uint8List;
    _recordData?.cancel();
    setState(() => _recording = false);
    await _ask(audio: bytes);
  }

  Future<void> _ask(
      {Uint8List? audio,
      String? action,
      String? prompt,
      String? displayQuestion,
      bool forceAudio = false}) async {
    final text = prompt ?? _question.text.trim();
    if (audio == null && action == null && text.isEmpty) return;
    FocusScope.of(context).unfocus();
    if (action != 'repeat' && action != 'slower') widget.onExpand?.call();
    _stop();
    final generation = _generation;
    final language = widget.language;
    final client = http.Client();
    _client = client;
    setState(() {
      _checking = true;
      _error = null;
      if (action == null) {
        _answer = '';
        _citations = [];
        _lastQuestion = audio == null ? (displayQuestion ?? text) : '';
      }
    });
    try {
      final snapshot = reportSnapshot(widget.report);
      final reportId = (snapshot['report_id'] ?? '').toString();
      final encodedSnapshot = jsonEncode(snapshot);
      if (utf8.encode(encodedSnapshot).length > 2000000) {
        throw const FormatException(
            'This report is too large for the free pilot. Try a shorter report.');
      }
      http.Response response;
      if (audio != null) {
        if (audio.length > 2000000) {
          throw const FormatException(
              'Keep each spoken question under 2 MB. Try a shorter recording.');
        }
        final request =
            http.MultipartRequest('POST', widget.apiUrl('/voice/turn'));
        request.fields.addAll({
          'report_id': reportId,
          'language': language,
          'report_snapshot': encodedSnapshot,
          'history': jsonEncode(_history),
          if (_lastAnswer != null) 'last_answer': jsonEncode(_lastAnswer),
        });
        request.files.add(http.MultipartFile.fromBytes('audio', audio,
            filename: 'question.webm'));
        response = await http.Response.fromStream(
            await client.send(request).timeout(const Duration(seconds: 360)));
      } else {
        response = await client
            .post(widget.apiUrl('/voice/turn'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'report_id': reportId,
                  'language': language,
                  'text': text,
                  'report_snapshot': snapshot,
                  'history': _history,
                  if (_lastAnswer != null) 'last_answer': _lastAnswer,
                  if (action != null) 'action': action,
                }))
            .timeout(const Duration(seconds: 360));
      }
      if (!mounted || generation != _generation) return;
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (response.statusCode != 200) {
        throw FormatException(
            (data['detail'] ?? 'Please try your question again.').toString());
      }
      final citations =
          (data['cited_measurement_ids'] as List).whereType<String>().toList();
      widget.onReportId(data['report_id'].toString());
      _lastAnswer = {
        'spoken_answer': data['spoken_answer'],
        'cited_measurement_ids': citations,
        'llm_model': data['llm_model'],
      };
      if (action != 'repeat' && action != 'slower') {
        _history.addAll([
          {'role': 'user', 'content': (data['transcript'] ?? text).toString()},
          {'role': 'assistant', 'content': jsonEncode(_lastAnswer)},
        ]);
        if (_history.length > 8) _history.removeRange(0, _history.length - 8);
      }
      setState(() {
        _answer = data['spoken_answer'].toString();
        if (action == null) {
          _lastQuestion =
              displayQuestion ?? (data['transcript'] ?? text).toString();
        }
        _citations = citations;
        _checking = false;
      });
      _question.clear();
      widget.onCitations(citations);
      if (!widget.autoplay &&
          !forceAudio &&
          audio == null &&
          action != 'repeat' &&
          action != 'slower') {
        return;
      }
      final blob = html.Blob(
          [base64Decode(data['audio_base64'] as String)], 'audio/mpeg');
      _audioUrl = html.Url.createObjectUrlFromBlob(blob);
      final player = html.AudioElement(_audioUrl!)
        ..playbackRate = (data['playback_rate'] as num).toDouble() *
            (action == 'slower' ? 1 : widget.playbackRate);
      _audio = player;
      player.onEnded.listen((_) {
        if (mounted && generation == _generation) {
          setState(() => _speaking = false);
        }
      });
      await player.play();
      if (mounted && generation == _generation) {
        setState(() => _speaking = true);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _checking = false;
          _speaking = false;
          _error = error is FormatException
              ? error.message
              : 'The voice service could not be reached. Check your connection and try again.';
        });
      }
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xff242c2b), green = Color(0xff3f6050);
    final rows = {
      for (final row in workspaceMeasurements(widget.report))
        row['measurement_id']: row
    };
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final selected = rows[widget.report['selected_measurement_id']] ??
        (rows.isEmpty ? null : rows.values.first);
    final sentences = _answer
        .split(RegExp(r'(?<=[।。])|(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final flagged = reportComparisonCounts(widget.report)['abnormal']!;
    final firstQuestion =
        _history.isEmpty && _answer.isEmpty && !_checking && !_recording;
    final status = _recording
        ? _copy[2]
        : _checking
            ? _copy[3]
            : _speaking
                ? _copy[4]
                : _answer.isNotEmpty
                    ? bodyCopy(widget.language, 'Answer ready', 'जवाब तैयार है',
                        'Respuesta lista', '回答已就绪')
                    : _copy[1];
    final activity = Row(mainAxisSize: MainAxisSize.min, children: [
      if (_checking)
        const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: green))
      else
        Icon(
            _speaking || _recording
                ? Icons.graphic_eq_rounded
                : Icons.check_circle_outline_rounded,
            size: 15,
            color: green),
      const SizedBox(width: 7),
      Flexible(
          child: Text(status,
              style: const TextStyle(fontSize: 12, color: green, height: 1.4))),
    ]);
    if (!widget.expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: activity),
                TextButton.icon(
                    onPressed: widget.onExpand,
                    icon: const Icon(Icons.open_in_full_rounded, size: 14),
                    label: Text(
                        bodyCopy(widget.language, 'Open conversation',
                            'बातचीत खोलें', 'Abrir conversación', '打开对话'),
                        style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(44, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 6))),
              ]),
              _composer(),
              if (_error != null) _errorMessage(),
            ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: mobile
              ? const EdgeInsets.fromLTRB(16, 10, 16, 8)
              : const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: activity),
      if (selected != null && !keyboard)
        Padding(
            padding: mobile
                ? const EdgeInsets.fromLTRB(16, 0, 16, 12)
                : const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _selectedResult(selected)),
      const Divider(height: 1, color: Color(0xffe5e0d8)),
      Expanded(
          child: Scrollbar(
        controller: _answerScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _answerScroll,
          padding: const EdgeInsets.fromLTRB(20, 20, 22, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_lastQuestion.isNotEmpty) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.person_outline_rounded,
                    size: 18, color: Color(0xff626a67)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_lastQuestion,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xff626a67),
                            height: 1.5))),
              ]),
              const SizedBox(height: 18),
            ],
            if (_answer.isNotEmpty)
              for (var i = 0; i < sentences.length; i++)
                Padding(
                    padding: EdgeInsets.only(
                        bottom: i == sentences.length - 1 ? 0 : 14),
                    child: Text(sentences[i].trim(),
                        style: TextStyle(
                            fontSize: widget.largeText ? 20 : 18,
                            height: 1.6,
                            color: ink))),
            if (_checking) ...[
              const SizedBox(height: 16),
              Text(
                  bodyCopy(
                      widget.language,
                      'Preparing a source-backed explanation…',
                      'रिपोर्ट के आधार पर जवाब तैयार कर रहे हैं…',
                      'Preparando una explicación basada en tu informe…',
                      '正在根据报告准备讲解…'),
                  style: const TextStyle(
                      fontSize: 15, height: 1.6, color: Color(0xff626a67))),
            ],
            if (firstQuestion) ...[
              Text(
                  bodyCopy(
                      widget.language,
                      'What would you like to understand?',
                      'आप क्या समझना चाहते हैं?',
                      '¿Qué te gustaría entender?',
                      '你想了解什么？'),
                  style: const TextStyle(
                      fontSize: 20, height: 1.4, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(_copy[11],
                  style: const TextStyle(
                      fontSize: 15, height: 1.6, color: Color(0xff626a67))),
              const SizedBox(height: 20),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (flagged > 0)
                  _starter(
                      bodyCopy(
                          widget.language,
                          'Explain my $flagged flagged results',
                          'मेरे $flagged अलग नतीजे समझाएं',
                          'Explicar $flagged resultados señalados',
                          '解释$flagged项异常结果'),
                      () => _ask(
                          prompt:
                              'Explain up to three of my $flagged flagged results, using their exact numbers and units and only the supplied references. Offer to continue with the others.',
                          displayQuestion: bodyCopy(
                              widget.language,
                              'Explain my flagged results',
                              'मेरे अलग नतीजे समझाएं',
                              'Explica mis resultados señalados',
                              '解释我的异常结果'))),
                if (selected != null)
                  _starter(
                      bodyCopy(widget.language, 'Explain this test',
                          'यह जांच समझाएं', 'Explicar esta prueba', '解释这项检测'),
                      () => _explainRow(selected)),
                if (flagged == 0)
                  _starter(
                      bodyCopy(
                          widget.language,
                          'Where should I start?',
                          'कहां से शुरू करूं?',
                          '¿Por dónde empiezo?',
                          '从哪里开始？'),
                      () => _ask(
                          prompt:
                              'Help me start understanding this report. Mention any extraction limitations and explain one important result in simple words.',
                          displayQuestion: bodyCopy(
                              widget.language,
                              'Where should I start?',
                              'कहां से शुरू करूं?',
                              '¿Por dónde empiezo?',
                              '从哪里开始？'))),
              ]),
            ],
            if (_citations.length > 1 ||
                _citations.length == 1 &&
                    _citations.first != selected?['measurement_id']) ...[
              const SizedBox(height: 20),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final id in _citations)
                  if (rows[id] != null)
                    _referenceChip(rows[id]!, () => widget.onCitations([id]))
              ]),
            ],
            if (_error != null) _errorMessage(),
          ]),
        ),
      )),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xffe5e0d8)))),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_answer.isNotEmpty) ...[
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _control(_copy[8], Icons.replay_rounded, 'repeat'),
                  _control(_copy[9], Icons.slow_motion_video_rounded, 'slower'),
                  _control(
                      _copy[10], Icons.lightbulb_outline_rounded, 'simpler'),
                ]),
                const SizedBox(height: 10),
              ],
              _composer(),
            ]),
      ),
    ]);
  }

  Widget _errorMessage() => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(_error!,
          style: const TextStyle(
              fontSize: 14, height: 1.5, color: Color(0xffa32e35))));

  Widget _composer() => Row(children: [
        SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  backgroundColor: _recording
                      ? const Color(0xffa32e35)
                      : const Color(0xff3f6050),
                  shape: const StadiumBorder()),
              onPressed: _recording
                  ? _finishRecording
                  : (_speaking || _checking)
                      ? _stop
                      : _record,
              icon: Icon(
                  _recording
                      ? Icons.send_rounded
                      : (_speaking || _checking)
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                  size: 20),
              label: Text(
                  _recording
                      ? _copy[12]
                      : (_speaking || _checking)
                          ? _copy[7]
                          : _copy[6],
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            )),
        const SizedBox(width: 8),
        Expanded(
            child: TextField(
          controller: _question,
          onSubmitted: _checking || _recording ? null : (_) => _ask(),
          style: const TextStyle(fontSize: 14, height: 1.4),
          decoration: InputDecoration(
            hintText: _copy[5],
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Color(0xffe5e0d8))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Color(0xffc9ceca))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide:
                    const BorderSide(color: Color(0xff3f6050), width: 2)),
            suffixIcon: IconButton(
                tooltip: _copy[12],
                onPressed: _checking || _recording ? null : () => _ask(),
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: const Color(0xffa32e35))),
          ),
        )),
      ]);

  Widget _starter(String label, VoidCallback action) => ActionChip(
      label: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      onPressed: action,
      backgroundColor: const Color(0xfffaf9f6),
      side: const BorderSide(color: Color(0xffe5e0d8)),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      visualDensity: VisualDensity.compact);

  Widget _selectedResult(Map<String, dynamic> row) {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final status = row['acceptance_state'] == 'eligible'
        ? (row['status'] ?? 'unknown')
        : 'review';
    final flagged = ['high', 'low', 'abnormal', 'critical'].contains(status);
    final label = switch (status) {
      'normal' => bodyCopy(widget.language, 'Within range', 'सीमा के अंदर',
          'Dentro del rango', '范围内'),
      'high' => bodyCopy(widget.language, 'High', 'ज़्यादा', 'Alto', '偏高'),
      'low' => bodyCopy(widget.language, 'Low', 'कम', 'Bajo', '偏低'),
      'abnormal' ||
      'critical' =>
        bodyCopy(widget.language, 'Flagged', 'अलग नतीजा', 'Señalado', '已标记'),
      'review' => bodyCopy(widget.language, 'Check source',
          'मूल रिपोर्ट जांचें', 'Revisar original', '核对原文'),
      _ => bodyCopy(widget.language, 'Unclassified', 'तुलना नहीं हुई',
          'Sin clasificar', '未分类'),
    };
    final reference = (row['reference_range'] ?? '').toString();
    final system = bodySystemForTest(row['test_name'].toString());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ActiveBodyVisual(
            key: ValueKey('active-body-${system.name}'),
            system: system,
            language: widget.language,
            compact: true),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row['test_name'].toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: widget.largeText ? 18 : 16,
                  height: 1.4,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${row['value']} ${row['unit'] ?? ''}',
                    style: TextStyle(
                        fontSize: widget.largeText ? 24 : 22,
                        height: 1.35,
                        fontWeight: FontWeight.w700)),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: flagged
                            ? const Color(0xfff9ebec)
                            : const Color(0xffedf3ef),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: flagged
                                ? const Color(0xffa32e35)
                                : const Color(0xff3f6050)))),
              ]),
        ])),
      ]),
      SizedBox(height: mobile ? 6 : 9),
      InkWell(
          onTap: reference.isEmpty
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                          title: Text(row['test_name'].toString()),
                          content:
                              SingleChildScrollView(
                                  child: SelectableText(
                                      'Reference range\n$reference')),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'))
                          ])),
          child: Row(children: [
            Expanded(
                child: Text(
                    'Ref: ${reference.isEmpty ? 'Not printed' : reference}',
                    maxLines: mobile ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: widget.largeText ? 15 : 13,
                        height: 1.5,
                        color: Color(0xff626a67)))),
            if (reference.length > 65)
              const Icon(Icons.unfold_more_rounded,
                  size: 18, color: Color(0xff626a67)),
          ])),
      if (!mobile) ...[
        const SizedBox(height: 9),
        Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(system.title(widget.language),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xff626a67))),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xffedf3ef),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(system.location(widget.language),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xff3f6050)))),
            ]),
      ],
    ]);
  }

  Widget _control(String label, IconData icon, String action) =>
      OutlinedButton.icon(
        onPressed: _answer.isEmpty || _checking || _recording
            ? null
            : () => _ask(action: action),
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        icon: Icon(icon, size: 15),
        label: Text(label),
      );

  Widget _referenceChip(Map<String, dynamic> row, VoidCallback select) =>
      ActionChip(
        avatar: BodySystemIcon(bodySystemForTest(row['test_name'].toString()),
            size: 22),
        label: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${row['test_name']} · ${row['value']} ${row['unit'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              if ((row['reference_range'] ?? '').toString().isNotEmpty)
                Text('Ref: ${row['reference_range']}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xff626a67))),
            ]),
        onPressed: select,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        backgroundColor: const Color(0xffedf3ef),
        side: const BorderSide(color: Color(0xffd4e0d7)),
      );

  @override
  void dispose() {
    _stop(notify: false);
    _question.dispose();
    _answerScroll.dispose();
    super.dispose();
  }
}
