import 'package:doanchuyennganh2/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/roleplay/data/sample_scenarios.dart';
import 'package:doanchuyennganh2/features/roleplay/domain/chat_session.dart';
import 'package:doanchuyennganh2/features/roleplay/presentation/conversation_screen.dart';
import 'package:doanchuyennganh2/features/roleplay/presentation/scenario_intro_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class ScenarioCatalogScreen extends StatefulWidget {
  const ScenarioCatalogScreen({
    super.key,
    required this.sessions,
    required this.saved,
    required this.notes,
    required this.onChanged,
  });
  final List<ChatSession> sessions;
  final Set<String> saved;
  final Map<String, String> notes;
  final VoidCallback onChanged;
  @override
  State<ScenarioCatalogScreen> createState() => _ScenarioCatalogScreenState();
}

class _ScenarioCatalogScreenState extends State<ScenarioCatalogScreen> {
  Future<void> room(ChatSession session) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScaffold(
          title: session.scenario.title,
          body: ConversationScreen(
            session: session,
            saved: widget.saved,
            notes: widget.notes,
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildPageTitle(
        'Bạn muốn nói chuyện gì?',
        'Bốn bối cảnh mẫu. Chưa có ghi âm, chấm nói hay phản hồi AI.',
      ),
      const SizedBox(height: 24),
      for (final s in sampleScenarios)
        buildActionTile(
          Icons.chat_bubble_outline,
          s.title,
          '${s.role} · ${s.goal}',
          () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScaffold(
                  title: 'Trước khi hội thoại',
                  body: ScenarioIntroScreen(
                    scenario: s,
                    onStart: () {
                      final session = ChatSession(
                        widget.sessions.length + 1,
                        s,
                      );
                      widget.sessions.add(session);
                      widget.onChanged();
                      Navigator.of(context).pop();
                      room(session);
                    },
                  ),
                ),
              ),
            );
            if (mounted) setState(() {});
          },
        ),
      const AccountPreviewLink(
        intent: AccountIntent.conversation,
        label: 'Xem luồng đăng nhập trước hội thoại',
      ),
      const SizedBox(height: 24),
      buildSectionHeading('Phiên trong lần mở app này'),
      const SizedBox(height: 12),
      if (widget.sessions.isEmpty)
        const Text('Chưa có phiên mẫu. Chọn một tình huống để bắt đầu.'),
      for (final session in widget.sessions.reversed)
        buildActionTile(
          session.ended ? Icons.task_alt : Icons.pause_circle_outline,
          '${session.scenario.title} · phiên ${session.number}',
          '${session.turns.length}/8 lượt · ${session.ended ? "Đã kết thúc — xem lại" : "Đang dở — tiếp tục"}',
          () => room(session),
        ),
    ],
  );
}
