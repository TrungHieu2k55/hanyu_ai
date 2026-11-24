import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/presentation_helpers.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../application/csv_file_source_provider.dart';
import '../application/local_admin_providers.dart';
import '../application/vocabulary_import_controller.dart';
import '../domain/local_admin.dart';
import '../domain/local_csv_import.dart';
import 'admin_page.dart';
import 'import_report_view.dart';

class AdminImportScreen extends ConsumerStatefulWidget {
  const AdminImportScreen({super.key});
  @override
  ConsumerState<AdminImportScreen> createState() => _ImportState();
}

class _ImportState extends ConsumerState<AdminImportScreen> {
  late final model = VocabularyImportController(
    repository: ref.read(localAdminRepositoryProvider),
    fileSource: ref.read(csvFileSourceProvider),
    persist: _persist,
  );
  final input = TextEditingController();
  Future<LocalAdminSnapshot> _persist(
    CsvImportPreview preview,
    bool skip,
    String op,
  ) async {
    late LocalAdminSnapshot snapshot;
    await ref.read(localAdminControllerProvider.notifier).commit((r) async {
      snapshot = await r.commitCsv(preview, skipInvalid: skip, operationId: op);
      return snapshot;
    });
    return snapshot;
  }

  @override
  void dispose() {
    model.dispose();
    input.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    await model.pickFile();
    if (mounted && input.text != model.content) input.text = model.content;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => UnsavedChangesGuard(
      dirty: model.dirty,
      busy: model.busy,
      child: AdminPage(
        title: 'Nhập từ vựng CSV',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildPageTitle(
              'Nhập từ vựng',
              'Bước ${model.step.index + 1}/5 · Lưu thành nháp trong database Admin. Chưa tự chuyển sang người học.',
            ),
            const SizedBox(height: 24),
            if (model.error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  model.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (model.step == ImportStep.source) ...[
              OutlinedButton.icon(
                onPressed: model.busy ? null : pick,
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
                key: const ValueKey('csv-source'),
                controller: input,
                enabled: !model.busy,
                minLines: 5,
                maxLines: 12,
                maxLength: maxCsvBytes,
                decoration: InputDecoration(
                  counterText:
                      '${utf8.encode(model.content).length}/$maxCsvBytes byte',
                  counterStyle: const TextStyle(fontSize: 14),
                  helperStyle: const TextStyle(fontSize: 14),
                  labelText: 'Nội dung CSV',
                  alignLabelWithHint: true,
                  helperMaxLines: 5,
                  helperText: 'UTF-8 · tối đa 512 KiB và 1.000 bản ghi · hỗ trợ ô có dấu phẩy, nháy và xuống dòng.',
                ),
                onChanged: model.updateContent,
              ),
              TextButton(
                onPressed: model.busy
                    ? null
                    : () {
                        model.updateContent(VocabularyImportController.sample);
                        input.text = model.content;
                      },
                child: const Text('Điền CSV ví dụ'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: model.busy ? null : model.parse,
                child: const Text('Đọc CSV'),
              ),
            ],
            if (model.step == ImportStep.mapping) ...[
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('csv-column-$i'),
                    initialValue: model.mapping[i],
                    isExpanded: true,
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
                    onChanged: model.busy
                        ? null
                        : (v) => model.setColumn(i, v!),
                  ),
                ),
              FilledButton(
                onPressed: model.busy ? null : model.validate,
                child: Text(
                  model.validating ? 'Đang kiểm tra…' : 'Kiểm tra dữ liệu',
                ),
              ),
            ],
            if (model.step == ImportStep.validation) ...[
              ImportReportView(report: model.report!),
              if (model.report!.issues.isNotEmpty &&
                  model.report!.drafts.isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: model.skipInvalid,
                  onChanged: model.busy
                      ? null
                      : (v) => model.setSkipInvalid(v ?? false),
                  title: const Text('Chỉ nhập dòng hợp lệ, bỏ qua dòng lỗi'),
                  subtitle: const Text(
                    'Mặc định không bỏ lỗi; bạn có thể quay lại sửa CSV.',
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: !model.busy && model.canConfirm ? model.next : null,
                child: const Text('Xem xác nhận nhập'),
              ),
            ],
            if (model.step == ImportStep.confirmation) ...[
              Text(
                'Sẽ lưu ${model.report!.drafts.length} từ nháp và bỏ qua ${model.skipInvalid ? model.report!.rejectedRecords : 0} bản ghi lỗi.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'Mỗi từ mới chưa được duyệt, chưa gán cấp HSK hoặc nguồn/quyền sử dụng. Không ghi đè từ đã có. Hãy đợi thông báo lưu thành công trước khi rời trang.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: model.busy ? null : model.complete,
                child: Text(
                  model.committing ? 'Đang lưu…' : 'Xác nhận nhập vào Admin',
                ),
              ),
            ],
            if (model.step == ImportStep.result) ...[
              CsvImportResultView(result: model.result!),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Về thư viện học liệu'),
              ),
            ],
            if (model.preview != null && !model.committed) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: model.busy ? null : model.validate,
                child: const Text('Kiểm tra lại với dữ liệu mới'),
              ),
            ],
            if (model.step != ImportStep.source &&
                model.step != ImportStep.result)
              TextButton(
                onPressed: model.busy ? null : model.back,
                child: const Text('Bước trước'),
              ),
          ],
        ),
      ),
    ),
  );
}

class CsvImportResultView extends StatelessWidget {
  const CsvImportResultView({required this.result, super.key});
  final CsvImportResult result;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          'Đã lưu ${result.acceptedCount} từ nháp vào Admin.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Tổng ${result.totalRows} bản ghi · bỏ qua ${result.skippedRows} bản ghi lỗi.',
      ),
      Text(
        'Thời điểm (giờ thiết bị): ${result.importedAt.toLocal().toString().substring(0, 16)}',
      ),
      Text(
        'Cột Hán tự / Pinyin / nghĩa Việt: ${result.mapping.map((v) => v + 1).join(' / ')}',
      ),
      const SizedBox(height: 16),
      const Text(
        'Đây là kết quả của lần nhập đã lưu. Nội dung vẫn chưa được kiểm duyệt; có thể đã được sửa hoặc xóa sau đó. Kiểm tra nguồn, Pinyin, nghĩa và quyền sử dụng trước khi khai báo duyệt/công bố.',
      ),
    ],
  );
}

class AdminCsvHistoryScreen extends ConsumerStatefulWidget {
  const AdminCsvHistoryScreen({super.key});
  @override
  ConsumerState<AdminCsvHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<AdminCsvHistoryScreen> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final imports = ref
        .watch(localAdminControllerProvider)
        .requireValue
        .imports;
    final last = imports.isEmpty ? 0 : (imports.length - 1) ~/ 25,
        current = page > last ? last : page;
    return AdminPage(
      title: 'Lịch sử nhập CSV',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Các lần nhập đã lưu',
            'Kết quả giữ qua mở lại ứng dụng và backup Admin. Không tính các lần xem trước hoặc hủy.',
          ),
          const SizedBox(height: 24),
          if (imports.isEmpty) const Text('Chưa có lần nhập CSV nào đã lưu.'),
          for (final result in imports.skip(current * 25).take(25))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Đã nhập ${result.acceptedCount} từ nháp'),
              subtitle: Text(
                '${result.importedAt.toLocal().toString().substring(0, 16)} · bỏ qua ${result.skippedRows} dòng lỗi',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AdminPage(
                    title: 'Kết quả nhập CSV',
                    child: CsvImportResultView(result: result),
                  ),
                ),
              ),
            ),
          if (imports.length > 25)
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Trang ${current + 1}/${last + 1}'),
                OutlinedButton(
                  onPressed: current == 0
                      ? null
                      : () => setState(() => page = current - 1),
                  child: const Text('Trang trước'),
                ),
                OutlinedButton(
                  onPressed: current == last
                      ? null
                      : () => setState(() => page = current + 1),
                  child: const Text('Trang sau'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
