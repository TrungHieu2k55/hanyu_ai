import 'dart:async';

import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/audio_player_panel.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/preview_message.dart';
import 'package:doanchuyennganh2/shared/widgets/status_panel.dart';
import 'package:doanchuyennganh2/shared/widgets/unsaved_changes_guard.dart';

class RecordingPreviewScreen extends StatefulWidget {
  const RecordingPreviewScreen({super.key, required this.sample});
  final String sample;
  @override
  State<RecordingPreviewScreen> createState() => _RecordingPreviewScreenState();
}

class _RecordingPreviewScreenState extends State<RecordingPreviewScreen> {
  late final editor = TextEditingController(text: widget.sample);
  Timer? timer;
  int step = 0, seconds = 0;
  bool finishing = false;
  void start() {
    timer?.cancel();
    setState(() {
      step = 1;
      seconds = 0;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        seconds++;
        if (seconds >= 60) {
          timer?.cancel();
          step = 2;
        }
      });
    });
  }

  void stop() {
    timer?.cancel();
    setState(() => step = 2);
  }

  @override
  void dispose() {
    timer?.cancel();
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty: !finishing && (step == 1 || editor.text != widget.sample),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Thử giao diện ghi âm',
          'Mô phỏng thao tác, không mở microphone, không thu âm hoặc tạo transcript từ giọng nói.',
        ),
        const SizedBox(height: 24),
        if (step == 0) ...[
          const PreviewStatusPanel(
            state: PreviewState.notConfigured,
            message: 'Ghi âm thật chưa được tích hợp. Bạn có thể thử các bước và dùng bản chữ mẫu để tiếp tục hội thoại.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: start,
            icon: const Icon(Icons.mic_none),
            label: const Text('Bắt đầu mô phỏng ghi âm'),
          ),
        ] else if (step == 1) ...[
          PanelCard(
            child: Column(
              children: [
                const Icon(Icons.mic_none, size: 56, color: brandTeal),
                const SizedBox(height: 16),
                Text(
                  '00:${seconds.toString().padLeft(2, "0")} / 01:00',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Đồng hồ mô phỏng · không có dữ liệu âm thanh.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: stop, child: const Text('Dừng mô phỏng')),
          TextButton(
            onPressed: () {
              timer?.cancel();
              setState(() => step = 0);
            },
            child: const Text('Hủy lượt mô phỏng'),
          ),
        ] else ...[
          const AudioPlayerPanel(),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('recording-transcript'),
            controller: editor,
            minLines: 3,
            maxLines: 8,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Bản chữ mẫu có thể sửa',
              alignLabelWithHint: true,
            ),
          ),
          const Text(
            'Chỉ đưa bản chữ về ô nhập. Bạn vẫn cần kiểm tra/xác nhận trước khi tăng số lượt hội thoại.',
            style: TextStyle(fontSize: 14, color: mutedText),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (finishing) return;
              if (editor.text.trim().isEmpty) {
                showPreviewMessage(context, 'Nhập bản chữ trước khi tiếp tục.');
                return;
              }
              final result = editor.text.trim();
              setState(() => finishing = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.pop(context, result);
              });
            },
            child: const Text('Dùng bản chữ này'),
          ),
          TextButton(
            onPressed: start,
            child: const Text('Thử ghi lại (mô phỏng)'),
          ),
        ],
      ],
    ),
  );
}
