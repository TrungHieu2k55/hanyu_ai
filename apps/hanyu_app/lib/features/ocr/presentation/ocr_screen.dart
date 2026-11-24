import 'package:doanchuyennganh2/features/auth/presentation/auth_screen.dart';
import 'package:doanchuyennganh2/features/ocr/presentation/create_personal_word_action.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/ocr/domain/scan_record.dart';
import 'package:doanchuyennganh2/features/ocr/presentation/sample_image.dart';
import 'package:doanchuyennganh2/features/ocr/presentation/scan_history_screen.dart';
import 'package:doanchuyennganh2/features/vocabulary/data/sample_vocabulary.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/word_detail_screen.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/preview_message.dart';
import 'package:doanchuyennganh2/shared/widgets/unsaved_changes_guard.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({
    super.key,
    required this.history,
    required this.saved,
    required this.notes,
    required this.onChanged,
    required this.personalWords,
    required this.nextPersonalId,
    this.scan,
  });
  final List<ScanRecord> history;
  final List<VocabularyItem> personalWords;
  final String Function() nextPersonalId;
  final Set<String> saved;
  final Map<String, String> notes;
  final VoidCallback onChanged;
  final ScanRecord? scan;
  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final editor = TextEditingController();
  ScanRecord? scan;
  int step = 0;
  String? lookedUpText;
  final selected = <String>{};
  List<VocabularyItem> matches = [];
  @override
  void initState() {
    super.initState();
    scan = widget.scan;
    if (scan != null) {
      step = 2;
      editor.text = scan!.editedText;
    }
  }

  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  void lookup() {
    setState(() {
      lookedUpText = editor.text.trim();
      selected.clear();
      // Local dictionary matches, never presented as an OCR provider result.
      matches = [
        ...sampleVocabulary,
        ...widget.personalWords,
      ].where((w) => lookedUpText!.contains(w.hanzi)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dirty = scan != null && editor.text != scan!.editedText;
    return UnsavedChangesGuard(
      dirty: dirty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Học từ chữ quanh bạn',
            'Thử luồng bằng ảnh mẫu. Chưa mở camera, chọn tệp thật hoặc chạy nhận diện AI.',
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailScaffold(
                    title: 'Lịch sử scan mẫu',
                    body: ScanHistoryScreen(
                      history: widget.history,
                      onChanged: widget.onChanged,
                      onOpenScan: (historyContext, scan) =>
                          Navigator.push<void>(
                            historyContext,
                            MaterialPageRoute(
                              builder: (_) => DetailScaffold(
                                title: 'Kết quả scan mẫu',
                                body: OcrScreen(
                                  history: widget.history,
                                  personalWords: widget.personalWords,
                                  nextPersonalId: widget.nextPersonalId,
                                  saved: widget.saved,
                                  notes: widget.notes,
                                  onChanged: widget.onChanged,
                                  scan: scan,
                                ),
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.history),
            label: Text('Lịch sử scan mẫu (${widget.history.length})'),
          ),
          const SizedBox(height: 16),
          if (step == 0) ...[
            const PanelCard(
              child: Column(
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    size: 64,
                    color: brandTeal,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Giữ ảnh thẳng, chụp rõ chữ và tránh lóa.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => setState(() => step = 1),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Chọn ảnh mẫu'),
            ),
            const AccountPreviewLink(
              intent: AccountIntent.photo,
              label: 'Xem luồng đăng nhập trước khi chọn ảnh',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showPreviewMessage(
                context,
                'Camera và thư viện ảnh chưa tích hợp. Dùng ảnh mẫu để xem luồng; chưa xin quyền thiết bị.',
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera / thư viện ảnh'),
            ),
          ] else if (step == 1) ...[
            const SampleScanImage(),
            const SizedBox(height: 16),
            const Text(
              'Hình minh họa nội bộ, không phải ảnh được nhận diện. Chỉ tiếp tục khi bạn muốn xem văn bản mẫu.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                final next = ScanRecord(widget.history.length + 1, '你好！我学习中文。');
                widget.history.add(next);
                setState(() {
                  scan = next;
                  editor.text = next.editedText;
                  step = 2;
                });
                widget.onChanged();
              },
              child: const Text('Xem văn bản mẫu'),
            ),
            TextButton(
              onPressed: () => setState(() => step = 0),
              child: const Text('Đổi nguồn / hủy'),
            ),
          ] else ...[
            if (scan!.hasImage)
              const SampleScanImage()
            else
              const PanelCard(
                child: Row(
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: mutedText),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ảnh mẫu đã bỏ. Văn bản vẫn còn để xem và chỉnh sửa.',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            buildSectionHeading('Văn bản gốc mẫu'),
            const SizedBox(height: 8),
            SelectionArea(
              child: Text(scan!.rawText, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const ValueKey('ocr-editor'),
              controller: editor,
              minLines: 2,
              maxLines: 6,
              maxLength: 2000,
              onChanged: (_) => setState(() {
                lookedUpText = null;
                matches = [];
                selected.clear();
              }),
              decoration: const InputDecoration(
                labelText: 'Bản sửa của bạn',
                alignLabelWithHint: true,
              ),
            ),
            if (dirty)
              const Text(
                'Bản sửa chưa giữ vào lịch sử mẫu.',
                style: TextStyle(color: mutedText, fontSize: 14),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: editor.text.trim().isEmpty ? null : lookup,
              child: const Text('Tra lại trong từ mẫu'),
            ),
            TextButton(
              onPressed: !dirty
                  ? null
                  : () {
                      setState(() => scan!.editedText = editor.text);
                      widget.onChanged();
                      showPreviewMessage(
                        context,
                        'Đã giữ bản sửa trong lịch sử mẫu của lần mở app này.',
                      );
                    },
              child: const Text('Giữ bản sửa vào lịch sử mẫu'),
            ),
            if (lookedUpText == null)
              const Text(
                'Sửa văn bản xong hãy tra lại. Kết quả cũ không dùng cho nội dung vừa sửa.',
                style: TextStyle(color: mutedText, fontSize: 14),
              ),
            if (lookedUpText != null) ...[
              const SizedBox(height: 24),
              buildSectionHeading('Từ khớp trong bộ mẫu và từ riêng'),
              const SizedBox(height: 8),
              const Text(
                'Chỉ khớp từ đã có trong bộ mẫu và danh sách riêng, không tách từ hoặc dịch bằng AI. Nghĩa/Pinyin chưa kiểm duyệt.',
                style: TextStyle(color: mutedText, fontSize: 14),
              ),
              if (matches.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Chưa có từ phù hợp trong bộ mẫu. Không tự tạo nghĩa hoặc Pinyin cho văn bản này.',
                  ),
                ),
              CreatePersonalWordAction(
                text: lookedUpText!,
                words: widget.personalWords,
                nextId: widget.nextPersonalId,
                onCreated: (word) {
                  widget.personalWords.add(word);
                  lookup();
                  widget.onChanged();
                  showPreviewMessage(
                    context,
                    'Đã giữ từ riêng trong RAM. Chọn từ nếu muốn thêm vào bộ ôn mẫu.',
                  );
                },
              ),
              const SizedBox(height: 16),
              for (final word in matches)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(word.id),
                      onChanged: widget.saved.contains(word.id)
                          ? null
                          : (v) => setState(() {
                              if (v == true) {
                                selected.add(word.id);
                              } else {
                                selected.remove(word.id);
                              }
                            }),
                      title: Text(
                        '${word.hanzi} · ${word.pinyin}',
                        style: const TextStyle(fontSize: 19),
                      ),
                      subtitle: Text(
                        (word.personal ? 'Từ riêng · chưa kiểm duyệt · ' : '') +
                            (widget.saved.contains(word.id)
                                ? '${word.vietnamese} · Đã có trong bộ ôn mẫu'
                                : word.vietnamese),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScaffold(
                                title: 'Chi tiết từ',
                                body: WordDetailScreen(
                                  word: word,
                                  saved: widget.saved,
                                  notes: widget.notes,
                                  onChanged: widget.onChanged,
                                ),
                              ),
                            ),
                          );
                          if (mounted) {
                            setState(
                              () => selected.removeWhere(widget.saved.contains),
                            );
                          }
                        },
                        child: Text('Xem từ ${word.hanzi}'),
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              if (matches.isNotEmpty)
                FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          final count = selected
                              .where((id) => !widget.saved.contains(id))
                              .length;
                          widget.saved.addAll(selected);
                          setState(selected.clear);
                          widget.onChanged();
                          showPreviewMessage(
                            context,
                            'Đã thêm $count từ vào bộ ôn mẫu. Chưa đồng bộ tài khoản.',
                          );
                        },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text('Lưu ${selected.length} từ đã chọn'),
                ),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: dirty
                  ? null
                  : () => setState(() {
                      step = 0;
                      scan = null;
                      editor.clear();
                      lookedUpText = null;
                      matches = [];
                      selected.clear();
                    }),
              child: const Text('Bắt đầu scan mẫu mới'),
            ),
          ],
        ],
      ),
    );
  }
}
