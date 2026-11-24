import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/backup_files.dart';
import 'package:doanchuyennganh2/shared/widgets/async_commit_button.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

final backupFilesProvider = Provider<BackupFiles>(
  (ref) => const LocalBackupFiles(),
);

class LocalDataScreen extends ConsumerStatefulWidget {
  const LocalDataScreen({required this.revision, super.key});
  final int revision;
  @override
  ConsumerState<LocalDataScreen> createState() => _LocalDataScreenState();
}

class _LocalDataScreenState extends ConsumerState<LocalDataScreen> {
  String? message;
  bool exporting = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Dữ liệu trên thiết bị',
        'Web lưu theo trình duyệt và địa chỉ truy cập. Xóa dữ liệu trình duyệt có thể làm mất dữ liệu học.',
      ),
      const SizedBox(height: 24),
      const Text(
        'Backup ZIP v5 gồm tiến độ, gói học liệu, báo lỗi và kết quả, bản luyện viết, ảnh và audio đã lưu. File có dữ liệu riêng của bạn. Trên điện thoại, chọn nơi lưu trong hộp chia sẻ hệ thống. Giới hạn tệp 60 MiB.',
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: exporting
            ? null
            : () async {
                setState(() {
                  exporting = true;
                  message = null;
                });
                try {
                  final json = await ref
                      .read(localRepositoryProvider)
                      .exportArchive();
                  final saved = await ref
                      .read(backupFilesProvider)
                      .saveArchive(json);
                  if (mounted) {
                    setState(
                      () => message = saved
                          ? 'Đã chuyển file backup cho trình duyệt/hệ thống lưu tệp. Hãy kiểm tra file tải về.'
                          : 'Đã hủy xuất backup.',
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => message = 'Chưa xuất được backup. Dữ liệu đang có không bị thay đổi.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => exporting = false);
                }
              },
        icon: const Icon(Icons.download_outlined),
        label: Text(exporting ? 'Đang chuẩn bị…' : 'Xuất backup ZIP'),
      ),
      const SizedBox(height: 16),
      AsyncCommitButton(
        label: 'Chọn backup để khôi phục',
        intentKey: 'restore:${widget.revision}',
        onCommit: (operationId) async {
          final json = await ref.read(backupFilesProvider).pickArchive();
          if (json == null || !context.mounted) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Thay dữ liệu hiện có bằng backup?'),
              content: const Text(
                'Dữ liệu học hiện tại sẽ được thay bằng file hợp lệ. Backup v1 cũ không có lịch sử ôn; v1/v2 không có bài đọc; JSON v1–v3 không có dữ liệu viết/ảnh/audio/phiên luyện nói. Backup trước v5 không có gói học liệu hoặc báo lỗi. Khôi phục file cũ sẽ thay thế cả dữ liệu không có trong file. Hãy xuất backup hiện tại trước. File lỗi không làm thay đổi dữ liệu.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('Xác nhận khôi phục'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await ref
              .read(localControllerProvider.notifier)
              .commit(
                (r) => r.restoreArchive(
                  json,
                  revision: widget.revision,
                  operationId: operationId,
                ),
              );
          if (mounted) {
            setState(() => message = 'Đã khôi phục backup trên thiết bị.');
          }
        },
      ),
      if (message != null) ...[
        const SizedBox(height: 20),
        Semantics(liveRegion: true, child: Text(message!)),
      ],
    ],
  );
}
