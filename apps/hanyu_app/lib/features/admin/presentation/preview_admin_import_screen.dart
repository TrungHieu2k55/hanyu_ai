import 'import_report_view.dart';

import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/admin/application/preview_vocabulary_import_controller.dart';
import 'package:doanchuyennganh2/features/admin/data/csv_file_source.dart';
import 'package:doanchuyennganh2/features/admin/domain/admin_record.dart';
import 'package:doanchuyennganh2/features/admin/data/vocabulary_csv_parser.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/unsaved_changes_guard.dart';

class PreviewAdminImportScreen extends StatefulWidget {
  const PreviewAdminImportScreen({
    required this.existing,
    this.fileSource = const LocalCsvFileSource(),
    super.key,
  });
  final Set<String> existing;
  final CsvFileSource fileSource;
  @override
  State<PreviewAdminImportScreen> createState() =>
      _PreviewAdminImportScreenState();
}

class _PreviewAdminImportScreenState extends State<PreviewAdminImportScreen> {
  late final model = PreviewVocabularyImportController(
    existing: widget.existing,
    fileSource: widget.fileSource,
  );
  late final input = TextEditingController(text: model.content);
  @override
  void dispose() {
    input.dispose();
    model.dispose();
    super.dispose();
  }

  Future<void> pickFile() async {
    await model.pickFile();
    if (mounted && input.text != model.content) input.text = model.content;
  }

  void finish() {
    final drafts = model.complete();
    if (drafts == null) return;
    final result = drafts
        .map(
          (d) => AdminRecord({
            'Hán tự': d.hanzi,
            'Pinyin': d.pinyin,
            'Nghĩa Việt': d.vietnamese,
            'Nguồn / giấy phép': '',
          }),
        )
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => UnsavedChangesGuard(
      dirty: model.dirty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Import từ vựng',
            'Bước ${model.step.index + 1} / 5 · Chọn tệp hoặc dán CSV. Dữ liệu chỉ thành bản nháp trong Admin mẫu, chưa gửi lên máy chủ.',
          ),
          const SizedBox(height: 20),
          if (model.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                model.error!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
          if (model.step == PreviewImportStep.source) ...[
            OutlinedButton.icon(
              onPressed: model.picking ? null : pickFile,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(model.picking ? 'Đang chọn tệp…' : 'Chọn tệp CSV'),
            ),
            if (model.fileName != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Tệp: ${model.fileName}'),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: input,
              onChanged: model.updateContent,
              minLines: 5,
              maxLines: 12,
              maxLength: VocabularyCsvParser.maxBytes,
              decoration: const InputDecoration(
                labelText: 'Nội dung CSV mẫu',
                helperText: 'UTF-8 · tối đa 512 KB/1000 bản ghi · hỗ trợ ô có dấu phẩy/dấu nháy.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: model.picking ? null : model.parse,
              child: const Text('Đọc CSV mẫu'),
            ),
          ] else if (model.step == PreviewImportStep.mapping) ...[
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: model.mapping[i],
                  decoration: InputDecoration(
                    labelText: ['Hán tự', 'Pinyin', 'Nghĩa Việt'][i],
                  ),
                  items: [
                    for (var j = 0; j < model.table!.headers.length; j++)
                      DropdownMenuItem(
                        value: j,
                        child: Text(
                          model.table!.headers[j],
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => model.setColumn(i, v!),
                ),
              ),
            FilledButton(
              onPressed: model.validate,
              child: const Text('Kiểm tra dữ liệu mẫu'),
            ),
          ] else if (model.step == PreviewImportStep.validation) ...[
            ImportReportView(report: model.report!),
            if (model.report!.issues.isNotEmpty &&
                model.report!.drafts.isNotEmpty)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: model.skipInvalid,
                onChanged: (v) => model.setSkipInvalid(v ?? false),
                title: const Text('Chỉ giữ dòng hợp lệ, bỏ qua dòng lỗi'),
                subtitle: const Text(
                  'Mặc định không bỏ qua lỗi. Có thể quay lại sửa CSV.',
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: model.canConfirm ? model.next : null,
              child: const Text('Xem xác nhận import'),
            ),
          ] else if (model.step == PreviewImportStep.confirmation) ...[
            Text(
              'Sẽ thêm ${model.report!.drafts.length} bản nháp và bỏ qua ${model.skipInvalid ? model.report!.rejectedRecords : 0} bản ghi lỗi. Không sửa dữ liệu từ điển học viên, không ghi lên database.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: model.next,
              child: const Text('Xác nhận import mẫu'),
            ),
          ] else ...[
            Text(
              'Sẵn sàng giữ ${model.report!.drafts.length} bản nháp mẫu. Cần kiểm duyệt ngôn ngữ và giấy phép trước khi công bố thật.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: model.committed ? null : finish,
              child: const Text('Về danh sách và giữ nháp'),
            ),
          ],
          if (model.step.index > 0 && model.step != PreviewImportStep.result)
            TextButton(onPressed: model.back, child: const Text('Bước trước')),
        ],
      ),
    ),
  );
}
