import 'package:doanchuyennganh2/shared/widgets/learner_navigation_bar.dart';
import 'package:doanchuyennganh2/shared/widgets/status_panel.dart';
import 'package:doanchuyennganh2/shared/widgets/figma_icon.dart';

import '../../features/practice/presentation/local_practice_home.dart';
import '../../features/profile/presentation/local_profile_home.dart';
import '../../features/vocabulary/presentation/local_learning_home.dart';
import '../../features/content/presentation/local_catalog_screen.dart';
import '../../features/content/application/learning_catalog.dart';
import '../../features/support/domain/local_feedback.dart';
import '../../features/support/presentation/local_feedback_screen.dart';
import '../../features/support/presentation/local_help_screen.dart';
import '../../features/practice/domain/local_practice.dart';
import '../../features/practice/presentation/practice_catalog.dart';
import '../../features/practice/presentation/local_writing.dart';
import '../../features/practice/presentation/local_photo.dart';
import '../../features/practice/presentation/local_conversation.dart';

import 'package:doanchuyennganh2/features/exam/presentation/local_exam_catalog.dart';
import 'package:doanchuyennganh2/features/exam/presentation/local_exam_instructions.dart';
import 'package:doanchuyennganh2/features/exam/presentation/local_exam_runner.dart';
import 'package:doanchuyennganh2/features/exam/presentation/local_exam_result.dart';
import 'package:doanchuyennganh2/features/progress/presentation/local_progress_screen.dart';
import 'package:doanchuyennganh2/features/review/presentation/local_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/onboarding/presentation/guest_preview_screen.dart';
import 'package:doanchuyennganh2/features/settings/presentation/device_permission_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:doanchuyennganh2/app/learner_shell.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/core/theme/app_theme.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/local_vocabulary_screen.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/local_word_detail.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/local_word_editor.dart';
import 'package:doanchuyennganh2/features/settings/presentation/local_settings_screen.dart';
import 'package:doanchuyennganh2/features/settings/presentation/local_data_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/brand_mark.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

import 'local_drafts.dart';
import 'local_providers.dart';

final Provider<GoRouter> localRouterProvider = Provider<GoRouter>((ref) {
  Widget page(Widget Function(LocalSnapshot data) build) =>
      _LocalDataPage(builder: build);
  GoRoute route(
    String path,
    Widget Function(BuildContext, GoRouterState) build,
  ) => GoRoute(
    path: path,
    onExit: (context, state) => ref.read(localDraftsProvider).mayLeave(context),
    builder: build,
  );
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/learn',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/learn'),
      ShellRoute(
        builder: (context, state, child) =>
            _LocalShell(path: state.uri.path, child: child),
        routes: [
          route(
            '/learn',
            (_, _) => page(
              (d) => LocalLearningHome(
                data: d,
                now: ref.read(localClockProvider)(),
              ),
            ),
          ),
          route(
            '/learn/words',
            (_, _) => page((d) => LocalVocabularyScreen(data: d)),
          ),
          route('/review', (_, _) => page((d) => LocalReviewLanding(data: d))),
          route(
            '/saved',
            (_, _) =>
                page((d) => LocalVocabularyScreen(data: d, savedOnly: true)),
          ),
          route(
            '/review/session/:id',
            (_, state) => page((d) {
              final session = d.review.find(state.pathParameters['id']!);
              return session == null
                  ? const Text('Không tìm thấy phiên ôn.')
                  : LocalReviewScreen(
                      key: ValueKey(session.id),
                      session: session,
                      revision: d.revision,
                      soundEnabled: d.preferences.sound,
                    );
            }),
          ),
          route('/practice', (_, _) => const LocalPracticeHome()),
          for (final kind in PracticeKind.values) ...[
            route(
              practicePathForRoute(kind),
              (_, _) => page((d) => PracticeCatalog(kind: kind, data: d)),
            ),
            route(
              '${practicePathForRoute(kind)}/new',
              (_, state) => page((d) {
                if (kind == PracticeKind.writing) {
                  return const LocalWritingEditor(key: ValueKey('new-writing'));
                }
                if (kind == PracticeKind.photo) {
                  return const LocalPhotoEditor(key: ValueKey('new-photo'));
                }
                final matches = catalogScenarios(
                  d.catalog,
                ).where((s) => s.id == state.uri.queryParameters['scenario']);
                if (matches.isEmpty) {
                  return const Text(
                    'Tình huống không tồn tại. Quay lại chọn tình huống.',
                  );
                }
                return LocalConversationEditor(
                  key: ValueKey('new-conversation:${matches.first.id}'),
                  scenario: matches.first,
                );
              }),
            ),
            route(
              '${practicePathForRoute(kind)}/:id',
              (_, state) => page((d) {
                final entry = d.practice
                    .where(
                      (e) =>
                          e.id == state.pathParameters['id'] && e.kind == kind,
                    )
                    .firstOrNull;
                if (entry == null) {
                  return const Text(
                    'Bản này không còn trên thiết bị. Quay lại lịch sử để chọn bản khác.',
                  );
                }
                return switch (kind) {
                  PracticeKind.writing => LocalWritingEditor(
                    key: ValueKey(entry.id),
                    entry: entry,
                  ),
                  PracticeKind.photo => LocalPhotoEditor(
                    key: ValueKey(entry.id),
                    entry: entry,
                  ),
                  PracticeKind.conversation => LocalConversationEditor(
                    key: ValueKey(entry.id),
                    entry: entry,
                  ),
                };
              }),
            ),
          ],
          route(
            '/learn/catalog',
            (_, _) => page((d) => LocalCatalogScreen(data: d)),
          ),
          route('/exams', (_, _) => page((d) => LocalExamCatalog(data: d))),
          route(
            '/exams/packages/:id/instructions',
            (_, state) => page((d) {
              final matches = catalogExams(d.catalog)
                  .where((p) => p.id == state.pathParameters['id']);
              return matches.isEmpty
                  ? const Text('Không tìm thấy bộ đề.')
                  : LocalExamInstructions(pack: matches.first, data: d);
            }),
          ),
          route(
            '/exams/packages/:id',
            (_, state) => page((d) {
              final matches = catalogExams(d.catalog)
                  .where((p) => p.id == state.pathParameters['id']);
              return matches.isEmpty
                  ? const Text('Không tìm thấy bộ đề.')
                  : LocalExamPackagePreview(pack: matches.first);
            }),
          ),
          route(
            '/exams/attempts/:id',
            (_, state) => page((d) {
              final attempt = d.exams.find(state.pathParameters['id']!);
              return attempt == null
                  ? const Text('Bài không còn tồn tại trên thiết bị.')
                  : attempt.done
                  ? LocalExamResult(
                      key: ValueKey('result:${attempt.id}'),
                      attempt: attempt,
                    )
                  : LocalExamRunner(
                      key: ValueKey(attempt.id),
                      attempt: attempt,
                      revision: d.revision,
                    );
            }),
          ),
          route(
            '/progress',
            (_, _) => page(
              (d) => LocalProgressScreen(
                data: d,
                now: ref.read(localClockProvider)(),
              ),
            ),
          ),
          route('/profile', (_, _) => page((d) => LocalProfileHome(data: d))),
          route(
            '/personal/new',
            (_, _) => page((d) => LocalWordEditor(data: d)),
          ),
          route(
            '/words/:id',
            (_, s) => page((d) {
              final word = d.find(s.pathParameters['id']!);
              return word == null
                  ? const Text(
                      'Từ không còn tồn tại. Quay lại danh sách để chọn từ khác.',
                    )
                  : LocalWordDetail(
                      key: ValueKey(word.entry.id),
                      word: word,
                      revision: d.revision,
                      soundEnabled: d.preferences.sound,
                    );
            }),
          ),
          route(
            '/words/:id/edit',
            (_, s) => page((d) {
              final word = d.find(s.pathParameters['id']!);
              return word == null || !word.entry.personal
                  ? const Text('Không tìm thấy từ riêng để sửa.')
                  : LocalWordEditor(
                      key: ValueKey('edit:${word.entry.id}'),
                      data: d,
                      word: word,
                    );
            }),
          ),
          route(
            '/profile/edit',
            (_, _) => page((d) => LocalProfileScreen(data: d)),
          ),
          route('/help', (_, _) => page((d) => LocalHelpScreen(data: d))),
          route('/privacy', (_, _) => const LocalPrivacyScreen()),
          route(
            '/permissions',
            (context, _) => DevicePermissionScreen(
              onPhoto: () => context.go('/photos/new'),
              onConversation: () => context.go('/conversations'),
            ),
          ),
          route(
            '/feedback',
            (_, _) => page((d) => LocalFeedbackListScreen(data: d)),
          ),
          route(
            '/feedback/new',
            (_, state) => page(
              (d) => LocalFeedbackScreen(
                data: d,
                source: state.extra is FeedbackContext
                    ? state.extra as FeedbackContext
                    : null,
              ),
            ),
          ),
          route(
            '/feedback/:id/:revision',
            (_, state) => page((d) {
              final report = d.feedback
                  .where(
                    (r) =>
                        r.id == state.pathParameters['id'] &&
                        r.revision.toString() ==
                            state.pathParameters['revision'],
                  )
                  .firstOrNull;
              return report == null
                  ? const Text('Không tìm thấy phiên bản báo lỗi.')
                  : LocalFeedbackScreen(
                      key: ValueKey('${report.id}:${report.revision}'),
                      data: d,
                      report: report,
                    );
            }),
          ),
          route(
            '/settings',
            (_, _) => page((d) => LocalSettingsScreen(data: d)),
          ),
          route(
            '/data',
            (_, _) => page((d) => LocalDataScreen(revision: d.revision)),
          ),
        ],
      ),
      GoRoute(
        path: '/guest',
        builder: (context, state) =>
            GuestPreviewScreen(onExit: () => context.go('/profile')),
      ),
      GoRoute(
        path: '/preview',
        builder: (context, state) => const _PreviewRoute(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không tìm thấy trang này.'),
              TextButton(
                onPressed: () => context.go('/learn'),
                child: const Text('Về học từ'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});

class LocalHanyuApp extends ConsumerWidget {
  const LocalHanyuApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'Hanyu AI',
    theme: AppTheme.learner,
    routerConfig: ref.watch(localRouterProvider),
  );
}

class _LocalDataPage extends ConsumerWidget {
  const _LocalDataPage({required this.builder});
  final Widget Function(LocalSnapshot) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(localControllerProvider)
      .when(
        skipLoadingOnRefresh: false,
        data: builder,
        loading: () => const StatusPanel(
          icon: Icons.hourglass_empty,
          title: 'Đang mở dữ liệu',
          message: 'Đang đọc tiến độ và học liệu trên thiết bị.',
          loading: true,
        ),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatusPanel(
              icon: Icons.storage_outlined,
              title: 'Kho dữ liệu chưa sẵn sàng',
              message: 'Chưa mở được dữ liệu trên thiết bị. Không tự chuyển sang lưu tạm hoặc xóa dữ liệu.',
              actionLabel: 'Thử mở lại',
              onAction: () => ref.invalidate(localControllerProvider),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push('/preview'),
              child: const Text('Chỉ xem giao diện mẫu, không lưu'),
            ),
          ],
        ),
      );
}

class _LocalShell extends StatefulWidget {
  const _LocalShell({required this.path, required this.child});
  final String path;
  final Widget child;

  @override
  State<_LocalShell> createState() => _LocalShellState();
}

class _LocalShellState extends State<_LocalShell> {
  final scroll = ScrollController(keepScrollOffset: false);
  String get path => widget.path;

  @override
  void didUpdateWidget(covariant _LocalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path == path) return;
    final destination = path;
    // Keep the viewport/render tree stable while a focused form finishes its
    // navigation. Reset only after the new route has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && path == destination && scroll.hasClients) scroll.jumpTo(0);
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  static const paths = [
    '/learn',
    '/review',
    '/practice',
    '/progress',
    '/profile',
  ];
  static const labels = ['Học', 'Ôn tập', 'Luyện tập', 'Tiến độ', 'Cá nhân'];

  String get pageTitle => switch (path.split('/').skip(1).toList()) {
    ['learn'] => 'Học hôm nay',
    ['learn', 'words'] => 'Tra từ',
    ['learn', 'catalog'] => 'Gói học liệu',
    ['words', _, 'edit'] => 'Sửa từ riêng',
    ['words', _] => 'Chi tiết từ',
    ['saved'] => 'Từ đã lưu',
    ['personal', 'new'] => 'Thêm từ riêng',
    ['review', ...] => 'Ôn tập',
    ['practice'] => 'Luyện tập',
    ['writing', ...] => 'Viết chữ',
    ['photos', ...] => 'Chụp chữ',
    ['conversations', ...] => 'Hội thoại',
    ['exams', ...] => 'Thi thử',
    ['progress'] => 'Tiến độ',
    ['profile', 'edit'] => 'Sửa hồ sơ',
    ['profile'] => 'Cá nhân',
    ['settings'] => 'Cài đặt',
    ['data'] => 'Dữ liệu',
    ['help'] => 'Hướng dẫn',
    ['privacy'] => 'Quyền riêng tư',
    ['permissions'] => 'Quyền thiết bị',
    ['feedback', ...] => 'Báo lỗi',
    _ => 'Học tiếng Trung',
  };

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1024;
    final medium = width >= 760 && !wide;
    final selected =
        path.startsWith('/review') ||
            path == '/saved' ||
            path.startsWith('/personal')
        ? 1
        : (path == '/practice' ||
              path.startsWith('/exams') ||
              path.startsWith('/writing') ||
              path.startsWith('/photos') ||
              path.startsWith('/conversations'))
        ? 2
        : path == '/progress'
        ? 3
        : (path.startsWith('/profile') ||
              path.startsWith('/feedback') ||
              [
                '/settings',
                '/data',
                '/help',
                '/privacy',
                '/permissions',
              ].contains(path))
        ? 4
        : 0;
    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView(
          controller: scroll,
          padding: wide
              ? const EdgeInsets.fromLTRB(32, 32, 32, 72)
              : const EdgeInsets.fromLTRB(20, 12, 20, 16),
          children: [widget.child],
        ),
      ),
    );
    final navigation = LearnerNavigationBar(
      labels: labels,
      selectedIndex: selected,
      onSelected: (i) => context.go(paths[i]),
      bottom: !medium,
    );
    return Scaffold(
      appBar: AppBar(
        centerTitle: wide ? null : false,
        titleSpacing: wide ? null : (paths.contains(path) ? 20 : 0),
        leading: paths.contains(path)
            ? null
            : BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(paths[selected]);
                  }
                },
              ),
        title: wide
            ? const Row(
                children: [
                  BrandMark(),
                  SizedBox(width: 12),
                  Expanded(child: Text('Hanyu AI')),
                ],
              )
            : Text(
                pageTitle,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (!wide && path == '/learn')
            IconButton(
              tooltip: 'Mở trang cá nhân',
              onPressed: () => context.go('/profile'),
              icon: const FigmaIcon(FigmaGlyph.person),
            ),
        ],
      ),
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  NavigationRail(
                    extended: true,
                    minExtendedWidth: 190,
                    selectedIndex: selected,
                    onDestinationSelected: (i) => context.go(paths[i]),
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
            : medium
            ? Column(
                children: [
                  navigation,
                  Expanded(child: body),
                ],
              )
            : body,
      ),
      bottomNavigationBar: wide || medium ? null : navigation,
    );
  }
}

class _PreviewRoute extends StatelessWidget {
  const _PreviewRoute();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: softSurface,
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/learn');
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Về bản lưu local'),
              ),
              const Expanded(
                child: Text(
                  'Khu mẫu · chỉ giữ RAM',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
      const Expanded(child: LearnerShell()),
    ],
  );
}

String practicePathForRoute(PracticeKind kind) => switch (kind) {
  PracticeKind.writing => '/writing',
  PracticeKind.photo => '/photos',
  PracticeKind.conversation => '/conversations',
};
