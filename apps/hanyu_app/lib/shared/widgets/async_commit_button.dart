import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';

/// One receipt ID per intent; retry uses the same ID until success or edited input.
class AsyncCommitButton extends StatefulWidget {
  const AsyncCommitButton({
    required this.label,
    required this.intentKey,
    required this.onCommit,
    this.onBusyChanged,
    this.enabled = true,
    this.compact = false,
    super.key,
  });
  final String label, intentKey;
  final bool enabled;
  final bool compact;
  final Future<void> Function(String operationId) onCommit;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<AsyncCommitButton> createState() => _AsyncCommitButtonState();
}

class _AsyncCommitButtonState extends State<AsyncCommitButton> {
  bool busy = false;
  String? error, operationId;
  @override
  void didUpdateWidget(covariant AsyncCommitButton old) {
    super.didUpdateWidget(old);
    if (!busy && old.intentKey != widget.intentKey) {
      operationId = null;
      error = null;
    }
  }

  Future<void> commit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      operationId ??= const Uuid().v4();
    });
    widget.onBusyChanged?.call(true);
    try {
      await widget.onCommit(operationId!);
      if (mounted) setState(() => operationId = null);
    } catch (problem) {
      if (mounted) {
        setState(
          () => error = problem is LocalDataException ? problem.message : 'Chưa lưu được. Nội dung vẫn giữ trên màn; kiểm tra bộ nhớ rồi thử lại.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.compact)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            minimumSize: const Size(48, 48),
          ),
          onPressed: busy || !widget.enabled ? null : commit,
          child: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.label),
        )
      else
        FilledButton(
          onPressed: busy || !widget.enabled ? null : commit,
          child: Text(
            busy
                ? 'Đang lưu…'
                : error != null
                ? 'Thử lại · ${widget.label}'
                : widget.label,
          ),
        ),
      if (error != null) ...[
        const SizedBox(height: 12),
        Semantics(liveRegion: true, child: Text(error!)),
      ],
    ],
  );
}
