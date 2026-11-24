import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';
import 'package:doanchuyennganh2/shared/widgets/async_commit_button.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class LocalExamInstructions extends ConsumerWidget {
  const LocalExamInstructions({
    required this.pack,
    required this.data,
    super.key,
  });
  final LocalExamPackage pack;
  final LocalSnapshot data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Luyện đọc · cấp mục tiêu ${pack.targetLevel}',
        '10 câu đọc nháp · 20 phút. Kết quả chỉ phản ánh bộ câu đang luyện, không phải điểm HSK được công nhận.',
      ),
      const SizedBox(height: 24),
      const Text(
        'Chọn rồi bấm Lưu đáp án. Chỉ đáp án đã lưu được chấm. Có thể rời bài và mở lại; đồng hồ vẫn chạy theo hạn nộp đã lưu.',
      ),
      const SizedBox(height: 16),
      const Text(
        'Hết giờ sẽ khóa và chấm đáp án đã lưu. Bản local dùng đồng hồ thiết bị, chưa có xác nhận thời gian từ máy chủ.',
      ),
      const SizedBox(height: 24),
      AsyncCommitButton(
        label: pack.readyForReading
            ? 'Bắt đầu luyện đọc'
            : 'Chưa đủ 10 câu đọc',
        enabled: pack.readyForReading,
        intentKey: 'exam-start:${pack.id}:${data.revision}',
        onCommit: (operationId) async {
          await ref
              .read(localControllerProvider.notifier)
              .commit(
                (r) => r.startExam(
                  pack.id,
                  LocalExamMode.readingPractice,
                  revision: data.revision,
                  operationId: operationId,
                ),
              );
          if (!context.mounted) return;
          final candidates = ref
              .read(localControllerProvider)
              .requireValue
              .exams
              .attempts
              .where(
                (a) =>
                    a.packageId == pack.id &&
                    a.mode == LocalExamMode.readingPractice,
              )
              .toList();
          if (candidates.isNotEmpty) {
            context.go('/exams/attempts/${candidates.first.id}');
          }
        },
      ),
      const SizedBox(height: 16),
      const Text(
        'Nếu bộ này đang có bài làm dở, nút trên tiếp tục bài đó thay vì tạo trùng.',
      ),
    ],
  );
}
