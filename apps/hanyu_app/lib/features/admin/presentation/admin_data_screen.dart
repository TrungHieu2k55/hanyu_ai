import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_transfer_provider.dart';
import '../../../core/files/local_file_transfer.dart';
import '../../../core/local/local_models.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../application/local_admin_providers.dart';
import '../data/admin_backup.dart';
import 'admin_page.dart';

class AdminDataScreen extends ConsumerStatefulWidget {
  const AdminDataScreen({super.key});
  @override
  ConsumerState<AdminDataScreen> createState() => _DataState();
}

class _DataState extends ConsumerState<AdminDataScreen> {
  late final label = TextEditingController(
    text: ref.read(localAdminControllerProvider).requireValue.identity.label,
  );
  late String saved = label.text;
  bool busy = false;
  String? message;
  AdminBackup? pending;
  bool get dirty => label.text != saved;
  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final file = await ref
          .read(localFileTransferProvider)
          .pick(LocalJsonKind.adminBackup);
      if (file == null) return;
      final preview = ref
          .read(localAdminRepositoryProvider)
          .prepareBackupRestore(file);
      if (mounted) {
        setState(() {
          pending = preview;
          message = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is LocalDataException
              ? e.message
              : 'Chưa đọc được backup Admin.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localAdminControllerProvider).requireValue;
    return UnsavedChangesGuard(
      dirty: dirty,
      busy: busy,
      child: AdminPage(
        title: 'Nguồn và backup Admin',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildPageTitle(
              'Danh tính nguồn local',
              'Mã nguồn được tạo một lần và giữ qua backup. Tên hiển thị không xác minh danh tính hoặc người duyệt.',
            ),
            const SizedBox(height: 24),
            SelectableText('Mã nguồn: ${data.identity.publisherId}'),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('admin-publisher-label'),
              controller: label,
              enabled: !busy,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Tên nguồn xuất'),
              onChanged: (_) => setState(() => message = null),
            ),
            AsyncCommitButton(
              label: 'Lưu tên nguồn',
              enabled: !busy && dirty,
              intentKey: '${data.revision}:${label.text}',
              onBusyChanged: (v) => setState(() => busy = v),
              onCommit: (op) async {
                await ref
                    .read(localAdminControllerProvider.notifier)
                    .commit(
                      (r) => r.saveIdentityLabel(
                        label.text,
                        revision: data.revision,
                        operationId: op,
                      ),
                    );
                if (mounted) {
                  setState(() {
                    label.text = ref
                        .read(localAdminControllerProvider)
                        .requireValue
                        .identity
                        .label;
                    saved = label.text;
                    message = 'Đã lưu tên nguồn local.';
                  });
                }
              },
            ),
            TextButton(
              onPressed: busy || !dirty
                  ? null
                  : () => setState(() => label.text = saved),
              child: const Text('Hủy đổi tên'),
            ),
            const Divider(height: 40),
            buildPageTitle(
              'Backup Admin',
              'File riêng gồm danh tính nguồn, phiên bản học liệu, khai báo duyệt, inbox và snapshot xuất. Không dùng làm backup cá nhân của learner.',
            ),
            const SizedBox(height: 16),
            AsyncCommitButton(
              label: 'Xuất backup Admin',
              enabled: !busy && !dirty,
              intentKey: 'backup:${data.revision}',
              onBusyChanged: (v) => setState(() => busy = v),
              onCommit: (op) async {
                final file = await ref
                    .read(localAdminRepositoryProvider)
                    .exportBackup();
                final result = await ref
                    .read(localFileTransferProvider)
                    .save(file);
                if (mounted) {
                  setState(
                    () => message = switch (result) {
                      FileHandoff.handedOff => 'Đã bàn giao backup cho hệ thống. Hãy kiểm tra nơi lưu file.',
                      FileHandoff.canceled => 'Đã hủy xuất backup.',
                      FileHandoff.unavailable => 'Hệ thống chưa xác nhận bàn giao backup; bạn có thể thử lại.',
                    },
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy || dirty ? null : pick,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Chọn backup Admin để xem trước'),
            ),
            if (dirty)
              const Text(
                'Lưu hoặc hủy đổi tên trước khi xuất/khôi phục backup.',
              ),
            if (pending case final preview?) ...[
              const SizedBox(height: 24),
              Text(
                'Nguồn trong backup: ${preview.identity.label.isEmpty ? 'Chưa đặt tên' : preview.identity.label}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SelectableText('Mã nguồn: ${preview.identity.publisherId}'),
              Text(
                '${preview.content.length} phiên bản học liệu · ${preview.inbox.length} snapshot báo lỗi · ${preview.exports.length} snapshot xuất',
              ),
              const SizedBox(height: 12),
              const Text(
                'Khôi phục sẽ thay toàn bộ dữ liệu Admin hiện tại, gồm mã nguồn. Dữ liệu learner ở database riêng không bị thay. Hãy xuất backup hiện tại trước nếu cần giữ.',
              ),
              AsyncCommitButton(
                label: 'Khôi phục backup này',
                enabled: !busy && !dirty,
                intentKey: 'restore:${preview.checksum}',
                onBusyChanged: (v) => setState(() => busy = v),
                onCommit: (op) async {
                  final accepted = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Thay dữ liệu Admin bằng backup?'),
                      content: const Text(
                        'Học liệu, lịch sử, inbox và mã nguồn Admin hiện tại sẽ được thay bằng nội dung đã xem trước.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Thay dữ liệu Admin'),
                        ),
                      ],
                    ),
                  );
                  if (accepted != true) return;
                  await ref
                      .read(localAdminControllerProvider.notifier)
                      .commit(
                        (r) => r.restoreBackup(
                          preview,
                          revision: data.revision,
                          operationId: op,
                        ),
                      );
                  if (mounted) {
                    setState(() {
                      label.text = ref
                          .read(localAdminControllerProvider)
                          .requireValue
                          .identity
                          .label;
                      saved = label.text;
                      pending = null;
                      message = 'Đã khôi phục dữ liệu Admin trên thiết bị.';
                    });
                  }
                },
              ),
              TextButton(
                onPressed: busy ? null : () => setState(() => pending = null),
                child: const Text('Hủy xem trước backup'),
              ),
            ],
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(localAdminControllerProvider.notifier)
                            .reload();
                        if (mounted) {
                          setState(
                            () => message =
                                'Đã tải trạng thái mới; tên đang sửa vẫn giữ.',
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => message = 'Chưa tải lại được. Nội dung đang soạn vẫn giữ.',
                          );
                        }
                      }
                    },
              child: const Text('Tải trạng thái, giữ tên đang sửa'),
            ),
            if (message != null)
              Semantics(liveRegion: true, child: Text(message!)),
          ],
        ),
      ),
    );
  }
}
