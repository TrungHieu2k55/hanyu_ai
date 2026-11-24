import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/ocr/domain/scan_record.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({
    super.key,
    required this.history,
    required this.onOpenScan,
    required this.onChanged,
  });
  final List<ScanRecord> history;
  final Future<void> Function(BuildContext context, ScanRecord scan) onOpenScan;
  final VoidCallback onChanged;
  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildPageTitle(
        'Lịch sử scan mẫu',
        'Chỉ giữ trong lần mở ứng dụng này, chưa phải lịch sử trên server.',
      ),
      const SizedBox(height: 24),
      if (widget.history.isEmpty)
        const PanelCard(
          child: Text('Chưa có scan mẫu. Quay lại Quét chữ để bắt đầu.'),
        ),
      for (final scan in widget.history.reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scan mẫu ${scan.number}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(scan.editedText),
                const SizedBox(height: 8),
                Text(
                  scan.hasImage
                      ? 'Có hình minh họa · văn bản đã giữ'
                      : 'Đã bỏ ảnh mẫu · văn bản còn',
                  style: const TextStyle(color: mutedText, fontSize: 14),
                ),
                TextButton(
                  onPressed: () async {
                    await widget.onOpenScan(context, scan);
                    if (mounted) setState(() {});
                  },
                  child: const Text('Mở lại kết quả'),
                ),
                if (scan.hasImage)
                  TextButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          title: const Text('Bỏ ảnh mẫu này?'),
                          content: const Text(
                            'Văn bản và từ đã lưu vẫn giữ. Đây là thao tác trên dữ liệu mẫu trong bộ nhớ.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, false),
                              child: const Text('Giữ ảnh'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dialog, true),
                              child: const Text('Bỏ ảnh mẫu'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        setState(() => scan.hasImage = false);
                        widget.onChanged();
                      }
                    },
                    icon: const Icon(Icons.hide_image_outlined),
                    label: const Text('Bỏ hình minh họa'),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}
