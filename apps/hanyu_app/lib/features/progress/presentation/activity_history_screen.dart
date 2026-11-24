import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/core/utils/vietnam_time.dart';
import 'package:doanchuyennganh2/features/progress/domain/local_activity.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/status_panel.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key, required this.loadItems});
  final List<LocalActivity> Function() loadItems;
  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  String kind = 'Tất cả', period = 'Tất cả thời gian';
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final items = widget.loadItems().where((item) {
      final date = item.createdAt.toUtc().add(const Duration(hours: 7));
      final dateMatches =
          period == 'Tất cả thời gian' ||
          (period == 'Hôm nay'
              ? date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day
              : item.createdAt.isAfter(
                  DateTime.now().toUtc().subtract(const Duration(days: 7)),
                ));
      return (kind == 'Tất cả' || item.kind == kind) && dateMatches;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Lịch hoạt động mẫu',
          'Thời điểm bắt đầu phiên/tác vụ, hiển thị giờ Việt Nam. Chỉ có dữ liệu trong bộ nhớ của lần mở app.',
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: period,
          decoration: const InputDecoration(labelText: 'Khoảng thời gian'),
          items: [
            for (final p in ['Tất cả thời gian', 'Hôm nay', '7 ngày gần đây'])
              DropdownMenuItem(value: p, child: Text(p)),
          ],
          onChanged: (v) => setState(() => period = v!),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in ['Tất cả', 'Ôn tập', 'OCR', 'Hội thoại', 'Thi'])
              ChoiceChip(
                label: Text(value),
                selected: kind == value,
                onSelected: (_) => setState(() => kind = value),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('${items.length} hoạt động mẫu'),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const PreviewStatusPanel(
            state: PreviewState.empty,
            message: 'Chưa có hoạt động khớp bộ lọc này. Thử loại khác hoặc quay lại bắt đầu một hoạt động.',
          ),
        for (final item in items)
          buildActionTile(
            Icons.history,
            item.title,
            '${item.detail}\n${formatVietnamTime(item.createdAt)} · giờ Việt Nam',
            () async {
              await item.onOpen();
              if (mounted) setState(() {});
            },
          ),
      ],
    );
  }
}
