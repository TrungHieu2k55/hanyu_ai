import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/core/utils/search_normalizer.dart';
import 'package:doanchuyennganh2/features/admin/domain/admin_record.dart';

import 'preview_admin_editor.dart';

import 'package:doanchuyennganh2/features/admin/presentation/preview_admin_import_screen.dart';
import 'package:doanchuyennganh2/features/exam/data/sample_questions.dart';
import 'package:doanchuyennganh2/features/roleplay/data/sample_scenarios.dart';
import 'package:doanchuyennganh2/features/vocabulary/data/sample_vocabulary.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/brand_mark.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/preview_notice.dart';

class PreviewAdminWorkspace extends StatefulWidget {
  const PreviewAdminWorkspace({super.key});
  @override
  State<PreviewAdminWorkspace> createState() => _PreviewAdminWorkspaceState();
}

class _PreviewAdminWorkspaceState extends State<PreviewAdminWorkspace> {
  static const sections = [
    'Tổng quan',
    'Từ vựng',
    'Đề thi',
    'Tình huống',
    'Báo lỗi',
  ];
  late final records = <String, List<AdminRecord>>{
    'Từ vựng': sampleVocabulary
        .map(
          (w) => AdminRecord({
            'Hán tự': w.hanzi,
            'Pinyin': w.pinyin,
            'Nghĩa Việt': w.vietnamese,
            'Nguồn / giấy phép': '',
          }),
        )
        .toList(),
    'Đề thi': sampleQuestions
        .map(
          (q) => AdminRecord({
            'Câu hỏi': q.prompt,
            'Lựa chọn A': q.choices[0],
            'Lựa chọn B': q.choices[1],
            'Lựa chọn C': q.choices[2],
            'Đáp án A/B/C': String.fromCharCode(65 + q.correct),
            'Giải thích': q.explanation,
          }),
        )
        .toList(),
    'Tình huống': sampleScenarios
        .map(
          (s) => AdminRecord({
            'Tên tình huống': s.title,
            'Vai học viên': s.role,
            'Vai đối tác': s.partner,
            'Mục tiêu': s.goal,
            'Lời mở đầu': s.opening[0],
            'Pinyin': s.opening[1],
            'Nghĩa Việt': s.opening[2],
          }),
        )
        .toList(),
    'Báo lỗi': [
      AdminRecord({
        'Nội dung báo lỗi': 'Ví dụ báo lỗi học liệu',
        'Ngữ cảnh': 'Bản ghi mẫu dùng để xem luồng xử lý; không phải phản hồi của người dùng thật.',
      }),
    ],
  };
  int section = 0, page = 0;
  String query = '', filter = 'Tất cả';

  Future<void> editor(String kind, AdminRecord? record) async {
    final template =
        record?.fields ??
        records[kind]!.firstOrNull?.fields ??
        _templates[kind]!;
    final fields = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScaffold(
          title: '${record == null ? "Thêm" : "Sửa"} · $kind',
          body: PreviewAdminEditor(
            initial: record == null
                ? {for (final key in template.keys) key: ''}
                : Map.of(template),
            kind: kind,
          ),
        ),
      ),
    );
    if (fields == null || !mounted) return;
    setState(() {
      if (record == null) {
        records[kind]!.add(AdminRecord(fields));
      } else {
        record.fields = fields;
        record.status = 'Nháp';
      }
    });
  }

  static const _templates = {
    'Từ vựng': {
      'Hán tự': '',
      'Pinyin': '',
      'Nghĩa Việt': '',
      'Nguồn / giấy phép': '',
    },
    'Đề thi': {
      'Câu hỏi': '',
      'Lựa chọn A': '',
      'Lựa chọn B': '',
      'Lựa chọn C': '',
      'Đáp án A/B/C': '',
      'Giải thích': '',
    },
    'Tình huống': {
      'Tên tình huống': '',
      'Vai học viên': '',
      'Vai đối tác': '',
      'Mục tiêu': '',
      'Lời mở đầu': '',
      'Pinyin': '',
      'Nghĩa Việt': '',
    },
    'Báo lỗi': {'Nội dung báo lỗi': '', 'Ngữ cảnh': ''},
  };
  Future<void> action(String kind, AdminRecord record, String next) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('$next?'),
        content: const Text(
          'Thao tác chỉ cập nhật bản ghi mẫu trên giao diện Admin. Không duyệt học liệu thật hoặc thay dữ liệu trong app học viên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xác nhận thao tác mẫu'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      if (next == 'Xóa bản ghi mẫu') {
        records[kind]!.remove(record);
      } else {
        record.status = next;
      }
      page = 0;
    });
  }

  void navigate(int value) => setState(() {
    section = value;
    page = 0;
    query = '';
    filter = 'Tất cả';
  });
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final kind = sections[section];
    final filtered = section == 0
        ? <AdminRecord>[]
        : records[kind]!
              .where(
                (r) =>
                    normalizeSearch(r.fields.values.join(' '))
                        .contains(normalizeSearch(query)) &&
                    (filter == 'Tất cả' || r.status == filter),
              )
              .toList();
    final lastPage = filtered.isEmpty ? 0 : (filtered.length - 1) ~/ 8;
    if (page > lastPage) page = lastPage;
    final nav = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        const Row(
          children: [
            BrandMark(),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hanyu AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < sections.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              selected: section == i,
              selectedTileColor: softSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                [
                  Icons.dashboard_outlined,
                  Icons.translate,
                  Icons.quiz_outlined,
                  Icons.forum_outlined,
                  Icons.flag_outlined,
                ][i],
              ),
              title: Text(sections[i]),
              onTap: () {
                navigate(i);
                if (!wide) Navigator.pop(context);
              },
            ),
          ),
      ],
    );
    final body = ListView(
      padding: EdgeInsets.all(wide ? 32 : 20),
      children: [
        const PreviewNotice(),
        const SizedBox(height: 12),
        const Text(
          'Admin mẫu độc lập · không xác thực quyền thật · mọi thay đổi chỉ trong RAM.',
          style: TextStyle(fontSize: 14, color: mutedText),
        ),
        const SizedBox(height: 24),
        buildPageTitle(
          kind,
          section == 0
              ? 'Kiểm kê học liệu mẫu trong khu quản trị này.'
              : 'Mở một hàng để xem và chỉnh sửa. Không dùng dữ liệu thật.',
        ),
        const SizedBox(height: 24),
        if (section == 0) ...[
          for (var i = 1; i < sections.length; i++)
            buildActionTile(
              Icons.folder_open_outlined,
              sections[i],
              '${records[sections[i]]!.length} bản ghi mẫu',
              () => navigate(i),
            ),
          const SizedBox(height: 16),
          const PanelCard(
            child: Text(
              'Luồng: tạo nháp → kiểm tra nội dung → duyệt/công bố/thu hồi (mẫu). Trạng thái mẫu không chứng minh đã kiểm duyệt ngôn ngữ, bản quyền hoặc quyền xuất bản.',
            ),
          ),
        ] else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => editor(kind, null),
                icon: const Icon(Icons.add),
                label: const Text('Thêm bản ghi mẫu'),
              ),
              if (kind == 'Từ vựng')
                OutlinedButton.icon(
                  onPressed: () async {
                    final imported = await Navigator.push<List<AdminRecord>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailScaffold(
                          title: 'Import CSV mẫu',
                          body: PreviewAdminImportScreen(
                            existing: records[kind]!
                                .map(
                                  (r) =>
                                      '${r.fields['Hán tự']}|${r.fields['Pinyin']}',
                                )
                                .toSet(),
                          ),
                        ),
                      ),
                    );
                    if (imported != null && mounted) {
                      setState(() => records[kind]!.addAll(imported));
                    }
                  },
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Import từ mẫu'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: ValueKey(kind),
            initialValue: query,
            onChanged: (value) => setState(() {
              query = value;
              page = 0;
            }),
            decoration: const InputDecoration(
              labelText: 'Tìm bản ghi mẫu',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final value in [
                'Tất cả',
                'Nháp',
                'Đã duyệt mẫu',
                'Công bố mẫu',
                'Thu hồi mẫu',
                if (kind == 'Báo lỗi') 'Đã đóng mẫu',
              ])
                ChoiceChip(
                  label: Text(value),
                  selected: filter == value,
                  onSelected: (_) => setState(() {
                    filter = value;
                    page = 0;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            const PanelCard(
              child: Text(
                'Không có bản ghi phù hợp. Thử thay bộ lọc hoặc từ tìm kiếm.',
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 56,
                dataRowMaxHeight:
                    (MediaQuery.textScalerOf(context).scale(16) * 3 + 16).clamp(
                      64.0,
                      112.0,
                    ),
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('Nội dung')),
                  DataColumn(label: Text('Chi tiết')),
                  DataColumn(label: Text('Trạng thái')),
                  DataColumn(label: Text('Thao tác')),
                ],
                rows: [
                  for (final record in filtered.skip(page * 8).take(8))
                    DataRow(
                      onSelectChanged: (_) => editor(kind, record),
                      cells: [
                        DataCell(
                          SizedBox(
                            width: wide ? 280 : 220,
                            child: Text(
                              record.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              kind == 'Từ vựng'
                                  ? '${record.fields['Pinyin']} · ${record.fields['Nghĩa Việt']}'
                                  : record.fields.values.skip(1).firstOrNull ??
                                        '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(record.status)),
                        DataCell(
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => editor(kind, record),
                                child: const Text('Mở'),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Thao tác bản ghi mẫu',
                                onSelected: (value) =>
                                    action(kind, record, value),
                                itemBuilder: (_) => [
                                  if (record.status == 'Nháp')
                                    const PopupMenuItem(
                                      value: 'Đã duyệt mẫu',
                                      child: Text('Duyệt (mẫu)'),
                                    ),
                                  if (record.status == 'Đã duyệt mẫu')
                                    const PopupMenuItem(
                                      value: 'Công bố mẫu',
                                      child: Text('Công bố (mẫu)'),
                                    ),
                                  if (record.status == 'Công bố mẫu')
                                    const PopupMenuItem(
                                      value: 'Thu hồi mẫu',
                                      child: Text('Thu hồi (mẫu)'),
                                    ),
                                  if (kind == 'Báo lỗi' &&
                                      record.status != 'Đã đóng mẫu')
                                    const PopupMenuItem(
                                      value: 'Đã đóng mẫu',
                                      child: Text('Đóng báo lỗi (mẫu)'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'Xóa bản ghi mẫu',
                                    child: Text('Xóa bản ghi mẫu'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${filtered.length} bản ghi · Trang ${page + 1}/${lastPage + 1}',
              ),
              OutlinedButton(
                onPressed: page == 0 ? null : () => setState(() => page--),
                child: const Text('Trang trước'),
              ),
              OutlinedButton(
                onPressed: page >= lastPage
                    ? null
                    : () => setState(() => page++),
                child: const Text('Trang sau'),
              ),
            ],
          ),
        ],
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text('Hanyu AI · Admin mẫu · $kind')),
      drawer: wide ? null : Drawer(child: nav),
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  SizedBox(width: 230, child: nav),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
    );
  }
}
