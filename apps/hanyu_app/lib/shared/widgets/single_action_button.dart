import 'package:flutter/material.dart';

class SingleActionButton extends StatefulWidget {
  const SingleActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  State<SingleActionButton> createState() => _SingleActionButtonState();
}

class _SingleActionButtonState extends State<SingleActionButton> {
  bool fired = false;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: fired
        ? null
        : () {
            if (fired) return;
            setState(() => fired = true);
            widget.onPressed();
          },
    child: Text(widget.label),
  );
}
