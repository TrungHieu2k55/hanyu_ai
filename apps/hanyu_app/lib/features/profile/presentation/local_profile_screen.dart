import 'dart:convert';

import '../domain/local_profile.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/app/local/local_drafts.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/shared/widgets/async_commit_button.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class LocalProfileScreen extends ConsumerStatefulWidget {
  const LocalProfileScreen({required this.data, super.key});
  final LocalSnapshot data;
  @override
  ConsumerState<LocalProfileScreen> createState() => _LocalProfileScreenState();
}

class _LocalProfileScreenState extends ConsumerState<LocalProfileScreen> {
  late final LocalDrafts drafts;
  @override
  void initState() {
    super.initState();
    drafts = ref.read(localDraftsProvider);
  }

  late final name = TextEditingController(text: widget.data.preferences.name);
  late int level = widget.data.preferences.level,
      minutes = widget.data.preferences.minutes;
  late bool sound = widget.data.preferences.sound;
  late int revision = widget.data.revision;
  late String saved = intent;
  late LocalProfile savedProfile = LocalProfile.fromPreferences(
    widget.data.preferences,
  );
  bool busy = false, conflict = false;
  int resetGeneration = 0;

  void cancelChanges() {
    setState(() {
      name.text = savedProfile.name;
      level = savedProfile.level;
      minutes = savedProfile.minutes;
      sound = savedProfile.sound;
      saved = intent;
      message = null;
      resetGeneration++;
    });
  }

  String? message;
  String get intent => jsonEncode([name.text, level, minutes, sound]);
  @override
  void dispose() {
    drafts.clear(this);
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    drafts.update(this, changed: saved != intent, saving: busy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Hồ sơ và nhịp học',
          'Thiết lập trên thiết bị, chưa liên kết tài khoản.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: name,
          enabled: !busy,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Tên hiển thị'),
          onChanged: (_) => setState(() => message = null),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: ValueKey('level:$resetGeneration'),
          initialValue: level,
          decoration: const InputDecoration(labelText: 'Mục tiêu HSK'),
          items: [
            for (final n in [1, 2, 3])
              DropdownMenuItem(value: n, child: Text('HSK $n')),
          ],
          onChanged: busy
              ? null
              : (v) => setState(() {
                  level = v!;
                  message = null;
                }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: ValueKey('minutes:$resetGeneration'),
          initialValue: minutes,
          decoration: const InputDecoration(labelText: 'Phút học mỗi ngày'),
          items: [
            for (final n in LocalProfile.dailyMinutes)
              DropdownMenuItem(value: n, child: Text('$n phút')),
          ],
          onChanged: busy
              ? null
              : (v) => setState(() {
                  minutes = v!;
                  message = null;
                }),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Âm thanh bài học'),
          value: sound,
          onChanged: busy
              ? null
              : (v) => setState(() {
                  sound = v;
                  message = null;
                }),
        ),
        const SizedBox(height: 20),
        AsyncCommitButton(
          label: 'Lưu cài đặt',
          intentKey: '$revision:$intent',
          onBusyChanged: (v) {
            if (mounted) setState(() => busy = v);
          },
          onCommit: (operationId) async {
            final profile = LocalProfile(
              name: name.text,
              level: level,
              minutes: minutes,
              sound: sound,
            );
            try {
              await ref
                  .read(localControllerProvider.notifier)
                  .commit(
                    (r) => r.saveProfile(
                      profile,
                      revision: revision,
                      operationId: operationId,
                    ),
                  );
            } on LocalConflict {
              if (mounted) setState(() => conflict = true);
              rethrow;
            }
            if (mounted) {
              setState(() {
                revision = ref
                    .read(localControllerProvider)
                    .requireValue
                    .revision;
                savedProfile = profile.validated();
                name.text = savedProfile.name;
                saved = intent;
                conflict = false;
                message = 'Đã lưu cài đặt trên thiết bị.';
              });
            }
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy || saved == intent ? null : cancelChanges,
          child: const Text('Hủy thay đổi'),
        ),
        if (conflict) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await ref.read(localControllerProvider.notifier).reload();
                      if (!mounted) return;
                      final fresh = ref
                          .read(localControllerProvider)
                          .requireValue;
                      setState(() {
                        revision = fresh.revision;
                        savedProfile = LocalProfile.fromPreferences(
                          fresh.preferences,
                        );
                        saved = jsonEncode([
                          savedProfile.name,
                          savedProfile.level,
                          savedProfile.minutes,
                          savedProfile.sound,
                        ]);
                        conflict = false;
                        message = 'Đã tải bản mới. Kiểm tra nội dung đang sửa trước khi lưu lại.';
                      });
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => message =
                              'Chưa tải được. Nội dung đang sửa vẫn được giữ.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: const Text('Tải bản mới, giữ nội dung đang sửa'),
          ),
        ],
        if (message != null) ...[
          const SizedBox(height: 16),
          Semantics(liveRegion: true, child: Text(message!)),
        ],
      ],
    );
  }
}
