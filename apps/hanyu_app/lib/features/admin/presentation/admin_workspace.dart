import 'content_package_export_screen.dart';
import 'admin_import_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/search_normalizer.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../application/local_admin_providers.dart';
import '../domain/content_payload.dart';
import '../domain/content_revision.dart';
import 'admin_page.dart';
import 'admin_editor.dart';
import 'admin_content_detail.dart';
import 'admin_data_screen.dart';

class AdminWorkspace extends ConsumerStatefulWidget {
  const AdminWorkspace({super.key});
  @override
  ConsumerState<AdminWorkspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends ConsumerState<AdminWorkspace> {
  String query = '';
  ContentKind? kind;
  ContentState? status;
  int page = 0;
  bool busy = false;
  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Quản lý học liệu',
    child: ref
        .watch(localAdminControllerProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(localAdminControllerProvider),
            child: const Text('Chưa mở được Admin. Thử lại'),
          ),
          data: (data) {
            final latest = <String, ContentRevision>{};
            for (final record in data.content) {
              if ((latest[record.itemId]?.revision ?? 0) < record.revision) {
                latest[record.itemId] = record;
              }
            }
            final all = status == null ? latest.values : data.content;
            final rows =
                all
                    .where(
                      (r) =>
                          (kind == null || r.kind == kind) &&
                          (status == null || r.state == status) &&
                          normalizeSearch(
                            '${r.payload.title} ${r.payload.toJson().values.join(' ')} ${r.source}',
                          ).contains(normalizeSearch(query)),
                    )
                    .toList()
                  ..sort((a, b) => a.payload.title.compareTo(b.payload.title));
            final last = rows.isEmpty ? 0 : (rows.length - 1) ~/ 25;
            final current = page > last ? last : page;
            void open(ContentRevision record) => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AdminContentDetail(
                  id: record.itemId,
                  initialRevision: record.revision,
                ),
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildPageTitle(
                  'Thư viện học liệu',
                  data.identity.label.isEmpty
                      ? 'Nguồn xuất local chưa đặt tên. Nội dung chưa tự chuyển sang người học.'
                      : 'Nguồn local: ${data.identity.label} · chưa xác minh danh tính',
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final type in ContentKind.values)
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => AdminEditor(kind: type),
                                ),
                              ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          'Thêm ${contentKindLabel(type).toLowerCase()}',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const AdminImportScreen(),
                              ),
                            ),
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Nhập từ CSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const ContentPackageExportScreen(),
                              ),
                            ),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Xuất gói học liệu'),
                    ),

                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const AdminCsvHistoryScreen(),
                              ),
                            ),
                      child: Text('Lịch sử nhập CSV (${data.imports.length})'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Tìm Hán tự, Pinyin, nghĩa hoặc nguồn',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() {
                    query = v;
                    page = 0;
                  }),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        initialValue: kind?.name ?? 'all',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Loại học liệu',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('Tất cả loại'),
                          ),
                          for (final type in ContentKind.values)
                            DropdownMenuItem(
                              value: type.name,
                              child: Text(contentKindLabel(type)),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          kind = ContentKind.values
                              .where((r) => r.name == v)
                              .firstOrNull;
                          page = 0;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<String>(
                        initialValue: status?.name ?? 'all',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('Phiên bản mới nhất'),
                          ),
                          for (final state in ContentState.values)
                            DropdownMenuItem(
                              value: state.name,
                              child: Text(contentStateLabel(state)),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          status = ContentState.values
                              .where((r) => r.name == v)
                              .firstOrNull;
                          page = 0;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mặc định hiện bản mới nhất; lọc trạng thái sẽ tìm trong cả lịch sử phiên bản.',
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Chưa có học liệu phù hợp. Thêm mới hoặc chủ động nạp ví dụ nháp.',
                    ),
                  ),
                if (rows.isNotEmpty && MediaQuery.sizeOf(context).width >= 900)
                  DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 12,
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 80,
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('Học liệu')),
                      DataColumn(label: Text('Loại')),
                      DataColumn(label: Text('Phiên bản / trạng thái')),
                      DataColumn(label: Text('Mở')),
                    ],
                    rows: [
                      for (final record in rows.skip(current * 25).take(25))
                        DataRow(
                          onSelectChanged: (_) => open(record),
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 280,
                                child: Text(
                                  record.payload.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(contentKindLabel(record.kind))),
                            DataCell(
                              Text(
                                'v${record.revision} · ${contentStateLabel(record.state)}',
                              ),
                            ),
                            DataCell(
                              IconButton(
                                tooltip: 'Mở ${record.payload.title}',
                                onPressed: () => open(record),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ),
                          ],
                        ),
                    ],
                  )
                else
                  for (final record in rows.skip(current * 25).take(25))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        record.payload.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${contentKindLabel(record.kind)} · v${record.revision}\n${contentStateLabel(record.state)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(record),
                    ),
                if (rows.length > 25)
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Trang ${current + 1}/${last + 1}'),
                      OutlinedButton(
                        onPressed: current == 0
                            ? null
                            : () => setState(() => page = current - 1),
                        child: const Text('Trang trước'),
                      ),
                      OutlinedButton(
                        onPressed: current == last
                            ? null
                            : () => setState(() => page = current + 1),
                        child: const Text('Trang sau'),
                      ),
                    ],
                  ),
                const Divider(height: 40),
                AsyncCommitButton(
                  label: 'Nạp 6 ví dụ nháp',
                  compact: true,
                  enabled: !busy,
                  intentKey: 'samples:${data.revision}',
                  onBusyChanged: (v) => setState(() => busy = v),
                  onCommit: (op) async {
                    final accepted = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Nạp ví dụ chưa duyệt?'),
                        content: const Text(
                          'Thêm một từ, một câu hỏi và bốn tình huống làm nháp. Không có người duyệt, nguồn ngoài hoặc chứng nhận HSK tự động.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Hủy'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Nạp ví dụ'),
                          ),
                        ],
                      ),
                    );
                    if (accepted != true) return;
                    await ref
                        .read(localAdminControllerProvider.notifier)
                        .commit(
                          (r) => r.seedSamples(
                            revision: data.revision,
                            operationId: op,
                          ),
                        );
                  },
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const AdminDataScreen(),
                          ),
                        ),
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Nguồn và backup Admin'),
                ),
              ],
            );
          },
        ),
  );
}
