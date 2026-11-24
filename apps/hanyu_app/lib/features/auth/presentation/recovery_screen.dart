import 'package:flutter/material.dart';

import '../../../core/validation/form_validators.dart';
import '../../../shared/ui_tokens.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/learner_surface.dart';
import 'account_scaffold.dart';

enum _RecoveryStage { email, inbox, reset, expired, done }

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  _RecoveryStage stage = _RecoveryStage.email;
  bool hidden = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void move(_RecoveryStage next) {
    FocusScope.of(context).unfocus();
    setState(() => stage = next);
  }

  void submit(_RecoveryStage next) {
    if (form.currentState?.validate() == true) move(next);
  }

  @override
  Widget build(BuildContext context) {
    final (title, action, onAction) = switch (stage) {
      _RecoveryStage.email => (
        'Khôi phục mật khẩu',
        'Xem bước kiểm tra email',
        () => submit(_RecoveryStage.inbox),
      ),
      _RecoveryStage.inbox => (
        'Kiểm tra hộp thư',
        'Mở liên kết mẫu hợp lệ',
        () => move(_RecoveryStage.reset),
      ),
      _RecoveryStage.reset => (
        'Đặt lại mật khẩu',
        'Kiểm tra mật khẩu mới',
        () => submit(_RecoveryStage.done),
      ),
      _RecoveryStage.expired => (
        'Liên kết hết hạn',
        'Nhập lại email',
        () => move(_RecoveryStage.email),
      ),
      _RecoveryStage.done => (
        'Hoàn tất bản mẫu',
        'Về đăng nhập',
        () => Navigator.pop(context),
      ),
    };
    return AccountScaffold(
      title: title,
      action: FilledButton(onPressed: onAction, child: Text(action)),
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stage == _RecoveryStage.email) ...[
              const Text('Nhập địa chỉ email mẫu để xem luồng khôi phục.'),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('recovery-email'),
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submit(_RecoveryStage.inbox),
                decoration: const InputDecoration(
                  labelText: 'Email khôi phục mẫu',
                ),
                validator: FormValidators.email,
              ),
              const SizedBox(height: 16),
              const _RecoveryNotice(
                glyph: FigmaGlyph.recoveryFlag,
                message:
                    'Liên kết khôi phục có thời hạn. Bản mẫu chưa gửi email.',
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại đăng nhập'),
              ),
            ] else if (stage == _RecoveryStage.inbox) ...[
              _RecoveryNotice(
                glyph: FigmaGlyph.recoveryCheck,
                message:
                    '${email.text.trim()}\nTrong ứng dụng thật, hãy kiểm tra email và thư rác. Bản mẫu chưa gửi thư nào.',
              ),
              TextButton(
                onPressed: () => move(_RecoveryStage.expired),
                child: const Text('Xem liên kết hết hạn'),
              ),
            ] else if (stage == _RecoveryStage.reset) ...[
              const Text('Chỉ dùng mật khẩu mẫu cho bước này.'),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('new-password'),
                controller: password,
                obscureText: hidden,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới mẫu',
                  suffixIcon: IconButton(
                    tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: FormValidators.password,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('confirm-password'),
                obscureText: hidden,
                enableSuggestions: false,
                autocorrect: false,
                onFieldSubmitted: (_) => submit(_RecoveryStage.done),
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu mới',
                ),
                validator: (value) =>
                    FormValidators.confirmation(value, password.text),
              ),
            ] else if (stage == _RecoveryStage.expired)
              const _RecoveryNotice(
                glyph: FigmaGlyph.recoveryFlag,
                message: 'Liên kết mẫu đã hết hạn hoặc không hợp lệ. Ở ứng dụng thật, bạn cần yêu cầu một liên kết mới.',
              )
            else
              const _RecoveryNotice(
                glyph: FigmaGlyph.recoveryCheck,
                message: 'Đã hoàn thành luồng mẫu. Mật khẩu thật chưa được thay đổi.',
              ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryNotice extends StatelessWidget {
  const _RecoveryNotice({required this.glyph, required this.message});
  final FigmaGlyph glyph;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: LearnerSurface(
      color: softSurface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FigmaIcon(glyph),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
