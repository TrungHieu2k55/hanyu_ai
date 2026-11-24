import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local/open_database.dart';
import '../data/local_admin_repository.dart';
import '../domain/local_admin.dart';

final localAdminRepositoryProvider = Provider<LocalAdminRepository>((ref) {
  final repository = LocalAdminRepository(openAdminDatabase());
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
});
final localAdminControllerProvider =
    AsyncNotifierProvider<LocalAdminController, LocalAdminSnapshot>(
      LocalAdminController.new,
    );

class LocalAdminController extends AsyncNotifier<LocalAdminSnapshot> {
  @override
  Future<LocalAdminSnapshot> build() =>
      ref.watch(localAdminRepositoryProvider).loadSnapshot();
  Future<void> commit(
    Future<LocalAdminSnapshot> Function(LocalAdminRepository) action,
  ) async {
    final snapshot = await action(ref.read(localAdminRepositoryProvider));
    if (ref.mounted) state = AsyncData(snapshot);
  }

  Future<void> reload() async {
    final snapshot = await ref
        .read(localAdminRepositoryProvider)
        .loadSnapshot();
    if (ref.mounted) state = AsyncData(snapshot);
  }
}
