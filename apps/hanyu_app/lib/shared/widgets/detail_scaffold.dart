import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/widgets/preview_notice.dart';

class DetailScaffold extends StatelessWidget {
  const DetailScaffold({super.key, required this.title, required this.body});
  final String title;
  final Widget body;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const PreviewNotice(),
              const SizedBox(height: 24),
              body,
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  );
}
