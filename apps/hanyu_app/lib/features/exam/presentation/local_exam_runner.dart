import '../../../shared/ui_tokens.dart';
import '../../../shared/widgets/learner_surface.dart';
import '../../support/presentation/report_content_button.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:doanchuyennganh2/app/local/local_drafts.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';
import 'package:doanchuyennganh2/features/exam/presentation/question_choices.dart';
import 'package:doanchuyennganh2/shared/widgets/async_commit_button.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class LocalExamRunner extends ConsumerStatefulWidget {
  const LocalExamRunner({
    required this.attempt,
    required this.revision,
    super.key,
  });
  final LocalExamAttempt attempt;
  final int revision;
  @override
  ConsumerState<LocalExamRunner> createState() => _LocalExamRunnerState();
}

class _LocalExamRunnerState extends ConsumerState<LocalExamRunner>
    with WidgetsBindingObserver {
  late final LocalDrafts drafts;
  late final Timer timer;
  late int? pending = widget.attempt.answers[widget.attempt.position];
  bool busy = false, expiring = false;
  String? error;
  bool get dirty => pending != widget.attempt.answers[widget.attempt.position];
  int get remaining =>
      widget.attempt.remainingSeconds(ref.read(localClockProvider)());
  @override
  void initState() {
    super.initState();
    drafts = ref.read(localDraftsProvider);
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remaining == 0) {
        unawaited(expire());
      } else {
        setState(() {});
      }
    });
    Future.microtask(() => expireIfDue());
  }

  Future<void> expireIfDue() async {
    if (mounted && remaining == 0) await expire();
  }

  Future<void> expire() async {
    if (!mounted || expiring) return;
    setState(() => expiring = true);
    try {
      await ref.read(localControllerProvider.notifier).reload();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Chưa khóa được bài trên thiết bị. Thử tải lại; không tính đáp án chưa lưu.',
        );
      }
    } finally {
      if (mounted) setState(() => expiring = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(expireIfDue());
  }

  @override
  void didUpdateWidget(covariant LocalExamRunner old) {
    super.didUpdateWidget(old);
    final hadDraft = pending != old.attempt.answers[old.attempt.position];
    if (old.attempt.position != widget.attempt.position ||
        old.attempt.id != widget.attempt.id ||
        !hadDraft) {
      pending = widget.attempt.answers[widget.attempt.position];
      error = null;
    }
  }

  @override
  void dispose() {
    timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    drafts.clear(this);
    super.dispose();
  }

  void saving(bool value) {
    if (mounted) setState(() => busy = value);
  }

  Future<void> move(int index, String operationId) => ref
      .read(localControllerProvider.notifier)
      .commit(
        (r) => r.moveExam(
          widget.attempt.id,
          index,
          revision: widget.revision,
          operationId: operationId,
        ),
      );
  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt,
        index = attempt.position,
        question = attempt.questions[index];
    drafts.update(this, changed: dirty, saving: busy || expiring);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Luyện đọc · câu ${index + 1}/${attempt.questions.length}',
          'Đáp án chưa lưu không được tính khi nộp hoặc hết giờ.',
        ),
        const SizedBox(height: 16),
        LearnerSurface(
          color: softSurface,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')} còn lại',
                style: const TextStyle(
                  fontSize: 19,
                  color: brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${attempt.answers.length}/${attempt.questions.length} đáp án đã lưu',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: (index + 1) / attempt.questions.length,
          minHeight: 5,
          borderRadius: BorderRadius.circular(3),
          backgroundColor: surfaceBorder,
          semanticsLabel: 'Tiến độ bài luyện đọc',
        ),
        const SizedBox(height: 24),
        LearnerSplit(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LearnerSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      question.prompt,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ReportContentButton(
                      contentId: question.id,
                      version: attempt.packageVersion,
                      label: 'Luyện đọc · câu ${index + 1}',
                      route: '/exams/attempts/${attempt.id}',
                      enabled: !busy && !expiring,
                    ),
                    const SizedBox(height: 20),
                    QuestionChoices(
                      choices: question.choices,
                      selected: pending,
                      enabled: !busy && !expiring && remaining > 0,
                      onSelected: (value) => setState(() {
                        pending = value;
                        error = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                dirty
                    ? 'Đáp án đang chọn chưa lưu.'
                    : attempt.answers.containsKey(index)
                    ? 'Đáp án câu này đã lưu.'
                    : 'Câu này chưa có đáp án đã lưu.',
              ),
              const SizedBox(height: 12),
              AsyncCommitButton(
                label: 'Lưu đáp án',
                enabled: dirty && !busy && !expiring && remaining > 0,
                intentKey: 'answer:${attempt.id}:$index:$pending',
                onBusyChanged: saving,
                onCommit: (operationId) async {
                  final chosen = pending;
                  await ref
                      .read(localControllerProvider.notifier)
                      .commit(
                        (r) => r.saveExamAnswer(
                          attempt.id,
                          index,
                          chosen,
                          revision: widget.revision,
                          operationId: operationId,
                        ),
                      );
                },
              ),
              TextButton(
                onPressed: busy || expiring
                    ? null
                    : () => setState(() => pending = null),
                child: const Text('Bỏ lựa chọn câu này'),
              ),
            ],
          ),
          aside: LearnerSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Danh sách câu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (dirty)
                  const Text('Lưu đáp án trước khi chuyển câu hoặc nộp bài.'),
                if (!dirty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < attempt.questions.length; i++)
                        SizedBox(
                          width: 72,
                          child: AsyncCommitButton(
                            compact: true,
                            label:
                                '${i + 1}${attempt.answers.containsKey(i) ? ' ✓' : ''}',
                            enabled: !busy && !expiring && i != index,
                            intentKey: 'move:${attempt.id}:$i',
                            onBusyChanged: saving,
                            onCommit: (operationId) => move(i, operationId),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                AsyncCommitButton(
                  label: 'Nộp bài luyện đọc',
                  enabled: !dirty && !busy && !expiring,
                  intentKey: 'submit:${attempt.id}',
                  onBusyChanged: saving,
                  onCommit: (operationId) async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                        title: const Text('Nộp và khóa bài?'),
                        content: Text(
                          'Đã lưu ${attempt.answers.length}/${attempt.questions.length} đáp án. ${attempt.blanks} câu còn trống sẽ không có điểm. Sau nộp không sửa được.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, false),
                            child: const Text('Quay lại làm tiếp'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialog, true),
                            child: const Text('Xác nhận nộp'),
                          ),
                        ],
                      ),
                    );
                    if (yes != true) return;
                    await ref
                        .read(localControllerProvider.notifier)
                        .commit(
                          (r) => r.submitExam(
                            attempt.id,
                            revision: widget.revision,
                            operationId: operationId,
                          ),
                        );
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: busy || expiring
                      ? null
                      : () => context.go('/exams'),
                  child: const Text('Rời bài, giữ đáp án đã lưu'),
                ),
                AsyncCommitButton(
                  label: 'Tải lại bài đã lưu, giữ lựa chọn',
                  intentKey: 'refresh:${attempt.id}:${widget.revision}',
                  enabled: !busy && !expiring,
                  onBusyChanged: saving,
                  onCommit: (_) =>
                      ref.read(localControllerProvider.notifier).reload(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(error!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
