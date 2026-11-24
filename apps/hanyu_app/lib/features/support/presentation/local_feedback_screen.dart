import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/local/local_drafts.dart';
import '../../../app/local/local_providers.dart';
import '../../../core/files/canonical_json.dart';
import '../../../core/files/file_transfer_provider.dart';
import '../../../core/files/local_file_transfer.dart';
import '../../../core/local/local_models.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../domain/local_feedback.dart';

class LocalFeedbackListScreen extends ConsumerStatefulWidget {
  const LocalFeedbackListScreen({required this.data, super.key});
  final LocalSnapshot data;
  @override
  ConsumerState<LocalFeedbackListScreen> createState() => _FeedbackListState();
}

class _FeedbackListState extends ConsumerState<LocalFeedbackListScreen> {
  int page = 0;
  bool busy = false;
  String? message;
  FeedbackReceipt? pending;
  Future<void> pickResult() async {
    setState(() => busy = true);
    try {
      final file = await ref
          .read(localFileTransferProvider)
          .pick(LocalJsonKind.feedback);
      if (file == null) return;
      final receipt = await ref
          .read(localRepositoryProvider)
          .previewFeedbackReceipt(file);
      if (mounted) {
        setState(() {
          pending = receipt;
          message = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is LocalDataException
              ? e.message
              : 'Chưa mở được tệp. Hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Báo lỗi của bạn',
        'Lưu trên thiết bị, xuất file để tự chuyển cho người quản lý.',
      ),
      const SizedBox(height: 16),
      const Text(
        'Không có gửi tự động. Báo lỗi chưa nằm trong backup chung ở đợt này; hãy xuất riêng bản hoàn chỉnh cần giữ.',
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: busy ? null : () => context.push('/feedback/new'),
        icon: const Icon(Icons.add),
        label: const Text('Tạo báo lỗi'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: busy ? null : pickResult,
        icon: const Icon(Icons.file_open_outlined),
        label: const Text('Chọn tệp kết quả xử lý'),
      ),
      if (pending case final receipt?) ...[
        const SizedBox(height: 16),
        Text(
          'Báo lỗi: ${widget.data.feedback.where((r) => r.id == receipt.reportId && r.revision == receipt.reportRevision).firstOrNull?.body ?? 'Báo lỗi không còn trên thiết bị'}',
        ),
        FeedbackReceiptSummary(receipt: receipt),
        AsyncCommitButton(
          label: 'Nhập kết quả này',
          enabled: !busy,
          intentKey: canonicalJson(receipt.toJson()),
          onBusyChanged: (v) => setState(() => busy = v),
          onCommit: (op) async {
            await ref
                .read(localControllerProvider.notifier)
                .commit(
                  (r) => r.importFeedbackReceipt(
                    receipt,
                    revision: widget.data.revision,
                    operationId: op,
                  ),
                );
            if (mounted) {
              setState(() {
                pending = null;
                message = 'Đã nhập kết quả trên thiết bị. Học liệu không tự thay đổi.';
              });
            }
          },
        ),
        TextButton(
          onPressed: busy ? null : () => setState(() => pending = null),
          child: const Text('Hủy nhập kết quả'),
        ),
      ],
      if (message != null) Semantics(liveRegion: true, child: Text(message!)),
      const SizedBox(height: 24),
      if (widget.data.feedback.isEmpty)
        const Text('Chưa có báo lỗi nào trên thiết bị.'),
      for (final report in widget.data.feedback.skip(page * 25).take(25))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            report.body.isEmpty ? 'Báo lỗi chưa có mô tả' : report.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'v${report.revision} · ${feedbackStateLabel(report.state)}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: busy
              ? null
              : () => context.push('/feedback/${report.id}/${report.revision}'),
        ),
      if (widget.data.feedback.length > 25)
        Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Trang ${page + 1}/${(widget.data.feedback.length + 24) ~/ 25}',
            ),
            OutlinedButton(
              onPressed: busy || page == 0
                  ? null
                  : () => setState(() => page--),
              child: const Text('Trang trước'),
            ),
            OutlinedButton(
              onPressed: busy || (page + 1) * 25 >= widget.data.feedback.length
                  ? null
                  : () => setState(() => page++),
              child: const Text('Trang sau'),
            ),
          ],
        ),
    ],
  );
}

class LocalFeedbackScreen extends ConsumerStatefulWidget {
  const LocalFeedbackScreen({
    required this.data,
    this.report,
    this.source,
    super.key,
  });
  final LocalSnapshot data;
  final FeedbackReport? report;
  final FeedbackContext? source;
  @override
  ConsumerState<LocalFeedbackScreen> createState() => _FeedbackEditorState();
}

class _FeedbackEditorState extends ConsumerState<LocalFeedbackScreen> {
  late final drafts = ref.read(localDraftsProvider);
  late final id = widget.report?.id ?? const Uuid().v4();
  late final body = TextEditingController(text: widget.report?.body ?? '');
  late FeedbackContext? source = widget.report?.context ?? widget.source;
  late int revision = widget.data.revision;
  late String saved = intent;
  bool busy = false;
  String? message;
  FeedbackReport? pendingExport;
  String get intent => jsonEncode([body.text, source?.values]);
  bool get editable =>
      widget.report == null ||
      !widget.data.feedback.any(
        (r) => r.id == id && r.revision > widget.report!.revision,
      );
  void saving(bool v) {
    if (!mounted) return;
    drafts.update(this, changed: saved != intent, saving: v);
    setState(() => busy = v);
  }

  @override
  void dispose() {
    drafts.clear(this);
    body.dispose();
    super.dispose();
  }

  Future<void> save(String op, {bool draft = false}) async {
    await ref
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.saveFeedback(
            id: id,
            reportRevision: widget.report?.revision ?? 0,
            body: body.text,
            context: source,
            draft: draft,
            revision: revision,
            operationId: op,
          ),
        );
    if (!mounted) return;
    final data = ref.read(localControllerProvider).requireValue;
    final versions = data.feedback.where((r) => r.id == id).toList()
      ..sort((a, b) => b.revision.compareTo(a.revision));
    final report = versions.first;
    setState(() {
      revision = data.revision;
      body.text = report.body;
      saved = intent;
      message = 'Đã lưu trên thiết bị, chưa gửi.';
    });
    drafts.clear(this);
    if (widget.report?.revision != report.revision) {
      context.go('/feedback/$id/${report.revision}');
    }
  }

  Future<void> markExported(String op, FeedbackReport report) async {
    await ref
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.markFeedbackExported(
            id,
            report.revision,
            report.checksum,
            revision: revision,
            operationId: op,
          ),
        );
    if (mounted) {
      setState(() {
        revision = ref.read(localControllerProvider).requireValue.revision;
        pendingExport = null;
        message = 'Đã bàn giao file cho hệ thống. Bạn cần tự chuyển file cho người quản lý.';
      });
    }
  }

  Future<void> export(String op, FeedbackReport report) async {
    await ref
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.prepareFeedbackExport(
            id,
            report.revision,
            revision: revision,
            operationId: '$op:prepare',
          ),
        );
    if (!mounted) return;
    setState(
      () => revision = ref.read(localControllerProvider).requireValue.revision,
    );
    final file = await ref
        .read(localRepositoryProvider)
        .feedbackExportFile(id, report.revision);
    final result = await ref.read(localFileTransferProvider).save(file);
    if (!mounted) return;
    if (result != FileHandoff.handedOff) {
      setState(
        () => message = result == FileHandoff.canceled
            ? 'Đã hủy xuất. Báo lỗi vẫn lưu trên thiết bị.'
            : 'Hệ thống chưa xác nhận bàn giao file. Bạn có thể xuất lại.',
      );
      return;
    }
    setState(() => pendingExport = report);
    await markExported('$op:mark', report);
  }

  @override
  Widget build(BuildContext context) {
    drafts.update(this, changed: saved != intent, saving: busy);
    final report = widget.report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          report == null
              ? 'Tạo báo lỗi'
              : 'Báo lỗi · phiên bản ${report.revision}',
          report == null
              ? 'Chỉ đính kèm ngữ cảnh học liệu bạn đang xem.'
              : feedbackStateLabel(report.state),
        ),
        const SizedBox(height: 16),
        const Text(
          'Không tự đính kèm ghi chú riêng, ảnh hoặc audio. Tên người xử lý trong tệp kết quả là khai báo, chưa xác minh danh tính.',
        ),
        if (!editable)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Đây là phiên bản cũ. Mở phiên bản mới nhất trong danh sách để sửa.',
            ),
          ),
        if (source != null) ...[
          const SizedBox(height: 16),
          Text(
            'Ngữ cảnh học liệu: ${source!.values['label'] ?? source!.values['contentId'] ?? ''}',
          ),
          Text('Phiên bản: ${source!.values['contentVersion'] ?? 'không có'}'),
          TextButton(
            onPressed: busy || !editable
                ? null
                : () => setState(() => source = null),
            child: const Text('Bỏ ngữ cảnh học liệu'),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('feedback-body'),
          controller: body,
          enabled: !busy && editable,
          maxLength: 2000,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(labelText: 'Mô tả vấn đề'),
          onChanged: (_) => setState(() => message = null),
        ),
        const SizedBox(height: 16),
        AsyncCommitButton(
          label: 'Lưu báo lỗi',
          compact:
              report != null &&
              report.state != FeedbackState.draft &&
              saved == intent,
          enabled: !busy && editable,
          intentKey: 'save:$revision:$intent',
          onBusyChanged: saving,
          onCommit: (op) => save(op),
        ),
        const SizedBox(height: 8),
        AsyncCommitButton(
          label: 'Lưu nháp',
          compact: true,
          enabled: !busy && editable,
          intentKey: 'draft:$revision:$intent',
          onBusyChanged: saving,
          onCommit: (op) => save(op, draft: true),
        ),
        if (report != null && report.state != FeedbackState.draft) ...[
          const SizedBox(height: 16),
          AsyncCommitButton(
            label: 'Xuất tệp báo lỗi',
            enabled: !busy && saved == intent && pendingExport == null,
            intentKey: 'export:${report.revision}:${report.checksum}',
            onBusyChanged: saving,
            onCommit: (op) => export(op, report),
          ),
        ],
        if (pendingExport case final exported?) ...[
          const SizedBox(height: 16),
          const Text(
            'File đã được bàn giao nhưng chưa ghi nhận được trạng thái. Nút dưới chỉ ghi nhận lại, không xuất thêm file.',
          ),
          AsyncCommitButton(
            label: 'Ghi nhận lại lần xuất',
            enabled: !busy,
            intentKey: 'mark:${exported.checksum}',
            onBusyChanged: saving,
            onCommit: (op) => markExported(op, exported),
          ),
        ],
        if (report?.outcome case final receipt?) ...[
          const SizedBox(height: 24),
          FeedbackReceiptSummary(receipt: receipt),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  saving(true);
                  try {
                    await ref.read(localControllerProvider.notifier).reload();
                    if (mounted) {
                      setState(() {
                        revision = ref
                            .read(localControllerProvider)
                            .requireValue
                            .revision;
                        message = 'Đã tải trạng thái mới; bản đang soạn vẫn giữ. Nếu báo lỗi đã có phiên bản mới hơn, hãy mở bản đó để sửa.';
                      });
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => message =
                            'Chưa tải được trạng thái. Bản đang soạn vẫn giữ.',
                      );
                    }
                  } finally {
                    saving(false);
                  }
                },
          child: const Text('Tải trạng thái, giữ bản soạn'),
        ),
        if (message != null) Semantics(liveRegion: true, child: Text(message!)),
      ],
    );
  }
}

class FeedbackReceiptSummary extends StatelessWidget {
  const FeedbackReceiptSummary({required this.receipt, super.key});
  final FeedbackReceipt receipt;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kết quả · phiên bản ${receipt.reportRevision}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(receipt.resolution),
        Text('Người xử lý khai báo: ${receipt.actorLabel}'),
        const Text('Nhập kết quả không tự sửa nội dung học liệu.'),
      ],
    ),
  );
}
