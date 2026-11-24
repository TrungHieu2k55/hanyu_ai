import 'package:flutter/material.dart';

class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    this.busy = false,
    required this.child,
  });
  final bool dirty;
  final bool busy;
  final Widget child;
  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool allowed = false;
  bool asking = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.busy && (!widget.dirty || allowed),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || asking || widget.busy) return;
      asking = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Rời khi chưa lưu?'),
          content: const Text(
            'Nội dung vừa chỉnh sẽ bị bỏ. Bạn có thể ở lại để tiếp tục.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Ở lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Bỏ thay đổi và rời'),
            ),
          ],
        ),
      );
      asking = false;
      if (discard != true || !mounted) return;
      setState(() => allowed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    },
    child: widget.child,
  );
}
