import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local/local_providers.dart';
import '../../../shared/widgets/async_commit_button.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/local/local_models.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../../content/application/learning_catalog.dart';
import '../domain/local_practice.dart';
import 'practice_widgets.dart';

class PracticeCatalog extends ConsumerWidget {
  const PracticeCatalog({required this.kind, required this.data, super.key});
  final PracticeKind kind;
  final LocalSnapshot data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = data.practice.where((e) => e.kind == kind).toList(),
        path = practicePath(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          switch (kind) {
            PracticeKind.writing => 'Sổ luyện viết',
            PracticeKind.photo => 'Ảnh và chữ tự nhập',
            PracticeKind.conversation => 'Luyện hội thoại thủ công',
          },
          'Bản đã lưu nằm trên thiết bị này. Chưa đồng bộ tài khoản hoặc tích hợp AI.',
        ),
        const SizedBox(height: 24),
        if (kind == PracticeKind.conversation) ...[
          if (catalogScenarios(data.catalog).isEmpty)
            const Text('Gói đang dùng chưa có tình huống.'),
          for (final s in catalogScenarios(data.catalog))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                onPressed: () =>
                    context.go('/conversations/new?scenario=${s.id}'),
                child: Text(s.title),
              ),
            ),
        ] else
          FilledButton.icon(
            onPressed: () => context.go('$path/new'),
            icon: const Icon(Icons.add),
            label: Text(
              kind == PracticeKind.writing
                  ? 'Bắt đầu viết'
                  : 'Thêm ảnh / văn bản',
            ),
          ),
        const SizedBox(height: 24),
        Text('Lịch sử đã lưu', style: Theme.of(context).textTheme.titleLarge),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Chưa có bản đã lưu. Bắt đầu một lượt mới ở phía trên.',
            ),
          ),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${e.done ? 'Đã hoàn thành' : 'Bản nháp / đang mở'} · ${e.updatedAt.toLocal().toString().substring(0, 16)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('$path/${e.id}'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 84,
                  child: AsyncCommitButton(
                    compact: true,
                    label: 'Xóa',
                    intentKey: 'delete-practice:${e.id}',
                    onCommit: (op) async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Xóa bản đã lưu?'),
                          content: const Text(
                            'Nội dung và ảnh/audio thuộc bản này sẽ bị xóa khỏi thiết bị. Hãy xuất backup trước nếu cần giữ.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Hủy'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Xác nhận xóa'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) {
                        await ref
                            .read(localControllerProvider.notifier)
                            .commit(
                              (r) => r.deletePractice(
                                e.id,
                                revision: data.revision,
                                operationId: op,
                              ),
                            );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Ảnh/audio đang lưu: ${(data.media.fold<int>(0, (n, m) => n + m.length) / 1024 / 1024).toStringAsFixed(1)} / 50 MiB',
        ),
      ],
    );
  }
}
