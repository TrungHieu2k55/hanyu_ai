import '../../../shared/widgets/pronunciation_button.dart';
import '../../vocabulary/domain/vocabulary_item.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/review/domain/local_review.dart';
import 'package:doanchuyennganh2/features/review/domain/sm2.dart';
import 'package:doanchuyennganh2/shared/widgets/async_commit_button.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/hanzi_focus.dart';
import 'package:doanchuyennganh2/shared/widgets/learner_surface.dart';

class LocalReviewLanding extends ConsumerWidget {
  const LocalReviewLanding({required this.data, super.key});
  final LocalSnapshot data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = data.review.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Nhớ lâu, học nhẹ.',
          'Ôn từ đến hạn theo SM-2. Lịch và phiên đang dở được lưu trên thiết bị.',
        ),
        const SizedBox(height: 24),
        LearnerSurface(
          color: softSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${data.review.dueCount} từ đến hạn',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (active != null) ...[
                Text(
                  'Phiên đang dở: ${active.position}/${active.cards.length} thẻ.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/review/session/${active.id}'),
                  child: const Text('Tiếp tục phiên ôn'),
                ),
              ] else if (data.review.dueCount > 0)
                AsyncCommitButton(
                  label: 'Bắt đầu ôn từ đến hạn',
                  intentKey: 'start:${data.revision}',
                  onCommit: (operationId) async {
                    await ref
                        .read(localControllerProvider.notifier)
                        .commit(
                          (r) => r.startReview(
                            revision: data.revision,
                            operationId: operationId,
                          ),
                        );
                    if (!context.mounted) return;
                    final session = ref
                        .read(localControllerProvider)
                        .requireValue
                        .review
                        .active;
                    if (session != null) {
                      context.push('/review/session/${session.id}');
                    }
                  },
                )
              else
                const Text(
                  'Chưa có từ đến hạn. Có thể xem lại bộ từ; xem lại không thay lịch ôn.',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AsyncCommitButton(
          label: 'Cập nhật hạn ôn',
          intentKey: 'refresh:${data.revision}',
          onCommit: (_) => ref.read(localControllerProvider.notifier).reload(),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push('/saved'),
          child: const Text('Quản lý từ đã lưu'),
        ),
        const SizedBox(height: 24),
        Text('${data.review.eventCount} lượt tự đánh giá đã lưu'),
        const SizedBox(height: 16),
        for (final session in data.review.sessions.where((s) => s.completed))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Phiên ôn · ${session.cards.length} thẻ'),
            subtitle: Text('Đã hoàn thành · ${session.createdAt.toLocal()}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/review/session/${session.id}'),
          ),
        const SizedBox(height: 24),
        buildSectionHeading('Từ trong bộ ôn'),
        for (final word in data.words.where((w) => w.saved))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(word.entry.hanzi, style: const TextStyle(fontSize: 24)),
            subtitle: Text(word.entry.pinyin),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('/words/${Uri.encodeComponent(word.entry.id)}'),
          ),
      ],
    );
  }
}

class LocalReviewScreen extends ConsumerStatefulWidget {
  const LocalReviewScreen({
    required this.session,
    required this.revision,
    required this.soundEnabled,
    super.key,
  });
  final LocalReviewSession session;
  final int revision;
  final bool soundEnabled;
  @override
  ConsumerState<LocalReviewScreen> createState() => _LocalReviewScreenState();
}

class _LocalReviewScreenState extends ConsumerState<LocalReviewScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session.completed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Đã hoàn thành phiên ôn',
            '${session.cards.length} lượt tự đánh giá đã lưu. Đây không phải tỷ lệ đúng hay điểm năng lực.',
          ),
          const SizedBox(height: 24),
          for (final rating in MemoryRating.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(rating.label),
              trailing: Text(
                '${session.qualities.where((q) => q == rating.quality).length}',
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/review'),
            child: const Text('Về lịch ôn'),
          ),
        ],
      );
    }
    final word = session.cards[session.position];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Ôn tập',
          'Thẻ ${session.position + 1} / ${session.cards.length}',
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: (session.position + 1) / session.cards.length,
          minHeight: 5,
          borderRadius: BorderRadius.circular(3),
          backgroundColor: surfaceBorder,
          semanticsLabel: 'Tiến độ ôn tập',
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 6,
          children: [
            const Text(
              'TỪ ĐÃ LƯU',
              style: TextStyle(
                color: brandTeal,
                fontWeight: FontWeight.w600,
                letterSpacing: .7,
              ),
            ),
            Text(session.revealed ? 'Đối chiếu đáp án' : 'Gợi nhớ chủ động'),
          ],
        ),
        const SizedBox(height: 16),
        _ReviewFace(
          word: word,
          revealed: session.revealed,
          soundEnabled: widget.soundEnabled,
        ),
        const SizedBox(height: 16),
        if (!session.revealed)
          AsyncCommitButton(
            label: 'Lật thẻ xem nghĩa',
            intentKey: 'reveal:${session.id}:${session.position}',
            enabled: !busy,
            onBusyChanged: (v) {
              if (mounted) setState(() => busy = v);
            },
            onCommit: (id) => ref
                .read(localControllerProvider.notifier)
                .commit(
                  (r) => r.revealReview(
                    session.id,
                    session.position,
                    revision: widget.revision,
                    operationId: id,
                  ),
                ),
          )
        else ...[
          const Text(
            'Bạn nhớ từ này đến đâu?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 285 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 21
                  ? 4
                  : 2;
              return Wrap(
                spacing: 8,
                runSpacing: 12,
                children: [
                  for (final rating in MemoryRating.values)
                    SizedBox(
                      width:
                          (constraints.maxWidth - 8 * (columns - 1)) / columns,
                      child: AsyncCommitButton(
                        key: ValueKey(
                          '${session.id}:${session.position}:${rating.quality}',
                        ),
                        label: rating.label,
                        compact: true,
                        enabled: !busy,
                        intentKey:
                            'rate:${session.id}:${session.position}:${rating.quality}',
                        onBusyChanged: (v) {
                          if (mounted) setState(() => busy = v);
                        },
                        onCommit: (id) => ref
                            .read(localControllerProvider.notifier)
                            .commit(
                              (r) => r.rateReview(
                                session.id,
                                session.position,
                                rating,
                                revision: widget.revision,
                                operationId: id,
                              ),
                            ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Chọn mức sát với lần nhớ vừa rồi.',
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: busy ? null : () => context.go('/review'),
          child: const Text('Tạm dừng phiên ôn'),
        ),
      ],
    );
  }
}

class _ReviewFace extends StatelessWidget {
  const _ReviewFace({
    required this.word,
    required this.revealed,
    required this.soundEnabled,
  });
  final VocabularyItem word;
  final bool revealed;
  final bool soundEnabled;

  @override
  Widget build(BuildContext context) => LearnerSurface(
    color: revealed ? Colors.white : brandInk,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          revealed ? 'MẶT ĐÁP ÁN' : 'MẶT TRƯỚC',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: revealed ? brandTeal : softSurface,
          ),
        ),
        SizedBox(height: revealed ? 10 : 32),
        Center(
          child: HanziFocus(
            word.hanzi,
            dark: !revealed,
            size: revealed ? 56 : 72,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: PronunciationButton(
            hanzi: word.hanzi,
            soundEnabled: soundEnabled,
          ),
        ),
        const SizedBox(height: 8),
        if (!revealed) ...[
          const Text(
            'Thử nhớ nghĩa tiếng Việt.',
            textAlign: TextAlign.center,
            style: TextStyle(color: softSurface),
          ),
          const SizedBox(height: 24),
        ] else ...[
          Text(
            word.pinyin,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              color: brandTeal,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            word.vietnamese,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          if (word.exampleHanzi.isNotEmpty ||
              word.exampleVietnamese.isNotEmpty) ...[
            const SizedBox(height: 16),
            LearnerSurface(
              color: softSurface,
              child: Column(
                children: [
                  if (word.exampleHanzi.isNotEmpty)
                    Text(
                      word.exampleHanzi,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        color: brandInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (word.exampleVietnamese.isNotEmpty)
                    Text(word.exampleVietnamese, textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ],
      ],
    ),
  );
}
