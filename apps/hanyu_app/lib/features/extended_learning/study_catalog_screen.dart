import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/ui_tokens.dart';
import '../../shared/widgets/learner_surface.dart';
import '../../shared/widgets/presentation_helpers.dart';
import '../../shared/widgets/status_panel.dart';
import 'study_lesson.dart';

IconData studyIcon(StudyKind kind) => switch (kind) {
  StudyKind.pinyin => Icons.graphic_eq,
  StudyKind.radical => Icons.grid_view_outlined,
  StudyKind.grammar => Icons.menu_book_outlined,
  StudyKind.sentenceOrder => Icons.view_stream_outlined,
  StudyKind.pronunciation => Icons.mic_none,
  StudyKind.dictation => Icons.headphones_outlined,
};

class StudyCatalogScreen extends StatefulWidget {
  const StudyCatalogScreen({this.offlineLevel, super.key});
  final int? offlineLevel;

  @override
  State<StudyCatalogScreen> createState() => _StudyCatalogScreenState();
}

class _StudyCatalogScreenState extends State<StudyCatalogScreen> {
  int? level;
  StudyKind? kind;

  @override
  Widget build(BuildContext context) {
    final fixedLevel = widget.offlineLevel;
    final lessons = studyLessons
        .where(
          (lesson) =>
              ((fixedLevel ?? level) == null ||
                  lesson.level == (fixedLevel ?? level)) &&
              (kind == null || lesson.kind == kind),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          fixedLevel == null
              ? 'Bài luyện tiếng Trung'
              : 'Gói mẫu HSK $fixedLevel',
          'Học liệu mẫu trên thiết bị.',
        ),
        const SizedBox(height: 20),
        LearnerSplit(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fixedLevel == null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in <int?>[null, 1, 2, 3])
                      ChoiceChip(
                        label: Text(
                          option == null ? 'Tất cả cấp' : 'HSK $option',
                        ),
                        selected: level == option,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: (_) => setState(() => level = option),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (lessons.isEmpty)
                StatusPanel(
                  icon: Icons.search_off,
                  title: 'Chưa có bài mẫu phù hợp',
                  message: 'Đổi cấp hoặc chọn một dạng bài khác.',
                  actionLabel: 'Bỏ lọc dạng bài',
                  onAction: () => setState(() => kind = null),
                )
              else
                for (final lesson in lessons) ...[
                  buildActionTile(
                    studyIcon(lesson.kind),
                    lesson.title,
                    '${lesson.kind.label} · HSK ${lesson.level}',
                    () => context.push('/practice/lessons/${lesson.id}'),
                  ),
                  const Divider(height: 1),
                ],
            ],
          ),
          sidebarFirstOnNarrow: true,
          aside: LearnerSurface(
            color: softSurface,
            child: DropdownButtonFormField<StudyKind?>(
              initialValue: kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Dạng bài'),
              items: [
                const DropdownMenuItem<StudyKind?>(
                  value: null,
                  child: Text('Tất cả dạng bài'),
                ),
                for (final option in StudyKind.values)
                  DropdownMenuItem<StudyKind?>(
                    value: option,
                    child: Text(option.label),
                  ),
              ],
              onChanged: (value) => setState(() => kind = value),
            ),
          ),
        ),
      ],
    );
  }
}
