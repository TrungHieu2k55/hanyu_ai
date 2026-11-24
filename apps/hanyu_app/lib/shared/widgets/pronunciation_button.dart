import 'package:flutter/material.dart';

import '../../core/media/mandarin_pronunciation.dart';
import '../ui_tokens.dart';

class PronunciationButton extends StatefulWidget {
  const PronunciationButton({
    required this.hanzi,
    required this.soundEnabled,
    super.key,
  });

  final String hanzi;
  final bool soundEnabled;

  @override
  State<PronunciationButton> createState() => _PronunciationButtonState();
}

class _PronunciationButtonState extends State<PronunciationButton> {
  bool _playing = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _play() async {
    if (!widget.soundEnabled) {
      _showMessage(
        'Bật Âm thanh bài học trong Cá nhân → Mục tiêu và âm thanh.',
      );
      return;
    }
    setState(() => _playing = true);
    final result = await MandarinPronunciation.instance.speak(widget.hanzi);
    if (!mounted) return;
    setState(() => _playing = false);
    switch (result) {
      case PronunciationResult.noVoice:
        _showMessage(
          'Hãy thêm giọng tiếng Quan thoại trên thiết bị hoặc trình duyệt.',
        );
      case PronunciationResult.unavailable:
        _showMessage('Chưa phát được âm thanh. Thử lại sau.');
      case PronunciationResult.busy:
      case PronunciationResult.played:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    style: IconButton.styleFrom(
      backgroundColor: softSurface,
      foregroundColor: brandTeal,
      minimumSize: const Size.square(48),
      visualDensity: VisualDensity.standard,
    ),
    tooltip: _playing ? 'Đang phát âm' : 'Nghe phát âm',
    onPressed: _playing ? null : _play,
    icon: _playing
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            widget.soundEnabled
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined,
          ),
  );
}
