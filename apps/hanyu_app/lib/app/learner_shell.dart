import 'package:doanchuyennganh2/shared/widgets/learner_navigation_bar.dart';
import 'package:doanchuyennganh2/shared/widgets/figma_icon.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/app/preview_session_store.dart';
import 'package:doanchuyennganh2/features/exam/presentation/exam_catalog_screen.dart';
import 'package:doanchuyennganh2/features/exam/presentation/exam_runner_screen.dart';
import 'package:doanchuyennganh2/features/home/presentation/home_screen.dart';
import 'package:doanchuyennganh2/features/ocr/presentation/ocr_screen.dart';
import 'package:doanchuyennganh2/features/profile/presentation/profile_screen.dart';
import 'package:doanchuyennganh2/features/progress/domain/local_activity.dart';
import 'package:doanchuyennganh2/features/progress/presentation/progress_screen.dart';
import 'package:doanchuyennganh2/features/review/presentation/review_screen.dart';
import 'package:doanchuyennganh2/features/roleplay/presentation/conversation_screen.dart';
import 'package:doanchuyennganh2/features/roleplay/presentation/scenario_catalog_screen.dart';
import 'package:doanchuyennganh2/features/vocabulary/data/sample_vocabulary.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/personal_words_screen.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/saved_words_screen.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/vocabulary_screen.dart';
import 'package:doanchuyennganh2/features/writing/presentation/writing_picker_screen.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/brand_mark.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/preview_notice.dart';

class LearnerShell extends StatefulWidget {
  const LearnerShell({super.key});
  @override
  State<LearnerShell> createState() => _LearnerShellState();
}

class _LearnerShellState extends State<LearnerShell> {
  int tab = 0;
  final data = PreviewSessionStore();
  static const labels = ['Học', 'Ôn tập', 'Luyện tập', 'Tiến độ', 'Cá nhân'];

  Future<void> open(String title, Widget body) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DetailScaffold(title: title, body: body),
      ),
    );
    if (mounted) setState(() {});
  }

  void words() => open(
    'Từ vựng',
    VocabularyScreen(
      words: [...sampleVocabulary, ...data.personalWords],
      saved: data.saved,
      notes: data.notes,
      onChanged: () => setState(() {}),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pages = [
      HomeScreen(
        data: data,
        onWords: words,
        onReview: () => setState(() => tab = 1),
        onChanged: () => setState(() {}),
        onOpen: open,
      ),
      _reviewLanding(),
      _practice(),
      _progress(),
      ProfileScreen(preferences: data.preferences, onOpen: open),
    ];
    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: ListView(
          padding: EdgeInsets.all(wide ? 32 : 20),
          children: [
            const PreviewNotice(),
            const SizedBox(height: 24),
            pages[tab],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            BrandMark(),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hanyu AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cá nhân',
            onPressed: () => setState(() => tab = 4),
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: softSurface,
              child: Icon(Icons.person_outline, color: brandTeal),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  NavigationRail(
                    extended: true,
                    minExtendedWidth: 200,
                    selectedIndex: tab,
                    onDestinationSelected: (v) => setState(() => tab = v),
                    destinations: [
                      for (var i = 0; i < 5; i++)
                        NavigationRailDestination(
                          icon: FigmaIcon(
                            learnerNavigationGlyphs[i],
                            color: mutedText,
                          ),
                          selectedIcon: FigmaIcon(
                            learnerNavigationGlyphs[i],
                            color: brandTeal,
                          ),
                          label: Text(labels[i]),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
      bottomNavigationBar: wide
          ? null
          : LearnerNavigationBar(
              labels: labels,
              selectedIndex: tab,
              onSelected: (value) => setState(() => tab = value),
            ),
    );
  }

  Widget _reviewLanding() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildPageTitle(
        'Nhớ lâu, học nhẹ.',
        'Ôn từng thẻ và tự đánh giá mức độ ghi nhớ.',
      ),
      TextButton.icon(
        onPressed: () => open(
          'Từ cá nhân',
          PersonalWordsScreen(
            words: data.personalWords,
            saved: data.saved,
            notes: data.notes,
            nextId: () => 'personal:${++data.personalCounter}',
            onChanged: () => setState(() {}),
          ),
        ),
        icon: const Icon(Icons.library_add_outlined),
        label: const Text('Từ cá nhân của tôi'),
      ),

      TextButton.icon(
        onPressed: () => open(
          'Từ đã lưu',
          SavedWordsScreen(
            words: [...sampleVocabulary, ...data.personalWords],
            saved: data.saved,
            notes: data.notes,
            onChanged: () => setState(() {}),
          ),
        ),
        icon: const Icon(Icons.bookmarks_outlined),
        label: const Text('Quản lý từ đã lưu'),
      ),
      if (data.reviewSession != null && !data.reviewSession!.completed)
        Text(
          'Phiên đang dở: ${data.reviewSession!.index}/${data.reviewSession!.words.length} thẻ đã xem. Bộ thẻ được giữ khi tạm dừng.',
        ),
      const SizedBox(height: 24),
      PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.style_outlined, size: 42, color: brandTeal),
            const SizedBox(height: 20),
            Text(
              data.saved.isEmpty
                  ? 'Bộ ôn của bạn đang trống'
                  : '${data.saved.length} từ sẵn sàng xem thử',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bản mẫu chỉ giữ lựa chọn trong lần mở ứng dụng này. Lịch ôn thật sẽ được nối sau.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed:
                  data.saved.isEmpty &&
                      (data.reviewSession == null ||
                          data.reviewSession!.completed)
                  ? words
                  : () {
                      final session = data.startOrResumeReview();
                      if (session == null) {
                        words();
                        return;
                      }
                      open(
                        'Ôn tập',
                        ReviewScreen(
                          session: session,
                          onChanged: () => setState(() {}),
                        ),
                      );
                    },
              child: Text(
                data.saved.isEmpty &&
                        (data.reviewSession == null ||
                            data.reviewSession!.completed)
                    ? 'Chọn từ để ôn'
                    : data.reviewSession != null &&
                          !data.reviewSession!.completed
                    ? 'Tiếp tục phiên mẫu'
                    : 'Bắt đầu xem thẻ',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Bạn tự đánh giá, không phải điểm AI.',
        style: TextStyle(color: mutedText),
      ),
    ],
  );

  Widget _practice() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildPageTitle(
        'Học bằng cách làm',
        'Chọn một cách luyện phù hợp với hôm nay.',
      ),
      const SizedBox(height: 24),
      buildActionTile(
        Icons.draw_outlined,
        'Luyện viết chữ Hán',
        'Làm quen ô chữ và nét bút.',
        () => open('Chọn chữ', const WritingPickerScreen()),
      ),
      buildActionTile(
        Icons.document_scanner_outlined,
        'Đọc chữ trong ảnh',
        'Xem luồng chụp → đọc → lưu từ.',
        () => open(
          'Quét chữ',
          OcrScreen(
            history: data.scanHistory,
            personalWords: data.personalWords,
            nextPersonalId: () => 'personal:${++data.personalCounter}',
            saved: data.saved,
            notes: data.notes,
            onChanged: () => setState(() {}),
          ),
        ),
      ),
      buildActionTile(
        Icons.mic_none_rounded,
        'Hội thoại theo tình huống',
        'Bốn bối cảnh để vận dụng từ vựng.',
        () => open(
          'Hội thoại',
          ScenarioCatalogScreen(
            sessions: data.chatSessions,
            saved: data.saved,
            notes: data.notes,
            onChanged: () => setState(() {}),
          ),
        ),
      ),
      buildActionTile(
        Icons.headphones_outlined,
        'Thi thử nghe và đọc',
        'Xem cách làm bài và chọn đáp án.',
        () => open(
          'Thi thử',
          ExamCatalogScreen(
            attempts: data.examAttempts,
            onChanged: () => setState(() {}),
          ),
        ),
      ),
    ],
  );

  List<LocalActivity> _activities() => [
    for (var i = 0; i < data.reviewHistory.length; i++)
      LocalActivity(
        'Ôn tập',
        'Phiên ôn mẫu ${i + 1}',
        '${data.reviewHistory[i].ratings.length}/${data.reviewHistory[i].words.length} thẻ · ${data.reviewHistory[i].completed ? "Đã xem hết" : "Đang dở"}',
        data.reviewHistory[i].createdAt,
        () => open(
          'Ôn tập',
          ReviewScreen(
            session: data.reviewHistory[i],
            onChanged: () => setState(() {}),
          ),
        ),
      ),
    for (final scan in data.scanHistory)
      LocalActivity(
        'OCR',
        'Scan mẫu ${scan.number}',
        scan.hasImage ? 'Còn ảnh mẫu và văn bản' : 'Ảnh mẫu đã bỏ, văn bản còn',
        scan.createdAt,
        () => open(
          'Kết quả scan mẫu',
          OcrScreen(
            history: data.scanHistory,
            personalWords: data.personalWords,
            nextPersonalId: () => 'personal:${++data.personalCounter}',
            saved: data.saved,
            notes: data.notes,
            onChanged: () => setState(() {}),
            scan: scan,
          ),
        ),
      ),
    for (final chat in data.chatSessions)
      LocalActivity(
        'Hội thoại',
        '${chat.scenario.title} · phiên ${chat.number}',
        '${chat.turns.length}/8 lượt · ${chat.ended ? "Đã kết thúc" : "Đang dở"}',
        chat.createdAt,
        () => open(
          chat.scenario.title,
          ConversationScreen(
            session: chat,
            saved: data.saved,
            notes: data.notes,
            onChanged: () => setState(() {}),
          ),
        ),
      ),
    for (final exam in data.examAttempts)
      LocalActivity(
        'Thi',
        'Bài mẫu ${exam.number} · HSK ${exam.level}',
        exam.done
            ? 'Đã khóa · đúng ${exam.correct}/4'
            : 'Đang làm · ${exam.answers.length}/4 câu đã chọn',
        exam.createdAt,
        () => open(
          'Mini-test · HSK ${exam.level}',
          ExamRunnerScreen(attempt: exam, onChanged: () => setState(() {})),
        ),
      ),
  ];
  Widget _progress() => ProgressScreen(
    savedCount: data.saved.length,
    reviews: data.reviewHistory,
    scans: data.scanHistory,
    chats: data.chatSessions,
    exams: data.examAttempts,
    loadActivities: _activities,
    onLearn: () => setState(() => tab = 0),
  );
}
