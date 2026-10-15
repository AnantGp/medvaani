import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'report_workspace.dart';
import 'report_pdf.dart';
import 'report_data.dart';
import 'voice_panel.dart';
import 'report_review_widgets.dart' show editReportResult;
import 'browser_report_store.dart';
import 'browser_explorer_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) WidgetsBinding.instance.ensureSemantics();
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Telugu', 'Gujarati', 'Kannada', 'Malayalam']) {
      final license =
          await rootBundle.loadString('assets/fonts/NotoSans$family-OFL.txt');
      yield LicenseEntryWithLineBreaks(['Noto Sans $family'], license);
    }
  });
  runApp(const MedicalCDSSApp());
}

class MedicalCDSSApp extends StatelessWidget {
  const MedicalCDSSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medivaanii',
      debugShowCheckedModeBanner: false,
      theme: medivaaniiTheme(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // FIX 1: unified index for both IndexedStack and NavigationBar
  int _currentIndex = 0;

  // FIX 2: added missing _loadingMessage variable
  String _loadingMessage = '';
  String? _fileName;
  String? _uploadError;
  String? _translationError;
  String? _audioError;
  int _reportGeneration = 0;
  int _translationGeneration = 0;
  bool _audioPreparing = false;
  Completer<void>? _audioChunkDone;
  html.FileUploadInputElement? _cameraInput;
  StreamSubscription<html.Event>? _cameraSelection;
  StreamSubscription<html.Event>? _cameraCancellation;

  final FlutterTts _tts = FlutterTts();

  // Data state
  Map<String, dynamic>? _reportData;
  final _reportStore = BrowserReportStore();
  Future<void> _storageWork = Future.value();
  Uint8List? _sourceBytes;
  html.IFrameElement? _explorerFrame;
  final _explorerBridge = BrowserExplorerBridge();
  final _explorerAnchor = GlobalKey();
  int _explorerFrameGeneration = 0;
  StreamSubscription<html.Event>? _explorerFrameLoad;
  double _explorerHeight = 980;
  String? _sourceUrl, _reviewError, _storageError;
  bool _reviewOpen = false, _reviewSaving = false, _restoringReport = false;
  bool _isLoading = false;
  bool _isTranslating = false;
  bool _isDownloadingPdf = false;
  String _selectedLanguage = 'English';
  bool _ttsEnabled = true;
  List<dynamic> _availableVoices = [];
  Timer? _pollingTimer;

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'es', 'name': 'Spanish', 'native': 'Español'},
    {'code': 'zh', 'name': 'Mandarin', 'native': '中文'},
  ];
  @override
  void initState() {
    super.initState();
    _initTts();
    _restoreReport();
  }

  void _onExplorerMessage(String message) {
    if (!mounted) return;
    try {
      final data = jsonDecode(message);
      if (data is! Map) return;
      if (data['type'] == 'medivaanii-explorer-ready') _sendExplorerReport();
      if (data['type'] == 'medivaanii-explorer-height' &&
          data['height'] is num) {
        final height = (data['height'] as num).clamp(650, 3000).toDouble();
        if ((height - _explorerHeight).abs() > 2) {
          setState(() => _explorerHeight = height);
        }
      }
      if (data['type'] == 'medivaanii-explorer-layout' &&
          data['layout'] is List &&
          _reportData != null) {
        _reportData = {..._reportData!, 'source_layout': data['layout']};
        _saveReport();
      }
      if (data['type'] == 'medivaanii-explorer-selection' &&
          data['measurement_id'] is String &&
          _reportData != null &&
          reportLabValues(_reportData!['parsed_data'])
              .any((row) => row['measurement_id'] == data['measurement_id'])) {
        _reportData = {
          ..._reportData!,
          'selected_measurement_id': data['measurement_id']
        };
        _saveReport();
      }
      if (data['type'] == 'medivaanii-explorer-edit' &&
          data['measurement_id'] is String) {
        _editExplorerResult(data['measurement_id'] as String);
      }
      if (data['type'] == 'medivaanii-explorer-focus' && data['top'] is num) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusExplorerSection((data['top'] as num).toDouble());
        });
        WidgetsBinding.instance.scheduleFrame();
      }
    } on FormatException {/* Ignore malformed frame messages. */}
  }

  Future<void> _editExplorerResult(String id) async {
    if (_reportData == null ||
        _reviewSaving ||
        reportQualityState(_reportData!) == 'legacy_unverified') {
      return;
    }
    final generation = _reportGeneration;
    final rows = reportLabValues(_reportData!['parsed_data']);
    final matches = rows.where((row) => row['measurement_id'] == id).toList();
    if (matches.length != 1) return;
    final sources = (_reportData!['source_evidence'] as List? ?? [])
        .whereType<Map>()
        .where((source) => source['measurement_id'] == id);
    final corrected = await editReportResult(
        context,
        matches.single,
        sources.length == 1
            ? sources.single['source_quote']?.toString()
            : null);
    if (!mounted || corrected == null || generation != _reportGeneration) {
      return;
    }
    await _confirmReview(rows
        .map((row) => row['measurement_id'] == id ? corrected : row)
        .toList());
    _sendExplorerReport();
  }

  void _focusExplorerSection(double top) {
    final anchor = _explorerAnchor.currentContext;
    if (anchor == null || !top.isFinite) return;
    final scrollable = Scrollable.maybeOf(anchor);
    final renderObject = anchor.findRenderObject();
    if (scrollable == null || renderObject == null) return;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return;
    final position = scrollable.position;
    final offset = (viewport.getOffsetToReveal(renderObject, 0).offset + top)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.of(context).accessibleNavigation) {
      position.jumpTo(offset);
    } else {
      position.animateTo(offset,
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic);
    }
  }

  String get _sourceMime => (_fileName ?? '').toLowerCase().endsWith('.pdf')
      ? 'application/pdf'
      : (_fileName ?? '').toLowerCase().endsWith('.png')
          ? 'image/png'
          : (_fileName ?? '').toLowerCase().endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';

  void _setSource(Uint8List? bytes) {
    if (_sourceUrl != null) html.Url.revokeObjectUrl(_sourceUrl!);
    _sourceBytes = bytes;
    _sourceUrl = bytes == null
        ? null
        : html.Url.createObjectUrlFromBlob(html.Blob([bytes], _sourceMime));
  }

  Future<void> _restoreReport() async {
    final generation = _reportGeneration;
    setState(() => _restoringReport = true);
    try {
      final saved = await _reportStore.restore();
      if (!mounted || generation != _reportGeneration || saved == null) return;
      final snapshot = jsonDecode(saved.payload) as Map<String, dynamic>;
      if (snapshot['version'] != 1 || snapshot['report'] is! Map) return;
      _fileName = snapshot['filename'] as String?;
      _setSource(saved.sourceBytes);
      setState(() {
        _reportData = restoredReport(
            Map<String, dynamic>.from(snapshot['report'] as Map));
        final language = snapshot['language'];
        if (_languages.any((item) => item['name'] == language)) {
          _selectedLanguage = language.toString();
        }
        _reviewOpen = snapshot['review_open'] == true;
        _currentIndex = 1;
      });
      if (!reportOutputAllowed(_reportData!)) _reviewOpen = true;
    } catch (_) {
      if (mounted) {
        setState(() => _storageError =
            'The saved report could not be restored. You can upload it again.');
      }
    } finally {
      if (mounted) setState(() => _restoringReport = false);
    }
  }

  Future<void> _saveReport() async {
    if (_reportData == null) return;
    final payload = jsonEncode({
      'version': 1,
      'report': _reportData,
      'filename': _fileName,
      'language': _selectedLanguage,
      'review_open': _reviewOpen
    });
    final bytes = _sourceBytes;
    final mime = _sourceMime;
    _storageWork = _storageWork
        .catchError((_) {})
        .then((_) => _reportStore.save(payload, bytes, mime));
    try {
      await _storageWork;
      if (mounted && _storageError != null) {
        setState(() => _storageError = null);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _storageError =
            'This report could not be saved in this browser. Keep this tab open or download the summary.');
      }
    }
  }

  Future<void> _clearSavedReport() async {
    _reportGeneration++;
    _translationGeneration++;
    _stopSpeaking();
    setState(() => _reviewSaving = true);
    try {
      await _storageWork.catchError((_) {});
      await _reportStore.clear();
      _setSource(null);
      if (mounted) {
        setState(() {
          _reportData = null;
          _fileName = null;
          _reviewOpen = false;
          _storageError = null;
          _currentIndex = 0;
        });
      }
    } catch (_) {
      if (mounted) {
        _showError('The saved report could not be cleared. Try again.');
      }
    } finally {
      if (mounted) setState(() => _reviewSaving = false);
    }
  }

  Widget? _sourcePreview() {
    if (_sourceBytes == null || _sourceUrl == null) return null;
    if (_sourceMime != 'application/pdf') {
      return SizedBox(
          height: 460, child: Image.memory(_sourceBytes!, fit: BoxFit.contain));
    }
    final url = _originalDocumentUrl!;
    return SizedBox(
        height: 460,
        child: HtmlElementView.fromTagName(
            tagName: 'iframe',
            onElementCreated: (element) {
              final frame = element as html.IFrameElement;
              frame.src = url;
              frame.title = 'Original uploaded report';
              frame.style.border = '0';
              frame.style.width = '100%';
              frame.style.height = '100%';
            }));
  }

  Widget? _sourceExplorer() {
    if (_sourceUrl == null || _reportData == null) return null;
    final url =
        '${Uri.base.resolve('report_explorer.html')}?type=${_sourceMime == 'application/pdf' ? 'pdf' : 'photo'}#${Uri.encodeComponent(_sourceUrl!)}';
    return SizedBox(
      key: _explorerAnchor,
      height: _explorerHeight,
      child: HtmlElementView.fromTagName(
        key: ValueKey('explorer:$_sourceUrl'),
        tagName: 'iframe',
        onElementCreated: (element) {
          final frame = element as html.IFrameElement;
          _explorerFrame = frame;
          frame.id = 'medivaanii-explorer-${++_explorerFrameGeneration}';
          _explorerBridge.watch(frame.id, _onExplorerMessage);
          _explorerFrameLoad?.cancel();
          frame.title = 'Interactive report explorer';
          frame.style.border = '0';
          frame.style.width = '100%';
          frame.style.height = '100%';
          _explorerFrameLoad =
              frame.onLoad.listen((_) => _sendExplorerReport());
          frame.src = url;
        },
      ),
    );
  }

  void _sendExplorerReport() {
    if (!mounted || _reportData == null) return;
    _explorerFrame?.contentWindow?.postMessage(
        jsonEncode({
          'type': 'medivaanii-explorer-report',
          'report': _reportData,
          'filename': _fileName,
          'language': _selectedLanguage,
        }),
        Uri.base.origin);
  }

  String? get _originalDocumentUrl => _sourceUrl == null
      ? null
      : _sourceMime == 'application/pdf'
          ? '${Uri.base.resolve('pdf_preview.html')}#${Uri.encodeComponent(_sourceUrl!)}'
          : _sourceUrl;

  Future<void> _confirmReview(List<Map<String, dynamic>> rows) async {
    if (_reportData == null || _reviewSaving) return;
    final generation = _reportGeneration;
    ++_translationGeneration;
    _stopSpeaking();
    setState(() {
      _reviewSaving = true;
      _isTranslating = false;
      _reviewError = null;
    });
    try {
      final response = await http
          .post(_buildApiUrl('/report/review'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'report': _reportData,
                'labs': rows,
                'language': _selectedLanguage
              }))
          .timeout(const Duration(seconds: 120));
      if (!mounted || generation != _reportGeneration) return;
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw FormatException(
            (result['detail'] ?? 'Review could not be saved.').toString());
      }
      setState(() {
        _reportData = result;
        _reviewOpen = false;
        _currentIndex = 1;
      });
      _sendExplorerReport();
      await _saveReport();
    } catch (error) {
      if (mounted && generation == _reportGeneration) {
        setState(() => _reviewError = error is FormatException
            ? error.message
            : 'The results could not be updated. Check your connection and try again.');
      }
    } finally {
      if (mounted && generation == _reportGeneration) {
        setState(() => _reviewSaving = false);
      }
    }
  }

  Future<void> _reextractReport() async {
    if (_reportData == null || _reviewSaving) return;
    var migrationBytes = _sourceBytes;
    var migrationName = _fileName;
    if (migrationBytes == null) {
      final selected = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
          withData: true);
      if (selected == null ||
          selected.files.isEmpty ||
          selected.files.first.bytes == null ||
          !mounted) {
        return;
      }
      migrationBytes = selected.files.first.bytes;
      migrationName = selected.files.first.name;
    }
    final generation = _reportGeneration;
    setState(() {
      _reviewSaving = true;
      _isTranslating = false;
      _reviewError = null;
    });
    try {
      final request =
          http.MultipartRequest('POST', _buildApiUrl('/report/reextract'));
      request.files.add(http.MultipartFile.fromBytes('file', migrationBytes!,
          filename: migrationName ??
              (_sourceMime == 'application/pdf'
                  ? 'original.pdf'
                  : 'original.png')));
      request.fields['report'] = jsonEncode(_reportData);
      final response = await http.Response.fromStream(
          await request.send().timeout(const Duration(seconds: 660)));
      if (!mounted || generation != _reportGeneration) return;
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw FormatException(
            (result['detail'] ?? 'The source could not be read.').toString());
      }
      setState(() {
        _fileName = migrationName;
        _setSource(migrationBytes);
        _reportData = result;
        _selectedLanguage = 'English';
        _reviewOpen = true;
      });
      _sendExplorerReport();
      await _saveReport();
    } catch (error) {
      if (mounted && generation == _reportGeneration) {
        setState(() => _reviewError = error is FormatException
            ? error.message
            : 'The source could not be re-read. Check your connection and try again.');
      }
    } finally {
      if (mounted && generation == _reportGeneration) {
        setState(() => _reviewSaving = false);
      }
    }
  }

  Future<Map<String, dynamic>> _askQuestion(String question) async {
    final generation = _reportGeneration;
    final language = _selectedLanguage;
    final response = await http
        .post(_buildApiUrl('/report/question'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'report': _reportData,
              'question': question,
              'language': language
            }))
        .timeout(const Duration(seconds: 60));
    if (!mounted ||
        generation != _reportGeneration ||
        language != _selectedLanguage) {
      throw const FormatException('Report changed');
    }
    if (response.statusCode != 200) {
      throw const FormatException('Answer unavailable');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  bool _voiceExplicitlyPinned = false;

  Future<void> _initTts() async {
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    await _loadAvailableVoices();
    await _applyVoiceForLanguage(_selectedLanguage);
  }

  Future<void> _loadAvailableVoices({int retries = 4}) async {
    try {
      for (var attempt = 0; attempt <= retries; attempt++) {
        final voices = await _tts.getVoices;
        if (voices is List && voices.isNotEmpty) {
          _availableVoices = voices;
          return;
        }
        if (attempt < retries) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
      _availableVoices = [];
    } catch (_) {
      _availableVoices = [];
    }
  }

  String _languageCodeOf(String locale) {
    final parts = locale.split(RegExp(r'[-_]'));
    return parts.isNotEmpty ? parts.first.toLowerCase() : locale.toLowerCase();
  }

  String _languageCodeFor(String language) {
    for (final entry in _languages) {
      if (entry['name'] == language) {
        return entry['code'] ?? _languageCodeOf(_ttsLocalesFor(language).first);
      }
    }
    return _languageCodeOf(_ttsLocalesFor(language).first);
  }

  Future<void> _applyVoiceForLanguage(String language) async {
    final targetLocales = _ttsLocalesFor(language);
    final targetLocale = targetLocales.first;
    final targetLangCode = _languageCodeOf(targetLocale);

    if (_availableVoices.isEmpty) {
      await _loadAvailableVoices();
    }

    final localeMatches = _availableVoices.where((voice) {
      final voiceLocale = _voiceLocaleOf(voice).toLowerCase();
      return targetLocales.map((e) => e.toLowerCase()).contains(voiceLocale) ||
          _languageCodeOf(voiceLocale) == targetLangCode;
    }).toList();

    await _trySetLanguage(targetLocales);

    if (localeMatches.isNotEmpty) {
      final bestVoice = _preferredVoice(localeMatches);
      await _setTtsVoice(bestVoice);
      _voiceExplicitlyPinned = true;
    } else if (_voiceExplicitlyPinned) {
      await _clearTtsVoice();
      _voiceExplicitlyPinned = false;
    } else {}

    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
  }

  String _voiceLocaleOf(dynamic voice) {
    if (voice is Map) {
      final locale = voice['locale'] ?? voice['language'] ?? voice['name'];
      return locale?.toString() ?? '';
    }
    return voice.toString();
  }

  String _voiceNameOf(dynamic voice) {
    if (voice is Map) {
      return voice['name']?.toString() ?? _voiceLocaleOf(voice);
    }
    return voice.toString();
  }

  int _voiceQualityScore(dynamic voice) {
    final name = _voiceNameOf(voice).toLowerCase();
    var score = 0;
    if (name.contains('neural')) score += 100;
    if (name.contains('natural')) score += 90;
    if (name.contains('online')) score += 80;
    if (name.contains('premium') || name.contains('enhanced')) score += 60;
    if (name.contains('wavenet')) score += 60;
    if (name.contains('google')) score += 30;
    if (name.contains('female')) score += 15;
    if (name.contains('smooth') || name.contains('soft')) score += 10;
    if (name.contains('compact') ||
        name.contains('espeak') ||
        name.contains('festival')) {
      score -= 50;
    }
    return score;
  }

  dynamic _preferredVoice(List<dynamic> voices) {
    final sorted = [...voices]
      ..sort((a, b) => _voiceQualityScore(b).compareTo(_voiceQualityScore(a)));
    return sorted.first;
  }

  Future<void> _setTtsVoice(dynamic voice) async {
    try {
      if (voice is Map) {
        final settings = <String, String>{};
        if (voice.containsKey('name')) {
          settings['name'] = voice['name'].toString();
        }
        if (voice.containsKey('locale')) {
          settings['locale'] = voice['locale'].toString();
        }
        if (settings.isNotEmpty) {
          await _tts.setVoice(settings);
        }
      }
    } catch (_) {}
  }

  Future<void> _clearTtsVoice() async {
    try {
      await _tts.setVoice({'name': '', 'locale': ''});
    } catch (_) {}
  }

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8001',
  );

  Uri _buildApiUrl(String path) {
    final configured = Uri.parse(_baseUrl);
    if (['localhost', '127.0.0.1', '::1'].contains(configured.host)) {
      return Uri.base.resolve('/api$path');
    }
    return Uri.parse('$_baseUrl$path');
  }

  Future<void> _pickFile({bool photo = false}) async {
    if (_isLoading || _isTranslating) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: photo ? ['jpg', 'jpeg', 'png', 'webp'] : ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          await _processFileBytes(file.bytes!, file.name);
        } else {
          _showError('Unable to read file data. Please try again.');
        }
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  void _clearCameraInput() {
    _cameraSelection?.cancel();
    _cameraCancellation?.cancel();
    _cameraInput?.remove();
    _cameraInput = null;
  }

  void _takePhoto() {
    if (_isLoading || _isTranslating) return;
    _clearCameraInput();
    // Native camera capture on supporting phone browsers; desktops offer a
    // file chooser. Keep the click synchronous to preserve the user gesture.
    final input = html.FileUploadInputElement()
      ..accept = 'image/jpeg,image/png,image/webp'
      ..setAttribute('capture', 'environment')
      ..style.display = 'none';
    _cameraInput = input;
    html.document.body?.append(input);
    _cameraCancellation = input.on['cancel'].listen((_) => _clearCameraInput());
    _cameraSelection = input.onChange.listen((_) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        _clearCameraInput();
        return;
      }
      final file = files.first;
      _clearCameraInput();
      if (file.size > 10 * 1024 * 1024) {
        if (mounted) _showError('Choose a photo smaller than 10 MB.');
        return;
      }
      try {
        final reader = html.FileReader();
        final loaded = reader.onLoad.first;
        reader.readAsArrayBuffer(file);
        await loaded;
        if (!mounted) return;
        final result = reader.result;
        if (result is! ByteBuffer) {
          throw const FormatException('Unable to read photo');
        }
        await _processFileBytes(Uint8List.view(result), file.name);
      } catch (_) {
        if (mounted) {
          _showError(
              'We could not open this photo. Try choosing it from your device.');
        }
      }
    });
    input.click();
  }

  Future<void> _processFileBytes(Uint8List bytes, String fileName) async {
    if (!mounted) return;
    final extension = fileName.split('.').last.toLowerCase();
    if (!['pdf', 'jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      _showError('Choose a PDF, JPG, PNG or WebP report.');
      return;
    }
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      _showError(bytes.isEmpty
          ? 'This file is empty. Choose another report.'
          : 'Choose a file smaller than 10 MB.');
      return;
    }
    final photo = extension != 'pdf';
    final generation = ++_reportGeneration;
    _translationGeneration++;
    _pollingTimer?.cancel();
    _stopSpeaking();
    setState(() {
      _isLoading = true;
      _isTranslating = false;
      _reportData = null;
      _uploadError = null;
      _translationError = null;
      _audioError = null;
      _fileName = fileName;
      _reviewOpen = true;
      _reviewError = null;
      _loadingMessage = photo ? 'Uploading your photo' : 'Uploading your PDF';
      _currentIndex = 0;
    });
    _setSource(bytes);
    try {
      final request = http.MultipartRequest('POST', _buildApiUrl('/upload'));
      request.files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      request.fields['language'] = 'English';
      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      if (!mounted || generation != _reportGeneration) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw FormatException(
            (data['detail'] ?? 'Upload failed. Try another file.').toString());
      }
      if (data['job_id'] != null) {
        setState(() => _loadingMessage =
            photo ? 'Reading text from your photo' : 'Reading your PDF');
        _startJobPolling(data['job_id'].toString(), generation);
      } else {
        setState(() {
          _reportData = data;
          _isLoading = false;
          _currentIndex = 1;
        });
        await _saveReport();
      }
    } catch (error) {
      if (mounted && generation == _reportGeneration) {
        setState(() {
          _isLoading = false;
          _uploadError = error is FormatException
              ? error.message
              : 'We could not upload this report. Check your connection and try again.';
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _startJobPolling(String jobId, int generation) {
    _pollingTimer?.cancel();
    var checking = false;
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (checking) return;
      if (!mounted || generation != _reportGeneration) {
        timer.cancel();
        return;
      }
      checking = true;
      try {
        final response = await http
            .get(_buildApiUrl('/job/$jobId'))
            .timeout(const Duration(seconds: 20));
        if (!mounted || generation != _reportGeneration) {
          timer.cancel();
          return;
        }
        if (response.statusCode != 200) {
          throw const FormatException('Status unavailable');
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'completed') {
          final result = Map<String, dynamic>.from(data['result'] as Map);
          timer.cancel();
          setState(() {
            _reportData = result;
            _isLoading = false;
            _currentIndex = 1;
          });
          await _saveReport();
        } else if (data['status'] == 'failed') {
          throw FormatException((data['error'] ??
                  'We could not read this report. Try a clearer photo or another PDF.')
              .toString());
        } else {
          setState(() => _loadingMessage =
              (data['message'] ?? 'Preparing your explanation').toString());
        }
      } catch (error) {
        timer.cancel();
        if (mounted && generation == _reportGeneration) {
          setState(() {
            _isLoading = false;
            _uploadError = error is FormatException
                ? error.message
                : 'We could not finish reading this report. Check your connection and try again.';
          });
        }
      } finally {
        checking = false;
      }
    });
  }

  // Strips markdown/decorative symbols that would read literally as text
  // or speech (e.g. "======" spoken as "equal equal equal").
  String _stripDecorativeSymbols(String input) {
    var t = input;
    t = t.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '');
    t = t.replaceAllMapped(RegExp(r'__(.*?)__'), (m) => m.group(1) ?? '');
    t = t.replaceAllMapped(
        RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'), (m) => m.group(1) ?? '');
    t = t.replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1) ?? '');
    t = t.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    t = t.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    t = t.replaceAll(RegExp(r'([^\w\s])\1{2,}'), ' '); // ===, ---, ***
    t = t.replaceAll(RegExp(r'_{3,}'), ' ');
    t = t.replaceAll(RegExp(r'[|`*_#]'), ' ');
    t = t.replaceAll(
        RegExp(r'[\u2600-\u27BF\u2B00-\u2BFF\uFE0E\uFE0F\u200D]'), ' ');
    t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
    t = t.replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '\n');
    return t.trim();
  }

  // TTS-specific: strips symbols AND folds newlines into ". " pauses.
  String _sanitizeForSpeech(String input) {
    var t = _stripDecorativeSymbols(input);
    t = t.replaceAll(RegExp(r'\n\s*\n+'), '. ');
    t = t.replaceAll('\n', '. ');
    t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
    return t.trim();
  }

  // Generation counter — increments every time _speak() is called.
  // Any in-flight audio loop compares against this; if it changed,
  // a newer card was tapped and the old audio stops immediately.
  int _speakGeneration = 0;
  html.AudioElement? _currentAudio;
  String? _activeSpeechContent; // tracks which card is speaking
  bool _isSpeaking = false;
  bool _isPaused = false;

  Future<void> _speak(String rawText, String contentLanguage) async {
    if (_reportData == null || !reportOutputAllowed(_reportData!)) return;
    if (rawText.isEmpty || !_ttsEnabled) return;

    final text = _sanitizeForSpeech(rawText);
    if (text.isEmpty) return;

    _stopSpeaking();
    // Increment generation — kills any in-flight playback loop
    final gen = ++_speakGeneration;

    // Stop whatever is currently playing
    _currentAudio?.pause();
    _currentAudio = null;
    await _tts.stop();
    if (!mounted || _speakGeneration != gen) return;

    setState(() {
      _activeSpeechContent = rawText;
      _isSpeaking = false;
      _audioPreparing = true;
      _isPaused = false;
      _audioError = null;
    });
    try {
      await _speakViaBackend(text, contentLanguage, gen);
    } catch (_) {
      if (mounted && _speakGeneration == gen) {
        setState(() => _audioError =
            'Narration unavailable. Check your connection and try Play again.');
      }
    }

    // Cleanup when done naturally
    if (_speakGeneration == gen && mounted) {
      setState(() {
        _activeSpeechContent = null;
        _isSpeaking = false;
        _audioPreparing = false;
        _isPaused = false;
      });
    }
  }

  void _stopSpeaking() {
    _speakGeneration++; // cancels in-flight loop
    if (_audioChunkDone != null && !_audioChunkDone!.isCompleted) {
      _audioChunkDone!.complete();
    }
    _audioPreparing = false;
    _currentAudio?.pause();
    _currentAudio = null;
    _tts.stop();
    if (mounted) {
      setState(() {
        _activeSpeechContent = null;
        _isSpeaking = false;
        _isPaused = false;
      });
    }
  }

  void _pauseSpeaking() {
    _currentAudio?.pause();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isPaused = true;
      });
    }
  }

  Future<void> _resumeSpeaking() async {
    final audio = _currentAudio;
    if (audio == null) return;
    final generation = _speakGeneration;
    setState(() => _audioPreparing = true);
    try {
      await audio.play();
      if (!mounted || generation != _speakGeneration) {
        audio.pause();
        return;
      }
      setState(() {
        _isSpeaking = true;
        _isPaused = false;
        _audioPreparing = false;
      });
    } catch (_) {
      if (mounted && generation == _speakGeneration) {
        _stopSpeaking();
        setState(
            () => _audioError = 'Playback could not resume. Try Play again.');
      }
    }
  }

  Future<void> _speakViaBackend(String text, String language, int gen) async {
    final langCode = _languageCodeFor(language);
    final ttsUrl = _buildApiUrl('/synthesize');
    for (final chunk in _splitSpeechChunks(text)) {
      if (_speakGeneration != gen || !mounted) return;
      if (chunk.trim().isEmpty) continue;
      final response = await http
          .post(
            ttsUrl,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'text': chunk, 'language': langCode}),
          )
          .timeout(const Duration(seconds: 30));
      if (_speakGeneration != gen || !mounted) return;
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw const FormatException('Narration unavailable');
      }
      final url = html.Url.createObjectUrlFromBlob(
          html.Blob([response.bodyBytes], 'audio/mpeg'));
      final audio = html.AudioElement(url);
      _currentAudio = audio;
      final done = Completer<void>();
      _audioChunkDone = done;
      var playbackFailed = false;
      final ended = audio.onEnded.listen((_) {
        if (!done.isCompleted) done.complete();
      });
      final failed = audio.onError.listen((_) {
        playbackFailed = true;
        if (!done.isCompleted) done.complete();
      });
      try {
        await audio.play();
        if (_speakGeneration != gen || !mounted) {
          audio.pause();
          return;
        }
        setState(() {
          _audioPreparing = false;
          _isSpeaking = true;
        });
        await done.future;
        if (playbackFailed) throw const FormatException('Playback failed');
        if (_speakGeneration != gen || !mounted) return;
        setState(() {
          _isSpeaking = false;
          _audioPreparing = true;
        });
      } finally {
        audio.pause();
        await ended.cancel();
        await failed.cancel();
        html.Url.revokeObjectUrl(url);
        if (identical(_currentAudio, audio)) _currentAudio = null;
        if (identical(_audioChunkDone, done)) _audioChunkDone = null;
      }
    }
  }

  List<String> _splitSpeechChunks(String text, {int maxLen = 300}) {
    text = text.trim();
    if (text.isEmpty) return [];
    if (text.length <= maxLen) return [text];

    final chunks = <String>[];
    while (text.isNotEmpty) {
      if (text.length <= maxLen) {
        chunks.add(text);
        break;
      }
      final slice = text.substring(0, maxLen);
      var cut = [
        slice.lastIndexOf('. '),
        slice.lastIndexOf('। '),
        slice.lastIndexOf('? '),
        slice.lastIndexOf('! '),
        slice.lastIndexOf('\n'),
      ].where((i) => i > 30).fold(-1, (a, b) => b > a ? b : a);
      if (cut < 0) cut = maxLen;
      chunks.add(text.substring(0, cut + 1).trim());
      text = text.substring(cut + 1).trim();
    }
    return chunks.where((c) => c.isNotEmpty).toList();
  }

  List<String> _ttsLocalesFor(String language) {
    const localeMap = {
      'English': ['en-US', 'en-GB', 'en'],
      'Hindi': ['hi-IN', 'hi'],
      'Bengali': ['bn-IN', 'bn-BD', 'bn'],
      'Tamil': ['ta-IN', 'ta-LK', 'ta'],
      'Telugu': ['te-IN', 'te'],
      'Marathi': ['mr-IN', 'mr'],
      'Gujarati': ['gu-IN', 'gu'],
      'Kannada': ['kn-IN', 'kn'],
      'Malayalam': ['ml-IN', 'ml'],
    };
    return List<String>.from(localeMap[language] ?? ['en-US']);
  }

  Future<void> _trySetLanguage(List<String> locales) async {
    for (final locale in locales) {
      try {
        await _tts.setLanguage(locale);
        return;
      } catch (_) {}
    }
    try {
      await _tts.setLanguage('en-US');
    } catch (_) {}
  }

  Future<void> _downloadPdf() async {
    if (_reportData == null || !reportOutputAllowed(_reportData!)) return;
    setState(() => _isDownloadingPdf = true);
    try {
      final bytes = await buildReportPdf(_reportData!, _selectedLanguage);
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download',
            'medical_report_${DateTime.now().millisecondsSinceEpoch}.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF downloaded successfully'),
          backgroundColor: ReportPalette.ink,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  void _changeLanguage(String language) {
    if (_isLoading ||
        _isTranslating ||
        _reviewSaving ||
        language == _selectedLanguage) {
      return;
    }
    _stopSpeaking();
    setState(() {
      _selectedLanguage = language;
      _translationError = null;
      if (_reportData != null) {
        _reportData = {
          ..._reportData!,
          'translated_explanation': '',
          'translated_suggestions': [],
          'disease_explanation_lang': '',
          'disease_explanation_hi': '',
          'solution_plan_lang': '',
          'solution_plan_hi': ''
        };
      }
    });
    _applyVoiceForLanguage(language);
    // The local conversational model answers in the selected language.
    _saveReport();
  }

  Future<void> _retranslate(String language) async {
    if (_reportData == null ||
        _reviewSaving ||
        !reportOutputAllowed(_reportData!) ||
        language == 'English') {
      return;
    }
    final generation = _reportGeneration;
    final requestId = ++_translationGeneration;
    final source = Map<String, dynamic>.from(_reportData!);
    setState(() {
      _isTranslating = true;
      _translationError = null;
    });
    try {
      final response = await http
          .post(_buildApiUrl('/retranslate'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'parsed_data': source['parsed_data'] ?? '',
                'language': language,
                'suggestions': source['suggestions'] ?? [],
                'medical_summary': source['medical_summary'] ?? '',
                'simplified_explanation': source['simple_explanation'] ??
                    source['simplified_explanation'] ??
                    '',
                'temporal_analysis': source['temporal_analysis'] ?? '',
                'causal_analysis': source['causal_analysis'] ?? '',
                'risk_probability': source['risk_probability'] ?? 0.0,
                'patient_id': source['patient_id'],
                'report_date': source['report_date'] ?? '',
                'disease_explanation_en':
                    source['disease_explanation_en'] ?? '',
                'solution_plan_en': source['solution_plan_en'] ?? '',
              }))
          .timeout(const Duration(seconds: 120));
      if (!mounted ||
          generation != _reportGeneration ||
          requestId != _translationGeneration) {
        return;
      }
      if (response.statusCode != 200) {
        throw const FormatException('Translation unavailable');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _reportData =
            mergeReportTranslation(_reportData!, source, data, language);
      });
      await _saveReport();
    } catch (_) {
      if (mounted &&
          generation == _reportGeneration &&
          requestId == _translationGeneration) {
        setState(() => _translationError = 'Translation unavailable');
      }
    } finally {
      if (mounted &&
          generation == _reportGeneration &&
          requestId == _translationGeneration) {
        setState(() => _isTranslating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ReportWorkspace(
        index: _currentIndex,
        onNavigate: (index) => setState(() => _currentIndex = index),
        language: _selectedLanguage,
        languages: _languages,
        onLanguage: (language) {
          _changeLanguage(language);
          _sendExplorerReport();
        },
        report: _reportData,
        reviewing: _reviewOpen,
        reviewSaving: _reviewSaving,
        restoring: _restoringReport,
        reviewError: _reviewError,
        storageError: _storageError,
        sourcePreview: _sourcePreview(),
        sourceExplorer: _sourceExplorer(),
        voicePanel: _reportData == null
            ? null
            : VoicePanel(
                key: ValueKey(_reportGeneration),
                report: _reportData!,
                language: _languages.firstWhere(
                    (entry) => entry['name'] == _selectedLanguage)['code']!,
                onLanguage: (code) => _changeLanguage(_languages
                    .firstWhere((entry) => entry['code'] == code)['name']!),
                apiUrl: _buildApiUrl,
                onReportId: (id) {
                  if (_reportData != null && _reportData!['report_id'] != id) {
                    setState(
                        () => _reportData = {..._reportData!, 'report_id': id});
                    _saveReport();
                  }
                },
                onCitations: (ids) {
                  if (_reportData == null) return;
                  setState(() => _reportData = {
                        ..._reportData!,
                        'voice_cited_measurement_ids': ids,
                        if (ids.isNotEmpty) 'selected_measurement_id': ids.first
                      });
                  _sendExplorerReport();
                }),
        onOpenSource: _sourceUrl == null
            ? null
            : () => html.window.open(_originalDocumentUrl!, '_blank'),
        onReview: () {
          setState(() {
            _reviewOpen = true;
            _currentIndex = 1;
          });
          _saveReport();
        },
        onConfirmReview: _confirmReview,
        onReextract: _reextractReport,
        onAskQuestion: _askQuestion,
        onClearSavedReport: _clearSavedReport,
        fileName: _fileName,
        loading: _isLoading,
        translating: _isTranslating,
        downloading: _isDownloadingPdf,
        loadingMessage: _loadingMessage,
        error: _uploadError,
        translationError: _translationError,
        audioError: _audioError,
        onUpload: () => _pickFile(),
        onPhoto: () => _pickFile(photo: true),
        onCamera: _takePhoto,
        onDownload: _downloadPdf,
        onRetryTranslation: () => _retranslate(_selectedLanguage),
        speechEnabled: _ttsEnabled,
        speaking: _isSpeaking,
        paused: _isPaused,
        activeSpeech: _activeSpeechContent,
        audioPreparing: _audioPreparing,
        onSpeak: _speak,
        onPause: _pauseSpeaking,
        onResume: _resumeSpeaking,
        onStop: _stopSpeaking,
        onSpeechEnabled: (enabled) {
          setState(() => _ttsEnabled = enabled);
          if (!enabled) _stopSpeaking();
        },
      );

  @override
  void dispose() {
    _explorerBridge.stop();
    _explorerFrameLoad?.cancel();
    if (_sourceUrl != null) html.Url.revokeObjectUrl(_sourceUrl!);
    _clearCameraInput();
    _speakGeneration++;
    _currentAudio?.pause();
    if (_audioChunkDone != null && !_audioChunkDone!.isCompleted) {
      _audioChunkDone!.complete();
    }
    _tts.stop();
    _pollingTimer?.cancel();
    super.dispose();
  }
}
