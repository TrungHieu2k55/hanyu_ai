import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localDraftsProvider = Provider((ref) => LocalDrafts());

class LocalDrafts {
  Object? owner;
  bool dirty = false, busy = false;
  void update(Object editor, {required bool changed, required bool saving}) {
    owner = editor;
    dirty = changed;
    busy = saving;
  }

  void clear(Object editor) {
    if (identical(owner, editor)) {
      owner = null;
      dirty = false;
      busy = false;
    }
  }

  Future<bool> mayLeave(BuildContext context) async {
    if (busy) return false;
    if (!dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Rời khi chưa lưu?'),
        content: const Text('Bạn có thể ở lại để lưu bản nháp trước.'),
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
    if (discard == true) {
      dirty = false;
      return true;
    }
    return false;
  }
}
