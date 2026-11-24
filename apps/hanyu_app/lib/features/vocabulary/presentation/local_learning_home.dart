import 'package:doanchuyennganh2/shared/widgets/figma_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/local/local_models.dart';
import '../../../shared/ui_tokens.dart';
import '../../../shared/widgets/hanzi_focus.dart';
import '../../../shared/widgets/learner_surface.dart';
import '../../../shared/widgets/pronunciation_button.dart';
import '../../content/application/learning_catalog.dart';
import '../../progress/domain/local_learning_stats.dart';
import 'local_vocabulary_screen.dart';

class LocalLearningHome extends StatelessWidget {
  const LocalLearningHome({required this.data, required this.now, super.key});
  final LocalSnapshot data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final saved = {
      for (final w in data.words)
        if (w.saved) w.entry.id,
    };
    final stats = localLearningStats(data.review.events, saved, now);
    final words = catalogWords(data).toList(growable: false);
    final featured = words.length < 2
        ? null
        : words.where((w) => w.entry.hanzi == '朋友').firstOrNull ?? words.first;
    final featuredCard = featured == null
        ? null
        : _FeaturedWord(featured, soundEnabled: data.preferences.sound);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final reviewAndPractice = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NextReview(data: data),
        const SizedBox(height: 16),
        const _PracticeShortcuts(),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'KẾ HOẠCH HÔM NAY',
              style: TextStyle(
                color: mutedText,
                fontSize: 12,
                letterSpacing: .7,
              ),
            ),
            if (stats.currentStreak > 0) StudyStreak(stats.currentStreak),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Học đều, nhớ lâu.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        if (!wide)
          _NextReview(data: data)
        else if (featuredCard == null)
          reviewAndPractice
        else
          LearnerSplit(main: reviewAndPractice, aside: featuredCard),
        SizedBox(height: wide ? 24 : 16),
        LocalVocabularyScreen(
          data: data,
          embedded: true,
          afterSearch: wide
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _PracticeShortcuts(),
                    if (featuredCard != null) ...[
                      const SizedBox(height: 16),
                      featuredCard,
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _NextReview extends StatelessWidget {
  const _NextReview({required this.data});
  final LocalSnapshot data;
  @override
  Widget build(BuildContext context) {
    final active = data.review.active;
    final count = data.review.dueCount;
    return LearnerSurface(
      color: brandTeal,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ÔN TẬP HÔM NAY',
                  style: TextStyle(
                    color: softSurface,
                    fontSize: 12,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  active == null ? '$count thẻ đến hạn' : 'Tiếp tục phiên ôn',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  active == null
                      ? (count == 0
                            ? 'Xem lại bộ từ đã lưu'
                            : 'Gặp lại từ đã học')
                      : '${active.position}/${active.cards.length} thẻ đã ôn',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: brandInk,
                  ),
                  onPressed: () => context.go(
                    active == null ? '/review' : '/review/session/${active.id}',
                  ),
                  child: Text(
                    active != null
                        ? 'Tiếp tục ôn'
                        : count > 0
                        ? 'Bắt đầu ôn'
                        : 'Xem lịch ôn',
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.textScalerOf(context).scale(14) <= 17) ...[
            const SizedBox(width: 12),
            Transform.rotate(
              angle: .11,
              child: const ExcludeSemantics(
                child: LearnerSurface(
                  color: softSurface,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Column(
                    children: [
                      SizedBox(width: 58, child: HanziFocus('人', size: 39)),
                      Text(
                        'rén',
                        style: TextStyle(color: brandInk, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PracticeShortcuts extends StatelessWidget {
  const _PracticeShortcuts();
  static const shortcuts = [
    (FigmaGlyph.practice, 'Viết chữ', '/writing'),
    (FigmaGlyph.camera, 'Chụp chữ', '/photos'),
    (FigmaGlyph.conversation, 'Hội thoại', '/conversations'),
    (FigmaGlyph.headphones, 'Thi thử', '/exams'),
  ];
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Luyện tập', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (MediaQuery.textScalerOf(context).scale(14) > 21)
        for (final (index, shortcut) in shortcuts.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          _Shortcut(shortcut),
        ]
      else
        for (var i = 0; i < shortcuts.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Shortcut(shortcuts[i])),
                const SizedBox(width: 12),
                Expanded(child: _Shortcut(shortcuts[i + 1])),
              ],
            ),
          ),
        ],
    ],
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.data);
  final (FigmaGlyph, String, String) data;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => context.push(data.$3),
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      side: const BorderSide(color: controlBorder),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: softSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: SizedBox.square(dimension: 20, child: FigmaIcon(data.$1)),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(data.$2, style: const TextStyle(color: brandInk)),
        ),
      ],
    ),
  );
}

class _FeaturedWord extends StatelessWidget {
  const _FeaturedWord(this.word, {required this.soundEnabled});
  final LocalWord word;
  final bool soundEnabled;
  @override
  Widget build(BuildContext context) => LearnerSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TỪ HÔM NAY',
          style: TextStyle(fontSize: 12, letterSpacing: .8, color: brandTeal),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 14,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  HanziFocus(word.entry.hanzi, size: 34),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.entry.pinyin,
                        style: const TextStyle(color: brandTeal),
                      ),
                      Text(
                        word.entry.vietnamese,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PronunciationButton(
              hanzi: word.entry.hanzi,
              soundEnabled: soundEnabled,
            ),
          ],
        ),
        if (word.entry.exampleHanzi.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(word.entry.exampleHanzi),
          Text(word.entry.exampleVietnamese),
        ],
        TextButton(
          onPressed: () =>
              context.push('/words/${Uri.encodeComponent(word.entry.id)}'),
          child: const Text('Xem mục từ'),
        ),
      ],
    ),
  );
}
