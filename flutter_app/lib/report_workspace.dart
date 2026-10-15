import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'app_content_utils.dart';
import 'report_data.dart';
import 'report_review_widgets.dart';

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
      this.activeSpeech});
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
  int _reportView = 0;

  @override
  void didUpdateWidget(covariant ReportWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cited = widget.report?['voice_cited_measurement_ids'];
    if (cited is List &&
        cited.isNotEmpty &&
        !identical(cited, oldWidget.report?['voice_cited_measurement_ids'])) {
      _reportView = 2;
    }
  }

  static const _labels = [
    'Upload report',
    'Explanation',
    'Suggestions',
    'Settings'
  ];
  static const _icons = [
    LucideIcons.fileUp,
    LucideIcons.bookOpen,
    LucideIcons.lightbulb,
    LucideIcons.settings2
  ];
  Duration get _transition => MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.of(context).accessibleNavigation
      ? Duration.zero
      : const Duration(milliseconds: 190);
  String _text(String key) => reportText(widget.report?[key]);
  String get _explanation => [
        _text('simple_explanation'),
        _text('simplified_explanation'),
        _text('simple_summary')
      ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
  bool get _busy =>
      widget.loading ||
      widget.translating ||
      widget.reviewSaving ||
      widget.restoring;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth >= 1000;
        return Scaffold(
          body: SafeArea(
              child: Row(children: [
            if (wide) _sidebar(),
            Expanded(
                child: Column(children: [
              Container(
                  height: 80,
                  padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16),
                  decoration: const BoxDecoration(
                      color: ReportPalette.ground,
                      border: Border(
                          bottom: BorderSide(color: ReportPalette.border))),
                  child: Row(children: [
                    if (wide)
                      Expanded(
                          child: Text(_labels[widget.index],
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)))
                    else
                      const Expanded(child: _Brand()),
                    _languageControl(compact: !wide),
                  ])),
              Expanded(
                  child: AnimatedSwitcher(
                      duration: _transition,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOut,
                      child: SingleChildScrollView(
                          key: ValueKey(widget.index),
                          padding: EdgeInsets.fromLTRB(wide ? 36 : 20,
                              wide ? 40 : 28, wide ? 36 : 20, 40),
                          child: Center(
                              child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          widget.index == 1 ? 1480 : 1120),
                                  child: _page()))))),
            ])),
          ])),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: widget.index,
                  onDestinationSelected: widget.onNavigate,
                  destinations: List.generate(
                      4,
                      (i) => NavigationDestination(
                          icon: Icon(_icons[i], size: 22),
                          label: i == 0 ? 'Upload' : _labels[i]))),
        );
      });

  Widget _sidebar() => Container(
      width: 236,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: ReportPalette.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4), child: _Brand()),
        const SizedBox(height: 42),
        for (var i = 0; i < 4; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                  selected: widget.index == i,
                  child: TextButton.icon(
                      onPressed: () => widget.onNavigate(i),
                      icon: Icon(_icons[i], size: 21),
                      label: Text(_labels[i]),
                      style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          backgroundColor: widget.index == i
                              ? ReportPalette.burgundy
                              : Colors.transparent,
                          foregroundColor: widget.index == i
                              ? Colors.white
                              : ReportPalette.ink,
                          textStyle: const TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w600))))),
        const Spacer(),
        const Text('Medical report assistant',
            style: TextStyle(fontSize: 14, color: ReportPalette.muted)),
      ]));

  Widget _languageControl({bool compact = false}) => PopupMenuButton<String>(
      tooltip: 'Choose explanation language',
      enabled: !_busy,
      onSelected: widget.onLanguage,
      itemBuilder: (_) => widget.languages
          .map((language) => PopupMenuItem<String>(
              value: language['name'],
              height: 52,
              child: Text('${language['native']} · ${language['name']}',
                  style: const TextStyle(fontSize: 16))))
          .toList(),
      child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: ReportPalette.border),
              borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.languages,
                size: 20, color: ReportPalette.burgundy),
            const SizedBox(width: 8),
            Text(compact ? _languageShort() : widget.language,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (!compact) ...[
              const SizedBox(width: 10),
              const Icon(LucideIcons.chevronDown, size: 16)
            ],
          ])));

  String _languageShort() => widget.languages
      .firstWhere((l) => l['name'] == widget.language,
          orElse: () => {'code': 'en'})['code']!
      .toUpperCase();
  Widget _page() => switch (widget.index) {
        0 => _upload(),
        1 => _explanationPage(),
        2 => _suggestions(),
        _ => _settings()
      };

  Widget _heading(String title, String subtitle) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: MediaQuery.sizeOf(context).width >= 1000 ? 38 : 28,
                fontWeight: FontWeight.w700,
                height: 1.18,
                letterSpacing: -.8)),
        const SizedBox(height: 14),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 17, height: 1.65, color: ReportPalette.muted)),
        const SizedBox(height: 28),
      ]);
  Widget _surface(Widget child, {EdgeInsetsGeometry? padding}) => Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: ReportPalette.border),
          borderRadius: BorderRadius.circular(14)),
      child: child);

  Widget _upload() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading('Your report, made clear.',
            'Take a photo or upload your medical report. Read a simpler explanation in your preferred language.'),
        if (widget.error != null) ...[
          _notice(widget.error!, error: true),
          const SizedBox(height: 20)
        ],
        LayoutBuilder(builder: (context, size) {
          final upload = _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(LucideIcons.fileText,
                  color: ReportPalette.burgundy, size: 24),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Add your report',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)))
            ]),
            const SizedBox(height: 28),
            AnimatedSwitcher(
                duration: _transition,
                child: widget.loading
                    ? _progress()
                    : Column(key: const ValueKey('ready-upload'), children: [
                        Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                                color: ReportPalette.rose,
                                borderRadius: BorderRadius.circular(16)),
                            child: const Icon(LucideIcons.scanText,
                                size: 32, color: ReportPalette.burgundy)),
                        const SizedBox(height: 20),
                        const Text('A clear photo works too',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        const Text('PDF, JPG, PNG or WebP · up to 10 MB',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: ReportPalette.muted, fontSize: 16)),
                        const SizedBox(height: 12),
                        const Text('For clear, printed English reports.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                                onPressed: _busy ? null : widget.onCamera,
                                icon: const Icon(LucideIcons.camera, size: 20),
                                label: const Text('Take a photo'))),
                        const SizedBox(height: 12),
                        Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                  onPressed: _busy ? null : widget.onPhoto,
                                  icon: const Icon(LucideIcons.image, size: 20),
                                  label: const Text('Choose photo')),
                              OutlinedButton.icon(
                                  onPressed: _busy ? null : widget.onUpload,
                                  icon:
                                      const Icon(LucideIcons.fileUp, size: 20),
                                  label: const Text('Choose PDF')),
                            ]),
                        const SizedBox(height: 20),
                        const Text(
                            'Keep the whole page visible, with good light and no blur. One photo per upload.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ReportPalette.muted)),
                        const SizedBox(height: 12),
                        const Text(
                            'Take a photo opens the camera on supported phones. Computers offer a file chooser.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ReportPalette.muted)),
                        const SizedBox(height: 16),
                        Text('Explanation language: ${widget.language}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16, color: ReportPalette.muted)),
                      ])),
            const SizedBox(height: 8),
          ]));
          final example = _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('An example explanation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const Text('See how medical terms become easier to understand.',
                style: TextStyle(color: ReportPalette.muted)),
            const SizedBox(height: 24),
            _exampleTerm('Hemoglobin', 'Carries oxygen in your blood.'),
            const Divider(height: 32),
            _exampleTerm(
                'White blood cells', 'Help your body fight infection.'),
            const SizedBox(height: 20),
            const Text('Illustrative content',
                style: TextStyle(fontSize: 14, color: ReportPalette.muted)),
          ]));
          return size.maxWidth >= 760
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 6, child: upload),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: example)
                ])
              : Column(children: [upload, const SizedBox(height: 20), example]);
        }),
        if (widget.report != null && !widget.loading) ...[
          const SizedBox(height: 24),
          _surface(Wrap(
              spacing: 20,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(widget.fileName ?? 'Your report',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Text('Explanation ready',
                    style: TextStyle(color: ReportPalette.sage)),
                OutlinedButton.icon(
                    onPressed: () => widget.onNavigate(1),
                    icon: const Icon(LucideIcons.arrowRight, size: 18),
                    label: const Text('Open explanation')),
              ]))
        ],
        const SizedBox(height: 32),
        const Text('How it works',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        _step('1', 'Upload',
            'Choose your language. Take a photo or select a report.'),
        _step('2', 'Understand',
            'Read the explanation and review the extracted values.'),
        _step('3', 'Listen or save',
            'Hear the explanation or download a summary PDF.'),
      ]);

  Widget _exampleTerm(String name, String meaning) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(meaning)
      ]);
  Widget _step(String number, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: ReportPalette.rose,
                borderRadius: BorderRadius.circular(10)),
            child: Text(number,
                style: const TextStyle(
                    color: ReportPalette.burgundy,
                    fontWeight: FontWeight.w700))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: ReportPalette.muted)),
        ])),
      ]));

  Widget _progress() => Semantics(
      liveRegion: true,
      child: Column(key: const ValueKey('processing'), children: [
        const SizedBox(height: 24),
        if (!MediaQuery.disableAnimationsOf(context))
          const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5))
        else
          const Icon(LucideIcons.hourglass,
              color: ReportPalette.burgundy, size: 28),
        const SizedBox(height: 20),
        if (widget.fileName != null) ...[
          Text(widget.fileName!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
        ],
        Text(
            widget.loadingMessage.isEmpty
                ? 'Reading your report'
                : widget.loadingMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Your explanation will appear when processing finishes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ReportPalette.muted)),
        const SizedBox(height: 24),
      ]));

  Widget _notice(String text, {bool error = false, VoidCallback? retry}) =>
      Semantics(
          liveRegion: true,
          child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: error ? ReportPalette.rose : ReportPalette.sageLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                              error
                                  ? LucideIcons.circleAlert
                                  : LucideIcons.info,
                              size: 21,
                              color: error
                                  ? ReportPalette.burgundy
                                  : ReportPalette.sage),
                          const SizedBox(width: 12),
                          Expanded(child: Text(text))
                        ]),
                    if (retry != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TextButton.icon(
                              onPressed: _busy ? null : retry,
                              icon: const Icon(LucideIcons.rotateCcw, size: 18),
                              label: const Text('Retry translation'))),
                  ])));

  Widget _empty(String title) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading(title,
            'Add a report photo or PDF to read your explanation, review values, and listen in your preferred language.'),
        _surface(widget.loading
            ? _progress()
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(LucideIcons.fileText,
                    size: 36, color: ReportPalette.burgundy),
                const SizedBox(height: 20),
                const Text('Your report will appear here.',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                FilledButton.icon(
                    onPressed: () => widget.onNavigate(0),
                    icon: const Icon(LucideIcons.fileUp, size: 18),
                    label: const Text('Upload a report')),
              ])),
      ]);

  Widget _reportActions() => Wrap(spacing: 12, runSpacing: 12, children: [
        FilledButton.icon(
            onPressed: _busy || widget.downloading ? null : widget.onDownload,
            icon: Icon(
                widget.downloading
                    ? LucideIcons.hourglass
                    : LucideIcons.download,
                size: 18),
            label: Text(widget.downloading
                ? 'Preparing PDF…'
                : 'Download summary PDF')),
        OutlinedButton.icon(
            onPressed: _busy ? null : () => widget.onNavigate(0),
            icon: const Icon(LucideIcons.fileUp, size: 18),
            label: const Text('Upload another')),
        if (widget.onReview != null)
          OutlinedButton.icon(
              onPressed: _busy ? null : widget.onReview,
              icon: const Icon(LucideIcons.scanText, size: 18),
              label: const Text('Review source & correct results')),
      ]);

  Widget _explanationPage() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.report != null && widget.voicePanel != null) ...[
        widget.voicePanel!,
        const SizedBox(height: 28),
      ],
      _reportExplanationContent(),
    ]);
  }

  Widget _reportExplanationContent() {
    if (widget.restoring) return _notice('Restoring your saved report…');
    if (widget.report == null) return _empty('Your report, explained.');
    final allowed = reportOutputAllowed(widget.report!);
    final labs = eligibleReportLabValues(widget.report!);
    final legacy = reportQualityState(widget.report!) == 'legacy_unverified';
    if (legacy || !allowed) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading(
            legacy ? 'Read the original again.' : 'Check your source fields.',
            widget.fileName ?? 'Your report'),
        _notice(legacy
            ? 'This saved report used an older extractor. Your original and corrections are retained. Read the original again to recover patient results.'
            : 'Explanations are paused. Check the fields marked for review against the original before using these results.'),
        const SizedBox(height: 20),
        if (legacy)
          OutlinedButton.icon(
              onPressed:
                  widget.reviewSaving ? null : widget.onReextract ?? () {},
              icon: const Icon(LucideIcons.scanText, size: 18),
              label: Text(widget.reviewSaving
                  ? 'Reading original…'
                  : 'Read original again')),
        if (widget.reviewError != null)
          _notice(widget.reviewError!, error: true),
        const SizedBox(height: 20),
        if (widget.sourceExplorer != null) widget.sourceExplorer!,
        if (widget.sourceExplorer == null && widget.onConfirmReview != null)
          ReportReviewPanel(
              report: widget.report!,
              sourcePreview: widget.sourcePreview,
              onOpenSource: widget.onOpenSource,
              onConfirm: widget.onConfirmReview!,
              onReextract: widget.onReextract,
              busy: widget.reviewSaving),
      ]);
    }
    if (widget.reviewing && widget.onConfirmReview != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading(
            'Review your report.', widget.fileName ?? 'Your uploaded report'),
        _notice(reportCoverageText(widget.report!)),
        const SizedBox(height: 20),
        if (widget.reviewError != null)
          _notice(widget.reviewError!, error: true),
        if ((widget.report!['unapplied_corrections'] as List? ?? [])
            .isNotEmpty) ...[
          _notice(
              'Saved corrections could not be matched uniquely. Compare them with the original before applying them.'),
          for (final correction
              in widget.report!['unapplied_corrections'] as List)
            Text(
                'Saved correction · ${correction['reviewed_fields']['test_name']}: ${correction['reviewed_fields']['value']} ${correction['reviewed_fields']['unit']}'),
          const SizedBox(height: 20),
        ],
        if (widget.sourceExplorer != null) ...[
          widget.sourceExplorer!,
          const SizedBox(height: 20),
          Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                  onPressed: widget.reviewSaving
                      ? null
                      : () => widget.onConfirmReview!(
                          reportLabValues(widget.report!['parsed_data'])),
                  icon: const Icon(LucideIcons.arrowRight, size: 18),
                  label: Text(widget.reviewSaving
                      ? 'Saving source review…'
                      : 'Continue to explanation'))),
        ] else
          ReportReviewPanel(
              key: ValueKey(widget.report!['parsed_data'].toString()),
              report: widget.report!,
              sourcePreview: widget.sourcePreview,
              onOpenSource: widget.onOpenSource,
              onReextract: widget.onReextract,
              onConfirm: widget.onConfirmReview!,
              busy: widget.reviewSaving,
              error: widget.reviewError),
      ]);
    }
    final translated = _text('translated_explanation');
    final isEnglish = widget.language == 'English';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(
          'Your report, explained.', widget.fileName ?? 'Your uploaded report'),
      _reportActions(),
      const SizedBox(height: 24),
      if ((widget.report!['unapplied_corrections'] as List? ?? [])
          .isNotEmpty) ...[
        _notice(
            'Some saved corrections could not be matched uniquely. They remain saved below; compare them with the original before applying them.'),
        for (final correction
            in widget.report!['unapplied_corrections'] as List)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                  'Saved correction · ${correction['reviewed_fields']['test_name']}: ${correction['reviewed_fields']['value']} ${correction['reviewed_fields']['unit']}')),
        const SizedBox(height: 20),
      ],
      _notice(
          '${reportQualityState(widget.report!) == 'partial' ? 'Partial extraction · ' : ''}${reportCoverageText(widget.report!)}'),
      const SizedBox(height: 20),
      if (widget.storageError != null) ...[
        _notice(widget.storageError!, error: true),
        const SizedBox(height: 16)
      ],
      if (_text('report_overview').isNotEmpty) ...[
        _notice(_text('report_overview')),
        const SizedBox(height: 20)
      ],
      if ((widget.report!['review'] is Map) &&
          widget.report!['review']['confirmed'] == true) ...[
        const Text('Extraction reviewed · Current report kept on this browser.',
            style: TextStyle(color: ReportPalette.muted, fontSize: 14)),
        const SizedBox(height: 16),
      ],
      if (widget.audioError != null) ...[
        _notice(widget.audioError!, error: true),
        const SizedBox(height: 20),
      ],
      if (widget.translating) ...[
        _notice(
            'Translating to ${widget.language}… The English explanation is available below.'),
        const SizedBox(height: 20)
      ],
      if (!isEnglish &&
          !widget.translating &&
          (translated.isEmpty || widget.translationError != null)) ...[
        _notice(
            'Translation unavailable. The English explanation is still available.',
            error: true,
            retry: widget.onRetryTranslation),
        const SizedBox(height: 20)
      ],
      Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(value: 0, label: Text('Overview')),
                ButtonSegment(
                    value: 1, label: Text('Lab values (${labs.length})')),
                if (widget.sourceExplorer != null)
                  const ButtonSegment(value: 2, label: Text('Explorer')),
              ],
              selected: {
                _reportView == 2 && widget.sourceExplorer == null
                    ? 0
                    : _reportView
              },
              onSelectionChanged: (value) =>
                  setState(() => _reportView = value.first))),
      const SizedBox(height: 24),
      AnimatedSwitcher(
          duration: _transition,
          child: _reportView == 2 && widget.sourceExplorer != null
              ? widget.sourceExplorer!
              : _reportView == 1
                  ? _labs(labs)
                  : Column(
                      key: const ValueKey('overview'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          _reading(
                              isEnglish || translated.isEmpty
                                  ? 'Simple explanation · English'
                                  : 'Simple explanation · ${widget.language}',
                              isEnglish || translated.isEmpty
                                  ? _explanation
                                  : translated,
                              language: isEnglish || translated.isEmpty
                                  ? 'English'
                                  : widget.language),
                          if (!isEnglish && translated.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text('English explanation'),
                                children: [
                                  _reading('Original generated explanation',
                                      _explanation,
                                      language: 'English')
                                ])
                          ],
                          if (_text('medical_summary').isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _reading('Medical summary · English',
                                _text('medical_summary'),
                                language: 'English')
                          ],
                        ])),
      const SizedBox(height: 24),
      if ((widget.report!['extracted_text'] ?? '')
          .toString()
          .trim()
          .isNotEmpty) ...[
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(widget.report!['input_type'] == 'photo'
              ? 'Text read from your photo'
              : 'Text read from your report'),
          subtitle: const Text(
              'Check names, numbers and units against the original.'),
          children: [
            Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SelectionArea(
                    child: Text(widget.report!['extracted_text'].toString(),
                        style: const TextStyle(fontSize: 17, height: 1.75))))
          ],
        ),
        const SizedBox(height: 20),
      ],
      if (widget.onAskQuestion != null) ...[
        Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: _surface(ReportQuestions(
                    key: ValueKey(
                        '${widget.language}:${widget.report!['parsed_data']}'),
                    language: widget.language,
                    onAsk: widget.onAskQuestion!,
                    onReview: widget.onReview ?? () {})))),
        const SizedBox(height: 24),
      ],
      _notice(
          'These explanations help you read the report. Discuss your results with your clinician.'),
    ]);
  }

  Widget _reading(String title, String text, {String? language}) => Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (text.isNotEmpty && widget.speechEnabled) ...[
              _audio(professionalReportText(text), language ?? widget.language),
              const SizedBox(height: 20)
            ],
            if (text.isEmpty)
              const Text('This explanation is not available for the report.')
            else
              SelectionArea(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final block in reportDocument(text))
                    _documentBlock(block)
                ],
              )),
          ]))));

  Widget _documentBlock(ReportBlock block) {
    const body = TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 16,
        height: 1.65,
        letterSpacing: 0,
        color: ReportPalette.ink);
    if (block.kind == ReportBlockKind.heading) {
      return Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Semantics(
              header: true,
              child: Text(block.text,
                  style: body.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      height: 1.35))));
    }
    if (block.kind == ReportBlockKind.field) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${block.label}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: block.text),
              ]),
              style: body));
    }
    if (block.kind == ReportBlockKind.notice) {
      return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              color: ReportPalette.ground,
              border: Border(
                  left: BorderSide(color: ReportPalette.burgundy, width: 3))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(block.label!,
                style: body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(block.text, style: body),
          ]));
    }
    if (block.kind == ReportBlockKind.bullet ||
        block.kind == ReportBlockKind.numbered) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 24,
                child: block.number != null
                    ? Text('${block.number}.',
                        style: body.copyWith(color: ReportPalette.muted))
                    : Padding(
                        padding: const EdgeInsets.only(top: 11),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                    color: ReportPalette.muted,
                                    shape: BoxShape.circle))))),
            Expanded(child: Text(block.text, style: body)),
          ]));
    }
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(block.text, style: body));
  }

  Widget _audio(String text, String language) {
    final active = widget.activeSpeech == text;
    final playing = active && widget.speaking;
    final paused = active && widget.paused;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: ReportPalette.sageLight,
            borderRadius: BorderRadius.circular(12)),
        child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              IconButton.filled(
                  tooltip: paused ? 'Resume narration' : 'Play narration',
                  onPressed: _busy || playing || widget.audioPreparing
                      ? null
                      : paused
                          ? widget.onResume
                          : () => widget.onSpeak(text, language),
                  icon: const Icon(LucideIcons.play, size: 20)),
              IconButton(
                  tooltip: 'Pause narration',
                  onPressed: playing ? widget.onPause : null,
                  icon: const Icon(LucideIcons.pause, size: 20)),
              IconButton(
                  tooltip: 'Stop narration',
                  onPressed:
                      playing || paused || (active && widget.audioPreparing)
                          ? widget.onStop
                          : null,
                  icon: const Icon(LucideIcons.square, size: 18)),
              AnimatedSwitcher(
                  duration: _transition,
                  child: Text(
                      active && widget.audioPreparing
                          ? 'Preparing audio…'
                          : playing
                              ? 'Playing'
                              : paused
                                  ? 'Paused'
                                  : 'Listen to explanation',
                      key: ValueKey(playing
                          ? 'playing'
                          : paused
                              ? 'paused'
                              : 'idle'),
                      style: const TextStyle(
                          fontSize: 14, color: ReportPalette.sage))),
            ]));
  }

  Widget _labs(List<Map<String, dynamic>> labs) => Column(
          key: const ValueKey('lab-values'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _notice(
                'Review these extracted values, units and flags against your original report. Extraction can contain errors.'),
            const SizedBox(height: 20),
            if (labs.isEmpty)
              _surface(const Text(
                  'No structured lab values were returned. Review the explanation and your original report.'))
            else
              _surface(Column(children: [
                for (var i = 0; i < labs.length; i++) ...[
                  if (i > 0) const Divider(height: 32),
                  _labRow(labs[i]),
                ]
              ])),
          ]);

  Widget _labRow(Map<String, dynamic> row) {
    final flag = (row['status'] ?? 'Not provided').toString();
    final flagged = ['low', 'high', 'critical'].contains(flag.toLowerCase());
    final rawReference =
        (row['reference_range'] ?? row['normal_range'] ?? '').toString().trim();
    final reference = rawReference.isEmpty ? 'Not provided' : rawReference;
    final statusLabel = switch (row['status_source']) {
      'report' => 'Report flag: $flag',
      'reference_range' => 'Compared with report range: $flag',
      'user_review' => 'Flag entered during review: $flag',
      'reviewed_range' => 'Compared with corrected range: $flag',
      'unknown' => 'Flag unavailable',
      _ => 'Extracted status: $flag',
    };
    return LayoutBuilder(builder: (context, size) {
      final value =
          '${row['value'] ?? 'Not provided'} ${row['unit'] ?? ''}'.trim();
      final label =
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((row['test_name'] ?? row['name'] ?? 'Unnamed test').toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()])),
      ]);
      final detail =
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reference: $reference', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(flagged ? LucideIcons.circleAlert : LucideIcons.info,
              size: 17,
              color: flagged ? ReportPalette.burgundy : ReportPalette.sage),
          const SizedBox(width: 6),
          Flexible(
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 16,
                      color: flagged
                          ? ReportPalette.burgundy
                          : ReportPalette.sage)))
        ]),
      ]);
      return size.maxWidth >= 620
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: label), Expanded(child: detail)])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 14), detail]);
    });
  }

  Widget _suggestions() {
    if (widget.report != null && !reportOutputAllowed(widget.report!)) {
      return _explanationPage();
    }
    if (widget.report == null) return _empty('Questions & next steps.');
    final translated = widget.language != 'English';
    final disease = translated
        ? (_text('disease_explanation_lang').isNotEmpty
            ? _text('disease_explanation_lang')
            : _text('disease_explanation_hi'))
        : _text('disease_explanation_en');
    final plan = translated
        ? (_text('solution_plan_lang').isNotEmpty
            ? _text('solution_plan_lang')
            : _text('solution_plan_hi'))
        : _text('solution_plan_en');
    final suggestions =
        widget.report![translated ? 'translated_suggestions' : 'suggestions'];
    final list = suggestions is List
        ? suggestions
            .map((s) => s.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList()
        : <String>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('Questions & next steps.',
          'Use these explanations to prepare for a conversation with your clinician.'),
      _reportActions(),
      const SizedBox(height: 24),
      if (widget.audioError != null) ...[
        _notice(widget.audioError!, error: true),
        const SizedBox(height: 20),
      ],
      if (widget.translating) ...[
        _notice('Translating to ${widget.language}…'),
        const SizedBox(height: 20)
      ],
      if (translated &&
          !widget.translating &&
          disease.isEmpty &&
          plan.isEmpty) ...[
        _notice(
            'Translation unavailable. Open Explanation to read the English summary.',
            error: true,
            retry: widget.onRetryTranslation),
        const SizedBox(height: 20)
      ],
      if (disease.isNotEmpty) ...[
        _reading('Condition & term education', disease),
        const SizedBox(height: 20)
      ],
      if (plan.isNotEmpty) ...[
        _reading('Generated follow-up information', plan),
        const SizedBox(height: 20)
      ],
      if (list.isNotEmpty) ...[
        _reading('Suggestions · ${widget.language}', list.join('\n\n')),
        const SizedBox(height: 20)
      ],
      _surface(
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Questions for your appointment',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        SizedBox(height: 16),
        Text('What do these results mean for me?'),
        SizedBox(height: 12),
        Text('Do any values need follow-up?'),
        SizedBox(height: 12),
        Text('When should I repeat these tests?'),
      ])),
      const SizedBox(height: 24),
      _notice(
          'Generated information is educational. Your clinician can advise you using your symptoms and medical history.'),
    ]);
  }

  Widget _settings() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading('Make it work for you.',
            'Choose how you want to read and listen to your explanations.'),
        _surface(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Explanation language',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          const Text(
              'Choose the language for your explanation. You can change it from any screen.'),
          const SizedBox(height: 20),
          _languageControl(),
          const Divider(height: 48),
          SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Read explanations aloud',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Show audio controls for summaries and suggestions.',
                  style: TextStyle(fontSize: 16, height: 1.6)),
              value: widget.speechEnabled,
              onChanged: widget.onSpeechEnabled),
          const SizedBox(height: 12),
          const Text(
              'Narration follows your selected language. Audio starts when you press Play.',
              style: TextStyle(color: ReportPalette.muted)),
        ])),
        const SizedBox(height: 28),
        if (widget.report != null && widget.onClearSavedReport != null) ...[
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Current report',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text(
                'The last report and its original document are kept in this browser so they can be reopened after a refresh.'),
            if (widget.storageError != null) Text(widget.storageError!),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _busy ? null : widget.onClearSavedReport,
                child: const Text('Clear saved report from this browser')),
          ])),
          const SizedBox(height: 20),
        ],
        _surface(const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Brand(),
              SizedBox(height: 20),
              Text(
                  'Medivaanii helps you read medical reports in simpler language and prepare questions for your healthcare professional.'),
              SizedBox(height: 16),
              Text(
                  'Educational information. Discuss your results with your clinician.',
                  style: TextStyle(color: ReportPalette.muted)),
            ])),
      ]);
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/arogya_pandit_logo.png',
            width: 40, height: 40, semanticLabel: 'Medivaanii logo'),
        const SizedBox(width: 10),
        const Flexible(
            child: Text('Medivaanii',
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6,
                    color: ReportPalette.ink))),
      ]);
}
