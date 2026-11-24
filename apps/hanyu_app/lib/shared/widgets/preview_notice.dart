import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

class PreviewNotice extends StatelessWidget {
  const PreviewNotice({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.info_outline, size: 18, color: mutedText),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Bản xem thử giao diện • Dữ liệu mẫu, chưa kết nối AI hoặc tài khoản.',
          style: TextStyle(fontSize: 14, color: mutedText),
        ),
      ),
    ],
  );
}
