import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/exam/domain/exam_attempt.dart';
import 'package:doanchuyennganh2/features/ocr/domain/scan_record.dart';
import 'package:doanchuyennganh2/features/progress/domain/local_activity.dart';
import 'package:doanchuyennganh2/features/progress/presentation/activity_history_screen.dart';
import 'package:doanchuyennganh2/features/review/domain/review_session.dart';
import 'package:doanchuyennganh2/features/roleplay/domain/chat_session.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/status_panel.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({
    super.key,
    required this.savedCount,
    required this.reviews,
    required this.scans,
    required this.chats,
    required this.exams,
    required this.loadActivities,
    required this.onLearn,
  });
  final int savedCount;
  final List<ReviewSession> reviews;
  final List<ScanRecord> scans;
  final List<ChatSession> chats;
  final List<ExamAttempt> exams;
  final List<LocalActivity> Function() loadActivities;
  final VoidCallback onLearn;
  @override
  Widget build(BuildContext context) {
    final ratings = reviews.expand((r) => r.ratings).toList();
    final remembered = ratings.where((r) => r == 'Nhớ' || r == 'Dễ').length;
    final stats = [
      ('$savedCount', 'Từ đang lưu tạm', Icons.bookmarks_outlined),
      ('${ratings.length}', 'Lượt ôn mẫu đã xác nhận', Icons.style_outlined),
      (
        '${scans.length}',
        'Scan mẫu trong bộ nhớ',
        Icons.document_scanner_outlined,
      ),
      ('${chats.length}', 'Phiên hội thoại mẫu', Icons.forum_outlined),
      (
        '${exams.where((e) => e.done).length}',
        'Bài mẫu đã khóa',
        Icons.fact_check_outlined,
      ),
      (
        ratings.isEmpty
            ? '—'
            : '${(remembered * 100 / ratings.length).round()}%',
        'Lượt tự đánh giá Nhớ / Dễ',
        Icons.psychology_outlined,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Hoạt động trong app',
          'Dữ liệu tạm từ thao tác trong lần mở này; chưa phải tiến độ tài khoản hay thành tích.',
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (_, box) {
            final columns = box.maxWidth >= 760
                ? 3
                : box.maxWidth >= 520 ||
                      (box.maxWidth >= 300 &&
                          MediaQuery.textScalerOf(context).scale(16) <= 20.8)
                ? 2
                : 1;
            final width = (box.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final stat in stats)
                  SizedBox(
                    width: width,
                    child: PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(stat.$3, color: brandTeal),
                          const SizedBox(height: 12),
                          Text(
                            stat.$1,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(stat.$2),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: const Text('Cách tính số liệu mẫu'),
              content: const Text(
                'Mỗi lần xác nhận mức nhớ tính một lượt ôn. Tỷ lệ Nhớ/Dễ lấy số lượt chọn hai mức này chia cho tổng lượt. Không phải số từ đã thành thạo.\n\nScan/hội thoại/bài thi là bản ghi mẫu đã tạo, không chứng minh AI hoạt động hoặc người học đã hoàn thành mục tiêu.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.info_outline),
          label: const Text('Cách tính số liệu mẫu'),
        ),
        const SizedBox(height: 12),
        if (loadActivities().isEmpty)
          PreviewStatusPanel(
            state: PreviewState.empty,
            message: 'Chưa có hoạt động mẫu. Thử ôn từ, scan, hội thoại hoặc bài thi. Đóng app sẽ xóa dữ liệu tạm.',
            onAction: onLearn,
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DetailScaffold(
                title: 'Lịch hoạt động mẫu',
                body: ActivityHistoryScreen(loadItems: loadActivities),
              ),
            ),
          ),
          icon: const Icon(Icons.history),
          label: const Text('Mở lịch hoạt động mẫu'),
        ),
        const SizedBox(height: 20),
        const PanelCard(
          child: Text(
            'Streak và mục tiêu hoàn thành từ dữ liệu chuẩn chưa được kết nối. Bản mẫu không tự tạo ngày học hoặc thành tích.',
          ),
        ),
      ],
    );
  }
}
