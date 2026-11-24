import 'package:doanchuyennganh2/features/writing/presentation/character_picker.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/widgets/writing_grid_painter.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/status_panel.dart';

enum PredictionMode { notConfigured, candidates, uncertain, unsupported }

class PredictionResultScreen extends StatelessWidget {
  const PredictionResultScreen({
    super.key,
    this.mode = PredictionMode.notConfigured,
    this.strokes = const [],
  });
  final PredictionMode mode;
  final List<List<Offset>> strokes;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        mode == PredictionMode.notConfigured
            ? 'Nhận diện chưa sẵn sàng'
            : 'Kết quả nhận diện · mẫu UI',
        'Chưa có CNN chạy trong app. Không chấm nét viết, không có confidence thật.',
      ),
      const SizedBox(height: 20),
      if (strokes.isNotEmpty)
        Center(
          child: SizedBox(
            width: 180,
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(painter: WritingGridPainter(strokes)),
            ),
          ),
        ),
      const SizedBox(height: 20),
      if (mode == PredictionMode.notConfigured)
        const PreviewStatusPanel(
          state: PreviewState.notConfigured,
          message: 'Mô hình chưa được nối. Nét viết vẫn giữ ở màn trước. Bạn có thể quay lại hoặc tự chọn chữ.',
        )
      else if (mode == PredictionMode.unsupported)
        const PanelCard(
          child: Text(
            'Chữ ngoài phạm vi hỗ trợ — đây là trạng thái minh họa. Bản thật cần đối chiếu danh sách nhãn/model đang công bố.',
          ),
        )
      else ...[
        Text(
          mode == PredictionMode.uncertain
              ? 'Mẫu kết quả chưa chắc chắn'
              : 'Ba gợi ý bố cục top-3',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          'Ba chữ cố định chỉ để xem cách lựa chọn. Không được suy ra từ nét người dùng, không có phần trăm tin cậy.',
        ),
        const SizedBox(height: 16),
        for (final hanzi in ['人', '入', '八'])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, hanzi),
              child: Text(
                'Chọn $hanzi (mẫu)',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
      ],
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: () async {
          final choice = await showCharacterPicker(context);
          if (choice != null && context.mounted) Navigator.pop(context, choice);
        },
        child: const Text('Chọn chữ thủ công'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại, giữ nét viết'),
      ),
    ],
  );
}
