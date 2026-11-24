import 'package:flutter/material.dart';

import '../../../shared/ui_tokens.dart';

class AccountScaffold extends StatelessWidget {
  const AccountScaffold({
    required this.title,
    required this.body,
    this.action,
    this.onBack,
    super.key,
  });

  final String title;
  final Widget body;
  final Widget? action;
  final VoidCallback? onBack;

  static Widget _bounded(Widget child) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 496),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: onBack == null ? null : BackButton(onPressed: onBack),
    ),
    body: SafeArea(
      bottom: action == null,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              child: _bounded(body),
            ),
          ),
          if (action case final action?)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: surfaceBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
                  child: _bounded(
                    SizedBox(width: double.infinity, child: action),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
