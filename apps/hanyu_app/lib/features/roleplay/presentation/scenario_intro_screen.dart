import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/roleplay/domain/scenario.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/single_action_button.dart';

class ScenarioIntroScreen extends StatelessWidget {
  const ScenarioIntroScreen({
    super.key,
    required this.scenario,
    required this.onStart,
  });
  final Scenario scenario;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(scenario.title, scenario.goal),
      const SizedBox(height: 24),
      PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vai của bạn', style: TextStyle(color: mutedText)),
            Text(
              scenario.role,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            const Text('Bạn đang nói với', style: TextStyle(color: mutedText)),
            Text(scenario.partner),
            const SizedBox(height: 20),
            const Text(
              'Tối đa 8 lượt đã xác nhận mỗi phiên. Chỉ mở xem hoặc sửa câu không làm tăng số lượt.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Bạn sẽ nhập câu trả lời, kiểm tra lại rồi mới xác nhận. Phản hồi đối tác là nội dung cố định để thử giao diện, không phân tích câu bạn nhập và chưa được kiểm duyệt.',
      ),
      const SizedBox(height: 20),
      SingleActionButton(onPressed: onStart, label: 'Bắt đầu phiên mẫu'),
    ],
  );
}
