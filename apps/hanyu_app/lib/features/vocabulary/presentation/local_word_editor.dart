import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';
import 'package:doanchuyennganh2/shared/widgets/async_commit_button.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/app/local/local_drafts.dart';

class LocalWordEditor extends ConsumerStatefulWidget {
  const LocalWordEditor({required this.data, this.word, super.key});
  final LocalSnapshot data;
  final LocalWord? word;
  @override
  ConsumerState<LocalWordEditor> createState() => _LocalWordEditorState();
}

class _LocalWordEditorState extends ConsumerState<LocalWordEditor> {
  late final LocalDrafts drafts;
  @override
  void initState() {
    super.initState();
    drafts = ref.read(localDraftsProvider);
  }

  late final id = widget.word?.entry.id ?? 'personal:${const Uuid().v4()}';
  late int revision = widget.data.revision;
  late final initial = [
    widget.word?.entry.hanzi ?? '',
    widget.word?.entry.pinyin ?? '',
    widget.word?.entry.vietnamese ?? '',
    widget.word?.entry.exampleHanzi ?? '',
    widget.word?.entry.exampleVietnamese ?? '',
  ];
  late final fields = initial
      .map((v) => TextEditingController(text: v))
      .toList();
  final form = GlobalKey<FormState>();
  bool busy = false, finished = false;
  @override
  void dispose() {
    drafts.clear(this);
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    drafts.update(
      this,
      changed:
          !finished &&
          List.generate(
            fields.length,
            (i) => fields[i].text != initial[i],
          ).contains(true),
      saving: busy,
    );
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            widget.word == null ? 'Thêm từ riêng' : 'Sửa từ riêng',
            'Tự nhập Pinyin và nghĩa; lưu trên thiết bị, không thay học liệu chung.',
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: fields[i],
                enabled: !busy,
                maxLength: i == 0 ? 30 : 300,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: [
                    'Hán tự riêng',
                    'Pinyin tự nhập',
                    'Nghĩa Việt riêng',
                    'Ví dụ Hán tự (tùy chọn)',
                    'Nghĩa ví dụ (tùy chọn)',
                  ][i],
                ),
                validator: (v) => i < 3 && (v?.trim().isEmpty ?? true)
                    ? 'Không được để trống.'
                    : null,
              ),
            ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    try {
                      await ref.read(localControllerProvider.notifier).reload();
                      if (!context.mounted) return;
                      setState(
                        () => revision = ref
                            .read(localControllerProvider)
                            .requireValue
                            .revision,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã tải dữ liệu mới; bản nháp vẫn giữ. Kiểm tra lại trước khi lưu.',
                          ),
                        ),
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Chưa tải lại được. Bản nháp vẫn giữ.',
                            ),
                          ),
                        );
                      }
                    }
                  },
            child: const Text('Tải dữ liệu mới, giữ bản nháp'),
          ),
          AsyncCommitButton(
            label: 'Lưu từ trên thiết bị',
            intentKey: jsonEncode(fields.map((f) => f.text).toList()),
            onBusyChanged: (v) {
              if (mounted) setState(() => busy = v);
            },
            onCommit: (operationId) async {
              if (!form.currentState!.validate()) {
                throw const LocalDataException(
                  'Điền đủ thông tin trước khi lưu.',
                );
              }
              final word = VocabularyItem(
                id: id,
                level: null,
                personal: true,
                hanzi: fields[0].text,
                pinyin: fields[1].text,
                vietnamese: fields[2].text,
                exampleHanzi: fields[3].text,
                exampleVietnamese: fields[4].text,
              );
              await ref
                  .read(localControllerProvider.notifier)
                  .commit(
                    (r) => r.putWord(
                      word,
                      revision: revision,
                      operationId: operationId,
                    ),
                  );
              if (!context.mounted) return;
              setState(() => finished = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go('/words/${Uri.encodeComponent(id)}');
                }
              });
            },
          ),
        ],
      ),
    );
  }
}
