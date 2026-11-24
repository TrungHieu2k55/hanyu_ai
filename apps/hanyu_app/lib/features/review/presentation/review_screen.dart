import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/review/domain/review_session.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.session,
    required this.onChanged,
  });
  final ReviewSession session;
  final VoidCallback onChanged;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool advancing = false;
  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session.completed) {
      return PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline, size: 56, color: brandTeal),
            const SizedBox(height: 16),
            const Text(
              'Đã xem hết bộ thẻ mẫu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (final label in ['Quên', 'Khó', 'Nhớ', 'Dễ'])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '$label: ${session.ratings.where((v) => v == label).length} thẻ',
                ),
              ),
            const Text(
              'Đây là tự đánh giá của phiên xem thử, chưa tạo lịch ôn hoặc thành tích thật.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Về bộ ôn'),
            ),
          ],
        ),
      );
    }
    final word = session.words[session.index];
    return Column(
      children: [
        Text('Thẻ ${session.index + 1} / ${session.words.length}'),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.pause_circle_outline),
          label: const Text('Tạm dừng phiên mẫu'),
        ),
        const Text(
          'Có thể tiếp tục từ tab Ôn tập trong lần mở app này.',
          style: TextStyle(color: mutedText, fontSize: 14),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: session.index / session.words.length,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: PanelCard(
            child: Column(
              children: [
                Text(
                  word.hanzi,
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                if (session.revealed) ...[
                  Text(
                    word.pinyin,
                    style: const TextStyle(fontSize: 24, color: brandTeal),
                  ),
                  const SizedBox(height: 8),
                  Text(word.vietnamese),
                  const Divider(height: 32),
                  Text(word.exampleHanzi),
                  Text(word.exampleVietnamese),
                ] else
                  OutlinedButton(
                    onPressed: () {
                      setState(() => session.revealed = true);
                      widget.onChanged();
                    },
                    child: const Text('Lật thẻ xem nghĩa'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (session.revealed) ...[
          const Text('Bạn nhớ từ này đến mức nào?'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in ['Quên', 'Khó', 'Nhớ', 'Dễ'])
                OutlinedButton(
                  onPressed: advancing
                      ? null
                      : () {
                          // Keep one accepted tap per rendered card, including rapid taps.
                          if (advancing) return;
                          advancing = true;
                          setState(() {
                            session.ratings.add(label);
                            session.index++;
                            session.revealed = false;
                          });
                          widget.onChanged();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => advancing = false);
                          });
                        },
                  child: Text(label),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Quên: chưa nhớ • Khó: cần gợi ý\nNhớ: tự nhớ được • Dễ: nhớ ngay',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedText, fontSize: 14),
          ),
        ],
      ],
    );
  }
}
