import 'package:flutter/material.dart';

import '../ui_tokens.dart';

class LearnerSurface extends StatelessWidget {
  const LearnerSurface({
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color == Colors.white ? surfaceBorder : color),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class LearnerSplit extends StatelessWidget {
  const LearnerSplit({
    required this.main,
    required this.aside,
    this.sidebarFirstOnNarrow = false,
    super.key,
  });
  final Widget main, aside;
  final bool sidebarFirstOnNarrow;

  @override
  Widget build(BuildContext context) {
    // On desktop the shell reserves a rail and horizontal content insets.
    if (MediaQuery.sizeOf(context).width < 1024) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sidebarFirstOnNarrow) aside else main,
          const SizedBox(height: 16),
          if (sidebarFirstOnNarrow) main else aside,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: main),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: aside),
      ],
    );
  }
}

class StudyStreak extends StatelessWidget {
  const StudyStreak(this.days, {super.key});
  final int days;
  @override
  Widget build(BuildContext context) => Chip(
    backgroundColor: streakSurface,
    side: BorderSide.none,
    avatar: const Icon(Icons.emoji_events_outlined, color: streakInk, size: 17),
    label: Text(
      '$days ngày liên tiếp',
      style: const TextStyle(color: streakInk),
    ),
  );
}
