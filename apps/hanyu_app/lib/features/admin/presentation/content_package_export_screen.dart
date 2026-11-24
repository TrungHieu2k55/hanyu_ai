import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/files/file_transfer_provider.dart';
import '../../../core/files/local_file_transfer.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../../../core/utils/search_normalizer.dart';
import '../../content/domain/content_package.dart';
import '../application/local_admin_providers.dart';
import '../data/admin_package_store.dart';
import '../domain/content_payload.dart';
import '../domain/content_revision.dart';
import '../domain/local_admin.dart';
import 'admin_page.dart';

/// Existing calm educational theme; selection -> preview -> freeze -> explicit OS handoff.
class ContentPackageExportScreen extends ConsumerStatefulWidget {
  const ContentPackageExportScreen({super.key});
  @override
  ConsumerState<ContentPackageExportScreen> createState() => _ExportState();
}

class _ExportState extends ConsumerState<ContentPackageExportScreen> {
  String newId = const Uuid().v4(), choice = 'new', query = '';
  PackageMode mode = PackageMode.trial;
  final selected = <String, int>{};
  int page = 0, historyPage = 0;
  bool busy = false, accepted = false;
  String? message;
  AdminPackagePreview? preview;
  void resetPreview() {
    preview = null;
    accepted = false;
    message = null;
    page = 0;
  }

  List<ContentRevision> candidates(LocalAdminSnapshot data) {
    final byId = <String, ContentRevision>{};
    for (final r in data.content) {
      if (mode == PackageMode.reviewed && r.state != ContentState.published) {
        continue;
      }
      if ((byId[r.itemId]?.revision ?? 0) < r.revision) byId[r.itemId] = r;
    }
    return byId.values
        .where(
          (r) => [
            ContentState.draft,
            ContentState.reviewed,
            ContentState.published,
          ].contains(r.state),
        )
        .toList()
      ..sort((a, b) => a.itemId.compareTo(b.itemId));
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty: selected.isNotEmpty || preview != null,
    busy: busy,
    child: AdminPage(
      title: 'Xuất gói học liệu',
      child: ref
          .watch(localAdminControllerProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(localAdminControllerProvider),
              child: const Text('Chưa mở được học liệu. Thử lại'),
            ),
            data: buildData,
          ),
    ),
  );
  Widget buildData(LocalAdminSnapshot data) {
    final all = candidates(data),
        visible = all
            .where(
              (r) => normalizeSearch(
                '${r.payload.title} ${r.payload.toJson().values.join(' ')}',
              ).contains(normalizeSearch(query)),
            )
            .toList();
    final packages = data.packages.map((p) => p.packageId).toSet().toList()
      ..sort();
    final preview = this.preview;
    final rows = preview == null ? visible : preview.package.records;
    final last = rows.isEmpty ? 0 : (rows.length - 1) ~/ 25,
        current = page.clamp(0, last);
    final history = data.packages;
    final historyLast = history.isEmpty ? 0 : (history.length - 1) ~/ 25,
        hp = historyPage.clamp(0, historyLast);
    final selectedStillValid = selected.entries.every(
      (e) => all.any((r) => r.itemId == e.key && r.revision == e.value),
    );
    final actualChoice = packages.contains(choice) ? choice : 'new';
    final packageId = actualChoice == 'new' ? newId : actualChoice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Chuyển học liệu sang người học',
          'Tạo gói văn bản có phiên bản. Xuất file là bước riêng; nội dung không tự đồng bộ sang ứng dụng học.',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 240,
            child: AsyncCommitButton(
              label: 'Tải lại dữ liệu Admin',
              compact: true,
              enabled: !busy,
              intentKey: 'reload',
              onBusyChanged: (v) => setState(() => busy = v),
              onCommit: (_) =>
                  ref.read(localAdminControllerProvider.notifier).reload(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (preview == null) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('package-choice:$actualChoice'),
            initialValue: actualChoice,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Gói cần tạo phiên bản',
            ),
            items: [
              const DropdownMenuItem(value: 'new', child: Text('Tạo gói mới')),
              for (final id in packages)
                DropdownMenuItem(
                  value: id,
                  child: Text('Gói ${id.substring(0, 8)}…'),
                ),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() {
                    choice = v!;
                    resetPreview();
                  }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PackageMode>(
            key: const ValueKey('package-mode'),
            initialValue: mode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Mức kiểm duyệt'),
            items: const [
              DropdownMenuItem(
                value: PackageMode.trial,
                child: Text('Dùng thử · có thể chưa duyệt'),
              ),
              DropdownMenuItem(
                value: PackageMode.reviewed,
                child: Text('Đã khai báo duyệt'),
              ),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() {
                    mode = v!;
                    selected.clear();
                    resetPreview();
                  }),
          ),
          const SizedBox(height: 12),
          Text(
            mode == PackageMode.trial
                ? 'Dùng bản mới nhất còn hợp lệ. Gói có thể chứa nội dung nháp.'
                : 'Chỉ chọn bản đang công bố, đủ nguồn, quyền sử dụng và khai báo duyệt. Danh tính người duyệt chưa được xác minh.',
          ),
          const SizedBox(height: 24),
          TextField(
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Tìm từ, câu hỏi hoặc tình huống',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() {
              query = v;
              page = 0;
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: busy || all.isEmpty
                    ? null
                    : () => setState(() {
                        selected.addEntries(
                          all.map((r) => MapEntry(r.itemId, r.revision)),
                        );
                      }),
                child: const Text('Chọn toàn bộ'),
              ),
              TextButton(
                onPressed: busy || selected.isEmpty
                    ? null
                    : () => setState(selected.clear),
                child: const Text('Bỏ chọn toàn bộ'),
              ),
            ],
          ),
          Text(
            'Đã chọn ${selected.length} học liệu · tối đa 1.000 từ, 60 câu hỏi, 4 tình huống / 2 MiB.',
          ),
          if (!selectedStillValid)
            const Text(
              'Một số phiên bản đã đổi. Bỏ chọn rồi chọn lại trước khi xem gói.',
            ),
        ] else ...[
          Text(
            'Xem trước · v${preview.package.version}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _PackageSummary(package: preview.package),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Nguồn và tính toàn vẹn của gói'),
            children: [
              SelectableText('Nguồn: ${preview.package.publisherId}'),
              SelectableText('Mã gói: ${preview.package.packageId}'),
              SelectableText('Checksum: ${preview.package.checksum}'),
              const Text(
                'Checksum kiểm tra nội dung thay đổi, không xác thực tác giả hoặc chất lượng học liệu.',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chưa có học liệu phù hợp',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Thêm học liệu hoặc khai báo duyệt và công bố trước khi tạo gói này.',
                ),
              ],
            ),
          ),
        for (final record in rows.skip(current * 25).take(25))
          if (preview == null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: selected[record.itemId] == record.revision,
              title: Text(record.payload.title),
              subtitle: Text(
                '${contentKindLabel(record.kind)} · r${record.revision} · ${contentStateLabel(record.state)}',
              ),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selected[record.itemId] = record.revision;
                      } else {
                        selected.remove(record.itemId);
                      }
                    }),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(record.payload.title),
              subtitle: Text(
                '${contentKindLabel(record.kind)} · r${record.revision} · ${record.source.isEmpty ? 'Chưa ghi nguồn' : record.source}',
              ),
            ),
        if (last > 0)
          _Pager(
            page: current,
            last: last,
            busy: busy,
            onChange: (v) => setState(() => page = v),
          ),
        const SizedBox(height: 24),
        if (preview == null)
          AsyncCommitButton(
            label: 'Xem trước gói',
            enabled: !busy && selected.isNotEmpty && selectedStillValid,
            intentKey:
                'preview:$packageId:${mode.name}:$selected:${data.revision}',
            onBusyChanged: (v) => setState(() => busy = v),
            onCommit: (_) async {
              final result = await ref
                  .read(localAdminRepositoryProvider)
                  .preparePackage(
                    packageId: packageId,
                    mode: mode,
                    selection: [
                      for (final e in selected.entries)
                        PackageSelection(itemId: e.key, revision: e.value),
                    ],
                  );
              if (mounted) {
                setState(() {
                  this.preview = result;
                  accepted = false;
                  page = 0;
                  message = null;
                });
              }
            },
          )
        else ...[
          if (preview.package.mode == PackageMode.trial)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: accepted,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Tôi hiểu gói dùng thử có thể chứa nội dung chưa duyệt.',
              ),
              onChanged: busy ? null : (v) => setState(() => accepted = v!),
            ),
          if (preview.baseRevision != data.revision)
            const Text(
              'Dữ liệu Admin đã thay đổi. Quay lại và xem trước lại gói.',
            ),
          AsyncCommitButton(
            label: 'Lưu phiên bản gói',
            enabled:
                !busy &&
                preview.baseRevision == data.revision &&
                (preview.package.mode != PackageMode.trial || accepted),
            intentKey:
                'freeze:${preview.baseRevision}:${preview.package.checksum}',
            onBusyChanged: (v) => setState(() => busy = v),
            onCommit: (op) async {
              await ref
                  .read(localAdminControllerProvider.notifier)
                  .commit(
                    (r) => r.commitPackage(
                      preview,
                      acceptTrial: accepted,
                      operationId: op,
                    ),
                  );
              if (mounted) {
                setState(() {
                  choice = preview.package.packageId;
                  this.preview = null;
                  selected.clear();
                  accepted = false;
                  page = 0;
                  historyPage = 0;
                  message =
                      'Đã lưu phiên bản v${preview.package.version}. Chọn Xuất lại bên dưới để bàn giao file.';
                });
              }
            },
          ),
          TextButton(
            onPressed: busy ? null : () => setState(resetPreview),
            child: const Text('Quay lại chọn nội dung'),
          ),
        ],
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Semantics(liveRegion: true, child: Text(message!)),
          ),
        const Divider(height: 48),
        Text(
          'Phiên bản đã lưu (${history.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Xuất lại giữ nguyên nội dung, thời gian và checksum. Hủy bàn giao không xóa phiên bản.',
        ),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Chưa có phiên bản gói nào.'),
          ),
        for (final p in history.skip(hp * 25).take(25))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Gói ${p.packageId.substring(0, 8)}… · v${p.version}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _PackageSummary(package: p),
                const SizedBox(height: 8),
                AsyncCommitButton(
                  label: 'Xuất lại v${p.version}',
                  compact: true,
                  enabled: !busy,
                  intentKey: 'export:${p.packageId}:${p.version}',
                  onBusyChanged: (v) => setState(() => busy = v),
                  onCommit: (_) async {
                    final file = await ref
                        .read(localAdminRepositoryProvider)
                        .exportPackage(p.packageId, p.version);
                    final result = await ref
                        .read(localFileTransferProvider)
                        .save(file);
                    if (mounted) {
                      setState(
                        () => message = switch (result) {
                          FileHandoff.handedOff => 'Đã bàn giao file cho hệ thống. Hãy kiểm tra nơi lưu file.',
                          FileHandoff.canceled => 'Đã hủy xuất file. Phiên bản vẫn được giữ để xuất lại.',
                          FileHandoff.unavailable => 'Hệ thống chưa xác nhận bàn giao file. Bạn có thể xuất lại phiên bản này.',
                        },
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        if (historyLast > 0)
          _Pager(
            page: hp,
            last: historyLast,
            busy: busy,
            onChange: (v) => setState(() => historyPage = v),
          ),
      ],
    );
  }
}

class _PackageSummary extends StatelessWidget {
  const _PackageSummary({required this.package});
  final ContentPackage package;
  @override
  Widget build(BuildContext context) => Text(
    '${package.mode == PackageMode.trial ? 'Dùng thử · có thể chưa duyệt' : 'Đã khai báo duyệt · chưa xác minh danh tính'}\n'
    '${package.count(ContentKind.vocabulary)} từ · ${package.count(ContentKind.question)} câu hỏi · ${package.count(ContentKind.scenario)} tình huống',
  );
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.last,
    required this.busy,
    required this.onChange,
  });
  final int page, last;
  final bool busy;
  final ValueChanged<int> onChange;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton(
        onPressed: busy || page == 0 ? null : () => onChange(page - 1),
        child: const Text('Trang trước'),
      ),
      Text('${page + 1}/${last + 1}'),
      TextButton(
        onPressed: busy || page == last ? null : () => onChange(page + 1),
        child: const Text('Trang sau'),
      ),
    ],
  );
}
