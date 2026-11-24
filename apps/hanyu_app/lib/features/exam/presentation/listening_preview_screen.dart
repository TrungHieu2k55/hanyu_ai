import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/audio_player_panel.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class ListeningPreviewScreen extends StatefulWidget {
  const ListeningPreviewScreen({super.key});
  @override
  State<ListeningPreviewScreen> createState() => _ListeningPreviewScreenState();
}

class _ListeningPreviewScreenState extends State<ListeningPreviewScreen> {
  bool transcript = false, result = false;
  int? selected;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Giao diện bài nghe',
        'Chưa có audio được duyệt. Đây là ví dụ bố cục; không tính vào điểm mini-test hoặc đánh giá kỹ năng nghe.',
      ),
      const SizedBox(height: 24),
      const AudioPlayerPanel(),
      const SizedBox(height: 16),
      TextButton(
        onPressed: () => setState(() => transcript = !transcript),
        child: Text(
          transcript ? 'Ẩn bản chép lời mẫu' : 'Xem bản chép lời mẫu',
        ),
      ),
      if (transcript)
        const PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('你想去哪里？', style: TextStyle(fontSize: 26)),
              SizedBox(height: 8),
              Text(
                'Nǐ xiǎng qù nǎlǐ?',
                style: TextStyle(color: brandTeal, fontSize: 18),
              ),
              Text('Bạn muốn đi đâu?'),
            ],
          ),
        ),
      const SizedBox(height: 24),
      const Text(
        'Người nói đang hỏi điều gì?',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(16),
              backgroundColor: selected == i ? softSurface : null,
            ),
            onPressed: result ? null : () => setState(() => selected = i),
            icon: Icon(
              selected == i
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            label: Text(
              ['Bạn muốn đi đâu?', 'Giá bao nhiêu?', 'Bạn tên là gì?'][i],
            ),
          ),
        ),
      FilledButton(
        onPressed: selected == null
            ? null
            : () => setState(() => result = true),
        child: const Text('Xem đáp án minh họa'),
      ),
      if (result) ...[
        const SizedBox(height: 16),
        const PanelCard(
          child: Text(
            'Đáp án: “Bạn muốn đi đâu?”. Bạn vừa xem bài tập với văn bản mẫu; chưa có phép đo khả năng nghe.',
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            result = false;
            selected = null;
          }),
          child: const Text('Thử lại lựa chọn'),
        ),
      ],
    ],
  );
}
