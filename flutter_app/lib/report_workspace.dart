import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'report_data.dart';
import 'app_strings.dart';
import 'body_systems.dart';
import 'meds/meds_page.dart';

class ReportPalette {
  static const ground = Color(0xFFFBF7F4);
  static const ink = Color(0xFF1F1B1A);
  static const body = Color(0xFF3C3533);
  static const muted = Color(0xFF5E5754);
  static const burgundy = Color(0xFF8B1A1A);
  static const burgundyDark = Color(0xFF5C0A0A);
  static const border = Color(0xFFE8DEDA);
  static const strongBorder = Color(0xFFDCCFCA);
  static const rose = Color(0xFFF7ECEA);
  static const blush = Color(0xFFFBF4F2);
  static const sand = Color(0xFFF3ECE9);
  static const charcoal = Color(0xFF2B2B2B);
  static const sage = Color(0xFF1D5C3A);
  static const sageLight = Color(0xFFE6F0EA);
  static const lowInk = Color(0xFF17407F);
  static const lowBg = Color(0xFFE3ECFA);
  static const highInk = Color(0xFF7A3A05);
  static const highBg = Color(0xFFFBE6D2);
  static const warnBg = Color(0xFFFDF3E6);
  static const warnBorder = Color(0xFFF1D3A8);
  static const serif = 'NotoSerif';
}

TextStyle serifStyle(double size,
        {FontWeight weight = FontWeight.w500,
        Color color = ReportPalette.ink,
        double height = 1.15}) =>
    TextStyle(
        fontFamily: ReportPalette.serif,
        fontFamilyFallback: const [
          'NotoSans',
          'NotoSansSC',
          'NotoDevanagari'
        ],
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: size >= 32 ? -0.4 : 0,
        color: color);

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
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
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
      backgroundColor: ReportPalette.burgundy,
      foregroundColor: Colors.white,
      disabledBackgroundColor: ReportPalette.sand,
      disabledForegroundColor: ReportPalette.muted,
      minimumSize: const Size(44, 52),
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
      minimumSize: const Size(44, 52),
      foregroundColor: ReportPalette.ink,
      backgroundColor: Colors.white,
      textStyle: const TextStyle(
          fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w600),
      shape: shape,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ).copyWith(
            side: WidgetStateProperty.resolveWith((states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? ReportPalette.burgundy
                    : ReportPalette.strongBorder,
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
      this.sampleConsent = false,
      this.onSampleConsent,
      this.activeSpeech});
  final bool sampleConsent;
  final ValueChanged<bool>? onSampleConsent;
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
  static const _nav = [0, 1, 4, 3];
  List<String> get _labels => [
        _t('Upload report'),
        _t('Report workspace'),
        '',
        _t('Settings'),
        _t('Medicines')
      ];
  String _t(String source, [Map<String, Object?> values = const {}]) =>
      AppStrings(widget.language).t(source, values);
  String _error(String message) => AppStrings(widget.language).error(message);
  static const _icons = [
    Icons.upload_file_outlined,
    Icons.space_dashboard_outlined,
    Icons.help_outline,
    Icons.tune_rounded,
    Icons.medication_outlined
  ];
  bool get _busy => widget.loading || widget.reviewSaving || widget.restoring;
  List<Map<String, dynamic>> get _rows => workspaceMeasurements(widget.report);
  String _copy(String en, String hi, String es, String zh) =>
      {'Hindi': hi, 'Spanish': es, 'Mandarin': zh}[widget.language] ?? en;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final desktop = size.maxWidth >= 900;
        final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
        final workspace = widget.index == 1 || widget.index == 2;
        return Scaffold(
          body: SafeArea(
              child: Column(children: [
            if (!keyboard) _prototypeBanner(desktop),
            if (desktop || !keyboard) _header(desktop),
            Expanded(
                child: IndexedStack(
                    index: workspace && widget.report != null ? 0 : 1,
                    children: [
                  if (widget.report != null)
                    _report(desktop)
                  else
                    const SizedBox(),
                  if (widget.index == 4)
                    MedsPage(language: widget.language)
                  else
                  SingleChildScrollView(
                      child: widget.index == 3
                          ? Padding(
                              padding: EdgeInsets.all(desktop ? 24 : 16),
                              child: _settings())
                          : workspace
                              ? Padding(
                                  padding: EdgeInsets.all(desktop ? 24 : 16),
                                  child: Align(
                                      alignment: Alignment.topCenter,
                                      child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 720),
                                          child: _empty())))
                              : _upload()),
                ])),
          ])),
          bottomNavigationBar: desktop || keyboard
              ? null
              : NavigationBar(
                  height: 64,
                  selectedIndex:
                      _nav.indexOf(widget.index == 2 ? 1 : widget.index),
                  onDestinationSelected: (i) => widget.onNavigate(_nav[i]),
                  destinations: [
                    NavigationDestination(
                        icon: const Icon(Icons.upload_file_outlined),
                        label: _t('Upload')),
                    NavigationDestination(
                        icon: const Icon(Icons.space_dashboard_outlined),
                        label: _t('Report')),
                    NavigationDestination(
                        icon: const Icon(Icons.medication_outlined),
                        label: _t('Medicines')),
                    NavigationDestination(
                        icon: const Icon(Icons.tune_rounded),
                        label: _t('Settings')),
                  ],
                ),
        );
      });

  Widget _prototypeBanner(bool desktop) => Semantics(
        container: true,
        child: Container(
          width: double.infinity,
          color: ReportPalette.charcoal,
          padding: EdgeInsets.symmetric(
              horizontal: 16, vertical: desktop ? 10 : 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Color(0xFFF5EFEC)),
            const SizedBox(width: 8),
            Flexible(
                child: Text(
                    _t('Research prototype. Please use sample reports only — not real patient records.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: desktop ? 14 : 12,
                        height: 1.4,
                        color: const Color(0xFFF5EFEC)))),
          ]),
        ),
      );

  Widget _header(bool desktop) => Container(
        padding:
            EdgeInsets.symmetric(horizontal: desktop ? 24 : 16, vertical: 12),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: ReportPalette.border))),
        child: desktop
            ? Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1392),
                    child: Row(children: [
                      Semantics(
                          button: true,
                          label: _t('Upload report'),
                          child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => widget.onNavigate(0),
                              child: _Brand(language: widget.language))),
                      const SizedBox(width: 32),
                      for (final i in _nav) _navLink(i),
                      const Spacer(),
                      _languages(),
                    ])))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Brand(language: widget.language),
                const SizedBox(height: 10),
                _languages(),
              ]),
      );

  Widget _navLink(int i) {
    final active = widget.index == i || (i == 1 && widget.index == 2);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Semantics(
        selected: active,
        child: TextButton.icon(
          onPressed: () => widget.onNavigate(i),
          icon: Icon(_icons[i],
              size: 19,
              color: active ? ReportPalette.burgundy : ReportPalette.muted),
          label: Text(_labels[i],
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? ReportPalette.burgundy : ReportPalette.body)),
          style: TextButton.styleFrom(
              backgroundColor: active ? ReportPalette.rose : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
        ),
      ),
    );
  }

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
        final reviewMode = widget.reviewing && rows.isNotEmpty;
        if (desktop) {
          return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(children: [
                        Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _stepper(reviewMode, true)),
                        toolbar,
                        Expanded(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Expanded(flex: 52, child: source),
                              const SizedBox(width: 20),
                              Expanded(
                                  flex: 48,
                                  child: reviewMode
                                      ? _reviewPanel(rows, review)
                                      : _reportCompanion()),
                            ])),
                      ]))));
        }
        if (reviewMode && _mobileView == 'conversation') {
          _mobileView = 'results';
        }
        return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(children: [
              if (!keyboard && _mobileView != 'conversation') ...[
                _stepper(reviewMode, false),
                const SizedBox(height: 10),
                toolbar,
              ],
              SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: ReportPalette.rose,
                          selectedForegroundColor: ReportPalette.burgundy,
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
                        if (!reviewMode)
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
              if (reviewMode) ...[
                const SizedBox(height: 10),
                _confirmButton(rows),
              ] else if (_mobileView != 'conversation' &&
                  widget.voicePanelBuilder != null) ...[
                const SizedBox(height: 10),
                _surface(widget.voicePanelBuilder!(false, _openConversation),
                    padding: EdgeInsets.zero),
              ],
            ]));
      });

  Widget _stepper(bool reviewMode, bool desktop) {
    Widget step(int n, String label, {required bool done, required bool current,
        VoidCallback? onTap}) {
      final color = current
          ? Colors.white
          : done
              ? ReportPalette.sage
              : ReportPalette.muted;
      final child = Container(
        padding: EdgeInsets.symmetric(
            horizontal: desktop ? 14 : 10, vertical: desktop ? 8 : 6),
        decoration: BoxDecoration(
            color: current ? ReportPalette.burgundy : Colors.transparent,
            borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (done && !current)
            Icon(Icons.check_rounded, size: 16, color: color)
          else
            Text('$n', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 6),
          Text(_t(label), style: TextStyle(
              fontSize: desktop ? 14 : 13,
              fontWeight: current ? FontWeight.w600 : FontWeight.w500,
              color: color)),
        ]),
      );
      return Semantics(
        button: onTap != null,
        selected: current,
        child: onTap == null
            ? child
            : InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _busy ? null : onTap,
                child: child),
      );
    }

    return Align(
      alignment: desktop ? Alignment.centerLeft : Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          step(1, 'Upload', done: true, current: false,
              onTap: () => widget.onNavigate(0)),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: ReportPalette.strongBorder),
          step(2, 'Check the numbers',
              done: !reviewMode && _rows.isNotEmpty,
              current: reviewMode,
              onTap: reviewMode || _rows.isEmpty ? null : widget.onReview),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: ReportPalette.strongBorder),
          step(3, 'Ask', done: false, current: !reviewMode && _rows.isNotEmpty),
        ]),
      ),
    );
  }

  Widget _confirmButton(List<Map<String, dynamic>> rows) => FilledButton.icon(
      onPressed: widget.reviewSaving || widget.onConfirmReview == null
          ? null
          : () => widget.onConfirmReview!(rows),
      icon: widget.reviewSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: ReportPalette.muted))
          : const Icon(Icons.arrow_forward_rounded, size: 20),
      label: Text(_t(widget.reviewSaving
          ? 'Updating your explanation…'
          : 'Looks right — explain my report')));

  Widget _reviewPanel(List<Map<String, dynamic>> rows, int review) => _surface(
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
                header: true,
                child: Text(_t('Check the numbers'), style: serifStyle(28))),
            const SizedBox(height: 8),
            Text(
                _t('We found {count} results. Compare them with your report — anything we misread changes every explanation that follows.',
                    {'count': rows.length}),
                style: const TextStyle(
                    fontSize: 15, height: 1.55, color: ReportPalette.body)),
            if (review > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: ReportPalette.warnBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ReportPalette.warnBorder)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 20, color: ReportPalette.highInk),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              _t('{count} results need your eyes. Use the pencil to correct a value, or continue if they match your report.',
                                  {'count': review}),
                              style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Color(0xFF5A2E04)))),
                    ]),
              ),
            ],
          ]),
        ),
        Expanded(child: _measurements(embedded: true)),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
                _t('Status labels repeat the flag printed on your report. Medivaanii never decides on its own whether a result is normal.'),
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: ReportPalette.muted)),
            const SizedBox(height: 14),
            Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                      onPressed: _busy ? null : () => widget.onNavigate(0),
                      child: Text(_t('Upload a different report'))),
                  _confirmButton(rows),
                ]),
          ]),
        ),
      ]),
      padding: EdgeInsets.zero);

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
        selectedColor: ReportPalette.rose,
        backgroundColor: Colors.white,
        side: BorderSide(
            color: _filter == value
                ? ReportPalette.burgundy
                : ReportPalette.border),
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
      'high': 'Above range',
      'low': 'Below range',
      'critical': 'Flagged',
      'abnormal': 'Flagged',
      'unknown': 'Unclassified',
      'review': 'Please confirm'
    };
    final (Color chipBg, Color color, IconData? chipIcon) = switch (status) {
      'high' => (ReportPalette.highBg, ReportPalette.highInk,
          Icons.arrow_upward_rounded),
      'low' => (ReportPalette.lowBg, ReportPalette.lowInk,
          Icons.arrow_downward_rounded),
      'critical' || 'abnormal' => (ReportPalette.highBg,
          ReportPalette.highInk, Icons.flag_outlined),
      'normal' => (ReportPalette.ground, ReportPalette.body, null),
      'review' => (ReportPalette.warnBg, ReportPalette.highInk,
          Icons.visibility_outlined),
      _ => (ReportPalette.sand, ReportPalette.muted, null),
    };
    final reference = (row['reference_range'] ?? '').toString();
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected
              ? ReportPalette.blush
              : status == 'review'
                  ? const Color(0xFFFFFBF5)
                  : Colors.white,
          shape: RoundedRectangleBorder(
              side: BorderSide(
                  color: selected
                      ? ReportPalette.burgundy
                      : status == 'review'
                          ? ReportPalette.warnBorder
                          : ReportPalette.border,
                  width: selected ? 1.5 : 1),
              borderRadius: BorderRadius.circular(12)),
          child: InkWell(
              borderRadius: BorderRadius.circular(12),
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
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                                color: chipBg,
                                borderRadius: BorderRadius.circular(999),
                                border: status == 'review'
                                    ? Border.all(
                                        color: ReportPalette.warnBorder)
                                    : null),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (chipIcon != null) ...[
                                Icon(chipIcon, size: 13, color: color),
                                const SizedBox(width: 4),
                              ],
                              Text(_t(labels[status] ?? 'Please confirm'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: color)),
                            ])),
                        IconButton(
                            tooltip: _t(
                                'Listen to {test}', {'test': row['test_name']}),
                            onPressed: () =>
                                _chooseMeasurement(id, listen: true),
                            icon:
                                const Icon(Icons.volume_up_outlined, size: 19),
                            style: IconButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                foregroundColor: ReportPalette.burgundy)),
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
        final wide = size.maxWidth >= 900;
        final pad = wide ? 24.0 : 16.0;
        Widget band(Widget child, {Color? color, double vertical = 56}) =>
            Container(
                width: double.infinity,
                decoration: color == null
                    ? null
                    : BoxDecoration(
                        color: color,
                        border: const Border.symmetric(
                            horizontal:
                                BorderSide(color: ReportPalette.border))),
                padding:
                    EdgeInsets.symmetric(horizontal: pad, vertical: vertical),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: child)));
        final intro =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('LAB REPORTS, IN YOUR LANGUAGE'),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: ReportPalette.burgundy)),
          const SizedBox(height: 18),
          Semantics(
              header: true,
              child: Text(
                  _t('Understand your report. Then talk it through with your doctor.'),
                  style: serifStyle(wide ? 52 : 34, height: 1.1))),
          const SizedBox(height: 20),
          Text(
              _t('Upload a printed lab report. Medivaanii reads each value, shows you exactly where it came from, and answers your questions out loud — in English, Hindi, Spanish or Mandarin.'),
              style: const TextStyle(
                  fontSize: 18, height: 1.6, color: ReportPalette.body)),
          const SizedBox(height: 28),
          Text(_t('Explain it to me in'),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final language in widget.languages)
              _languageChoice(language['name']!, language['native']!),
          ]),
          const SizedBox(height: 10),
          Text(
              _t('You can switch at any time. The report itself needs to be printed in English for now.'),
              style: const TextStyle(
                  fontSize: 14, height: 1.5, color: ReportPalette.muted)),
        ]);
        final canUpload = !_busy && widget.sampleConsent;
        final upload = AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.all(wide ? 28 : 20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: widget.dragging
                        ? ReportPalette.burgundy
                        : ReportPalette.border,
                    width: widget.dragging ? 2 : 1),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x0F2B1B18),
                      blurRadius: 32,
                      offset: Offset(0, 12))
                ]),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_t('Add your report'), style: serifStyle(24)),
                  const SizedBox(height: 18),
                  if (widget.loading)
                    _progress()
                  else
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 32),
                        decoration: BoxDecoration(
                            color: widget.dragging
                                ? ReportPalette.rose
                                : ReportPalette.blush,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: const Color(0xFFD9B8B3), width: 1.5)),
                        child: Column(children: [
                          Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF3E2DF),
                                  borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.upload_file_outlined,
                                  size: 28, color: ReportPalette.burgundy)),
                          const SizedBox(height: 14),
                          Text(
                              _t(widget.dragging
                                  ? 'Drop your report here'
                                  : 'Drop a PDF or photo here'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(_t('PDF, JPG, PNG or WebP · under 4 MB'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 14, color: ReportPalette.muted)),
                        ])),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: canUpload ? widget.onUpload : null,
                      icon: const Icon(Icons.upload_file_outlined, size: 20),
                      label: Text(_t('Choose PDF'))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: canUpload ? widget.onCamera : null,
                            icon:
                                const Icon(Icons.camera_alt_outlined, size: 20),
                            label: Text(_t('Take photo')))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: canUpload ? widget.onPhoto : null,
                            icon: const Icon(Icons.image_outlined, size: 20),
                            label: Text(_t('Choose photo'))))
                  ]),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _busy
                          ? null
                          : () => widget.onSampleConsent
                              ?.call(!widget.sampleConsent),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                  value: widget.sampleConsent,
                                  activeColor: ReportPalette.burgundy,
                                  onChanged: _busy
                                      ? null
                                      : (value) => widget.onSampleConsent
                                          ?.call(value ?? false)),
                              const SizedBox(width: 4),
                              Expanded(
                                  child: Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                          _t('This is a sample or anonymised report. I understand this prototype is not for real patient data.'),
                                          style: const TextStyle(
                                              fontSize: 15,
                                              height: 1.5,
                                              color: ReportPalette.body)))),
                            ]),
                      ),
                    ),
                  ),
                  if (!widget.sampleConsent && !widget.loading)
                    Padding(
                        padding: const EdgeInsets.only(left: 52, top: 2),
                        child: Text(
                            _t('Tick the box above to enable upload.'),
                            style: const TextStyle(
                                fontSize: 13, color: ReportPalette.muted))),
                  if (widget.error != null)
                    Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: ReportPalette.rose,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(_error(widget.error!),
                            style: const TextStyle(
                                color: ReportPalette.burgundyDark,
                                height: 1.5))),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                      _t('Keep the full page in view, with good light and no blur. For clear, printed English reports.'),
                      style: const TextStyle(
                          fontSize: 13,
                          color: ReportPalette.muted,
                          height: 1.6)),
                  if (widget.report != null) ...[
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                            onPressed: () => widget.onNavigate(1),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(_t('Return to your current report')))),
                  ],
                ]));
        final hero = wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 11, child: intro),
                const SizedBox(width: 56),
                Expanded(flex: 10, child: upload),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                intro,
                const SizedBox(height: 28),
                upload
              ]);
        final steps = [
          _step('1', 'Upload',
              'A PDF from the lab, or a photo taken on your phone. We read the tests, values, units and reference ranges printed on it.'),
          _step('2', 'Check the numbers',
              'Every value sits beside the original page. Reading a photo can go wrong, so we mark uncertain rows and let you fix them.'),
          _step('3', 'Ask by voice',
              'Speak or type a question. The answer is read aloud and points to the exact line on your report it is based on.'),
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          band(hero, vertical: wide ? 56 : 28),
          band(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_t('Three steps, and you stay in control'),
                    style: serifStyle(wide ? 34 : 26)),
                const SizedBox(height: 28),
                wide
                    ? IntrinsicHeight(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            for (var i = 0; i < steps.length; i++) ...[
                              if (i > 0) const SizedBox(width: 20),
                              Expanded(child: steps[i]),
                            ]
                          ]))
                    : Column(children: [
                        for (final step in steps)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: step)
                      ]),
              ]),
              color: Colors.white),
          band(_honesty(wide), vertical: wide ? 56 : 32),
          Container(
              decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: ReportPalette.border))),
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 24),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 24,
                          runSpacing: 8,
                          children: [
                            Text(
                                _t('Medivaanii · a research prototype by ArogyaPandit'),
                                style: const TextStyle(
                                    fontSize: 14, color: ReportPalette.muted)),
                            Text(
                                _t('Not a medical device. Always confirm results with a clinician.'),
                                style: const TextStyle(
                                    fontSize: 14, color: ReportPalette.muted)),
                          ])))),
        ]);
      });

  Widget _languageChoice(String name, String native) {
    final selected = widget.language == name;
    return Semantics(
      selected: selected,
      button: true,
      child: OutlinedButton(
        onPressed: () => widget.onLanguage(name),
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(96, 50),
            backgroundColor: selected ? ReportPalette.burgundy : Colors.white,
            foregroundColor: selected ? Colors.white : ReportPalette.ink,
            side: BorderSide(
                color:
                    selected ? ReportPalette.burgundy : ReportPalette.strongBorder,
                width: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text(native,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _honesty(bool wide) {
    Widget list(IconData icon, Color iconColor, String title,
            List<String> items) =>
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ReportPalette.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_t(title),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 14),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                          padding: EdgeInsets.only(top: 9, right: 10),
                          child: SizedBox(
                              width: 5,
                              height: 5,
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: ReportPalette.muted,
                                      shape: BoxShape.circle)))),
                      Expanded(
                          child: Text(_t(item),
                              style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.55,
                                  color: ReportPalette.body))),
                    ]),
              ),
          ]),
        );
    final does = list(Icons.check_rounded, ReportPalette.sage,
        'What Medivaanii does', [
      'Explains the values printed on your report in plain words',
      'Uses only the flags and ranges the lab printed — it doesn’t invent its own',
      'Shows where every number and answer came from',
      'Helps you prepare questions for your doctor',
    ]);
    final doesnt = list(Icons.close_rounded, ReportPalette.burgundy,
        'What it won’t do', [
      'Diagnose a condition or tell you which medicine to take',
      'Replace your doctor — it has not been clinically validated',
      'Read handwritten notes or reports in other scripts, yet',
      'Keep a long-term history — your report stays in this browser until you clear it',
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(_t('Being honest about what this is'),
          style: serifStyle(wide ? 34 : 26)),
      const SizedBox(height: 24),
      wide
          ? IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Expanded(child: does),
                  const SizedBox(width: 20),
                  Expanded(child: doesnt),
                ]))
          : Column(children: [does, const SizedBox(height: 14), doesnt]),
      const SizedBox(height: 20),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: ReportPalette.sand,
              borderRadius: BorderRadius.circular(18)),
          child: Text(
              _t('Where your data goes: report text and your questions are sent to an AI service (Groq) to write explanations; answer text goes to a speech service to be read aloud. Your original file stays in your browser.'),
              style: const TextStyle(
                  fontSize: 15, height: 1.6, color: ReportPalette.body))),
    ]);
  }

  Widget _step(String n, String title, String body) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: ReportPalette.ground,
            borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n, style: serifStyle(30, color: ReportPalette.burgundy)),
          const SizedBox(height: 10),
          Text(_t(title),
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_t(body),
              style: const TextStyle(
                  fontSize: 15, height: 1.6, color: ReportPalette.body)),
        ]),
      );
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
            style: serifStyle(28)),
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
                style: serifStyle(30, height: 1.25)),
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
                                  color: ReportPalette.burgundy))),
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
                                  activeTrackColor: ReportPalette.burgundy,
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
      selectedBackgroundColor: ReportPalette.rose,
      selectedForegroundColor: ReportPalette.burgundy,
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
        ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset('assets/images/arogya_pandit_logo.png',
                width: 38,
                height: 38,
                semanticLabel: AppStrings(language).t('Medivaanii logo'))),
        const SizedBox(width: 10),
        Flexible(
            child: Text('Medivaanii',
                style: serifStyle(22, weight: FontWeight.w600)))
      ]);
}
