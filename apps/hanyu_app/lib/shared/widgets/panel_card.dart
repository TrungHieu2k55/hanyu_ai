import 'package:flutter/material.dart';

class PanelCard extends StatelessWidget {
  const PanelCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
}
