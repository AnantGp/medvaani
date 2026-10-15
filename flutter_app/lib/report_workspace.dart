import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'report_data.dart';

class ReportPalette {
  static const ground = Color(0xFFF7F5F1);
  static const ink = Color(0xFF242C2B);
  static const muted = Color(0xFF626A67);
  static const burgundy = Color(0xFFA32E35);
  static const border = Color(0xFFE5E0D8);
  static const rose = Color(0xFFF9EBEC);
  static const sage = Color(0xFF3F6050);
  static const sageLight = Color(0xFFEDF3EF);
}

ThemeData medivaaniiTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSans',
    fontFamilyFallback: const [
      'NotoDevanagari',
      'NotoBengali',
      'NotoTamil',
      'NotoTelugu',
      'NotoGujarati',
      'NotoKannada',
      'NotoMalayalam'
    ],
    scaffoldBackgroundColor: ReportPalette.ground,
    colorScheme: const ColorScheme.light(
      primary: ReportPalette.burgundy,
      onPrimary: Colors.white,
      primaryContainer: ReportPalette.rose,
      onPrimaryContainer: ReportPalette.burgundy,
      secondary: ReportPalette.sage,
      surface: Colors.white,
      onSurface: ReportPalette.ink,
      outline: ReportPalette.border,
      error: Color(0xFF9E2930),
    ),
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: ReportPalette.ink, displayColor: ReportPalette.ink)
        .copyWith(
          bodyLarge:
              base.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.65),
          bodyMedium:
              base.textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.6),
        ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
      minimumSize: const Size(44, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      textStyle: const TextStyle(
          fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w600),
      shape: shape,
    ).copyWith(
            side: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.focused)
                    ? const BorderSide(color: Colors.white, width: 2)
                    : BorderSide.none))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
      minimumSize: const Size(44, 48),
      foregroundColor: ReportPalette.ink,
      textStyle: const TextStyle(
          fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w600),
      shape: shape,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ).copyWith(
            side: WidgetStateProperty.resolveWith((states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? ReportPalette.burgundy
                    : ReportPalette.border,
                width: states.contains(WidgetState.focused) ? 2 : 1)))),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: const Size(44, 48),
            textStyle: const TextStyle(fontFamily: 'NotoSans'))),
    dividerTheme:
        const DividerThemeData(color: ReportPalette.border, thickness: 1),
    navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: ReportPalette.rose,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 76),
    textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ReportPalette.burgundy,
        selectionColor: Color(0xFFEBCFD1),
        selectionHandleColor: ReportPalette.burgundy),
    snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ReportPalette.ink,
        contentTextStyle: TextStyle(fontSize: 16, color: Colors.white)),
  );
}

class ReportWorkspace extends StatefulWidget {
  const ReportWorkspace(
      {super.key,
      required this.index,
      required this.onNavigate,
      required this.language,
      required this.languages,
      required this.onLanguage,
      required this.onUpload,
      required this.onPhoto,
      required this.onCamera,
      required this.onDownload,
      required this.onRetryTranslation,
      required this.onSpeak,
      required this.onPause,
      required this.onResume,
      required this.onStop,
      required this.onSpeechEnabled,
      this.report,
      this.fileName,
      this.loading = false,
      this.translating = false,
      this.downloading = false,
      this.loadingMessage = '',
      this.error,
      this.translationError,
      this.audioError,
      this.speechEnabled = true,
      this.speaking = false,
      this.paused = false,
      this.audioPreparing = false,
      this.reviewing = false,
      this.reviewSaving = false,
      this.restoring = false,
      this.reviewError,
      this.storageError,
      this.sourcePreview,
      this.sourceExplorer,
      this.voicePanel,
      this.onOpenSource,
      this.onReview,
      this.onReextract,
      this.onConfirmReview,
      this.onAskQuestion,
      this.onClearSavedReport,
      this.onSelectMeasurement,
      this.onEditMeasurement,
      this.onDropFile,
      this.dragging = false,
      this.activeSpeech});
  final void Function(String id, bool speak)? onSelectMeasurement;
  final ValueChanged<String>? onEditMeasurement;
  final void Function(Uint8List bytes, String name)? onDropFile;
  final bool dragging;
  final bool reviewing, reviewSaving, restoring;
  final String? reviewError, storageError;
  final Widget? sourcePreview, sourceExplorer, voicePanel;
  final VoidCallback? onOpenSource, onReview, onReextract, onClearSavedReport;
  final ValueChanged<List<Map<String, dynamic>>>? onConfirmReview;
  final Future<Map<String, dynamic>> Function(String)? onAskQuestion;
  final int index;
  final ValueChanged<int> onNavigate;
  final String language;
  final List<Map<String, String>> languages;
  final ValueChanged<String> onLanguage;
  final VoidCallback onUpload,
      onPhoto,
      onCamera,
      onDownload,
      onRetryTranslation,
      onPause,
      onResume,
      onStop;
  final void Function(String text, String language) onSpeak;
  final ValueChanged<bool> onSpeechEnabled;
  final Map<String, dynamic>? report;
  final String? fileName, error, translationError, audioError, activeSpeech;
  final bool loading,
      translating,
      downloading,
      speechEnabled,
      speaking,
      paused,
      audioPreparing;
  final String loadingMessage;
  @override
  State<ReportWorkspace> createState() => _ReportWorkspaceState();
}

class _ReportWorkspaceState extends State<ReportWorkspace> {
  String _query = '';
  String _filter = 'all';
  bool _mobileSource = true;
  static const _nav = [0, 1, 3];
  static const _labels = ['Upload report', 'Report workspace', '', 'Settings'];
  static const _icons = [
    Icons.upload_file_outlined,
    Icons.space_dashboard_outlined,
    Icons.help_outline,
    Icons.tune_rounded
  ];
  bool get _busy => widget.loading || widget.reviewSaving || widget.restoring;
  List<Map<String, dynamic>> get _rows => workspaceMeasurements(widget.report);
  String _copy(String en, String hi, String es, String zh) =>
      {'Hindi': hi, 'Spanish': es, 'Mandarin': zh}[widget.language] ?? en;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final desktop = size.maxWidth >= 900;
        final expandedRail = size.maxWidth >= 1350;
        final workspace = widget.index == 1 || widget.index == 2;
        return Scaffold(
          body: SafeArea(
              child: Row(children: [
            if (desktop) _sidebar(expandedRail),
            Expanded(
                child: Column(children: [
              _header(desktop),
              Expanded(
                  child: workspace && widget.report != null
                      ? _report(desktop)
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(desktop ? 24 : 16),
                          child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 1440),
                                child: widget.index == 3
                                    ? _settings()
                                    : workspace
                                        ? _empty()
                                        : _upload(),
                              )))),
            ])),
          ])),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  height: 62,
                  selectedIndex:
                      _nav.indexOf(widget.index == 2 ? 1 : widget.index),
                  onDestinationSelected: (i) => widget.onNavigate(_nav[i]),
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.upload_file_outlined),
                        label: 'Upload'),
                    NavigationDestination(
                        icon: Icon(Icons.space_dashboard_outlined),
                        label: 'Report'),
                    NavigationDestination(
                        icon: Icon(Icons.tune_rounded), label: 'Settings'),
                  ],
                ),
        );
      });

  Widget _sidebar(bool expanded) => Container(
        width: expanded ? 208 : 84,
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: ReportPalette.border))),
        padding:
            EdgeInsets.symmetric(horizontal: expanded ? 16 : 12, vertical: 24),
        child: Column(children: [
          if (expanded)
            const _Brand()
          else
            Image.asset('assets/images/arogya_pandit_logo.png',
                width: 40, height: 40, semanticLabel: 'Medivaanii logo'),
          const SizedBox(height: 40),
          for (final i in _nav)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Tooltip(
                  message: _labels[i],
                  child: Material(
                    color: (widget.index == i || i == 1 && widget.index == 2)
                        ? ReportPalette.burgundy
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.onNavigate(i),
                      child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: expanded ? 14 : 0, vertical: 16),
                          child: Row(
                              mainAxisAlignment: expanded
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                Icon(_icons[i],
                                    size: 22,
                                    color: widget.index == i
                                        ? Colors.white
                                        : ReportPalette.muted),
                                if (expanded) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(_labels[i],
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: widget.index == i
                                                  ? Colors.white
                                                  : ReportPalette.ink)))
                                ],
                              ])),
                    ),
                  )),
            ),
          const Spacer(),
          if (expanded)
            const Text('Clarity, in your language.',
                style: TextStyle(fontSize: 12, color: ReportPalette.muted)),
        ]),
      );

  Widget _header(bool desktop) => Container(
        padding:
            EdgeInsets.symmetric(horizontal: desktop ? 24 : 16, vertical: 14),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: ReportPalette.border))),
        child: desktop
            ? Row(children: [
                Expanded(
                    child: Text(_labels[widget.index == 2 ? 1 : widget.index],
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700))),
                _languages(),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const _Brand(),
                const SizedBox(height: 12),
                _languages(),
              ]),
      );

  Widget _languages() => Semantics(
      label: 'Explanation language',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: ReportPalette.ground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: ReportPalette.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final language in widget.languages)
            Flexible(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Semantics(
                  selected: widget.language == language['name'],
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => widget.onLanguage(language['name']!),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(66, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        backgroundColor: widget.language == language['name']
                            ? ReportPalette.burgundy
                            : Colors.transparent,
                        foregroundColor: widget.language == language['name']
                            ? Colors.white
                            : ReportPalette.ink,
                        shape: const StadiumBorder()),
                    child: Text(language['native']!,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  )),
            )),
        ]),
      ));

  Widget _report(bool desktop) => LayoutBuilder(builder: (context, size) {
        final rows = _rows;
        final attention = rows
            .where((r) =>
                ['high', 'low', 'abnormal', 'critical'].contains(r['status']))
            .length;
        final review =
            rows.where((r) => r['acceptance_state'] != 'eligible').length;
        final toolbar = Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.fileName ?? 'Your report',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 3),
                    Text(
                        rows.isEmpty
                            ? 'Report text available · measurements are not yet mapped'
                            : '${rows.length} measurements · $attention outside report range${review > 0 ? ' · $review to check' : ''}',
                        style: const TextStyle(
                            fontSize: 13, color: ReportPalette.muted)),
                  ])),
              if (desktop)
                OutlinedButton.icon(
                    onPressed: widget.downloading ||
                            !reportOutputAllowed(widget.report!)
                        ? null
                        : widget.onDownload,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Save summary'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(40, 42))),
              const SizedBox(width: 8),
              IconButton(
                  tooltip: 'Upload another report',
                  onPressed: () => widget.onNavigate(0),
                  icon: const Icon(Icons.add_rounded)),
            ]));
        final source = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.sourceExplorer ??
                _surface(const Center(
                    child: Text(
                        'Upload the original document to view its source.'))));
        if (desktop)
          return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        toolbar,
                        Expanded(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Expanded(flex: 52, child: source),
                              const SizedBox(width: 20),
                              Expanded(
                                  flex: 48,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (widget.voicePanel != null)
                                          ConstrainedBox(
                                              constraints: BoxConstraints(
                                                  maxHeight:
                                                      (size.maxHeight - 112) *
                                                          .61),
                                              child: widget.voicePanel!),
                                        const SizedBox(height: 16),
                                        Expanded(child: _measurements()),
                                      ])),
                            ])),
                      ]))));
        return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(children: [
              toolbar,
              SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.description_outlined,
                                size: 17),
                            label: Text(_copy('Original report', 'मूल रिपोर्ट',
                                'Informe original', '原始报告'))),
                        ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.format_list_bulleted_rounded,
                                size: 17),
                            label: Text(_copy('Measurements', 'जांच के नतीजे',
                                'Resultados', '检测结果'))),
                      ],
                      selected: {_mobileSource},
                      onSelectionChanged: (s) =>
                          setState(() => _mobileSource = s.first))),
              const SizedBox(height: 10),
              Expanded(
                  child: IndexedStack(
                      index: _mobileSource ? 0 : 1,
                      children: [source, _measurements()])),
              const SizedBox(height: 10),
              if (widget.voicePanel != null)
                ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight:
                            (size.maxHeight * .48).clamp(230, 360).toDouble()),
                    child: widget.voicePanel!),
            ]));
      });

  Widget _measurements() {
    final rows = _rows;
    final visible = rows
        .where((r) =>
            r['test_name']
                .toString()
                .toLowerCase()
                .contains(_query.toLowerCase()) &&
            (_filter == 'all' ||
                _filter == 'flagged' &&
                    ['high', 'low', 'critical', 'abnormal']
                        .contains(r['status']) ||
                _filter == 'review' && r['acceptance_state'] != 'eligible'))
        .toList();
    return _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(children: [
                Expanded(
                    child: Text(
                        _copy('Measurements', 'जांच के नतीजे', 'Resultados',
                            '检测结果'),
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700))),
                Text('${rows.length}',
                    style: const TextStyle(
                        fontSize: 14, color: ReportPalette.muted)),
                PopupMenuButton<String>(
                    tooltip: 'Filter measurements',
                    initialValue: _filter,
                    onSelected: (value) => setState(() => _filter = value),
                    icon: const Icon(Icons.filter_list_rounded, size: 20),
                    itemBuilder: (_) => [
                          for (final entry in {
                            'all': 'All results',
                            'flagged': 'Outside range',
                            'review': 'Needs review'
                          }.entries)
                            PopupMenuItem(
                                value: entry.key, child: Text(entry.value)),
                        ]),
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                  onChanged: (s) => setState(() => _query = s),
                  decoration: InputDecoration(
                      hintText: _copy('Find a test', 'जांच का नाम खोजें',
                          'Buscar una prueba', '搜索检测项目'),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: ReportPalette.ground,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none)))),
          if (widget.reviewSaving) const LinearProgressIndicator(minHeight: 2),
          if (widget.reviewError != null)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.reviewError!,
                    style: const TextStyle(color: ReportPalette.burgundy))),
          const Divider(height: 1),
          Expanded(
              child: ListView(padding: const EdgeInsets.all(12), children: [
            if (rows.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'The report text is available. Its results have not been mapped into individual measurements yet.',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 10),
                        const Text(
                            'The assistant can explain the text, but cannot point to a measurement until it is mapped.',
                            style: TextStyle(
                                fontSize: 14, color: ReportPalette.muted)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : widget.onReextract,
                            icon: const Icon(Icons.document_scanner_outlined),
                            label: const Text('Read results again')),
                      ])),
            if (rows.isNotEmpty && visible.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No measurements match this filter.')),
            for (final row in visible) _measurement(row),
            if (rows.isNotEmpty) _doctorQuestions(rows),
          ])),
        ]),
        padding: EdgeInsets.zero);
  }

  Widget _measurement(Map<String, dynamic> row) {
    final id = row['measurement_id'].toString();
    final selected = widget.report?['selected_measurement_id'] == id;
    final checked = row['acceptance_state'] == 'eligible';
    final status = checked ? (row['status'] ?? 'unknown').toString() : 'review';
    final labels = {
      'normal': 'Within range',
      'high': 'High',
      'low': 'Low',
      'critical': 'Flagged',
      'abnormal': 'Flagged',
      'unknown': 'Range unavailable',
      'review': 'Check source'
    };
    final flagged = ['high', 'low', 'critical', 'abnormal'].contains(status);
    final color = flagged
        ? ReportPalette.burgundy
        : status == 'normal'
            ? ReportPalette.sage
            : ReportPalette.muted;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
            color: selected ? const Color(0xFFF3F7F3) : Colors.white,
            shape: RoundedRectangleBorder(
                side: BorderSide(
                    color: selected ? ReportPalette.sage : ReportPalette.border,
                    width: selected ? 1.5 : 1),
                borderRadius: BorderRadius.circular(12)),
            child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => widget.onSelectMeasurement?.call(id, true),
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Text(row['test_name'].toString(),
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700))),
                                const SizedBox(width: 8),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: ReportPalette.ground,
                                        borderRadius: BorderRadius.circular(7)),
                                    child: Text(
                                        '${row['value']} ${row['unit'] ?? ''}',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700))),
                              ]),
                          const SizedBox(height: 8),
                          Text(
                              'Reference: ${(row['reference_range'] ?? '').toString().isEmpty ? 'Not printed' : row['reference_range']}',
                              style: const TextStyle(
                                  fontSize: 13, color: ReportPalette.muted)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: flagged
                                        ? ReportPalette.rose
                                        : ReportPalette.sageLight,
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(labels[status] ?? 'Check source',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: color))),
                            const Spacer(),
                            IconButton(
                                tooltip: 'Listen to ${row['test_name']}',
                                onPressed: () =>
                                    widget.onSelectMeasurement?.call(id, true),
                                icon: const Icon(Icons.volume_up_outlined,
                                    size: 20),
                                style: IconButton.styleFrom(
                                    minimumSize: const Size(40, 40),
                                    foregroundColor: ReportPalette.sage)),
                            IconButton(
                                tooltip: 'Correct ${row['test_name']}',
                                onPressed: widget.reviewSaving
                                    ? null
                                    : () => widget.onEditMeasurement?.call(id),
                                icon: const Icon(Icons.edit_outlined, size: 19),
                                style: IconButton.styleFrom(
                                    minimumSize: const Size(40, 40))),
                          ]),
                        ])))));
  }

  Widget _doctorQuestions(List<Map<String, dynamic>> rows) {
    final flagged = rows
        .where((r) =>
            r['acceptance_state'] == 'eligible' &&
            ['high', 'low', 'critical', 'abnormal'].contains(r['status']))
        .take(3)
        .toList();
    return ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        title: const Text('Questions for your doctor',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        children: [
          for (final row in flagged)
            ListTile(
                leading: const Icon(Icons.chat_bubble_outline, size: 18),
                title: Text(
                    'What could affect my ${row['test_name']} result of ${row['value']} ${row['unit'] ?? ''}?',
                    style: const TextStyle(fontSize: 14)),
                subtitle: const Text(
                    'Ask whether follow-up is needed in your situation.',
                    style: TextStyle(fontSize: 13))),
          if (flagged.isEmpty)
            const ListTile(
                title: Text(
                    'How do these results fit with my symptoms and medical history?',
                    style: TextStyle(fontSize: 14))),
          const ListTile(
              title: Text(
                  'Is there anything I should check or discuss at my next visit?',
                  style: TextStyle(fontSize: 14))),
        ]);
  }

  Widget _upload() => LayoutBuilder(builder: (context, size) {
        final intro =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('UNDERSTAND. ASK. FEEL INFORMED.',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: ReportPalette.sage)),
          const SizedBox(height: 20),
          const Text('Your report.\nA clearer conversation.',
              style: TextStyle(
                  fontSize: 42,
                  height: 1.15,
                  letterSpacing: -1.4,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          const Text(
              'Make sense of medical terms and numbers, in a language that feels like home.',
              style: TextStyle(
                  fontSize: 18, height: 1.6, color: ReportPalette.muted)),
          const SizedBox(height: 30),
          _step('01', 'Add your report',
              'Upload a PDF, choose a photo, or use your camera.'),
          _step('02', 'See it at the source',
              'Review the numbers alongside the original report.'),
          _step('03', 'Talk it through',
              'Ask a question and hear a simple explanation.'),
          const SizedBox(height: 10),
          _surface(const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.auto_stories_outlined,
                      color: ReportPalette.sage, size: 21),
                  SizedBox(width: 10),
                  Text('An example explanation',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16))
                ]),
                SizedBox(height: 14),
                Text('“What does hemoglobin measure?”',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text(
                    'Hemoglobin carries oxygen through your blood. Your doctor looks at this result alongside your other tests and how you feel.',
                    style: TextStyle(fontSize: 16, height: 1.6)),
                SizedBox(height: 12),
                Text('Illustrative content · not your report',
                    style: TextStyle(fontSize: 12, color: ReportPalette.muted)),
              ])),
        ]);
        final upload = AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: widget.dragging
                        ? ReportPalette.sage
                        : ReportPalette.border,
                    width: widget.dragging ? 2 : 1)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Add your medical report',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  const Text('A PDF or a clear photo is all you need.',
                      style: TextStyle(color: ReportPalette.muted)),
                  const SizedBox(height: 28),
                  if (widget.loading)
                    _progress()
                  else
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 36),
                        decoration: BoxDecoration(
                            color: ReportPalette.ground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ReportPalette.border)),
                        child: Column(children: [
                          Container(
                              padding: const EdgeInsets.all(18),
                              decoration: const BoxDecoration(
                                  color: ReportPalette.rose,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.upload_file_outlined,
                                  size: 34, color: ReportPalette.burgundy)),
                          const SizedBox(height: 20),
                          Text(
                              widget.dragging
                                  ? 'Drop your report here'
                                  : 'Drag your report here',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          const Text('PDF, JPG, PNG or WebP · under 4 MB',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: ReportPalette.muted)),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                              onPressed: _busy ? null : widget.onUpload,
                              icon: const Icon(Icons.upload_file_outlined,
                                  size: 20),
                              label: const Text('Choose PDF')),
                        ])),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _busy ? null : widget.onCamera,
                            icon:
                                const Icon(Icons.camera_alt_outlined, size: 20),
                            label: const Text('Take photo'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _busy ? null : widget.onPhoto,
                            icon: const Icon(Icons.image_outlined, size: 20),
                            label: const Text('Choose photo')))
                  ]),
                  if (widget.error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(widget.error!,
                            style: const TextStyle(
                                color: ReportPalette.burgundy))),
                  const SizedBox(height: 22),
                  const Text(
                      'Keep the full page in view, with good light and no blur. For clear, printed English reports.',
                      style: TextStyle(
                          fontSize: 13,
                          color: ReportPalette.muted,
                          height: 1.6)),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                      'Reports and voice questions use Groq. Spoken answers use Microsoft Edge neural speech.',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: ReportPalette.muted)),
                  if (widget.report != null) ...[
                    const SizedBox(height: 20),
                    TextButton.icon(
                        onPressed: () => widget.onNavigate(1),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Return to your current report'))
                  ],
                ]));
        return size.maxWidth >= 800
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: intro),
                      const SizedBox(width: 56),
                      Expanded(child: upload)
                    ]))
            : Column(children: [intro, const SizedBox(height: 28), upload]);
      });

  Widget _step(String n, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: ReportPalette.sageLight,
                borderRadius: BorderRadius.circular(10)),
            child: Text(n,
                style: const TextStyle(
                    fontSize: 12,
                    color: ReportPalette.sage,
                    fontWeight: FontWeight.w700))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(body,
              style: const TextStyle(fontSize: 14, color: ReportPalette.muted))
        ]))
      ]));
  Widget _surface(Widget child,
          {EdgeInsetsGeometry padding = const EdgeInsets.all(22)}) =>
      Container(
          padding: padding,
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: ReportPalette.border),
              borderRadius: BorderRadius.circular(16)),
          child: child);
  Widget _progress() => const Padding(
      padding: EdgeInsets.all(32),
      child: Column(children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text('Reading your report…')
      ]));
  Widget _empty() =>
      _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('A clearer view starts with your report.',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text(
            'Upload a PDF or a clear photo to see your results and start a conversation.'),
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: () => widget.onNavigate(0),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Add a report'))
      ]));
  Widget _settings() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Your preferences',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text(
            'Change your explanation language in the header, on any screen.',
            style: TextStyle(color: ReportPalette.muted)),
        const SizedBox(height: 28),
        if (widget.report != null)
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Saved on this browser',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(widget.fileName ?? 'Your current report'),
            const SizedBox(height: 8),
            const Text(
                'Your report and corrections stay available after a refresh. Clear them when using a shared device.',
                style: TextStyle(color: ReportPalette.muted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
                onPressed: _busy ? null : widget.onClearSavedReport,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear saved report'))
          ])),
        const SizedBox(height: 20),
        _surface(const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Brand(),
              SizedBox(height: 18),
              Text(
                  'Medivaanii helps you understand the words and numbers in a medical report. Your doctor can interpret them with your symptoms and history.',
                  style: TextStyle(fontSize: 16, height: 1.6))
            ])),
      ]);
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/arogya_pandit_logo.png',
            width: 36, height: 36, semanticLabel: 'Medivaanii logo'),
        const SizedBox(width: 10),
        const Flexible(
            child: Text('Medivaanii',
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6)))
      ]);
}
