import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/app/preview_session_store.dart';
import 'package:doanchuyennganh2/features/roleplay/presentation/scenario_catalog_screen.dart';
import 'package:doanchuyennganh2/features/writing/presentation/writing_canvas_screen.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.data,
    required this.onWords,
    required this.onReview,
    required this.onChanged,
    required this.onOpen,
    super.key,
  });
  final PreviewSessionStore data;
  final VoidCallback onWords, onReview, onChanged;
  final Future<void> Function(String, Widget) onOpen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Một chút mỗi ngày,',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: brandInk,
        ),
      ),
      const Text(
        'gần hơn với tiếng Trung.',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: brandTeal,
        ),
      ),
      const SizedBox(height: 10),
      const Text('Bắt đầu từ một từ mới và dùng nó trong cuộc sống.'),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: brandInk,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bài học đầu tiên',
              style: TextStyle(color: Color(0xFFBDE5DF), fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              '你好！\nXin chào, tiếng Trung.',
              style: TextStyle(
                fontSize: 28,
                height: 1.4,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Làm quen cách chào hỏi và giới thiệu bản thân.',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: brandInk,
              ),
              onPressed: onWords,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Khám phá từ mẫu'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      buildSectionHeading(
        'Góc học hôm nay',
        action: 'Xem từ vựng',
        onTap: onWords,
      ),
      const SizedBox(height: 12),
      buildActionTile(
        Icons.style_outlined,
        'Ôn lại để nhớ lâu',
        data.saved.isEmpty
            ? 'Lưu từ đầu tiên để tạo bộ ôn của bạn.'
            : '${data.saved.length} từ đã chọn trong bản xem thử.',
        onReview,
      ),
      buildActionTile(
        Icons.draw_outlined,
        'Một chữ, từng nét',
        'Thử viết chữ 人 trên ô luyện chữ.',
        () => onOpen('Luyện viết', const WritingCanvasScreen()),
      ),
      buildActionTile(
        Icons.record_voice_over_outlined,
        'Nói trong tình huống thật',
        'Đón khách, hỏi đường, mua hàng và thương mại.',
        () => onOpen(
          'Hội thoại',
          ScenarioCatalogScreen(
            sessions: data.chatSessions,
            saved: data.saved,
            notes: data.notes,
            onChanged: onChanged,
          ),
        ),
      ),
      const SizedBox(height: 22),
      const PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Từ của ngày', style: TextStyle(color: mutedText)),
            SizedBox(height: 12),
            Text(
              '朋友',
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.w600),
            ),
            Text('péngyou', style: TextStyle(color: brandTeal, fontSize: 20)),
            SizedBox(height: 6),
            Text('Bạn bè — cùng nhau học thêm một điều mới.'),
          ],
        ),
      ),
    ],
  );
}
