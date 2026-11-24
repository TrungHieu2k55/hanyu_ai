import 'package:flutter/material.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({
    required this.title,
    required this.child,
    this.actions = const [],
    super.key,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: actions,
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    ),
  );
}
