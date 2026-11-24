import '../../../shared/widgets/learner_surface.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/status_panel.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/local/local_providers.dart';
import '../../../core/media/practice_media.dart';
import '../../../core/local/local_models.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../domain/local_practice.dart';
import 'practice_widgets.dart';

class LocalPhotoEditor extends ConsumerStatefulWidget {
  const LocalPhotoEditor({this.entry, super.key});
  final LocalPracticeEntry? entry;
  @override
  ConsumerState<LocalPhotoEditor> createState() => _LocalPhotoEditorState();
}

class _LocalPhotoEditorState extends PracticeEditorState<LocalPhotoEditor> {
  late final id = widget.entry?.id ?? const Uuid().v4(),
      created = widget.entry?.createdAt ?? DateTime.now().toUtc();
  late final editor = TextEditingController(
    text: widget.entry?.data['text'] as String? ?? '',
  );
  late String? imageId = widget.entry?.data['imageId'] as String?;
  LocalMediaInput? input, pending;
  String? lookedUp, error;
  bool picking = false, permissionDenied = false;
  @override
  String get intent => jsonEncode([editor.text, imageId, pending?.id]);
  @override
  void initState() {
    super.initState();
    saved = intent;
  }

  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  Future<void> pick(bool camera) async {
    onBusy(true);
    setState(() {
      error = null;
      permissionDenied = false;
      picking = true;
    });
    try {
      final m = await ref
          .read(practiceImagePickerProvider)
          .pick(camera: camera);
      if (mounted && m != null) setState(() => pending = m);
    } catch (e) {
      if (mounted) {
        setState(() {
          permissionDenied =
              e is PlatformException &&
              {
                'camera_access_denied',
                'camera_access_restricted',
                'photo_access_denied',
                'photo_access_restricted',
              }.contains(e.code);
          error = e is LocalDataException
              ? e.message
              : permissionDenied
              ? 'Kiểm tra quyền thiết bị, chọn nguồn ảnh khác hoặc tiếp tục bằng văn bản.'
              : 'Chưa mở được ảnh/camera. Hãy chọn tệp JPEG/PNG hoặc nhập văn bản.';
        });
      }
    } finally {
      if (mounted) setState(() => picking = false);
      onBusy(false);
    }
  }

  Future<void> save(String op) async {
    final e = LocalPracticeEntry(
      id: id,
      kind: PracticeKind.photo,
      createdAt: created,
      updatedAt: created,
      data: {
        'original': widget.entry?.data['original'] ?? editor.text,
        'text': editor.text,
        'imageId': imageId,
      },
    );
    await ref
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.savePractice(
            e,
            media: input == null ? [] : [input!],
            revision: revision,
            operationId: op,
          ),
        );
    await committed();
    if (mounted && widget.entry == null) context.go('/photos/$id');
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ==
      true;
  @override
  Widget build(BuildContext context) {
    track();
    final data = ref.watch(localControllerProvider).requireValue;
    final matches = lookedUp == null
        ? const <LocalWord>[]
        : data.words.where((w) => lookedUp!.contains(w.entry.hanzi)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Kiểm tra ảnh và văn bản',
          'Chọn ảnh và tự nhập văn bản. Chưa có OCR; ảnh không được gửi lên mạng.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : () => pick(false),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Chọn ảnh thật'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : () => pick(true),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Chụp ảnh'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (picking)
          const StatusPanel(
            icon: Icons.photo_outlined,
            title: 'Đang mở nguồn ảnh',
            message: 'Chọn ảnh hoặc đóng cửa sổ chọn để tiếp tục.',
            loading: true,
          )
        else if (error != null)
          StatusPanel(
            icon: permissionDenied
                ? Icons.lock_outline
                : Icons.broken_image_outlined,
            title: permissionDenied
                ? 'Chưa có quyền mở nguồn ảnh'
                : 'Chưa mở được ảnh',
            message: error!,
            actionLabel: 'Chọn ảnh khác',
            onAction: () => pick(false),
          ),
        if (pending != null) ...[
          _PhotoPreview(
            child: Image.memory(
              pending!.bytes,
              height: 240,
              fit: BoxFit.contain,
            ),
          ),
          const Text('Ảnh xem trước · chưa chọn dùng hoặc lưu.'),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: () => setState(() {
                  input = pending;
                  imageId = input!.id;
                  pending = null;
                }),
                child: const Text('Dùng ảnh này'),
              ),
              TextButton(
                onPressed: () => setState(() => pending = null),
                child: const Text('Hủy ảnh xem trước'),
              ),
            ],
          ),
        ] else if (input != null)
          _PhotoPreview(
            child: Image.memory(input!.bytes, height: 240, fit: BoxFit.contain),
          )
        else if (imageId != null)
          _PhotoPreview(child: SavedImage(id: imageId!)),
        if (imageId != null)
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    if (!await confirm(
                      'Bỏ ảnh, giữ văn bản?',
                      'Thay đổi chỉ có hiệu lực sau khi lưu. Văn bản đã có vẫn được giữ.',
                    )) {
                      return;
                    }
                    if (mounted) {
                      setState(() {
                        imageId = null;
                        input = null;
                      });
                    }
                  },
            child: const Text('Bỏ ảnh, giữ văn bản'),
          ),
        const SizedBox(height: 16),
        if (widget.entry != null)
          ExpansionTile(
            title: const Text('Bản chữ tự nhập đầu tiên'),
            children: [Text(widget.entry!.data['original'] as String)],
          ),
        TextField(
          controller: editor,
          enabled: !busy,
          minLines: 3,
          maxLines: 8,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Văn bản bạn tự nhập / đang sửa',
            helperText: 'Pinyin và nghĩa chưa được AI kiểm chứng.',
          ),
          onChanged: (_) => setState(() => lookedUp = null),
        ),
        const SizedBox(height: 16),
        AsyncCommitButton(
          label: 'Lưu ảnh và văn bản',
          intentKey: 'photo:$id:$intent',
          enabled: !busy && pending == null,
          onBusyChanged: onBusy,
          onCommit: save,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: busy || editor.text.trim().isEmpty
              ? null
              : () => setState(() => lookedUp = editor.text.trim()),
          child: const Text('Tra trong từ điển local'),
        ),
        if (lookedUp != null && matches.isEmpty)
          const StatusPanel(
            icon: Icons.search_off_outlined,
            title: 'Không có kết quả',
            message: 'Chưa có từ khớp. Bạn có thể tự thêm từ riêng.',
          ),
        for (final w in matches)
          PracticeWordAction(
            word: w,
            revision: revision,
            scope: 'photo',
            enabled: !busy && saved == intent,
            onBusy: onBusy,
            onSaved: committed,
          ),
        if (saved != intent)
          const Text(
            'Lưu ảnh/văn bản trước khi mở màn khác hoặc lưu từ vào ôn.',
          ),
        TextButton(
          onPressed: busy || saved != intent
              ? null
              : () => context.push('/personal/new'),
          child: const Text('Tự thêm từ cá nhân, Pinyin và nghĩa'),
        ),
        reloadButton(),
        if (widget.entry != null)
          AsyncCommitButton(
            label: 'Xóa cả ghi chú này',
            intentKey: 'delete-photo:$id',
            enabled: !busy,
            onBusyChanged: onBusy,
            onCommit: (op) async {
              if (!await confirm(
                'Xóa ghi chú ảnh?',
                'Ảnh và văn bản của ghi chú sẽ bị xóa khỏi thiết bị. Hãy xuất backup nếu cần giữ.',
              )) {
                return;
              }
              await ref
                  .read(localControllerProvider.notifier)
                  .commit(
                    (r) => r.deletePractice(
                      id,
                      revision: revision,
                      operationId: op,
                    ),
                  );
              await committed();
              if (context.mounted) context.go('/photos');
            },
          ),
        TextButton(
          onPressed: busy ? null : () => context.go('/photos'),
          child: const Text('Về lịch sử ảnh và văn bản'),
        ),
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LearnerSurface(
    color: const Color(0xFFF1F5F9),
    child: Center(child: child),
  );
}
