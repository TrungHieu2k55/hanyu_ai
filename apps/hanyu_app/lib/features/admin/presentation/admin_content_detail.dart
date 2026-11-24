import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../application/local_admin_providers.dart';
import '../domain/content_revision.dart';
import 'admin_page.dart';
import 'admin_editor.dart';

class AdminContentDetail extends ConsumerStatefulWidget {
  const AdminContentDetail({required this.id, this.initialRevision, super.key});
  final String id;
  final int? initialRevision;
  @override
  ConsumerState<AdminContentDetail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<AdminContentDetail> {
  late int? selected = widget.initialRevision;
  final reviewer = TextEditingController(), note = TextEditingController();
  bool showReview = false, busy = false;
  String? message;
  @override
  void dispose() {
    reviewer.dispose();
    note.dispose();
    super.dispose();
  }

  Future<bool> confirm(String title, String body) => showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  ).then((v) => v ?? false);
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localAdminControllerProvider).asData?.value;
    final versions =
        (data?.content.where((r) => r.itemId == widget.id).toList() ?? [])
          ..sort((a, b) => b.revision.compareTo(a.revision));
    final record =
        versions.where((r) => r.revision == selected).firstOrNull ??
        versions.firstOrNull;
    final latest = record != null && record.revision == versions.first.revision;
    return UnsavedChangesGuard(
      dirty: showReview && (reviewer.text.isNotEmpty || note.text.isNotEmpty),
      busy: busy,
      child: AdminPage(
        title: 'Chi tiết học liệu',
        child: record == null
            ? const Text(
                'Học liệu không còn tồn tại. Quay lại thư viện để chọn bản khác.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    record.payload.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'version:${record.revision}:${versions.length}',
                    ),
                    initialValue: record.revision,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Lịch sử phiên bản',
                    ),
                    items: [
                      for (final r in versions)
                        DropdownMenuItem(
                          value: r.revision,
                          child: Text(
                            'v${r.revision} · ${contentStateLabel(r.state)}',
                          ),
                        ),
                    ],
                    onChanged: busy || showReview
                        ? null
                        : (v) => setState(() => selected = v),
                  ),
                  const SizedBox(height: 24),
                  for (final entry in record.payload.toJson().entries.where(
                    (e) => e.value is! String || (e.value as String).isNotEmpty,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _labels[entry.key] ?? entry.key,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            entry.key == 'correctIndex'
                                ? String.fromCharCode(65 + (entry.value as int))
                                : entry.key == 'section'
                                ? (entry.value == 'reading'
                                      ? 'Đọc'
                                      : 'Nghe · chưa có audio')
                                : entry.value is List
                                ? (entry.value as List).join('\n')
                                : '${entry.value ?? 'Chưa gán'}',
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 32),
                  Text(
                    'Nguồn: ${record.source.isEmpty ? 'Chưa khai báo' : record.source}',
                  ),
                  Text(
                    'Quyền sử dụng: ${record.license.isEmpty ? 'Chưa khai báo' : record.license}',
                  ),
                  const SizedBox(height: 16),
                  if (record.review.status ==
                      ReviewStatus.externallyDeclared) ...[
                    Text('Người khai báo duyệt: ${record.review.reviewerName}'),
                    Text(
                      'Phiên bản đã duyệt: ${record.review.reviewedRevision}',
                    ),
                    Text(
                      'Thời điểm (giờ thiết bị): ${record.review.reviewedAt!.toLocal().toString().substring(0, 16)}',
                    ),
                    Text(record.review.note!),
                    const Text(
                      'Đây là khai báo local, chưa xác minh danh tính hoặc chứng nhận HSK.',
                    ),
                  ] else
                    const Text('Chưa có khai báo duyệt.'),
                  if (record.exported)
                    const Text(
                      'Đã được pin trong snapshot xuất; không thể xóa bản này.',
                    ),
                  const SizedBox(height: 24),
                  if (latest)
                    OutlinedButton(
                      onPressed: busy || showReview
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => AdminEditor(
                                  kind: record.kind,
                                  record: record,
                                ),
                              ),
                            ),
                      child: const Text('Sửa thành bản nháp mới'),
                    ),
                  if (latest && record.state == ContentState.draft) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: busy || showReview
                          ? null
                          : () => setState(() => showReview = true),
                      child: const Text('Khai báo duyệt nội dung'),
                    ),
                    if (showReview) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Chỉ điền khi đã có người kiểm tra thực tế. Ứng dụng không tự xác minh người duyệt.',
                      ),
                      TextField(
                        key: const ValueKey('admin-reviewer'),
                        controller: reviewer,
                        enabled: !busy,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Tên người khai báo duyệt',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      TextField(
                        key: const ValueKey('admin-review-note'),
                        controller: note,
                        enabled: !busy,
                        maxLength: 2000,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú đối chiếu',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      AsyncCommitButton(
                        label: 'Lưu khai báo duyệt',
                        enabled: !busy,
                        intentKey:
                            '${data!.revision}:${reviewer.text}:${note.text}',
                        onBusyChanged: (v) => setState(() => busy = v),
                        onCommit: (op) async {
                          await ref
                              .read(localAdminControllerProvider.notifier)
                              .commit(
                                (r) => r.recordReview(
                                  widget.id,
                                  record.revision,
                                  reviewerName: reviewer.text,
                                  note: note.text,
                                  revision: data.revision,
                                  operationId: op,
                                ),
                              );
                          if (mounted) {
                            setState(() {
                              showReview = false;
                              reviewer.clear();
                              note.clear();
                              message =
                                  'Đã lưu khai báo duyệt cho phiên bản ${record.revision}.';
                            });
                          }
                        },
                      ),
                    ],
                  ],
                  if (latest && record.state == ContentState.reviewed)
                    AsyncCommitButton(
                      label: 'Công bố phiên bản này',
                      enabled: !busy,
                      intentKey: 'publish:${record.revision}',
                      onBusyChanged: (v) => setState(() => busy = v),
                      onCommit: (op) async {
                        if (!await confirm(
                          'Công bố phiên bản này?',
                          'Phiên bản đang công bố trước đó sẽ thành đã thay thế. Nội dung chưa tự chuyển tới thiết bị người học.',
                        )) {
                          return;
                        }
                        await ref
                            .read(localAdminControllerProvider.notifier)
                            .commit(
                              (r) => r.publishRevision(
                                widget.id,
                                record.revision,
                                revision: data!.revision,
                                operationId: op,
                              ),
                            );
                      },
                    ),
                  if (record.state == ContentState.published)
                    AsyncCommitButton(
                      label: 'Thu hồi phiên bản này',
                      compact: true,
                      enabled: !busy,
                      intentKey: 'withdraw:${record.revision}',
                      onBusyChanged: (v) => setState(() => busy = v),
                      onCommit: (op) async {
                        if (!await confirm(
                          'Thu hồi phiên bản này?',
                          'Loại khỏi lần xuất mới, không tự khôi phục phiên bản cũ hoặc xóa file đã chuyển cho người khác.',
                        )) {
                          return;
                        }
                        await ref
                            .read(localAdminControllerProvider.notifier)
                            .commit(
                              (r) => r.withdrawRevision(
                                widget.id,
                                record.revision,
                                revision: data!.revision,
                                operationId: op,
                              ),
                            );
                      },
                    ),
                  const SizedBox(height: 8),
                  if (latest &&
                      record.state == ContentState.draft &&
                      !record.exported &&
                      !showReview)
                    AsyncCommitButton(
                      label: 'Xóa nháp chưa xuất',
                      compact: true,
                      enabled: !busy,
                      intentKey: 'delete:${record.revision}',
                      onBusyChanged: (v) => setState(() => busy = v),
                      onCommit: (op) async {
                        if (!await confirm(
                          'Xóa bản nháp này?',
                          'Chỉ xóa phiên bản nháp mới nhất chưa xuất. Các phiên bản và lịch sử công bố khác vẫn giữ.',
                        )) {
                          return;
                        }
                        await ref
                            .read(localAdminControllerProvider.notifier)
                            .commit(
                              (r) => r.deleteUnexportedDraft(
                                widget.id,
                                record.revision,
                                revision: data!.revision,
                                operationId: op,
                              ),
                            );
                        if (mounted) setState(() => selected = null);
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
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => message = 'Chưa tải lại được. Nội dung đang soạn vẫn giữ.',
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
    );
  }
}

const _labels = {
  'hanzi': 'Hán tự',
  'pinyin': 'Pinyin',
  'vietnamese': 'Nghĩa Việt',
  'targetLevel': 'Cấp mục tiêu',
  'exampleHanzi': 'Ví dụ Hán tự',
  'exampleVietnamese': 'Nghĩa ví dụ',
  'section': 'Phần nghe/đọc',
  'slot': 'Vị trí cố định',
  'prompt': 'Câu hỏi',
  'choices': 'Bốn lựa chọn',
  'correctIndex': 'Đáp án đúng',
  'explanation': 'Giải thích',
  'key': 'Tình huống',
  'role': 'Vai người học',
  'partner': 'Vai đối tác',
  'goal': 'Mục tiêu',
  'opening': 'Lời mở đầu · Hán/Pinyin/Việt',
  'sampleReply': 'Câu đáp mẫu · Hán/Pinyin/Việt',
  'suggestion': 'Gợi ý',
};
