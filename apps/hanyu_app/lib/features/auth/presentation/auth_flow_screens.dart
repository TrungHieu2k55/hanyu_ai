import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/settings/domain/learning_preferences.dart';
import 'package:doanchuyennganh2/features/settings/presentation/study_settings_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/status_panel.dart';

class AuthConnectionScreen extends StatelessWidget {
  const AuthConnectionScreen({
    required this.provider,
    required this.returnMessage,
    super.key,
  });
  final String provider;
  final String returnMessage;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Đăng nhập chưa sẵn sàng',
        'Bạn đang xem luồng $provider. Chưa tạo tài khoản hoặc phiên đăng nhập.',
      ),
      const SizedBox(height: 24),
      const PreviewStatusPanel(
        state: PreviewState.notConfigured,
        message: 'Dịch vụ tài khoản chưa được kết nối. Không gửi mật khẩu, không nhận token và không tự thực hiện thao tác riêng tư.',
      ),
      const SizedBox(height: 12),
      Text(returnMessage),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Về form, giữ thông tin đang nhập'),
      ),
    ],
  );
}

enum EmailVerificationStage { pending, expired, verified }

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    required this.email,
    this.displayName = '',
    required this.preferences,
    super.key,
  });
  final String email;
  final String displayName;
  final LearningPreferences preferences;
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  EmailVerificationStage stage = EmailVerificationStage.pending;
  bool resendPreview = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Xác minh email · bản mẫu',
        'Email: ${widget.email}. Chưa gửi thư hoặc tạo tài khoản thật.',
      ),
      if (widget.displayName.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Tên hiển thị: ${widget.displayName}'),
      ],
      const SizedBox(height: 24),
      PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              stage == EmailVerificationStage.verified
                  ? Icons.mark_email_read_outlined
                  : Icons.mark_email_unread_outlined,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              switch (stage) {
                EmailVerificationStage.pending => 'Chờ kiểm tra email',
                EmailVerificationStage.expired => 'Liên kết mẫu hết hạn',
                EmailVerificationStage.verified =>
                  'Email đã xác minh · trạng thái minh họa',
              },
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Trong ứng dụng thật, trạng thái phải do dịch vụ Auth xác nhận. Bản này chỉ chuyển màn để xem trải nghiệm.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (stage != EmailVerificationStage.verified) ...[
        FilledButton(
          onPressed: () =>
              setState(() => stage = EmailVerificationStage.verified),
          child: const Text('Xem xác minh thành công (mẫu)'),
        ),
        TextButton(
          onPressed: () => setState(() {
            stage = EmailVerificationStage.pending;
            resendPreview = true;
          }),
          child: const Text('Xem gửi lại email (mẫu)'),
        ),
        TextButton(
          onPressed: () =>
              setState(() => stage = EmailVerificationStage.expired),
          child: const Text('Xem liên kết hết hạn (mẫu)'),
        ),
      ] else
        FilledButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DetailScaffold(
                title: 'Mục tiêu học mẫu',
                body: StudySettingsScreen(preferences: widget.preferences),
              ),
            ),
          ),
          child: const Text('Chọn mục tiêu học mẫu'),
        ),
      if (resendPreview)
        const Text(
          'Đã xem thao tác gửi lại mẫu. Không có email thật nào được gửi.',
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Về đăng ký'),
      ),
    ],
  );
}

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});
  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool logoutPreview = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Bảo mật tài khoản · mẫu',
        'Bạn chưa có phiên đăng nhập thật. Các thao tác không gọi Auth hoặc xóa dữ liệu tạm.',
      ),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => const DetailScaffold(
              title: 'Đổi mật khẩu · mẫu',
              body: PasswordChangeScreen(),
            ),
          ),
        ),
        child: const Text('Xem form đổi mật khẩu'),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: () async {
          final yes = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: const Text('Đăng xuất · xác nhận mẫu?'),
              content: const Text(
                'Chưa có phiên Auth thật để đăng xuất. Bản mẫu chỉ xem xác nhận, không xóa từ hoặc tiến độ tạm.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Ở lại'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Xem xác nhận đăng xuất'),
                ),
              ],
            ),
          );
          if (yes == true && mounted) setState(() => logoutPreview = true);
        },
        child: const Text('Xem thao tác đăng xuất'),
      ),
      if (logoutPreview)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Đã xem xác nhận đăng xuất mẫu. Không có phiên thật nào bị thay đổi.',
          ),
        ),
    ],
  );
}

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});
  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool hidden = true, checked = false;
  @override
  void dispose() {
    current.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Đổi mật khẩu',
          'Chỉ dùng mật khẩu mẫu. Bản này không xác thực mật khẩu cũ hoặc gửi thay đổi lên máy chủ.',
        ),
        const SizedBox(height: 24),
        for (final field in [
          (current, 'Mật khẩu hiện tại mẫu'),
          (password, 'Mật khẩu mới mẫu'),
          (confirmation, 'Nhập lại mật khẩu mới'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextFormField(
              controller: field.$1,
              obscureText: hidden,
              decoration: InputDecoration(labelText: field.$2),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Không được để trống.';
                }
                if (field.$1 == password && value.length < 8) {
                  return 'Cần ít nhất 8 ký tự.';
                }
                if (field.$1 == confirmation && value != password.text) {
                  return 'Hai mật khẩu chưa khớp.';
                }
                return null;
              },
            ),
          ),
        TextButton(
          onPressed: () => setState(() => hidden = !hidden),
          child: Text(hidden ? 'Hiện mật khẩu mẫu' : 'Ẩn mật khẩu mẫu'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) setState(() => checked = true);
          },
          child: const Text('Kiểm tra form đổi mật khẩu'),
        ),
        if (checked)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: PreviewStatusPanel(
              state: PreviewState.notConfigured,
              message: 'Form hợp lệ. Mật khẩu thật chưa được thay đổi vì chưa kết nối Auth.',
            ),
          ),
      ],
    ),
  );
}
