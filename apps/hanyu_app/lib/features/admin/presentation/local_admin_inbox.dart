import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/canonical_json.dart';
import '../../../core/files/file_transfer_provider.dart';
import '../../../core/files/local_file_transfer.dart';
import '../../../core/local/local_models.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../../support/domain/local_feedback.dart';
import '../../support/presentation/local_feedback_screen.dart'
    show FeedbackReceiptSummary;
import '../application/local_admin_providers.dart';
import '../domain/local_admin.dart';
import 'admin_workspace.dart';

class LocalAdminInboxScreen extends ConsumerStatefulWidget {
  const LocalAdminInboxScreen({super.key});
  @override
  ConsumerState<LocalAdminInboxScreen> createState() => _InboxState();
}

class _InboxState extends ConsumerState<LocalAdminInboxScreen> {
  int page = 0;
  bool busy = false;
  String? message;
  FeedbackReport? pending;
  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final file = await ref
          .read(localFileTransferProvider)
          .pick(LocalJsonKind.feedback);
      if (file == null) return;
      final report = FeedbackReport.fromFile(file);
      if (mounted) {
        setState(() {
          pending = report;
          message = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is LocalDataException
              ? e.message
              : 'Chưa đọc được tệp. Hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          BrandMark(),
          SizedBox(width: 12),
          Expanded(child: Text('Hanyu AI · Admin local')),
        ],
      ),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ref
                .watch(localAdminControllerProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Column(
                    children: [
                      const Text(
                        'Chưa mở được database Admin. Không thay bằng dữ liệu tạm.',
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(localAdminControllerProvider),
                        child: const Text('Thử mở lại'),
                      ),
                    ],
                  ),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildPageTitle(
                        'Inbox báo lỗi',
                        'Nhận file do người học chủ động chuyển. Dữ liệu nằm trong database Admin riêng.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Admin local chưa có xác thực máy chủ. Đóng báo lỗi không tự thông báo cho người học; cần xuất và chuyển file kết quả.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy ? null : pick,
                        icon: const Icon(Icons.file_open_outlined),
                        label: const Text('Chọn tệp báo lỗi'),
                      ),
                      if (pending case final report?) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Xem trước · phiên bản ${report.revision}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(report.body),
                        if (report.context != null)
                          Text(
                            'Học liệu: ${report.context!.values['label'] ?? report.context!.values['contentId'] ?? ''}',
                          ),
                        const Text(
                          'Nhập file chỉ lưu vào inbox này, chưa xác minh người gửi.',
                        ),
                        AsyncCommitButton(
                          label: 'Nhận báo lỗi này',
                          enabled: !busy,
                          intentKey: report.checksum,
                          onBusyChanged: (v) => setState(() => busy = v),
                          onCommit: (op) async {
                            await ref
                                .read(localAdminControllerProvider.notifier)
                                .commit(
                                  (r) => r.importFeedback(
                                    report,
                                    revision: data.revision,
                                    operationId: op,
                                  ),
                                );
                            if (mounted) {
                              setState(() {
                                pending = null;
                                message = 'Đã lưu vào inbox Admin. Bản trùng không tạo thêm.';
                              });
                            }
                          },
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => pending = null),
                          child: const Text('Hủy nhận file'),
                        ),
                      ],
                      if (message != null)
                        Semantics(liveRegion: true, child: Text(message!)),
                      const SizedBox(height: 24),
                      if (data.inbox.isEmpty)
                        const Text(
                          'Inbox chưa có báo lỗi. Chọn tệp để xem trước trước khi nhận.',
                        ),
                      for (final entry in data.inbox.skip(page * 25).take(25))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            entry.report.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'v${entry.report.revision} · ${inboxStatusLabel(entry.status)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: busy
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => LocalAdminInboxDetail(
                                      id: entry.report.id,
                                      reportRevision: entry.report.revision,
                                    ),
                                  ),
                                ),
                        ),
                      if (data.inbox.length > 25)
                        Wrap(
                          spacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Trang ${page + 1}/${(data.inbox.length + 24) ~/ 25}',
                            ),
                            OutlinedButton(
                              onPressed: busy || page == 0
                                  ? null
                                  : () => setState(() => page--),
                              child: const Text('Trang trước'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  busy || (page + 1) * 25 >= data.inbox.length
                                  ? null
                                  : () => setState(() => page++),
                              child: const Text('Trang sau'),
                            ),
                          ],
                        ),
                      const Divider(height: 40),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const AdminWorkspace(),
                                ),
                              ),
                        child: const Text('Quản lý học liệu'),
                      ),
                      const Text(
                        'Học liệu Admin chưa tự chuyển sang thiết bị người học.',
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                try {
                                  await ref
                                      .read(
                                        localAdminControllerProvider.notifier,
                                      )
                                      .reload();
                                } catch (_) {
                                  if (mounted) {
                                    setState(
                                      () => message = 'Chưa tải lại được. Dữ liệu đã lưu được giữ nguyên.',
                                    );
                                  }
                                }
                              },
                        child: const Text('Tải lại inbox'),
                      ),
                    ],
                  ),
                ),
          ),
        ),
      ),
    ),
  );
}

class LocalAdminInboxDetail extends ConsumerStatefulWidget {
  const LocalAdminInboxDetail({
    required this.id,
    required this.reportRevision,
    super.key,
  });
  final String id;
  final int reportRevision;
  @override
  ConsumerState<LocalAdminInboxDetail> createState() => _InboxDetailState();
}

class _InboxDetailState extends ConsumerState<LocalAdminInboxDetail> {
  final resolution = TextEditingController(), actor = TextEditingController();
  bool busy = false;
  String? message;
  bool get dirty => resolution.text.isNotEmpty || actor.text.isNotEmpty;
  @override
  void dispose() {
    resolution.dispose();
    actor.dispose();
    super.dispose();
  }

  Future<bool> mayLeave() async {
    if (busy) return false;
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Rời khi chưa lưu kết quả?'),
            content: const Text('Mô tả xử lý đang soạn sẽ không được lưu.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Ở lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Bỏ bản soạn và rời'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localAdminControllerProvider).asData?.value;
    final entry = data?.inbox
        .where(
          (i) =>
              i.report.id == widget.id &&
              i.report.revision == widget.reportRevision,
        )
        .firstOrNull;
    final closed = entry?.status == InboxStatus.closed;
    return PopScope(
      canPop: !busy && !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !await mayLeave() || !context.mounted) return;
        setState(() {
          resolution.clear();
          actor.clear();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.pop(context);
        });
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Xử lý báo lỗi')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: entry == null
                    ? const Text('Không tìm thấy báo lỗi.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Phiên bản ${entry.report.revision} · ${inboxStatusLabel(entry.status)}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(entry.report.body),
                          if (entry.report.context != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Học liệu: ${entry.report.context!.values['label'] ?? entry.report.context!.values['contentId'] ?? ''}',
                            ),
                            Text(
                              'Phiên bản học liệu: ${entry.report.context!.values['contentVersion'] ?? 'không có'}',
                            ),
                          ],
                          const SizedBox(height: 24),
                          if (!closed) ...[
                            if (entry.status == InboxStatus.open)
                              AsyncCommitButton(
                                label: 'Bắt đầu xử lý',
                                enabled: !busy,
                                intentKey:
                                    'triage:${widget.id}:${widget.reportRevision}',
                                onBusyChanged: (v) => setState(() => busy = v),
                                onCommit: (op) => ref
                                    .read(localAdminControllerProvider.notifier)
                                    .commit(
                                      (r) => r.updateInbox(
                                        widget.id,
                                        widget.reportRevision,
                                        InboxStatus.inProgress,
                                        revision: data!.revision,
                                        operationId: op,
                                      ),
                                    ),
                              ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: actor,
                              enabled: !busy,
                              maxLength: 80,
                              decoration: const InputDecoration(
                                labelText: 'Tên người xử lý (khai báo local)',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: resolution,
                              enabled: !busy,
                              maxLength: 2000,
                              minLines: 4,
                              maxLines: 10,
                              decoration: const InputDecoration(
                                labelText: 'Kết quả xử lý',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            AsyncCommitButton(
                              label: 'Lưu kết quả và đóng',
                              enabled: !busy,
                              intentKey: canonicalJson([
                                actor.text,
                                resolution.text,
                                data!.revision,
                              ]),
                              onBusyChanged: (v) => setState(() => busy = v),
                              onCommit: (op) async {
                                await ref
                                    .read(localAdminControllerProvider.notifier)
                                    .commit(
                                      (r) => r.updateInbox(
                                        widget.id,
                                        widget.reportRevision,
                                        InboxStatus.closed,
                                        resolution: resolution.text,
                                        actorLabel: actor.text,
                                        revision: data.revision,
                                        operationId: op,
                                      ),
                                    );
                                if (mounted) {
                                  setState(() {
                                    actor.clear();
                                    resolution.clear();
                                    message = 'Đã đóng trong inbox. Người học chưa tự động nhận kết quả.';
                                  });
                                }
                              },
                            ),
                          ],
                          if (entry.receipt case final receipt?) ...[
                            FeedbackReceiptSummary(receipt: receipt),
                            AsyncCommitButton(
                              label: 'Xuất tệp kết quả',
                              enabled: !busy,
                              intentKey: 'receipt:${receipt.reportChecksum}',
                              onBusyChanged: (v) => setState(() => busy = v),
                              onCommit: (op) async {
                                final file = await ref
                                    .read(localAdminRepositoryProvider)
                                    .exportFeedbackReceipt(
                                      widget.id,
                                      widget.reportRevision,
                                    );
                                final result = await ref
                                    .read(localFileTransferProvider)
                                    .save(file);
                                if (mounted) {
                                  setState(
                                    () => message = switch (result) {
                                      FileHandoff.handedOff => 'Đã bàn giao file cho hệ thống. Hãy tự chuyển file cho người học.',
                                      FileHandoff.canceled => 'Đã hủy xuất. Kết quả đã lưu vẫn giữ nguyên.',
                                      FileHandoff.unavailable => 'Hệ thống chưa xác nhận bàn giao. Bạn có thể xuất lại.',
                                    },
                                  );
                                }
                              },
                            ),
                          ],
                          TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    try {
                                      await ref
                                          .read(
                                            localAdminControllerProvider
                                                .notifier,
                                          )
                                          .reload();
                                    } catch (_) {
                                      if (mounted) {
                                        setState(
                                          () => message = 'Chưa tải lại được. Bản đang soạn vẫn giữ.',
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
          ),
        ),
      ),
    );
  }
}
