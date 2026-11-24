import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/local/local_models.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../application/local_admin_providers.dart';
import '../domain/content_payload.dart';
import '../domain/content_revision.dart';
import 'admin_page.dart';

class AdminEditor extends ConsumerStatefulWidget {
  const AdminEditor({required this.kind, this.record, super.key});
  final ContentKind kind;
  final ContentRevision? record;
  @override
  ConsumerState<AdminEditor> createState() => _AdminEditorState();
}

class _AdminEditorState extends ConsumerState<AdminEditor> {
  final form = GlobalKey<FormState>();
  late final id = widget.record?.itemId ?? const Uuid().v4();
  late int base = widget.record?.revision ?? 0;
  late int revision = ref
      .read(localAdminControllerProvider)
      .requireValue
      .revision;
  late final fields = _initial().map(
    (key, value) => MapEntry(key, TextEditingController(text: value)),
  );
  late int? level = switch (widget.record?.payload) {
    VocabularyContent(:final targetLevel) => targetLevel,
    QuestionContent(:final targetLevel) => targetLevel,
    _ => widget.kind == ContentKind.question ? 1 : null,
  };
  late String section = widget.record?.payload is QuestionContent
      ? (widget.record!.payload as QuestionContent).section
      : 'reading';
  late int answer = widget.record?.payload is QuestionContent
      ? (widget.record!.payload as QuestionContent).correctIndex
      : 0;
  late String scenario = widget.record?.payload is ScenarioContent
      ? (widget.record!.payload as ScenarioContent).key
      : 'tourism';
  late String saved = intent;
  bool busy = false;
  String? message;
  Map<String, String> _initial() {
    final payload = widget.record?.payload;
    return {
      if (widget.kind == ContentKind.vocabulary) ...{
        'hanzi': payload is VocabularyContent ? payload.hanzi : '',
        'pinyin': payload is VocabularyContent ? payload.pinyin : '',
        'vietnamese': payload is VocabularyContent ? payload.vietnamese : '',
        'exampleHanzi': payload is VocabularyContent
            ? payload.exampleHanzi
            : '',
        'exampleVietnamese': payload is VocabularyContent
            ? payload.exampleVietnamese
            : '',
      },
      if (widget.kind == ContentKind.question) ...{
        'slot': payload is QuestionContent ? '${payload.slot}' : '1',
        'prompt': payload is QuestionContent ? payload.prompt : '',
        for (var i = 0; i < 4; i++)
          'choice$i': payload is QuestionContent ? payload.choices[i] : '',
        'explanation': payload is QuestionContent ? payload.explanation : '',
      },
      if (widget.kind == ContentKind.scenario) ...{
        'role': payload is ScenarioContent ? payload.role : '',
        'partner': payload is ScenarioContent ? payload.partner : '',
        'goal': payload is ScenarioContent ? payload.goal : '',
        for (var i = 0; i < 3; i++)
          'opening$i': payload is ScenarioContent ? payload.opening[i] : '',
        for (var i = 0; i < 3; i++)
          'reply$i': payload is ScenarioContent ? payload.sampleReply[i] : '',
        'suggestion': payload is ScenarioContent ? payload.suggestion : '',
      },
      'source': widget.record?.source ?? '',
      'license': widget.record?.license ?? '',
    };
  }

  String get intent => jsonEncode([
    for (final c in fields.values) c.text,
    level,
    section,
    answer,
    scenario,
  ]);
  String text(String key) => fields[key]!.text;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  ContentPayload payload() => switch (widget.kind) {
    ContentKind.vocabulary => VocabularyContent(
      hanzi: text('hanzi'),
      pinyin: text('pinyin'),
      vietnamese: text('vietnamese'),
      targetLevel: level,
      exampleHanzi: text('exampleHanzi'),
      exampleVietnamese: text('exampleVietnamese'),
    ),
    ContentKind.question => QuestionContent(
      targetLevel: level!,
      section: section,
      slot: int.tryParse(text('slot')) ?? 0,
      prompt: text('prompt'),
      choices: [for (var i = 0; i < 4; i++) text('choice$i')],
      correctIndex: answer,
      explanation: text('explanation'),
    ),
    ContentKind.scenario => ScenarioContent(
      key: scenario,
      role: text('role'),
      partner: text('partner'),
      goal: text('goal'),
      opening: [for (var i = 0; i < 3; i++) text('opening$i')],
      sampleReply: [for (var i = 0; i < 3; i++) text('reply$i')],
      suggestion: text('suggestion'),
    ),
  };
  Widget input(
    String key,
    String label,
    int max, {
    bool optional = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('admin-$key'),
      controller: fields[key],
      enabled: !busy,
      maxLength: max,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 8,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() => message = null),
      validator: (v) => !optional && (v?.trim().isEmpty ?? true)
          ? 'Vui lòng nhập $label.'
          : null,
    ),
  );
  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty: saved != intent,
    busy: busy,
    child: AdminPage(
      title: 'Soạn ${contentKindLabel(widget.kind).toLowerCase()}',
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildPageTitle(
              base == 0 ? 'Học liệu mới' : 'Chỉnh sửa từ phiên bản $base',
              'Lưu tạo bản nháp mới. Không kế thừa khai báo duyệt; chưa tự thay học liệu của người học.',
            ),
            const SizedBox(height: 24),
            if (widget.kind != ContentKind.scenario) ...[
              DropdownButtonFormField<int>(
                initialValue: level ?? 0,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Cấp mục tiêu'),
                items: [
                  if (widget.kind == ContentKind.vocabulary)
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Chưa gán cấp'),
                    ),
                  for (final n in [1, 2, 3])
                    DropdownMenuItem(
                      value: n,
                      child: Text('HSK $n · mục tiêu'),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) => setState(() => level = v == 0 ? null : v),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.kind == ContentKind.vocabulary) ...[
              input('hanzi', 'Hán tự', 30),
              input('pinyin', 'Pinyin', 300),
              input('vietnamese', 'Nghĩa Việt', 300),
              input(
                'exampleHanzi',
                'Ví dụ Hán tự',
                1000,
                optional: true,
                lines: 2,
              ),
              input(
                'exampleVietnamese',
                'Nghĩa ví dụ',
                1000,
                optional: true,
                lines: 2,
              ),
            ],
            if (widget.kind == ContentKind.question) ...[
              DropdownButtonFormField<String>(
                initialValue: section,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Phần'),
                items: const [
                  DropdownMenuItem(value: 'reading', child: Text('Đọc')),
                  DropdownMenuItem(
                    value: 'listening',
                    child: Text('Nghe · chưa có audio'),
                  ),
                ],
                onChanged: busy ? null : (v) => setState(() => section = v!),
              ),
              const SizedBox(height: 16),
              input('slot', 'Vị trí cố định (1–10)', 2),
              input('prompt', 'Câu hỏi', 2000, lines: 2),
              for (var i = 0; i < 4; i++)
                input(
                  'choice$i',
                  'Lựa chọn ${String.fromCharCode(65 + i)}',
                  300,
                ),
              DropdownButtonFormField<int>(
                initialValue: answer,
                decoration: const InputDecoration(labelText: 'Đáp án đúng'),
                items: [
                  for (var i = 0; i < 4; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(String.fromCharCode(65 + i)),
                    ),
                ],
                onChanged: busy ? null : (v) => setState(() => answer = v!),
              ),
              const SizedBox(height: 16),
              input('explanation', 'Giải thích', 2000, lines: 2),
            ],
            if (widget.kind == ContentKind.scenario) ...[
              DropdownButtonFormField<String>(
                initialValue: scenario,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tình huống'),
                items: [
                  for (var i = 0; i < 4; i++)
                    DropdownMenuItem(
                      value: ScenarioContent.keys[i],
                      child: Text(ScenarioContent.labels[i]),
                    ),
                ],
                onChanged: busy ? null : (v) => setState(() => scenario = v!),
              ),
              const SizedBox(height: 16),
              input('role', 'Vai người học', 200),
              input('partner', 'Vai đối tác', 200),
              input('goal', 'Mục tiêu', 1000, lines: 2),
              for (var i = 0; i < 3; i++)
                input(
                  'opening$i',
                  'Lời mở đầu · ${['Hán tự', 'Pinyin', 'Việt'][i]}',
                  2000,
                  lines: 2,
                ),
              for (var i = 0; i < 3; i++)
                input(
                  'reply$i',
                  'Câu đáp mẫu · ${['Hán tự', 'Pinyin', 'Việt'][i]}',
                  2000,
                  lines: 2,
                ),
              input('suggestion', 'Gợi ý', 300, optional: true),
            ],
            const Divider(height: 32),
            const Text(
              'Nguồn và quyền sử dụng có thể để trống ở nháp; cần điền trước khi khai báo duyệt.',
            ),
            const SizedBox(height: 16),
            input('source', 'Nguồn học liệu', 2000, optional: true, lines: 2),
            input('license', 'Quyền sử dụng', 300, optional: true),
            AsyncCommitButton(
              label: 'Lưu phiên bản nháp',
              enabled: !busy,
              intentKey: '$revision:$base:$intent',
              onBusyChanged: (v) => setState(() => busy = v),
              onCommit: (op) async {
                if (!form.currentState!.validate()) {
                  throw const LocalDataException(
                    'Kiểm tra các trường còn thiếu.',
                  );
                }
                final value = payload();
                await ref
                    .read(localAdminControllerProvider.notifier)
                    .commit(
                      (r) => r.saveRevision(
                        id: id,
                        baseRevision: base,
                        payload: value,
                        source: text('source'),
                        license: text('license'),
                        revision: revision,
                        operationId: op,
                      ),
                    );
                if (!mounted) return;
                final data = ref
                    .read(localAdminControllerProvider)
                    .requireValue;
                final versions =
                    data.content.where((r) => r.itemId == id).toList()
                      ..sort((a, b) => b.revision.compareTo(a.revision));
                setState(() {
                  base = versions.first.revision;
                  revision = data.revision;
                  saved = intent;
                  message =
                      'Đã lưu phiên bản $base · ${contentStateLabel(versions.first.state)}.';
                });
              },
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(localAdminControllerProvider.notifier)
                            .reload();
                        if (mounted) {
                          setState(() {
                            revision = ref
                                .read(localAdminControllerProvider)
                                .requireValue
                                .revision;
                            message = 'Đã tải trạng thái mới; bản đang soạn vẫn giữ. Nếu nội dung có phiên bản mới, mở phiên bản đó trước khi sửa tiếp.';
                          });
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => message =
                                'Chưa tải được. Bản đang soạn vẫn giữ.',
                          );
                        }
                      }
                    },
              child: const Text('Tải trạng thái, giữ bản soạn'),
            ),
            if (message != null)
              Semantics(liveRegion: true, child: Text(message!)),
          ],
        ),
      ),
    ),
  );
}
