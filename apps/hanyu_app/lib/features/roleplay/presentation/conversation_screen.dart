import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/roleplay/domain/chat_session.dart';
import 'package:doanchuyennganh2/features/roleplay/presentation/confirm_turn_screen.dart';
import 'package:doanchuyennganh2/features/roleplay/presentation/recording_preview_screen.dart';
import 'package:doanchuyennganh2/features/vocabulary/data/sample_vocabulary.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/word_detail_screen.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/audio_player_panel.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/preview_message.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.session,
    required this.saved,
    required this.notes,
    required this.onChanged,
  });
  final ChatSession session;
  final Set<String> saved;
  final Map<String, String> notes;
  final VoidCallback onChanged;
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late final controller = TextEditingController(text: widget.session.draft);
  final actionKey = GlobalKey();
  bool confirming = false;
  bool showHistory = false;
  bool textOnly = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> confirmTurn() async {
    final session = widget.session;
    if (confirming || session.ended || session.turns.length >= 8) return;
    if (controller.text.trim().isEmpty) {
      showPreviewMessage(context, 'Nhập câu trả lời trước khi xem lại.');
      return;
    }
    setState(() => confirming = true);
    final text = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScaffold(
          title: 'Kiểm tra câu trước khi gửi',
          body: ConfirmTurnScreen(
            initial: controller.text,
            onDraftChanged: (value) => session.draft = value,
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      confirming = false;
      if (text == null) controller.text = session.draft;
      if (text != null &&
          text.trim().isNotEmpty &&
          !session.ended &&
          session.turns.length < 8) {
        session.confirmTurn(text);
        controller.clear();
      }
    });
    widget.onChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = actionKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: .8);
    });
  }

  Future<void> endSession() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Kết thúc phiên mẫu?'),
        content: Text(
          widget.session.draft.isEmpty
              ? 'Các lượt đã xác nhận vẫn xem lại được trong lần mở app này.'
              : 'Bản nháp chưa xác nhận sẽ bị bỏ. Các lượt đã xác nhận vẫn xem lại được trong lần mở app này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Tiếp tục hội thoại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Kết thúc phiên'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      widget.session.end();
      controller.clear();
    });
    widget.onChanged();
  }

  Widget message(List<String> content, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: mutedText)),
          const SizedBox(height: 12),
          Text(content[0], style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            content[1],
            style: const TextStyle(color: brandTeal, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(content[2]),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final scenario = session.scenario;
    final usedText =
        '${scenario.opening[0]} ${session.turns.isEmpty ? "" : scenario.reply[0]} ${session.turns.map((t) => t.text).join(" ")}';
    final words = sampleVocabulary
        .where((w) => usedText.contains(w.hanzi))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${session.turns.length}/8 lượt đã xác nhận · ${session.ended ? "Đã kết thúc" : "Phiên mẫu đang mở"}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text('Bạn: ${scenario.role}. Đối tác: ${scenario.partner}.'),
        const SizedBox(height: 20),
        if (session.ended) ...[
          buildPageTitle(
            'Đã kết thúc phiên mẫu',
            'Bạn đã xác nhận ${session.turns.length} lượt. Không có điểm phát âm hoặc nhận xét AI.',
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() => showHistory = !showHistory),
            child: Text(
              showHistory ? 'Ẩn lịch sử hội thoại' : 'Xem lại hội thoại',
            ),
          ),
        ],
        if (!session.ended || showHistory) ...[
          message(scenario.opening, 'Đối tác · lời mở đầu mẫu'),
          for (var i = 0; i < session.turns.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: softSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bạn · lượt ${i + 1}',
                    style: const TextStyle(color: mutedText, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.turns[i].text,
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),
            message(scenario.reply, 'Đối tác · phản hồi cố định minh họa'),
          ],
        ],
        if (!session.ended) ...[
          const Text(
            'Bản nháp giữ tạm khi quay lại. Chưa gửi cho AI hoặc đồng bộ tài khoản.',
            style: TextStyle(fontSize: 14, color: mutedText),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('conversation-input'),
            controller: controller,
            minLines: 2,
            maxLines: 6,
            maxLength: 300,
            onChanged: (text) => session.draft = text,
            decoration: const InputDecoration(
              labelText: 'Câu trả lời của bạn',
              alignLabelWithHint: true,
            ),
          ),
          TextButton(
            onPressed: () {
              controller.text = scenario.suggestion;
              session.draft = controller.text;
            },
            child: const Text('Dùng câu gợi ý mẫu'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: actionKey,
            onPressed: confirming ? null : confirmTurn,
            child: const Text('Tiếp tục hội thoại'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: confirming
                ? null
                : () async {
                    final transcript = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailScaffold(
                          title: 'Ghi âm · mẫu giao diện',
                          body: RecordingPreviewScreen(
                            sample: scenario.suggestion,
                          ),
                        ),
                      ),
                    );
                    if (transcript != null && mounted) {
                      setState(() {
                        controller.text = transcript;
                        session.draft = transcript;
                      });
                    }
                  },
            icon: const Icon(Icons.mic_none),
            label: const Text('Ghi âm / bản chữ mẫu'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: endSession,
            child: const Text('Kết thúc phiên'),
          ),
        ],
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => setState(() => textOnly = true),
          icon: const Icon(Icons.volume_off_outlined),
          label: const Text('Giọng đọc / văn bản thay thế'),
        ),
        if (textOnly)
          const AudioPlayerPanel(
            description: 'Chưa có dịch vụ giọng đọc. Hán tự, Pinyin và nghĩa Việt của nội dung mẫu vẫn xem được; phiên hội thoại không bị mất.',
          ),
        const SizedBox(height: 24),
        buildSectionHeading('Từ trong hội thoại'),
        const Text(
          'Chỉ khớp từ có sẵn trong bộ mẫu; học liệu chưa được kiểm duyệt.',
          style: TextStyle(color: mutedText, fontSize: 14),
        ),
        for (final word in words)
          TextButton(
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailScaffold(
                    title: 'Chi tiết từ',
                    body: WordDetailScreen(
                      word: word,
                      saved: widget.saved,
                      notes: widget.notes,
                      onChanged: widget.onChanged,
                    ),
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
            child: Text(
              '${word.hanzi} · ${word.pinyin}${widget.saved.contains(word.id) ? " · Đã lưu mẫu" : ""}',
            ),
          ),
        if (session.ended) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Về danh sách tình huống'),
          ),
        ],
      ],
    );
  }
}
