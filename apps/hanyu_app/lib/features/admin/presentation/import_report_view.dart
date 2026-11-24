import 'package:flutter/material.dart';

import '../domain/vocabulary_import.dart';

class ImportReportView extends StatelessWidget {
  const ImportReportView({required this.report, super.key});
  final VocabularyImportReport report;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${report.drafts.length} bản ghi hợp lệ · ${report.rejectedRecords} bản ghi có lỗi',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      const Text(
        'Chỉ số bản ghi CSV tính cả hàng tiêu đề là số 1; ô nhiều dòng vẫn là một bản ghi. Kiểm tra này chưa xác minh Pinyin, nghĩa hoặc bản quyền.',
      ),
      if (report.issues.isNotEmpty)
        LayoutBuilder(
          builder: (context, box) => box.maxWidth < 600
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final issue in report.issues.take(50))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bản ghi ${issue.record} · ${issue.field}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              issue.message,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              : _IssueTable(issues: report.issues.take(50).toList()),
        ),
      if (report.issues.length > 50)
        Text('Đang hiển thị 50/${report.issues.length} lỗi đầu tiên.'),
      const SizedBox(height: 20),
      for (final draft in report.drafts.take(20))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('${draft.hanzi} · ${draft.pinyin} · ${draft.vietnamese}'),
        ),
      if (report.drafts.length > 20)
        Text('… và ${report.drafts.length - 20} bản nháp khác.'),
    ],
  );
}

class _IssueTable extends StatelessWidget {
  const _IssueTable({required this.issues});
  final List<ImportIssue> issues;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      dataRowMinHeight: 56,
      dataRowMaxHeight: 100,
      columns: const [
        DataColumn(label: Text('Bản ghi')),
        DataColumn(label: Text('Trường')),
        DataColumn(label: Text('Lỗi')),
      ],
      rows: [
        for (final issue in issues)
          DataRow(
            cells: [
              DataCell(Text('${issue.record}')),
              DataCell(Text(issue.field)),
              DataCell(
                SizedBox(
                  width: 280,
                  child: Text(
                    issue.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}
