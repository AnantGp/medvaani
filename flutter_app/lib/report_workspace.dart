import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'report_data.dart';
import 'app_strings.dart';
import 'body_systems.dart';

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
      'NotoSansSC',
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
      this.voiceRate = 1,
      this.largeText = false,
      this.pageCount,
      this.uploadedAt,
      this.onVoiceRate,
      this.onLargeText,
      this.onListenMeasurement,
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
      this.voicePanelBuilder,
      this.voiceExplanationRequest = 0,
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
  final ValueChanged<String>? onListenMeasurement;
  final ValueChanged<double>? onVoiceRate;
  final ValueChanged<bool>? onLargeText;
  final double voiceRate;
  final bool largeText;
  final int? pageCount;
  final DateTime? uploadedAt;
  final void Function(Uint8List bytes, String name)? onDropFile;
  final bool dragging;
  final bool reviewing, reviewSaving, restoring;
  final String? reviewError, storageError;
  final Widget? sourcePreview, sourceExplorer;
  final Widget Function(bool expanded, VoidCallback onExpand)?
      voicePanelBuilder;
  final int voiceExplanationRequest;
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
  final _measurementsScroll = ScrollController();
  final _searchController = TextEditingController();
  bool _conversation = false;
  String _mobileView = 'report';

  void _openConversation() => setState(() {
        _conversation = true;
        _mobileView = 'conversation';
      });

  @override
  void didUpdateWidget(covariant ReportWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.voiceExplanationRequest != oldWidget.voiceExplanationRequest) {
      _conversation = true;
      _mobileView = 'conversation';
    }
    if (widget.fileName != oldWidget.fileName) {
      _conversation = false;
      _mobileView = 'report';
      _filter = 'all';
      _query = '';
      _searchController.clear();
    }
  }

  void _chooseMeasurement(String id, {bool listen = false}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _showSearch = false;
      _conversation = true;
      _mobileView = 'conversation';
    });
    if (listen && widget.onListenMeasurement != null) {
      widget.onListenMeasurement!(id);
    } else {
      widget.onSelectMeasurement?.call(id, true);
    }
  }

  void _setFilter(String value) {
    setState(() {
      _filter = value;
      _conversation = false;
      _mobileView = 'results';
      _query = '';
      _searchController.clear();
      _showSearch = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _measurementsScroll.hasClients) {
        _measurementsScroll.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _measurementsScroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _showSearch = false;
  static const _nav = [0, 1, 3];
  List<String> get _labels =>
      [_t('Upload report'), _t('Report workspace'), '', _t('Settings')];
  String _t(String source, [Map<String, Object?> values = const {}]) =>
      AppStrings(widget.language).t(source, values);
  String _error(String message) => AppStrings(widget.language).error(message);
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
        final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
        final expandedRail = size.maxWidth >= 1350;
        final workspace = widget.index == 1 || widget.index == 2;
        return Scaffold(
          body: SafeArea(
              child: Row(children: [
            if (desktop) _sidebar(expandedRail),
            Expanded(
                child: Column(children: [
              if (desktop || !keyboard) _header(desktop),
              Expanded(
                  child: IndexedStack(
                      index: workspace && widget.report != null ? 0 : 1,
                      children: [
                    if (widget.report != null)
                      _report(desktop)
                    else
                      const SizedBox(),
                    SingleChildScrollView(
                        padding: EdgeInsets.all(desktop ? 24 : 16),
                        child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1440),
                              child: widget.index == 3
                                  ? _settings()
                                  : workspace
                                      ? _empty()
                                      : _upload(),
                            ))),
                  ])),
            ])),
          ])),
          bottomNavigationBar: desktop || keyboard
              ? null
              : NavigationBar(
                  height: 62,
                  selectedIndex:
                      _nav.indexOf(widget.index == 2 ? 1 : widget.index),
                  onDestinationSelected: (i) => widget.onNavigate(_nav[i]),
                  destinations: [
                    NavigationDestination(
                        icon: Icon(Icons.upload_file_outlined),
                        label: _t('Upload')),
                    NavigationDestination(
                        icon: Icon(Icons.space_dashboard_outlined),
                        label: _t('Report')),
                    NavigationDestination(
                        icon: Icon(Icons.tune_rounded), label: _t('Settings')),
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
            _Brand(language: widget.language)
          else
            Image.asset('assets/images/arogya_pandit_logo.png',
                width: 40, height: 40, semanticLabel: _t('Medivaanii logo')),
          const SizedBox(height: 40),
          for (final i in _nav)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Tooltip(
                  excludeFromSemantics: true,
                  message: _labels[i],
                  child: Material(
                    color: (widget.index == i || i == 1 && widget.index == 2)
                        ? ReportPalette.rose
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.onNavigate(i),
                      child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: expanded ? 14 : 0,
                              vertical: expanded ? 16 : 11),
                          child: expanded
                              ? Row(
                                  mainAxisAlignment: expanded
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.center,
                                  children: [
                                      Icon(_icons[i],
                                          size: 22,
                                          color: widget.index == i
                                              ? ReportPalette.burgundy
                                              : ReportPalette.muted),
                                      if (expanded) ...[
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(_labels[i],
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: widget.index == i
                                                        ? ReportPalette.burgundy
                                                        : ReportPalette.ink)))
                                      ],
                                    ])
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                      Icon(_icons[i],
                                          size: 22,
                                          color: widget.index == i
                                              ? ReportPalette.burgundy
                                              : ReportPalette.muted),
                                      const SizedBox(height: 5),
                                      Text(
                                          _t(i == 0
                                              ? 'Upload'
                                              : i == 1
                                                  ? 'Report'
                                                  : 'Settings'),
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: widget.index == i
                                                  ? ReportPalette.burgundy
                                                  : ReportPalette.muted)),
                                    ])),
                    ),
                  )),
            ),
          const Spacer(),
          if (expanded)
            Text(_t('Clarity, in your language.'),
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
                _Brand(language: widget.language),
                const SizedBox(height: 12),
                _languages(),
              ]),
      );

  Widget _languages() => Semantics(
      label: _t('App language'),
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
                    onPressed: () => widget.onLanguage(language['name']!),
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
        final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
        final rows = _rows;
        final counts = reportComparisonCounts(widget.report!);
        final partial = reportQualityState(widget.report!) == 'partial';
        final expected = declaredMeasurementCount(widget.report!);
        final review =
            rows.where((r) => r['acceptance_state'] != 'eligible').length;
        final toolbar = Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.fileName ?? _t('Your report'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 3),
                    if (rows.isEmpty)
                      Text(_t('Report text available · measurements are not yet mapped'),
                          style: TextStyle(
                              fontSize: 13, color: ReportPalette.muted))
                    else ...[
                      if (partial)
                        Text(
                            [
                              _t('Partial extraction'),
                              if (expected != null)
                                _t('{count} of {total} measurements',
                                    {'count': rows.length, 'total': expected}),
                              if (review > 0)
                                _t('{count} to check', {'count': review})
                            ].join(' · '),
                            style: const TextStyle(
                                fontSize: 12, color: ReportPalette.burgundy)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _filterChip(
                            'all',
                            _copy('All ${rows.length}', 'सभी ${rows.length}',
                                'Todos ${rows.length}', '全部 ${rows.length}')),
                        _filterChip('flagged',
                            "${counts['abnormal']} ${_copy('Flagged', 'अलग नतीजे', 'Señalados', '已标记')}"),
                        _filterChip('normal',
                            "${counts['normal']} ${_copy('Within range', 'सीमा के अंदर', 'Dentro del rango', '范围内')}"),
                        _filterChip('unclassified',
                            "${counts['unclassified']} ${_copy('Unclassified', 'बिना तुलना', 'Sin clasificar', '未分类')}"),
                      ]),
                    ],
                  ])),
              if (desktop)
                OutlinedButton.icon(
                    onPressed: widget.downloading ||
                            !reportOutputAllowed(widget.report!)
                        ? null
                        : widget.onDownload,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(_t('Save summary')),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(40, 42))),
              if (partial && widget.onReextract != null)
                TextButton.icon(
                    onPressed: _busy ? null : widget.onReextract,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label:
                        Text(_t(desktop ? 'Read results again' : 'Re-read'))),
              const SizedBox(width: 8),
              IconButton(
                  tooltip: _t('Upload another report'),
                  onPressed: () => widget.onNavigate(0),
                  icon: const Icon(Icons.add_rounded)),
            ]));
        final source = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.sourceExplorer ??
                _surface(Center(
                    child: Text(_t(
                        'Upload the original document to view its source.')))));
        if (desktop) {
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
                              const SizedBox(width: 16),
                              Expanded(flex: 48, child: _reportCompanion()),
                            ])),
                      ]))));
        }
        return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(children: [
              if (!keyboard && _mobileView != 'conversation') toolbar,
              SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: ReportPalette.sageLight,
                          selectedForegroundColor: ReportPalette.sage,
                          backgroundColor: Colors.white,
                          foregroundColor: ReportPalette.muted,
                          textStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                      segments: [
                        ButtonSegment(
                            value: 'report',
                            label: Text(
                                _copy('Report', 'रिपोर्ट', 'Informe', '报告'))),
                        ButtonSegment(
                            value: 'results',
                            label: Text(
                                _copy('Results', 'नतीजे', 'Resultados', '结果'))),
                        ButtonSegment(
                            value: 'conversation',
                            label: Text(_copy('Conversation', 'बातचीत',
                                'Conversación', '对话'))),
                      ],
                      selected: {_mobileView},
                      onSelectionChanged: (s) =>
                          setState(() => _mobileView = s.first))),
              const SizedBox(height: 10),
              Expanded(
                  child: IndexedStack(
                      index: ['report', 'results', 'conversation']
                          .indexOf(_mobileView),
                      children: [
                    source,
                    _measurements(),
                    if (_mobileView == 'conversation')
                      _surface(
                          widget.voicePanelBuilder
                                  ?.call(true, _openConversation) ??
                              const SizedBox(),
                          padding: EdgeInsets.zero)
                    else
                      const SizedBox(),
                  ])),
              if (_mobileView != 'conversation' &&
                  widget.voicePanelBuilder != null) ...[
                const SizedBox(height: 10),
                _surface(widget.voicePanelBuilder!(false, _openConversation),
                    padding: EdgeInsets.zero),
              ],
            ]));
      });

  Widget _reportCompanion() => _surface(
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            _companionTab(false, _copy('Results', 'नतीजे', 'Resultados', '结果'),
                Icons.format_list_bulleted_rounded),
            const SizedBox(width: 22),
            _companionTab(
                true,
                _copy('Conversation', 'बातचीत', 'Conversación', '对话'),
                Icons.graphic_eq_rounded),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!_conversation) Expanded(child: _measurements(embedded: true)),
            if (widget.voicePanelBuilder != null)
              if (_conversation)
                Expanded(
                    child: widget.voicePanelBuilder!(true, _openConversation))
              else ...[
                const Divider(height: 1),
                widget.voicePanelBuilder!(false, _openConversation),
              ],
          ]),
        ),
      ]),
      padding: EdgeInsets.zero);

  Widget _companionTab(bool conversation, String title, IconData icon) =>
      Semantics(
        button: true,
        selected: _conversation == conversation,
        child: InkWell(
          onTap: () => setState(() => _conversation = conversation),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: _conversation == conversation
                            ? ReportPalette.burgundy
                            : Colors.transparent,
                        width: 2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 19,
                  color: _conversation == conversation
                      ? ReportPalette.burgundy
                      : ReportPalette.muted),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _conversation == conversation
                          ? ReportPalette.ink
                          : ReportPalette.muted)),
            ]),
          ),
        ),
      );

  Widget _filterChip(String value, String label) => FilterChip(
        label: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        selected: _filter == value,
        showCheckmark: false,
        onSelected: (_) => _setFilter(value),
        selectedColor: ReportPalette.sageLight,
        backgroundColor: Colors.white,
        side: BorderSide(
            color:
                _filter == value ? ReportPalette.sage : ReportPalette.border),
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      );

  Widget _measurements({bool embedded = false}) {
    final rows = _rows;
    final visible = rows
        .where((r) =>
            r['test_name']
                .toString()
                .toLowerCase()
                .contains(_query.toLowerCase()) &&
            measurementMatchesFilter(r, _filter))
        .toList();
    final groups = groupMeasurementsByBodySystem(visible);
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(children: [
            Expanded(
                child: _showSearch
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (value) => setState(() => _query = value),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                            hintText: _copy('Find a test', 'जांच का नाम खोजें',
                                'Buscar una prueba', '搜索检测项目'),
                            isDense: true,
                            filled: true,
                            fillColor: ReportPalette.ground,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none)))
                    : Text(
                        _copy('Measurements', 'जांच के नतीजे', 'Resultados',
                            '检测结果'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Text(
                '${visible.length}${visible.length == rows.length ? '' : ' / ${rows.length}'}',
                style:
                    const TextStyle(fontSize: 14, color: ReportPalette.muted)),
            IconButton(
                tooltip: _t(_showSearch ? 'Close search' : 'Find a test'),
                onPressed: () => setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _query = '';
                        _searchController.clear();
                      }
                    }),
                icon: Icon(
                    _showSearch ? Icons.close_rounded : Icons.search_rounded,
                    size: 21)),
            PopupMenuButton<String>(
                tooltip: _t('Filter measurements'),
                initialValue: _filter,
                onSelected: _setFilter,
                icon: const Icon(Icons.filter_list_rounded, size: 20),
                itemBuilder: (_) => [
                      for (final entry in {
                        'all': 'All results',
                        'flagged': 'Flagged results',
                        'normal': 'Within range',
                        'unclassified': 'Unclassified',
                        'review': 'Needs review'
                      }.entries)
                        PopupMenuItem(
                            value: entry.key, child: Text(_t(entry.value))),
                    ]),
          ])),
      if (widget.reviewSaving) const LinearProgressIndicator(minHeight: 2),
      if (widget.reviewError != null)
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error(widget.reviewError!),
                style: const TextStyle(color: ReportPalette.burgundy))),
      const Divider(height: 1, thickness: 1, color: ReportPalette.border),
      Expanded(
          child: ListView(
              key: const PageStorageKey('report-measurements'),
              controller: _measurementsScroll,
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              children: [
            if (rows.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _t('The report text is available. Its results have not been mapped into individual measurements yet.'),
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 10),
                        Text(_t('The assistant can explain the text, but cannot point to a measurement until it is mapped.'),
                            style: TextStyle(
                                fontSize: 14, color: ReportPalette.muted)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : widget.onReextract,
                            icon: const Icon(Icons.document_scanner_outlined),
                            label: Text(_t('Read results again'))),
                      ])),
            if (rows.isNotEmpty && visible.isEmpty)
              Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(_t('No measurements match this filter.'))),
            for (final group in groups.entries) ...[
              _systemHeader(group.key, group.value.length),
              for (final row in group.value) _measurement(row),
            ],
            if (rows.isNotEmpty) _doctorQuestions(rows),
          ])),
    ]);
    return embedded ? content : _surface(content, padding: EdgeInsets.zero);
  }

  String get _languageCode => switch (widget.language) {
        'Hindi' => 'hi',
        'Spanish' => 'es',
        'Mandarin' => 'zh',
        _ => 'en',
      };

  Widget _systemHeader(BodySystem system, int count) => Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
          child: Row(children: [
            BodySystemIcon(system, size: 21),
            const SizedBox(width: 9),
            Expanded(
                child: Text(system.title(_languageCode),
                    style: const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700))),
            Text('$count',
                style:
                    const TextStyle(fontSize: 13, color: ReportPalette.muted)),
          ]),
        ),
      );

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
      'unknown': 'Unclassified',
      'review': 'Check source'
    };
    final flagged = ['high', 'low', 'critical', 'abnormal'].contains(status);
    final color = flagged
        ? ReportPalette.burgundy
        : status == 'normal'
            ? ReportPalette.sage
            : ReportPalette.muted;
    final reference = (row['reference_range'] ?? '').toString();
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? const Color(0xffedf3ef) : Colors.white,
          shape: RoundedRectangleBorder(
              side: BorderSide(
                  color: selected ? ReportPalette.sage : ReportPalette.border,
                  width: selected ? 1.5 : 1),
              borderRadius: BorderRadius.circular(10)),
          child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _chooseMeasurement(id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Tooltip(
                                    message: row['test_name'].toString(),
                                    excludeFromSemantics: true,
                                    child: Text(row['test_name'].toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize:
                                                widget.largeText ? 17 : 15,
                                            height: 1.35,
                                            fontWeight: FontWeight.w700)))),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 180),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: selected
                                            ? Colors.white
                                            : ReportPalette.ground,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                        '${row['value']} ${row['unit'] ?? ''}',
                                        style: TextStyle(
                                            fontSize:
                                                widget.largeText ? 17 : 15,
                                            fontWeight: FontWeight.w700)))),
                          ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Expanded(
                            child: InkWell(
                                onTap: reference.isEmpty
                                    ? null
                                    : () => showDialog<void>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                                title: Text(row['test_name'].toString()),
                                                content: SelectableText('${_t('Reference range')}\n$reference'),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child: Text(_t('Close')))
                                                ])),
                                child: Tooltip(
                                    message: reference.isEmpty
                                        ? _t('Reference not printed')
                                        : _t('Reference: {range}',
                                            {'range': reference}),
                                    child: Text(_t('Ref: {range}', {'range': reference.isEmpty ? _t('Not printed') : reference}),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: widget.largeText ? 14 : 12,
                                            color: ReportPalette.muted))))),
                        const SizedBox(width: 6),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                                color: flagged
                                    ? ReportPalette.rose
                                    : ReportPalette.sageLight,
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(_t(labels[status] ?? 'Check source'),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: color))),
                        IconButton(
                            tooltip: _t(
                                'Listen to {test}', {'test': row['test_name']}),
                            onPressed: () =>
                                _chooseMeasurement(id, listen: true),
                            icon:
                                const Icon(Icons.volume_up_outlined, size: 19),
                            style: IconButton.styleFrom(
                                minimumSize: const Size(40, 40),
                                foregroundColor: ReportPalette.sage)),
                        IconButton(
                            tooltip: _t(
                                'Correct {test}', {'test': row['test_name']}),
                            onPressed: widget.reviewSaving
                                ? null
                                : () => widget.onEditMeasurement?.call(id),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            style: IconButton.styleFrom(
                                minimumSize: const Size(40, 40))),
                      ]),
                    ]),
              )),
        ));
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
        title: Text(_t('Questions for your doctor'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        children: [
          for (final row in flagged)
            ListTile(
                leading: const Icon(Icons.chat_bubble_outline, size: 18),
                title: Text(
                    _t(
                        'What could affect my {test} result of {value} {unit}?',
                        {
                          'test': row['test_name'],
                          'value': row['value'],
                          'unit': row['unit'] ?? ''
                        }),
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                    _t('Ask whether follow-up is needed in your situation.'),
                    style: TextStyle(fontSize: 13))),
          if (flagged.isEmpty)
            ListTile(
                title: Text(
                    _t('How do these results fit with my symptoms and medical history?'),
                    style: TextStyle(fontSize: 14))),
          ListTile(
              title: Text(
                  _t('Is there anything I should check or discuss at my next visit?'),
                  style: TextStyle(fontSize: 14))),
        ]);
  }

  Widget _upload() => LayoutBuilder(builder: (context, size) {
        final intro =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('UNDERSTAND. ASK. FEEL INFORMED.'),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: ReportPalette.sage)),
          const SizedBox(height: 20),
          Text(_t('Your report.\nA clearer conversation.'),
              style: TextStyle(
                  fontSize: 42,
                  height: 1.15,
                  letterSpacing: -1.4,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Text(_t('Make sense of medical terms and numbers, in a language that feels like home.'),
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
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_stories_outlined,
                  color: ReportPalette.sage, size: 21),
              SizedBox(width: 10),
              Expanded(
                  child: Text(_t('An example explanation'),
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)))
            ]),
            SizedBox(height: 14),
            Text(_t('“What does hemoglobin measure?”'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
                _t('Hemoglobin carries oxygen through your blood. Your doctor looks at this result alongside your other tests and how you feel.'),
                style: TextStyle(fontSize: 16, height: 1.6)),
            SizedBox(height: 12),
            Text(_t('Illustrative content · not your report'),
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
                  Text(_t('Add your medical report'),
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(_t('A PDF or a clear photo is all you need.'),
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
                              _t(widget.dragging
                                  ? 'Drop your report here'
                                  : 'Drag your report here'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(_t('PDF, JPG, PNG or WebP · under 4 MB'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: ReportPalette.muted)),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                              onPressed: _busy ? null : widget.onUpload,
                              icon: const Icon(Icons.upload_file_outlined,
                                  size: 20),
                              label: Text(_t('Choose PDF'))),
                        ])),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _busy ? null : widget.onCamera,
                            icon:
                                const Icon(Icons.camera_alt_outlined, size: 20),
                            label: Text(_t('Take photo')))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _busy ? null : widget.onPhoto,
                            icon: const Icon(Icons.image_outlined, size: 20),
                            label: Text(_t('Choose photo'))))
                  ]),
                  if (widget.error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(_error(widget.error!),
                            style: const TextStyle(
                                color: ReportPalette.burgundy))),
                  const SizedBox(height: 22),
                  Text(_t('Keep the full page in view, with good light and no blur. For clear, printed English reports.'),
                      style: TextStyle(
                          fontSize: 13,
                          color: ReportPalette.muted,
                          height: 1.6)),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text(_t('Reports and voice questions use Groq. Spoken answers use Microsoft Edge neural speech.'),
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: ReportPalette.muted)),
                  if (widget.report != null) ...[
                    const SizedBox(height: 20),
                    TextButton.icon(
                        onPressed: () => widget.onNavigate(1),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(_t('Return to your current report')))
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
          Text(_t(title),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(_t(body),
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
  Widget _progress() => Padding(
      padding: EdgeInsets.all(32),
      child: Column(children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text(AppStrings(widget.language).progress(widget.loadingMessage))
      ]));
  Widget _empty() =>
      _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_t('A clearer view starts with your report.'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(_t(
            'Upload a PDF or a clear photo to see your results and start a conversation.')),
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: () => widget.onNavigate(0),
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(_t('Add a report')))
      ]));
  Widget _settings() => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),
            Text(
                _copy('App settings & data', 'ऐप सेटिंग्स और डेटा',
                    'Configuración y datos', '应用设置与数据'),
                style: const TextStyle(
                    fontSize: 28, height: 1.3, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                _copy(
                    'Manage voice playback, reading size, and this browser’s report.',
                    'आवाज़, पढ़ने के आकार और इस ब्राउज़र की रिपोर्ट की सेटिंग्स चुनें।',
                    'Gestiona la voz, el tamaño de lectura y el informe de este navegador.',
                    '管理语音播放、阅读字号和此浏览器中的报告。'),
                style: const TextStyle(
                    fontSize: 15, height: 1.6, color: ReportPalette.muted)),
            const SizedBox(height: 24),
            _surface(
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _settingsHeading(_copy(
                          'Voice & reading preferences',
                          'आवाज़ और पढ़ने की पसंद',
                          'Voz y lectura',
                          '语音与阅读偏好')),
                      _settingsRow(
                          Icons.translate_rounded,
                          _t('App language'),
                          _copy(
                              'Change it for the whole app using the selector in the top bar.',
                              'ऊपर भाषा चुनें। यह पूरी ऐप में लागू होगी।',
                              'Cámbialo para toda la aplicación en la barra superior.',
                              '在顶部选择器中更改整个应用的语言。'),
                          trailing: Text(
                              widget.languages.firstWhere((entry) =>
                                  entry['name'] == widget.language)['native']!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ReportPalette.sage))),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _preferenceChoices(
                          Icons.slow_motion_video_rounded,
                          _copy(
                              'Default voice speed',
                              'आवाज़ की सामान्य रफ़्तार',
                              'Velocidad de voz',
                              '默认语速'),
                          _copy(
                              'Applied to each new spoken answer.',
                              'हर नए जवाब पर लागू होगी।',
                              'Se aplica a cada respuesta hablada.',
                              '应用于每次新的语音回答。'),
                          SegmentedButton<double>(
                              showSelectedIcon: false,
                              style: _preferenceStyle,
                              segments: [
                                ButtonSegment(
                                    value: 1,
                                    label: Text(_copy(
                                        'Normal · 1×',
                                        'सामान्य · 1×',
                                        'Normal · 1×',
                                        '正常 · 1×'))),
                                ButtonSegment(
                                    value: .85,
                                    label: Text(_copy(
                                        'Slower · 0.85×',
                                        'धीरे · 0.85×',
                                        'Lenta · 0.85×',
                                        '较慢 · 0.85×'))),
                              ],
                              selected: {widget.voiceRate},
                              onSelectionChanged: _busy
                                  ? null
                                  : (values) =>
                                      widget.onVoiceRate?.call(values.first))),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _settingsRow(
                          Icons.volume_up_outlined,
                          _copy(
                              'Play explanations automatically',
                              'जवाब अपने आप सुनाएं',
                              'Reproducir explicaciones automáticamente',
                              '自动播放讲解'),
                          _copy(
                              'Speak when a result is selected. With this off, read first; Listen and spoken questions still play audio.',
                              'नतीजा चुनने पर आवाज़ चलेगी। बंद होने पर पहले पढ़ें; सुनें बटन और बोलकर पूछे सवाल आवाज़ चलाएंगे।',
                              'Hablar al seleccionar un resultado. Si lo desactivas, lee primero; Escuchar y las preguntas por voz siguen reproduciendo audio.',
                              '选择结果后自动讲解。关闭后可先阅读，收听按钮和语音提问仍播放音频。'),
                          trailing: Semantics(
                              label: _copy(
                                  'Play explanations automatically',
                                  'जवाब अपने आप सुनाएं',
                                  'Reproducir explicaciones automáticamente',
                                  '自动播放讲解'),
                              child: Switch.adaptive(
                                  value: widget.speechEnabled,
                                  activeTrackColor: ReportPalette.sage,
                                  onChanged:
                                      _busy ? null : widget.onSpeechEnabled))),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _preferenceChoices(
                          Icons.text_fields_rounded,
                          _copy(
                              'Reading text size',
                              'पढ़ने के लिए अक्षर का आकार',
                              'Tamaño de lectura',
                              '阅读字号'),
                          _copy(
                              'Changes result values and explanations. Use the report zoom for the original document.',
                              'नतीजे और जवाब के अक्षर बदलेंगे। मूल रिपोर्ट के लिए ज़ूम इस्तेमाल करें।',
                              'Cambia resultados y explicaciones. Usa el zoom para el documento original.',
                              '调整结果数值和讲解文字，原始文档请使用缩放。'),
                          SegmentedButton<bool>(
                              showSelectedIcon: false,
                              style: _preferenceStyle,
                              segments: [
                                ButtonSegment(
                                    value: false,
                                    label: Text(_copy('Standard', 'सामान्य',
                                        'Estándar', '标准'))),
                                ButtonSegment(
                                    value: true,
                                    label: Text(_copy('Large text',
                                        'बड़े अक्षर', 'Texto grande', '大字'))),
                              ],
                              selected: {widget.largeText},
                              onSelectionChanged: _busy
                                  ? null
                                  : (values) =>
                                      widget.onLargeText?.call(values.first))),
                      const Divider(height: 1),
                      _settingsHeading(_copy('Stored report',
                          'सेव की गई रिपोर्ट', 'Informe guardado', '已保存的报告')),
                      _settingsRow(
                          Icons.description_outlined,
                          widget.report == null
                              ? _copy(
                                  'No saved report',
                                  'कोई रिपोर्ट सेव नहीं है',
                                  'No hay informe guardado',
                                  '没有已保存的报告')
                              : (widget.fileName ?? _t('Your report')),
                          widget.report == null
                              ? _copy(
                                  'Add a medical report to start a conversation.',
                                  'बातचीत शुरू करने के लिए मेडिकल रिपोर्ट जोड़ें।',
                                  'Añade un informe médico para empezar.',
                                  '添加医疗报告以开始对话。')
                              : _storedReportDetails()),
                      if (widget.storageError != null)
                        Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: Text(_error(widget.storageError!),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: ReportPalette.burgundy))),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.report != null) ...[
                                  Text(
                                      _copy(
                                          'Clear the saved report after using a shared device. Downloaded files are kept.',
                                          'साझा डिवाइस पर काम के बाद सेव रिपोर्ट हटाएं। डाउनलोड की गई फाइलें रहेंगी।',
                                          'Borra el informe tras usar un dispositivo compartido. Los archivos descargados se conservan.',
                                          '使用共用设备后请清除保存的报告，已下载的文件会保留。'),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.6,
                                          color: ReportPalette.muted)),
                                  const SizedBox(height: 14),
                                ],
                                Wrap(spacing: 10, runSpacing: 10, children: [
                                  OutlinedButton.icon(
                                      onPressed: () => widget.onNavigate(
                                          widget.report == null ? 0 : 1),
                                      icon: Icon(widget.report == null ? Icons.upload_file_outlined : Icons.space_dashboard_outlined,
                                          size: 18),
                                      label: Text(widget.report == null
                                          ? _copy(
                                              'Add a report',
                                              'रिपोर्ट जोड़ें',
                                              'Añadir informe',
                                              '添加报告')
                                          : _copy(
                                              'Return to workspace',
                                              'रिपोर्ट पर वापस जाएं',
                                              'Volver al informe',
                                              '返回报告工作区')),
                                      style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(44, 44),
                                          textStyle: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600))),
                                  if (widget.report != null)
                                    TextButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : _confirmClearSavedReport,
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18),
                                        label: Text(_copy(
                                            'Clear saved report',
                                            'सेव रिपोर्ट हटाएं',
                                            'Borrar informe guardado',
                                            '清除已保存的报告')),
                                        style: TextButton.styleFrom(
                                            foregroundColor:
                                                ReportPalette.burgundy,
                                            minimumSize: const Size(44, 44),
                                            textStyle: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600))),
                                ]),
                              ])),
                      const Divider(height: 1),
                      _settingsHeading(_copy(
                          'About & clinical disclaimer',
                          'ऐप और स्वास्थ्य संबंधी जानकारी',
                          'Acerca de la aplicación y aviso clínico',
                          '关于与医疗声明')),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    _copy(
                                        'Medivaanii explains the words and numbers in medical reports. It is an educational aid, not a diagnosis. Discuss results and medication with your doctor.',
                                        'Medivaanii मेडिकल रिपोर्ट के शब्द और नंबर समझाता है। यह जानकारी देने में मदद है, निदान नहीं। नतीजों और दवाओं पर डॉक्टर से बात करें।',
                                        'Medivaanii explica las palabras y cifras de informes médicos. Es una ayuda educativa, no un diagnóstico. Consulta los resultados y medicamentos con tu médico.',
                                        'Medivaanii解释医疗报告中的词语和数值，是教育辅助工具，不提供诊断。请与医生讨论结果及用药。'),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.7,
                                        color: ReportPalette.muted)),
                                const SizedBox(height: 14),
                                Text(
                                    _copy(
                                        'Processing & privacy',
                                        'प्रोसेसिंग और निजता',
                                        'Procesamiento y privacidad',
                                        '处理与隐私'),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(
                                    _copy(
                                        'Report content and voice questions are processed by Groq. Spoken answers use Microsoft Edge neural speech, or Sarvam when enabled.',
                                        'रिपोर्ट और आवाज़ के सवाल Groq पर प्रोसेस होते हैं। जवाब Microsoft Edge neural speech से, या चालू होने पर Sarvam से सुनाए जाते हैं।',
                                        'Groq procesa informes y preguntas por voz. Las respuestas usan Microsoft Edge neural speech o Sarvam cuando está habilitado.',
                                        'Groq处理报告内容和语音提问，Microsoft Edge神经语音或已启用的Sarvam生成语音回答。'),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.7,
                                        color: ReportPalette.muted)),
                                const SizedBox(height: 16),
                                const Text('Medivaanii · v1.0.0 · MVP',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: ReportPalette.muted)),
                              ])),
                    ]),
                padding: EdgeInsets.zero),
            const SizedBox(height: 24),
          ]),
        ),
      );

  ButtonStyle get _preferenceStyle => SegmentedButton.styleFrom(
      selectedBackgroundColor: ReportPalette.sageLight,
      selectedForegroundColor: ReportPalette.sage,
      backgroundColor: Colors.white,
      foregroundColor: ReportPalette.muted,
      minimumSize: const Size(44, 42),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));

  Widget _settingsHeading(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Text(title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)));

  Widget _preferenceChoices(
          IconData icon, String title, String description, Widget control) =>
      LayoutBuilder(builder: (context, size) {
        if (size.maxWidth >= 600) {
          return _settingsRow(icon, title, description,
              trailing: SizedBox(width: 248, child: control));
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsRow(icon, title, description),
              Padding(
                  padding: const EdgeInsets.fromLTRB(55, 0, 20, 20),
                  child: control),
            ]);
      });

  String _storedReportDetails() {
    final parts = <String>[
      _copy('${_rows.length} measurements', '${_rows.length} नतीजे',
          '${_rows.length} resultados', '${_rows.length}项检测'),
      if (widget.pageCount != null)
        _copy('${widget.pageCount} pages', '${widget.pageCount} पन्ने',
            '${widget.pageCount} páginas', '${widget.pageCount}页'),
      widget.storageError == null
          ? _copy('Saved on this browser', 'इस ब्राउज़र में सेव है',
              'Guardado en este navegador', '保存在此浏览器中')
          : _copy('Available in this tab', 'इस टैब में उपलब्ध है',
              'Disponible en esta pestaña', '此标签页中可用'),
    ];
    final date = widget.uploadedAt?.toLocal();
    if (date != null) {
      parts.add(_copy(
          'Added ${date.day}/${date.month}/${date.year}',
          'जोड़ा गया ${date.day}/${date.month}/${date.year}',
          'Añadido ${date.day}/${date.month}/${date.year}',
          '添加于 ${date.year}/${date.month}/${date.day}'));
    }
    return parts.join(' · ');
  }

  Widget _settingsRow(IconData icon, String title, String description,
          {Widget? trailing}) =>
      Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 21, color: ReportPalette.muted),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.65,
                          color: ReportPalette.muted)),
                ])),
            if (trailing != null) ...[const SizedBox(width: 12), trailing],
          ]));

  Future<void> _confirmClearSavedReport() async {
    final clear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(_copy(
                  'Clear this browser’s report?',
                  'इस ब्राउज़र की रिपोर्ट हटाएं?',
                  '¿Borrar el informe de este navegador?',
                  '清除此浏览器中的报告？')),
              content: Text(_copy(
                  'This removes the saved document and corrections from this browser. Files you have downloaded are kept.',
                  'इस ब्राउज़र से सेव रिपोर्ट और सुधार हट जाएंगे। डाउनलोड की हुई फाइलें रहेंगी।',
                  'Se eliminarán el documento y las correcciones guardados en este navegador. Los archivos descargados se conservan.',
                  '这将移除此浏览器保存的文档和更正，已下载的文件会保留。')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(_copy(
                        'Keep report', 'रिपोर्ट रखें', 'Conservar', '保留报告'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(_copy('Clear report', 'रिपोर्ट हटाएं',
                        'Borrar informe', '清除报告')))
              ],
            ));
    if (clear == true && mounted) widget.onClearSavedReport?.call();
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.language = 'English'});
  final String language;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/arogya_pandit_logo.png',
            width: 36,
            height: 36,
            semanticLabel: AppStrings(language).t('Medivaanii logo')),
        const SizedBox(width: 10),
        const Flexible(
            child: Text('Medivaanii',
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6)))
      ]);
}
