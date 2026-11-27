import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/ui_tokens.dart';
import '../../shared/widgets/learner_surface.dart';
import '../../shared/widgets/presentation_helpers.dart';
import '../../shared/widgets/status_panel.dart';
import 'study_catalog_screen.dart';
import 'study_lesson.dart';
import 'study_preview.dart';
import 'study_tools_widgets.dart';

class StudyReminderScreen extends StatelessWidget {
  const StudyReminderScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      StudyDataView(builder: (data) => _ReminderForm(initial: data.reminder));
}

class _ReminderForm extends ConsumerStatefulWidget {
  const _ReminderForm({required this.initial});
  final StudyReminder initial;
  @override
  ConsumerState<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends ConsumerState<_ReminderForm> {
  late bool enabled = widget.initial.enabled;
  late TimeOfDay time = TimeOfDay(
    hour: widget.initial.hour,
    minute: widget.initial.minute,
  );
  late Set<int> days = widget.initial.weekdays.toSet();
  bool saving = false;
  String? message;

  Future<void> save() async {
    if (saving || days.isEmpty) return;
    setState(() {
      saving = true;
      message = null;
    });
    final saved = await saveStudyUpdate(
      context,
      ref,
      (data) => data.copyWith(
        reminder: StudyReminder(
          enabled: enabled,
          hour: time.hour,
          minute: time.minute,
          weekdays: days.toList()..sort(),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        saving = false;
        if (saved) message = 'Đã lưu lịch trên thiết bị.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle('Nhắc lịch học', 'Chọn các ngày và giờ bạn muốn học.'),
      const SizedBox(height: 20),
      LearnerSplit(
        main: LearnerSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bật lịch nhắc'),
                  value: enabled,
                  onChanged: saving
                      ? null
                      : (value) => setState(() {
                          enabled = value;
                          message = null;
                        }),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: saving
                    ? null
                    : () async {
                        final selected = await showTimePicker(
                          context: context,
                          initialTime: time,
                          helpText: 'Chọn giờ học',
                          cancelText: 'Hủy',
                          confirmText: 'Chọn giờ',
                        );
                        if (selected != null && mounted) {
                          setState(() {
                            time = selected;
                            message = null;
                          });
                        }
                      },
                icon: const Icon(Icons.schedule),
                label: Text('Giờ học · ${time.format(context)}'),
              ),
              const SizedBox(height: 16),
              const Text('Ngày trong tuần'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(day == 7 ? 'Chủ nhật' : 'Thứ ${day + 1}'),
                      selected: days.contains(day),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: saving
                          ? null
                          : (value) => setState(() {
                              value ? days.add(day) : days.remove(day);
                              message = null;
                            }),
                    ),
                ],
              ),
              if (days.isEmpty) const Text('Chọn ít nhất một ngày.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: saving || days.isEmpty ? null : save,
                child: Text(saving ? 'Đang lưu…' : 'Lưu lịch học'),
              ),
              if (message case final text?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(liveRegion: true, child: Text(text)),
                ),
            ],
          ),
        ),
        aside: const StatusPanel(
          icon: Icons.notifications_off_outlined,
          title: 'Thông báo thiết bị chưa kết nối',
          message: 'Bạn có thể lưu giờ học. Bản này chưa gửi thông báo vào giờ đã chọn.',
        ),
      ),
    ],
  );
}

class StudyOfflineScreen extends ConsumerWidget {
  const StudyOfflineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => StudyDataView(
    builder: (data) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Gói bài học offline',
          'Lưu gói mẫu từ nội dung đi kèm ứng dụng.',
        ),
        const SizedBox(height: 20),
        for (var level = 1; level <= 3; level++) ...[
          _OfflinePackTile(
            level: level,
            saved: data.offlineLevels.contains(level),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Trên Web, trình duyệt cần giữ dữ liệu trang. Phần nghe cần giọng Quan thoại có sẵn trên thiết bị.',
        ),
      ],
    ),
  );
}

class _OfflinePackTile extends ConsumerWidget {
  const _OfflinePackTile({required this.level, required this.saved});
  final int level;
  final bool saved;
  @override
  Widget build(BuildContext context, WidgetRef ref) => LearnerSurface(
    color: saved ? softSurface : Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gói mẫu HSK $level',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          '${studyLessons.where((lesson) => lesson.level == level).length} bài · ${saved ? 'Đã lưu trên thiết bị' : 'Chưa lưu'}',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (saved)
              FilledButton.tonal(
                onPressed: () => context.push('/profile/offline/$level'),
                child: const Text('Mở gói'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => _save(context, ref, true),
                icon: const Icon(Icons.save_alt),
                label: const Text('Lưu gói mẫu'),
              ),
            if (saved)
              TextButton(
                onPressed: () => _save(context, ref, false),
                child: const Text('Gỡ gói'),
              ),
          ],
        ),
      ],
    ),
  );

  Future<void> _save(BuildContext context, WidgetRef ref, bool add) =>
      saveStudyUpdate(
        context,
        ref,
        (data) => data.copyWith(
          offlineLevels: [
            ...data.offlineLevels.where((item) => item != level),
            if (add) level,
          ],
        ),
      );
}

class StudyOfflinePackScreen extends StatelessWidget {
  const StudyOfflinePackScreen({required this.level, super.key});
  final int? level;
  @override
  Widget build(BuildContext context) => StudyDataView(
    builder: (data) => data.offlineLevels.contains(level)
        ? StudyCatalogScreen(key: ValueKey(level), offlineLevel: level)
        : StatusPanel(
            icon: Icons.download_outlined,
            title: 'Gói chưa lưu trên thiết bị',
            message: 'Chọn một gói mẫu để lưu trước.',
            actionLabel: 'Về gói học offline',
            onAction: () => context.go('/profile/offline'),
          ),
  );
}
