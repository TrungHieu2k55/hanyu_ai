import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/core/local/local_repository.dart';
import 'package:doanchuyennganh2/core/local/open_database.dart';

final localClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final localRepositoryProvider = Provider<LocalRepository>((ref) {
  final repository = DriftLocalRepository(
    openLocalDatabase(),
    clock: ref.watch(localClockProvider),
  );
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
});

final localControllerProvider =
    AsyncNotifierProvider<LocalController, LocalSnapshot>(LocalController.new);

class LocalController extends AsyncNotifier<LocalSnapshot> {
  @override
  Future<LocalSnapshot> build() => ref.watch(localRepositoryProvider).load();

  Future<void> commit(
    Future<LocalSnapshot> Function(LocalRepository repository) action,
  ) async {
    // Do not publish optimistic data or clear the previous snapshot on failure.
    final committed = await action(ref.read(localRepositoryProvider));
    if (ref.mounted) state = AsyncData(committed);
  }

  Future<void> reload() async {
    final loaded = await ref.read(localRepositoryProvider).load();
    if (ref.mounted) state = AsyncData(loaded);
  }
}
