import '../../support/presentation/report_content_button.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';

import '../../content/application/learning_catalog.dart';

import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class LocalExamCatalog extends StatelessWidget {
  const LocalExamCatalog({required this.data, super.key});
  final LocalSnapshot data;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Thi thử và luyện đọc',
        data.catalog.active != null
            ? 'Câu hỏi từ gói đang dùng. Thi đầy đủ cần audio.'
            : 'Ba bộ đề dự thảo, mỗi bộ 10 câu nghe + 10 câu đọc. Chưa duyệt ngôn ngữ hoặc phân cấp HSK; chưa có audio.',
      ),
      const SizedBox(height: 24),
      for (final attempt in data.exams.attempts.where((a) => !a.done))
        buildActionTile(
          Icons.play_circle_outline,
          'Tiếp tục bài đọc · cấp ${attempt.targetLevel}',
          '${attempt.answers.length}/${attempt.questions.length} đáp án đã lưu · đồng hồ vẫn chạy',
          () => context.push('/exams/attempts/${attempt.id}'),
        ),
      if (catalogExams(data.catalog).isEmpty)
        const Text('Gói đang dùng chưa có câu hỏi.'),
      for (final pack in catalogExams(data.catalog)) ...[
        buildActionTile(
          Icons.quiz_outlined,
          'Bộ nháp định hướng cấp ${pack.targetLevel}',
          pack.fromCatalog
              ? '${pack.questions.length} câu · thiếu audio cho phần nghe'
              : '20 câu dự thảo · thiếu 10 audio · chưa mở thi đầy đủ',
          () => context.push('/exams/packages/${pack.id}'),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: OutlinedButton(
            onPressed: !pack.readyForReading
                ? null
                : () => context.push('/exams/packages/${pack.id}/instructions'),
            child: Text(
              pack.readyForReading
                  ? 'Luyện 10 câu đọc · cấp ${pack.targetLevel}'
                  : 'Chưa đủ 10 câu đọc',
            ),
          ),
        ),
      ],
      const SizedBox(height: 24),
      buildSectionHeading('Lịch sử bài đã nộp'),
      if (data.exams.attempts.every((a) => !a.done))
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Chưa có bài đã nộp.'),
        ),
      for (final attempt in data.exams.attempts.where((a) => a.done))
        buildActionTile(
          Icons.task_alt,
          'Luyện đọc · ${attempt.correctCount}/${attempt.questions.length} câu',
          'Cấp mục tiêu ${attempt.targetLevel} · ${attempt.timedOut ? 'hết giờ' : 'đã nộp'} · ${attempt.blanks} câu bỏ trống',
          () => context.push('/exams/attempts/${attempt.id}'),
        ),
    ],
  );
}

class LocalExamPackagePreview extends StatelessWidget {
  const LocalExamPackagePreview({required this.pack, super.key});
  final LocalExamPackage pack;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Đề dự thảo · cấp ${pack.targetLevel}',
        pack.fromCatalog
            ? 'Câu hỏi từ gói học liệu đang dùng. Xem trước không tạo bài làm.'
            : 'Nội dung do trợ lý soạn, chưa được người biết tiếng Trung kiểm duyệt. Xem nháp không tạo bài làm hoặc điểm.',
      ),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: !pack.readyForReading
            ? null
            : () => context.push('/exams/packages/${pack.id}/instructions'),
        child: const Text('Luyện riêng phần đọc'),
      ),
      const SizedBox(height: 20),
      const Text(
        'Phần nghe chưa có audio. Bản chữ bên dưới chỉ dùng kiểm duyệt nội dung, không thay thế bài nghe.',
      ),
      const SizedBox(height: 16),
      for (var i = 0; i < pack.questions.length; i++)
        ExpansionTile(
          key: ValueKey(pack.questions[i].id),
          title: Text(
            'Câu ${i + 1} · ${pack.questions[i].section == ExamSection.listening ? 'Nghe · thiếu audio' : 'Đọc'}',
          ),
          subtitle: Text(pack.questions[i].prompt),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pack.questions[i].transcript != null) ...[
                    Text('Bản chữ dự thảo: ${pack.questions[i].transcript}'),
                    const SizedBox(height: 12),
                  ],
                  ReportContentButton(
                    contentId: pack.questions[i].id,
                    version: pack.version,
                    label: 'Đề nháp · câu ${i + 1}',
                    route: '/exams/packages/${pack.id}',
                  ),
                  for (final choice in pack.questions[i].choices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $choice'),
                    ),
                  Text(
                    'Đáp án dự thảo: ${pack.questions[i].choices[pack.questions[i].correct]}',
                  ),
                  const SizedBox(height: 8),
                  if (pack.questions[i].section == ExamSection.reading)
                    Text(pack.questions[i].explanation),
                ],
              ),
            ),
          ],
        ),
    ],
  );
}
