import 'package:flutter/material.dart';
import 'report_data.dart';
import 'app_content_utils.dart';
import 'review_strings.dart';
import 'app_strings.dart';

const _ink = Color(0xFF242C2B);
const _muted = Color(0xFF626A67);
const _border = Color(0xFFE5E0D8);
const _body =
    TextStyle(fontFamily: 'NotoSans', fontSize: 16, height: 1.6, color: _ink);

Future<Map<String, dynamic>?> editReportResult(
        BuildContext context, Map<String, dynamic> row, String? source,
        {String language = 'English'}) =>
    showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) =>
            _ResultEditor(row: row, source: source, language: language));

class ReportReviewPanel extends StatefulWidget {
  const ReportReviewPanel(
      {super.key,
      required this.report,
      required this.onConfirm,
      this.sourcePreview,
      this.onOpenSource,
      this.onReextract,
      this.busy = false,
      this.language = 'English',
      this.error});
  final Map<String, dynamic> report;
  final ValueChanged<List<Map<String, dynamic>>> onConfirm;
  final Widget? sourcePreview;
  final VoidCallback? onOpenSource, onReextract;
  final bool busy;
  final String language;
  final String? error;
  @override
  State<ReportReviewPanel> createState() => _ReportReviewPanelState();
}

class _ReportReviewPanelState extends State<ReportReviewPanel> {
  ReviewStrings get _s => ReviewStrings(widget.language);
  late final List<Map<String, dynamic>> _rows =
      reportLabValues(widget.report['parsed_data'])
          .map((row) => {
                ...row,
                for (final key in [
                  'test_name',
                  'value',
                  'unit',
                  'reference_range'
                ])
                  key: (row[key] ?? '').toString(),
                'flag_override': false
              })
          .toList();
  final _resultsScroll = ScrollController();
  final _edited = <int>{};
  int _selected = 0;
  bool _onlyUncertain = false;
  String _query = '';
  List get _sources => widget.report['source_evidence'] is List
      ? widget.report['source_evidence'] as List
      : const [];
  Map _source(int index) {
    final id = _rows[index]['measurement_id'];
    final matches = _sources
        .whereType<Map>()
        .where((source) => id != null && source['measurement_id'] == id);
    return matches.length == 1 ? matches.single : const {};
  }

  bool _uncertain(int index) => _rows[index]['acceptance_state'] != 'eligible';
  List<int> get _visible => List.generate(_rows.length, (i) => i)
      .where((i) =>
          (!_onlyUncertain || _uncertain(i)) &&
          _rows[i]['test_name']
              .toString()
              .toLowerCase()
              .contains(_query.toLowerCase()))
      .toList();
  static const _small = TextStyle(
      fontFamily: 'NotoSans', fontSize: 13, height: 1.5, color: _muted);
  static const _cell =
      TextStyle(fontFamily: 'NotoSans', fontSize: 14, height: 1.5, color: _ink);

  Future<void> _edit(int index) async {
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _ResultEditor(
            row: _rows[index],
            source: _source(index)['source_quote']?.toString(),
            language: widget.language));
    if (!mounted || result == null) return;
    setState(() {
      if (['test_name', 'value', 'unit', 'reference_range', 'status']
              .any((key) => result[key] != _rows[index][key]) ||
          result['flag_override'] == true) {
        _edited.add(index);
      }
      _rows[index] = result;
      _selected = index;
    });
  }

  Widget _card(Widget child) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: _border),
          borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: child);

  Widget _sourcePane() =>
      _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(children: [
              const Icon(Icons.description_outlined, size: 20, color: _muted),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_s.t('originalDocument'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600))),
              if (widget.onOpenSource != null)
                IconButton(
                    tooltip: _s.t('openOriginal'),
                    onPressed: widget.onOpenSource,
                    icon: const Icon(Icons.open_in_new, size: 18)),
            ])),
        const Divider(height: 1),
        if (widget.sourcePreview != null) widget.sourcePreview!,
        ExpansionTile(
            title: Text(_s.t('viewExtracted'), style: _cell),
            subtitle: widget.sourcePreview == null
                ? Text(_s.t('previewUnavailable'), style: _small)
                : null,
            initiallyExpanded: widget.sourcePreview == null,
            children: [
              SizedBox(
                  height: 240,
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                          (widget.report['extracted_text'] ??
                                  _s.t('sourceTextUnavailable'))
                              .toString(),
                          style: _cell)))
            ]),
      ]));

  Widget _flag(int index) {
    final status = (_rows[index]['status'] ?? 'unknown').toString();
    final edited = _edited.contains(index);
    final label = edited
        ? _s.t('edited')
        : switch (status) {
            'normal' => _s.t('status_normal'),
            'high' => _s.t('status_high'),
            'low' => _s.t('status_low'),
            'critical' => _s.t('status_critical'),
            'abnormal' => _s.t('status_abnormal'),
            _ => _uncertain(index) ? _s.t('check') : _s.t('noComparison'),
          };
    final color = edited
        ? _muted
        : status == 'normal'
            ? const Color(0xFF3F6050)
            : ['high', 'low', 'critical', 'abnormal'].contains(status)
                ? const Color(0xFFA32E35)
                : const Color(0xFF826326);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: _small.copyWith(color: color, fontWeight: FontWeight.w600)));
  }

  Widget _resultRow(int index, bool compact) {
    final row = _rows[index];
    final selected = _selected == index;
    final measurement =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_readableNumber(row['value'].toString()),
          style: _cell.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
      if (row['unit'].toString().isNotEmpty) Text(row['unit'], style: _small),
    ]);
    final range = row['reference_range'].toString().isEmpty
        ? _s.t('notShown')
        : row['reference_range'].toString();
    final unit = row['unit'].toString();
    final hasRangeUnit = unit.isNotEmpty && range.endsWith(unit);
    final rangeNumber = hasRangeUnit
        ? range.substring(0, range.length - unit.length).trim()
        : range;
    final reference =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_readableNumber(rangeNumber), style: _small),
      if (hasRangeUnit) Text(unit, style: _small),
    ]);
    final edit = IconButton(
        key: ValueKey('edit-result-$index'),
        tooltip: _s.t('editTest', {'test': row['test_name']}),
        onPressed: widget.busy ? null : () => _edit(index),
        icon: const Icon(Icons.edit_outlined, size: 18));
    return Semantics(
        selected: selected,
        button: true,
        label: _s.t('selectSource', {'test': row['test_name']}),
        child: InkWell(
            onTap: () => setState(() => _selected = index),
            child: Container(
                constraints: const BoxConstraints(minHeight: 70),
                decoration: BoxDecoration(
                    color: selected ? const Color(0xFFF0F4F1) : Colors.white,
                    border: Border(
                        left: BorderSide(
                            color: selected
                                ? const Color(0xFF4D6B5E)
                                : Colors.transparent,
                            width: 3))),
                padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Row(children: [
                              Expanded(
                                  child: Text(row['test_name'],
                                      style: _cell.copyWith(
                                          fontWeight: FontWeight.w600))),
                              _flag(index),
                              edit
                            ]),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: measurement),
                                  Expanded(
                                      flex: 2,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(_s.t('reference'),
                                                style: _small),
                                            reference
                                          ]))
                                ]),
                          ])
                    : Row(children: [
                        Expanded(
                            flex: 3,
                            child: Text(row['test_name'],
                                style: _cell.copyWith(
                                    fontWeight: FontWeight.w600))),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: measurement),
                        const SizedBox(width: 10),
                        Expanded(flex: 4, child: reference),
                        const SizedBox(width: 10),
                        SizedBox(
                            width: 76,
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: _flag(index))),
                        edit,
                      ]))));
  }

  String _readableNumber(String text) => text
      .replaceAllMapped(RegExp(r'(\d)[-–](?=\d)'), (match) => '${match[1]}–')
      .replaceAllMapped(
          RegExp(r'(?<![\d,.])\d{4,}(?![\d,.])'),
          (match) => match[0]!
              .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','));

  Widget _resultsPane() => _card(LayoutBuilder(builder: (context, size) {
        final compact = size.maxWidth < 440;
        final visible = _visible;
        final uncertain =
            List.generate(_rows.length, (i) => i).where(_uncertain).length;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(_s.t('extractedResults'),
                                  style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600))),
                          Text(_s.t('tests', {'count': _rows.length}),
                              style: _small)
                        ]),
                        const SizedBox(height: 4),
                        Text(_s.t('selectRow'), style: _small),
                        const SizedBox(height: 14),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          ChoiceChip(
                              label: Text(_s.t('allResults')),
                              selected: !_onlyUncertain,
                              onSelected: (_) =>
                                  setState(() => _onlyUncertain = false)),
                          ChoiceChip(
                              label: Text(
                                  _s.t('needsCheck', {'count': uncertain})),
                              selected: _onlyUncertain,
                              onSelected: (_) =>
                                  setState(() => _onlyUncertain = true)),
                        ]),
                        if (_rows.length > 8) ...[
                          const SizedBox(height: 12),
                          TextField(
                              style: _cell,
                              decoration: InputDecoration(
                                  hintText: _s.t('findTest'),
                                  prefixIcon:
                                      const Icon(Icons.search, size: 20),
                                  isDense: true,
                                  border: const OutlineInputBorder()),
                              onChanged: (value) =>
                                  setState(() => _query = value))
                        ],
                      ])),
              if (!compact)
                Container(
                    color: const Color(0xFFF7F6F3),
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    child: Row(children: [
                      Expanded(
                          flex: 3,
                          child: Text(_s.t('testHeader'), style: _small)),
                      const SizedBox(width: 10),
                      Expanded(
                          flex: 2,
                          child: Text(_s.t('resultHeader'), style: _small)),
                      const SizedBox(width: 10),
                      Expanded(
                          flex: 4,
                          child: Text(_s.t('referenceHeader'), style: _small)),
                      const SizedBox(width: 10),
                      SizedBox(
                          width: 76,
                          child: Text(_s.t('flagHeader'), style: _small)),
                      const SizedBox(width: 48)
                    ])),
              const Divider(height: 1),
              if (visible.isNotEmpty)
                ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 410),
                    child: Scrollbar(
                        controller: _resultsScroll,
                        child: ListView.separated(
                            controller: _resultsScroll,
                            shrinkWrap: true,
                            primary: false,
                            itemCount: visible.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) =>
                                _resultRow(visible[i], compact))))
              else
                Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        _rows.isEmpty
                            ? _s.t('noValues')
                            : _onlyUncertain
                                ? _s.t('noUncertain')
                                : _s.t('noSearchMatches'),
                        style: _cell)),
              if (_rows.isNotEmpty) ...[
                const Divider(height: 1),
                Container(
                    color: const Color(0xFFFAFAF8),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const Icon(Icons.format_quote,
                                size: 18, color: _muted),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    _s.t('sourceTest', {
                                      'test': _rows[_selected]['test_name']
                                    }),
                                    style: _small.copyWith(
                                        fontWeight: FontWeight.w600)))
                          ]),
                          const SizedBox(height: 8),
                          SelectableText(
                              (_source(_selected)['source_quote'] ??
                                      _s.t('missingSource'))
                                  .toString(),
                              style: _cell),
                          const SizedBox(height: 8),
                          Text(
                              _edited.contains(_selected)
                                  ? _s.t('correctionReady')
                                  : (_source(_selected)['status_description'] ==
                                          null
                                      ? _s.t('compareOriginal')
                                      : _s.resultDescription(_rows[_selected])),
                              style: _small),
                        ])),
              ],
            ]);
      }));

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(
            builder: (context, size) => size.maxWidth >= 900
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _sourcePane()),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: _resultsPane())
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        _resultsPane(),
                        const SizedBox(height: 20),
                        _sourcePane()
                      ])),
        const SizedBox(height: 20),
        if (widget.error != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(AppStrings(widget.language).error(widget.error!),
                  style: _body.copyWith(color: const Color(0xFFA32E35)))),
        _card(Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(builder: (context, size) {
              final note = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _edited.isEmpty
                            ? _s.t('ready')
                            : _s.t(
                                _edited.length == 1
                                    ? 'oneCorrection'
                                    : 'corrections',
                                {'count': _edited.length}),
                        style: _cell.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_s.t('confirmExtracted'), style: _small),
                  ]);
              final actions = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    if (widget.onReextract != null)
                      TextButton.icon(
                          onPressed: widget.busy ? null : widget.onReextract,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(_s.t('rereadSource'))),
                    FilledButton.icon(
                        onPressed: widget.busy ||
                                reportQualityState(widget.report) ==
                                    'legacy_unverified'
                            ? null
                            : () => widget.onConfirm(_rows
                                .map((row) => Map<String, dynamic>.from(row))
                                .toList()),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: Text(widget.busy
                            ? _s.t('updatingResults')
                            : _s.t('confirmContinue'))),
                  ]);
              return size.maxWidth >= 760
                  ? Row(children: [
                      Expanded(child: note),
                      const SizedBox(width: 20),
                      actions
                    ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [note, const SizedBox(height: 16), actions]);
            }))),
      ]);

  @override
  void dispose() {
    _resultsScroll.dispose();
    super.dispose();
  }
}

class _ResultEditor extends StatefulWidget {
  const _ResultEditor(
      {required this.row, this.source, this.language = 'English'});
  final Map<String, dynamic> row;
  final String? source;
  final String language;
  @override
  State<_ResultEditor> createState() => _ResultEditorState();
}

class _ResultEditorState extends State<_ResultEditor> {
  ReviewStrings get _s => ReviewStrings(widget.language);
  final _form = GlobalKey<FormState>();
  late final _draft = Map<String, dynamic>.from(widget.row);
  Widget _field(String key, String label,
          {bool required = false}) =>
      TextFormField(
          initialValue: _draft[key].toString(),
          style: const TextStyle(fontSize: 16, height: 1.4),
          maxLength: 256,
          decoration:
              InputDecoration(
                  labelText: label,
                  counterText: '',
                  border: const OutlineInputBorder()),
          validator: (value) => required && (value ?? '').trim().isEmpty
              ? _s.t('enterField', {'field': label})
              : null,
          onChanged: (value) => _draft[key] = value);
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_s.t('editTest', {'test': widget.row['test_name']}),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_s.t('copyExactly'),
                              style: const TextStyle(
                                  fontSize: 14, height: 1.5, color: _muted)),
                          if (widget.source != null) ...[
                            const SizedBox(height: 12),
                            Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F1),
                                    borderRadius: BorderRadius.circular(8)),
                                child: SelectableText(widget.source!,
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.5)))
                          ],
                          const SizedBox(height: 20),
                          _field('test_name', _s.t('testName'), required: true),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                                child: _field('value', _s.t('value'),
                                    required: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _field('unit', _s.t('unit')))
                          ]),
                          const SizedBox(height: 16),
                          _field('reference_range', _s.t('referenceRange')),
                          if ((widget.row['source_fields'] as Map? ?? {})
                              .values
                              .any((field) =>
                                  field is Map &&
                                  ['ocr', 'docling_ocr', 'groq_vision']
                                      .contains(field['method']))) ...[
                            const SizedBox(height: 16),
                            Text(_s.t('checkPhotoFields')),
                            for (final key in [
                              'test_name',
                              'value',
                              'unit',
                              'reference_range',
                              'flag'
                            ])
                              if ((key == 'flag'
                                          ? (widget.row['source_fields']
                                                  as Map? ??
                                              {})['flag']
                                          : _draft[key]) !=
                                      null &&
                                  (key == 'flag' ||
                                      (_draft[key] ?? '')
                                          .toString()
                                          .isNotEmpty))
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_s.checkedField(key)),
                                  value: (_draft['source_checked_fields']
                                              as List? ??
                                          [])
                                      .contains(key),
                                  onChanged: (checked) => setState(() {
                                    final fields = List<String>.from(
                                        _draft['source_checked_fields']
                                                as List? ??
                                            []);
                                    checked == true
                                        ? fields.add(key)
                                        : fields.remove(key);
                                    _draft['source_checked_fields'] =
                                        fields.toSet().toList();
                                  }),
                                ),
                          ],
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: const [
                                'normal',
                                'high',
                                'low',
                                'critical',
                                'abnormal',
                                'unknown'
                              ].contains(_draft['status'])
                                  ? _draft['status']
                                  : 'unknown',
                              decoration: InputDecoration(
                                  labelText: _s.t('reportFlag'),
                                  border: const OutlineInputBorder()),
                              items: [
                                DropdownMenuItem(
                                    value: 'unknown',
                                    child: Text(_s.t('notShownUncertain'))),
                                DropdownMenuItem(
                                    value: 'normal',
                                    child: Text(_s.t('status_normal'))),
                                DropdownMenuItem(
                                    value: 'high',
                                    child: Text(_s.t('status_high'))),
                                DropdownMenuItem(
                                    value: 'low',
                                    child: Text(_s.t('status_low'))),
                                DropdownMenuItem(
                                    value: 'abnormal',
                                    child: Text(_s.t('status_abnormal'))),
                                DropdownMenuItem(
                                    value: 'critical',
                                    child: Text(_s.t('status_critical')))
                              ],
                              onChanged: (value) {
                                _draft['status'] = value;
                                _draft['flag_override'] = true;
                              }),
                        ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_s.t('cancel'))),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _draft);
                }
              },
              child: Text(_s.t('saveCorrection')))
        ],
      );
}

class ReportQuestions extends StatefulWidget {
  const ReportQuestions(
      {super.key,
      required this.onAsk,
      required this.onReview,
      this.language = 'English'});
  final Future<Map<String, dynamic>> Function(String) onAsk;
  final VoidCallback onReview;
  final String language;
  @override
  State<ReportQuestions> createState() => _ReportQuestionsState();
}

class _ReportQuestionsState extends State<ReportQuestions> {
  ReviewStrings get _s => ReviewStrings(widget.language);
  final _question = TextEditingController();
  Map<String, dynamic>? _reply;
  String? _asked;
  bool _failed = false;
  bool _busy = false;
  Future<void> _ask([String? prompt]) async {
    final question = (prompt ?? _question.text).trim();
    if (question.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _reply = null;
      _asked = question;
    });
    try {
      final reply = await widget.onAsk(question);
      if (mounted) setState(() => _reply = reply);
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_s.t('askAboutReport'),
            style: _body.copyWith(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_s.t('questionIntro'), style: _body),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final prompt in [_s.t('flaggedPrompt'), _s.t('summaryPrompt')])
            OutlinedButton(
                onPressed: _busy ? null : () => _ask(prompt),
                child: Text(prompt)),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: _question,
            maxLength: 1000,
            minLines: 1,
            maxLines: 3,
            style: _body,
            enabled: !_busy,
            decoration: InputDecoration(
                labelText: _s.t('yourQuestion'),
                hintText: _s.t('questionExample'),
                border: const OutlineInputBorder()),
            onSubmitted: (_) => _ask()),
        Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
                onPressed: _busy ? null : () => _ask(),
                child: Text(
                    _busy ? _s.t('checkingReport') : _s.t('askQuestion')))),
        if (_failed)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_s.t('answerUnavailable'), style: _body)),
        if (_reply != null)
          Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_asked!,
                        style: _body.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (_reply!['answer_language'] != null &&
                        ReviewStrings.languageCode(
                                _reply!['answer_language'].toString()) !=
                            ReviewStrings.languageCode(widget.language))
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_s.t('translationUnavailable'),
                              style: _body.copyWith(color: _muted))),
                    SelectableText(
                        professionalReportText(
                            (_reply!['answer'] ?? '').toString()),
                        style: _body),
                    for (final source in (_reply!['sources'] as List? ?? []))
                      Material(
                          type: MaterialType.transparency,
                          child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(_s.t('questionSource',
                                  {'test': source['test_name']})),
                              children: [
                                SelectableText(
                                    (source['source_quote'] ??
                                            _s.t('questionMissingSource'))
                                        .toString(),
                                    style: _body),
                                const SizedBox(height: 8),
                              ])),
                    TextButton(
                        onPressed: widget.onReview,
                        child: Text(_s.t('reviewOriginal'))),
                  ])),
      ]);
}
