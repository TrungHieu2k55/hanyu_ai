import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';
import 'package:doanchuyennganh2/shared/widgets/unsaved_changes_guard.dart';

class PersonalWordEditor extends StatefulWidget {
  const PersonalWordEditor({
    super.key,
    required this.word,
    required this.nextId,
    this.initialHanzi = '',
    this.existingWords = const [],
  });
  final VocabularyItem? word;
  final String initialHanzi;
  final List<VocabularyItem> existingWords;
  final String Function() nextId;
  @override
  State<PersonalWordEditor> createState() => _PersonalWordEditorState();
}

class _PersonalWordEditorState extends State<PersonalWordEditor> {
  late final initial = [
    widget.word?.hanzi ?? widget.initialHanzi,
    widget.word?.pinyin ?? '',
    widget.word?.vietnamese ?? '',
    widget.word?.exampleHanzi ?? '',
    widget.word?.exampleVietnamese ?? '',
  ];
  late final fields = initial
      .map((text) => TextEditingController(text: text))
      .toList();
  final form = GlobalKey<FormState>();
  bool finishing = false;
  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty:
        !finishing &&
        List.generate(
          fields.length,
          (i) => fields[i].text != initial[i],
        ).contains(true),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nhập thủ công, chưa dùng AI để dịch hoặc kiểm tra. Dữ liệu chỉ giữ trong lần mở app này.',
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: fields[i],
                onChanged: (_) => setState(() {}),
                maxLength: i == 0 ? 30 : 300,
                decoration: InputDecoration(
                  labelText: [
                    'Hán tự riêng',
                    'Pinyin tự nhập',
                    'Nghĩa Việt riêng',
                    'Ví dụ Hán tự (tùy chọn)',
                    'Nghĩa ví dụ (tùy chọn)',
                  ][i],
                ),
                validator: (value) {
                  if (i < 3 && (value?.trim().isEmpty ?? true)) {
                    return 'Không được để trống.';
                  }
                  if (i == 0 &&
                      !RegExp(r'[\u3400-\u9fff]').hasMatch(value ?? '')) {
                    return 'Cần có ít nhất một chữ Hán.';
                  }
                  if (i == 1 &&
                      widget.existingWords.any(
                        (word) =>
                            word.id != widget.word?.id &&
                            word.hanzi.trim() == fields[0].text.trim() &&
                            word.pinyin.trim().toLowerCase() ==
                                fields[1].text.trim().toLowerCase(),
                      )) {
                    return 'Từ riêng với Hán tự và Pinyin này đã có. Hãy sửa từ hiện có.';
                  }
                  return null;
                },
              ),
            ),
          FilledButton(
            onPressed: () {
              if (finishing || !form.currentState!.validate()) return;
              final result = VocabularyItem(
                id: widget.word?.id ?? widget.nextId(),
                level: null,
                personal: true,
                hanzi: fields[0].text.trim(),
                pinyin: fields[1].text.trim(),
                vietnamese: fields[2].text.trim(),
                exampleHanzi: fields[3].text.trim(),
                exampleVietnamese: fields[4].text.trim(),
              );
              setState(() => finishing = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.pop(context, result);
              });
            },
            child: const Text('Giữ từ cá nhân mẫu'),
          ),
          TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Hủy chỉnh sửa'),
          ),
        ],
      ),
    ),
  );
}
