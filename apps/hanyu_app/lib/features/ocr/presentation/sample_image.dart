import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

class SampleScanImage extends StatelessWidget {
  const SampleScanImage({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Hình minh họa có chữ 你好 và 我学习中文',
    child: Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB8D1D1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hình minh họa nội bộ',
            style: TextStyle(fontSize: 14, color: mutedText),
          ),
          SizedBox(height: 16),
          Text(
            '你好！',
            style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text('我学习中文。', style: TextStyle(fontSize: 26)),
        ],
      ),
    ),
  );
}
