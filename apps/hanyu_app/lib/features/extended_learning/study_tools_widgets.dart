import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/status_panel.dart';
import 'study_preview.dart';
import 'study_preview_controller.dart';

class StudyDataView extends ConsumerWidget {
  const StudyDataView({required this.builder, super.key});
  final Widget Function(StudyPreview) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(studyPreviewProvider)
      .when(
        data: builder,
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: LinearProgressIndicator(
            semanticsLabel: 'Đang đọc dữ liệu học',
          ),
        ),
        error: (_, _) => StatusPanel(
          icon: Icons.refresh,
          title: 'Chưa đọc được dữ liệu học',
          message: 'Thử tải lại dữ liệu trên thiết bị.',
          actionLabel: 'Thử lại',
          onAction: () => ref.invalidate(studyPreviewProvider),
        ),
      );
}

Future<bool> saveStudyUpdate(
  BuildContext context,
  WidgetRef ref,
  StudyPreview Function(StudyPreview) change,
) async {
  try {
    await ref.read(studyPreviewProvider.notifier).updatePreview(change);
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa lưu được thay đổi. Hãy thử lại.')),
      );
    }
    return false;
  }
}
