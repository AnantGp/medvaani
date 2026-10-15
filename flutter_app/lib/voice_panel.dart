import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'report_data.dart';
import 'report_snapshot.dart';

class VoicePanelController {
  Future<void> Function(Map<String, dynamic> row)? _explain;
  Future<void> explain(Map<String, dynamic> row) async {
    await _explain?.call(row);
  }
}

class VoicePanel extends StatefulWidget {
  const VoicePanel(
      {super.key,
      required this.report,
      required this.language,
      required this.onLanguage,
      required this.apiUrl,
      required this.onCitations,
      required this.onReportId,
      this.controller});
  final VoicePanelController? controller;
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
    widget.controller?._explain = _explainRow;
  }

  Future<void> _explainRow(Map<String, dynamic> row) async {
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
    await _ask(prompt: question);
  }

  @override
  void didUpdateWidget(covariant VoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._explain = null;
      widget.controller?._explain = _explainRow;
    }
    if (oldWidget.language != widget.language ||
        oldWidget.report['parsed_data'] != widget.report['parsed_data']) {
      _stop(notify: false);
      _answer = '';
      _citations = [];
      _history.clear();
      _lastAnswer = null;
      _error = null;
    }
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

  Future<void> _ask({Uint8List? audio, String? action, String? prompt}) async {
    final text = prompt ?? _question.text.trim();
    if (audio == null && action == null && text.isEmpty) return;
    _stop();
    final generation = _generation;
    final language = widget.language;
    final client = http.Client();
    _client = client;
    setState(() {
      _checking = true;
      _error = null;
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
        _citations = citations;
        _checking = false;
      });
      _question.clear();
      widget.onCitations(citations);
      final blob = html.Blob(
          [base64Decode(data['audio_base64'] as String)], 'audio/mpeg');
      _audioUrl = html.Url.createObjectUrlFromBlob(blob);
      final player = html.AudioElement(_audioUrl!)
        ..playbackRate = (data['playback_rate'] as num).toDouble();
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
    const ink = Color(0xff242c2b),
        green = Color(0xff3f6050),
        burgundy = Color(0xffa32e35);
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final status = _recording
        ? _copy[2]
        : _checking
            ? _copy[3]
            : _speaking
                ? _copy[4]
                : _copy[1];
    final rows = {
      for (final row in workspaceMeasurements(widget.report))
        row['measurement_id']: row
    };
    final selected = rows[widget.report['selected_measurement_id']];
    final sentences = _answer
        .split(RegExp(r'(?<=[।。])|(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final content = _answer.isEmpty
        ? [
            selected == null
                ? _copy[11]
                : {
                    'en':
                        'Let’s talk about ${selected['test_name']}. Tap the microphone or ask a question below.',
                    'hi':
                        'आइए ${selected['test_name']} जांच समझें। बोलने के लिए माइक दबाएं या अपना सवाल लिखें।',
                    'es':
                        'Hablemos de ${selected['test_name']}. Usa el micrófono o escribe tu pregunta.',
                    'zh': '我们来了解${selected['test_name']}。请点击麦克风或输入问题。',
                  }[widget.language]!,
          ]
        : sentences;
    return Container(
      padding: EdgeInsets.all(mobile ? 14 : 18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffe5e0d8))),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: const Color(0xffedf3ef),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.graphic_eq_rounded,
                      color: green, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_copy[0],
                      style: TextStyle(
                          fontSize: mobile ? 17 : 19,
                          fontWeight: FontWeight.w700,
                          color: ink))),
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: _recording ? burgundy : green,
                      shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(status,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: green)),
            ]),
            const SizedBox(height: 12),
            Flexible(
                fit: FlexFit.loose,
                child: Container(
                  constraints: BoxConstraints(maxHeight: mobile ? 84 : 144),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xfff5f7f3),
                      borderRadius: BorderRadius.circular(10)),
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        for (var i = 0; i < content.length; i++)
                          Padding(
                              padding: EdgeInsets.only(
                                  bottom: i == content.length - 1 ? 0 : 8),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (content.length > 2) ...[
                                      const Text('•',
                                          style: TextStyle(
                                              fontSize: 19,
                                              height: 1.5,
                                              color: green)),
                                      const SizedBox(width: 9)
                                    ],
                                    Expanded(
                                        child: Text(content[i].trim(),
                                            style: TextStyle(
                                                fontSize: mobile ? 18 : 19,
                                                height: 1.5,
                                                color: ink))),
                                  ])),
                      ])),
                )),
            if (_citations.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: mobile ? 52 : 80),
                  child: SingleChildScrollView(
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final id in _citations)
                      if (rows[id] != null)
                        _referenceChip(
                            rows[id]!, () => widget.onCitations([id])),
                  ]))),
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 13, color: burgundy, height: 1.5))),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _control(_copy[8], Icons.replay_rounded, 'repeat'),
              _control(_copy[9], Icons.slow_motion_video_rounded, 'slower'),
              _control(_copy[10], Icons.lightbulb_outline_rounded, 'simpler'),
            ]),
            const SizedBox(height: 10),
            LayoutBuilder(
                builder: (context, size) => Row(children: [
                      SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding: EdgeInsets.symmetric(
                                    horizontal: mobile ? 12 : 16),
                                backgroundColor: _recording ? burgundy : green,
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
                              onSubmitted: _checking || _recording
                                  ? null
                                  : (_) => _ask(),
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: _copy[5],
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                filled: true,
                                fillColor: const Color(0xfffaf9f6),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(
                                        color: Color(0xffe5e0d8))),
                                suffixIcon: IconButton(
                                    tooltip: _copy[5],
                                    onPressed: _checking || _recording
                                        ? null
                                        : () => _ask(),
                                    icon: const Icon(Icons.arrow_upward_rounded,
                                        size: 20),
                                    style: IconButton.styleFrom(
                                        minimumSize: const Size(40, 40),
                                        foregroundColor: burgundy)),
                              ))),
                    ])),
          ]),
    );
  }

  Widget _control(String label, IconData icon, String action) =>
      OutlinedButton.icon(
        onPressed: _answer.isEmpty || _checking || _recording
            ? null
            : () => _ask(action: action),
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 34),
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
        avatar: const Icon(Icons.description_outlined,
            size: 15, color: Color(0xff3f6050)),
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
    widget.controller?._explain = null;
    _stop(notify: false);
    _question.dispose();
    super.dispose();
  }
}
