import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'report_data.dart';
import 'report_snapshot.dart';

class VoicePanel extends StatefulWidget {
  const VoicePanel(
      {super.key,
      required this.report,
      required this.language,
      required this.onLanguage,
      required this.apiUrl,
      required this.onCitations,
      required this.onReportId});
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
  String _answer = '', _transcript = '';
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
  void didUpdateWidget(covariant VoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.report['parsed_data'] != widget.report['parsed_data']) {
      _stop(notify: false);
      _answer = '';
      _transcript = '';
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

  Future<void> _ask({Uint8List? audio, String? action}) async {
    final text = _question.text.trim();
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
        _transcript = (data['transcript'] ?? '').toString();
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
              : 'The local voice service is unavailable. Try again or check that the backend is running.';
        });
      }
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xff263331),
        green = Color(0xff406555),
        burgundy = Color(0xffa62f38);
    final status = _recording
        ? _copy[2]
        : _checking
            ? _copy[3]
            : _speaking
                ? _copy[4]
                : _copy[1];
    final names = {
      for (final row in reportLabValues(widget.report['parsed_data']))
        row['measurement_id']: row['test_name']
    };
    return Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xffe5e2dc)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x07000000),
                  blurRadius: 28,
                  offset: Offset(0, 8))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xffedf3ee),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.graphic_eq_rounded,
                    color: green, size: 24)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(_copy[0],
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: ink))),
          ]),
          const SizedBox(height: 18),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in {
              'en': 'English',
              'hi': 'हिन्दी',
              'es': 'Español',
              'zh': '中文'
            }.entries)
              ChoiceChip(
                  label: Text(entry.value),
                  selected: widget.language == entry.key,
                  onSelected: (_) {
                    _stop();
                    widget.onLanguage(entry.key);
                  }),
          ]),
          const SizedBox(height: 20),
          AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xfff6f7f3),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                          _recording
                              ? Icons.mic_rounded
                              : _speaking
                                  ? Icons.volume_up_rounded
                                  : Icons.radio_button_checked,
                          size: 16,
                          color: green),
                      const SizedBox(width: 8),
                      Text(status,
                          style: const TextStyle(
                              color: green,
                              fontSize: 13,
                              fontWeight: FontWeight.w600))
                    ]),
                    const SizedBox(height: 14),
                    Text(_answer.isEmpty ? _copy[11] : _answer,
                        style: const TextStyle(
                            fontSize: 18, height: 1.6, color: ink)),
                    if (_transcript.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(_transcript,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xff77817c)))
                    ],
                    if (_citations.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final id in _citations)
                          ActionChip(
                              avatar: const Icon(Icons.description_outlined,
                                  size: 16),
                              label: Text((names[id] ?? 'Source').toString()),
                              onPressed: () => widget.onCitations([id])),
                      ])
                    ],
                  ])),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(_error!,
                    style: const TextStyle(color: burgundy, height: 1.5))),
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: _answer.isEmpty || _checking || _recording
                    ? null
                    : () => _ask(action: 'repeat'),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: Text(_copy[8])),
            OutlinedButton.icon(
                onPressed: _answer.isEmpty || _checking || _recording
                    ? null
                    : () => _ask(action: 'slower'),
                icon: const Icon(Icons.slow_motion_video_rounded, size: 18),
                label: Text(_copy[9])),
            OutlinedButton.icon(
                onPressed: _answer.isEmpty || _checking || _recording
                    ? null
                    : () => _ask(action: 'simpler'),
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: Text(_copy[10])),
          ]),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: _recording ? burgundy : green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  onPressed: _recording
                      ? _finishRecording
                      : _speaking || _checking
                          ? _stop
                          : _record,
                  icon: Icon(
                      _recording
                          ? Icons.send_rounded
                          : _speaking || _checking
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                      size: 24),
                  label: Text(
                      _recording
                          ? _copy[12]
                          : _speaking || _checking
                              ? _copy[7]
                              : _copy[6],
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _question,
                    onSubmitted: _checking || _recording ? null : (_) => _ask(),
                    decoration: InputDecoration(
                        hintText: _copy[5],
                        filled: true,
                        fillColor: const Color(0xfffaf9f6),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xffe5e2dc)))))),
            const SizedBox(width: 8),
            IconButton.filled(
                tooltip: _copy[5],
                onPressed: _checking || _recording ? null : () => _ask(),
                icon: const Icon(Icons.arrow_upward_rounded))
          ]),
        ]));
  }

  @override
  void dispose() {
    _stop(notify: false);
    _question.dispose();
    super.dispose();
  }
}
