import 'package:doanchuyennganh2/features/exam/presentation/exam_layout_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/single_action_button.dart';

class ExamInstructionsScreen extends StatelessWidget {
  const ExamInstructionsScreen({
    super.key,
    required this.level,
    required this.onStart,
  });
  final int level;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Trước khi bắt đầu · HSK $level',
        'Cấp độ đang là nhãn cấu hình mẫu, chưa xác nhận độ khó tương ứng HSK.',
      ),
      const SizedBox(height: 24),
      const PanelCard(
        child: Text(
          '• 4 câu đọc minh họa, 20 phút.\n• Đồng hồ bắt đầu khi bấm bắt đầu. Rời màn không dừng giờ.\n• Câu trả lời giữ trong RAM; đóng app/tải lại trang sẽ mất.\n• Chưa nộp thì có thể quay lại đổi đáp án.\n• Hết giờ khóa bài; lời giải chỉ hiện sau khi khóa.\n\nĐề chính thức dự kiến 20 câu nghe/đọc sau khi có học liệu và audio được duyệt.',
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => DetailScaffold(
              title: 'Bố cục đề 20 câu',
              body: ExamLayoutScreen(level: level),
            ),
          ),
        ),
        child: const Text('Xem bố cục 20 câu nghe/đọc'),
      ),
      const SizedBox(height: 16),
      SingleActionButton(onPressed: onStart, label: 'Bắt đầu bài mẫu'),
    ],
  );
}
