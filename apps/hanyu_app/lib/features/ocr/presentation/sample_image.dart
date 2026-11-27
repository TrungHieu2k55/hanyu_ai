import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

class SampleScanImage extends StatelessWidget {
  const SampleScanImage({this.lookupIllustration = false, super.key});
  final bool lookupIllustration;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: lookupIllustration
        ? 'Ảnh mẫu có chữ 学习中文, 朋友 và 学校'
        : 'Hình minh họa có chữ 你好 và 我学习中文',
    child: Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB8D1D1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ảnh mẫu',
            style: TextStyle(fontSize: 14, color: mutedText),
          ),
          const SizedBox(height: 16),
          Text(
            lookupIllustration ? '学习中文' : '你好！',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            lookupIllustration ? '朋友  学校' : '我学习中文。',
            style: const TextStyle(fontSize: 26),
          ),
        ],
      ),
    ),
  );
}
