import 'package:flutter/material.dart';

Future<bool> confirmWordRemoval(BuildContext context, String hanzi) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Bỏ $hanzi khỏi bộ ôn?'),
        content: const Text(
          'Từ sẽ không có trong bộ ôn mẫu mới. Ghi chú vẫn được giữ trong lần mở app này; phiên đang dở vẫn giữ bộ thẻ đã chọn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Bỏ khỏi bộ ôn'),
          ),
        ],
      ),
    ) ??
    false;
