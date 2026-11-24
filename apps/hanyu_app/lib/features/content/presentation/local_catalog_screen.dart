import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local/local_providers.dart';
import '../../../core/files/file_transfer_provider.dart';
import '../../../core/files/local_file_transfer.dart';
import '../../../core/local/learning_catalog_store.dart';
import '../../../core/local/local_models.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../../admin/domain/content_payload.dart';
import '../domain/content_package.dart';

class LocalCatalogScreen extends ConsumerStatefulWidget {
  const LocalCatalogScreen({required this.data, super.key});
  final LocalSnapshot data;

  @override
  ConsumerState<LocalCatalogScreen> createState() => _LocalCatalogScreenState();
}

class _LocalCatalogScreenState extends ConsumerState<LocalCatalogScreen> {
  CatalogInstallPreview? preview;
  bool trialAccepted = false, activateAfterInstall = true, busy = false;
  String? status;

  LocalController get controller => ref.read(localControllerProvider.notifier);
  void setBusy(bool value) => setState(() => busy = value);

  Future<void> chooseFile() async {
    final file = await ref
        .read(localFileTransferProvider)
        .pick(LocalJsonKind.contentPackage);
    if (file == null || !mounted) return;
    final prepared = await ref
        .read(localRepositoryProvider)
        .preparePackageInstall(file);
    if (!mounted) return;
    setState(() {
      preview = prepared;
      trialAccepted = false;
      activateAfterInstall = !prepared.alreadyInstalled;
      status = null;
    });
  }

  String summary(ContentPackage p) =>
      '${p.count(ContentKind.vocabulary)} từ · '
      '${p.count(ContentKind.question)} câu hỏi · ${p.count(ContentKind.scenario)} tình huống';
  String mode(ContentPackage p) => p.mode == PackageMode.trial
      ? 'Gói dùng thử · có thể chưa duyệt'
      : 'Đã khai báo duyệt · danh tính chưa xác minh';

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final catalog = data.catalog;
    final pending = preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Gói học liệu',
          'Cài file từ Admin để dùng từ vựng, câu đọc và tình huống trên thiết bị này.',
        ),
        const SizedBox(height: 24),
        AsyncCommitButton(
          label: 'Chọn file gói học liệu',
          intentKey: 'catalog-pick',
          enabled: !busy,
          onBusyChanged: setBusy,
          onCommit: (_) => chooseFile(),
        ),
        if (pending != null) ...[
          const Divider(height: 40),
          buildSectionHeading('Xem trước · v${pending.package.version}'),
          const SizedBox(height: 8),
          Text(mode(pending.package)),
          Text(summary(pending.package)),
          Text(
            pending.alreadyInstalled
                ? 'Phiên bản này đã được cài.'
                : '${pending.added.length} mục thêm · ${pending.removed.length} mục rút khỏi gói',
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Nguồn và phiên bản'),
            children: [
              SelectableText('Nguồn: ${pending.package.publisherId}'),
              SelectableText('Mã gói: ${pending.package.packageId}'),
              SelectableText('Checksum: ${pending.package.checksum}'),
            ],
          ),
          if (pending.package.mode == PackageMode.trial &&
              !pending.alreadyInstalled)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Tôi hiểu gói dùng thử có thể chưa được duyệt.',
              ),
              value: trialAccepted,
              onChanged: busy
                  ? null
                  : (value) => setState(() => trialAccepted = value ?? false),
            ),
          if (!pending.alreadyInstalled)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dùng gói này sau khi cài'),
              value: activateAfterInstall,
              onChanged: busy
                  ? null
                  : (value) =>
                        setState(() => activateAfterInstall = value ?? false),
            ),
          if (data.revision != pending.baseRevision)
            const Text(
              'Dữ liệu đã thay đổi. Chọn lại file để xem trước phiên bản hiện tại.',
            ),
          if (!pending.alreadyInstalled)
            AsyncCommitButton(
              label: 'Xác nhận cài gói',
              intentKey:
                  '${pending.baseRevision}:${pending.package.checksum}:$activateAfterInstall',
              enabled:
                  !busy &&
                  data.revision == pending.baseRevision &&
                  (pending.package.mode != PackageMode.trial || trialAccepted),
              onBusyChanged: setBusy,
              onCommit: (operationId) async {
                await controller.commit(
                  (repo) => repo.installPackage(
                    pending,
                    operationId: operationId,
                    acceptTrial: trialAccepted,
                    activate: activateAfterInstall,
                  ),
                );
                if (mounted) {
                  setState(() {
                    preview = null;
                    status = 'Đã cài phiên bản v${pending.package.version}.';
                  });
                }
              },
            ),
          TextButton(
            onPressed: busy ? null : () => setState(() => preview = null),
            child: const Text('Đóng xem trước'),
          ),
        ],
        if (status case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Semantics(liveRegion: true, child: Text(message)),
          ),
        const Divider(height: 40),
        buildSectionHeading('Gói đã cài'),
        const SizedBox(height: 12),
        if (catalog.packages.isEmpty)
          const Text('Chưa có gói. Bạn đang dùng học liệu mẫu.'),
        if (catalog.active != null)
          AsyncCommitButton(
            label: 'Dùng học liệu mẫu',
            compact: true,
            enabled: !busy,
            intentKey: 'catalog-seed:${data.revision}',
            onBusyChanged: setBusy,
            onCommit: (op) => controller.commit(
              (repo) => repo.activatePackage(
                null,
                revision: data.revision,
                operationId: op,
              ),
            ),
          ),
        for (final p in catalog.packages) ...[
          const Divider(height: 32),
          Text(
            'Gói ${p.packageId.substring(0, 8)} · v${p.version}${p == catalog.active ? ' · Đang dùng' : ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(mode(p)),
          Text(summary(p)),
          if (p != catalog.active)
            AsyncCommitButton(
              label: 'Dùng gói này',
              compact: true,
              enabled: !busy,
              intentKey: 'catalog-active:${p.packageId}:${data.revision}',
              onBusyChanged: setBusy,
              onCommit: (op) => controller.commit(
                (repo) => repo.activatePackage(
                  p.packageId,
                  revision: data.revision,
                  operationId: op,
                ),
              ),
            ),
          TextButton(
            onPressed: busy ? null : () => confirmRemove(p, data.revision),
            child: const Text('Gỡ gói'),
          ),
        ],
      ],
    );
  }

  Future<void> confirmRemove(ContentPackage p, int revision) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Gỡ gói học liệu?'),
        content: const Text(
          'Các từ có ghi chú, đã lưu hoặc còn lịch ôn sẽ được giữ. Bài làm và phiên hội thoại đã lưu vẫn xem được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xác nhận gỡ'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || busy) return;
    setBusy(true);
    try {
      await controller.commit(
        (repo) => repo.removePackage(
          p.packageId,
          revision: revision,
          operationId: 'catalog-remove:${p.packageId}:$revision',
        ),
      );
      if (mounted) setState(() => status = 'Đã gỡ gói v${p.version}.');
    } on LocalDataException catch (error) {
      if (mounted) setState(() => status = error.message);
    } catch (_) {
      if (mounted) setState(() => status = 'Chưa gỡ được gói. Hãy thử lại.');
    } finally {
      if (mounted) setBusy(false);
    }
  }
}
