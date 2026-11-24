import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';

class AudioPlayerPanel extends StatelessWidget {
  const AudioPlayerPanel({super.key, this.description});
  final String? description;
  @override
  Widget build(BuildContext context) => PanelCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.volume_off_outlined, color: brandTeal),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chưa có tệp audio',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          description ?? 'Bộ điều khiển âm thanh đang ở trạng thái chưa có tệp. Không phát audio hoặc xin quyền thiết bị.',
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            IconButton(
              tooltip: 'Phát audio — chưa có tệp',
              onPressed: null,
              icon: Icon(Icons.play_arrow),
            ),
            Expanded(child: Slider(value: 0, onChanged: null)),
            Text('--:--'),
          ],
        ),
      ],
    ),
  );
}
