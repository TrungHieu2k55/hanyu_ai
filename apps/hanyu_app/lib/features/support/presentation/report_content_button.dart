import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/local_feedback.dart';

/// Only the explicit public content identifiers enter report context.
class ReportContentButton extends StatelessWidget {
  const ReportContentButton({
    required this.contentId,
    required this.version,
    required this.label,
    required this.route,
    this.enabled = true,
    super.key,
  });
  final String contentId, version, label, route;
  final bool enabled;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: enabled
        ? () => context.push(
            '/feedback/new',
            extra: FeedbackContext({
              'contentId': contentId,
              'contentVersion': version,
              'label': label,
              'route': route,
            }),
          )
        : null,
    icon: const Icon(Icons.flag_outlined),
    label: const Text('Báo lỗi học liệu'),
  );
}
