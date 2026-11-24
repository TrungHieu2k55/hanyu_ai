import 'package:doanchuyennganh2/features/auth/presentation/auth_flow_screens.dart';
import 'package:doanchuyennganh2/features/settings/domain/learning_preferences.dart';
import 'package:doanchuyennganh2/core/validation/form_validators.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/auth/presentation/recovery_screen.dart';
import 'package:doanchuyennganh2/features/privacy/presentation/policy_screen.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';

import 'account_scaffold.dart';

enum AccountIntent {
  learning('Tiếp tục hành trình học tiếng Trung.'),
  saveWord('Quay về từ đang xem để tự xác nhận lưu.'),
  photo('Quay về bước chọn ảnh. Ảnh chỉ được mở khi bạn chọn lại.'),
  conversation('Quay về tình huống để tự bắt đầu hội thoại.');

  const AccountIntent(this.description);
  final String description;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    this.preferences,
    this.startInRegistration = false,
    this.returnTo = AccountIntent.learning,
    super.key,
  });
  final bool startInRegistration;
  final AccountIntent returnTo;
  final LearningPreferences? preferences;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool register = widget.startInRegistration;
  bool hide = true, terms = false, training = false;
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool termsError = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    confirmation.dispose();
    password.dispose();
    super.dispose();
  }

  void showConnection(String provider) {
    FocusScope.of(context).unfocus();
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountScaffold(
          title: 'Kết nối tài khoản',
          body: AuthConnectionScreen(
            provider: provider,
            returnMessage: widget.returnTo.description,
          ),
        ),
      ),
    );
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    if (register && !terms) {
      setState(() => termsError = true);
      return;
    }
    FocusScope.of(context).unfocus();
    if (register) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => AccountScaffold(
            title: 'Xác minh email',
            body: EmailVerificationScreen(
              email: email.text.trim(),
              displayName: name.text.trim(),
              preferences: widget.preferences ?? LearningPreferences(),
            ),
          ),
        ),
      );
    } else {
      showConnection('email');
    }
  }

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: register ? 'Tạo tài khoản' : 'Chào mừng trở lại',
    action: FilledButton(
      onPressed: submit,
      child: Text(
        register ? 'Kiểm tra form đăng ký' : 'Kiểm tra form đăng nhập',
      ),
    ),
    body: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.returnTo.description,
            style: const TextStyle(color: mutedText),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bản mẫu · chỉ nhập thông tin ví dụ.',
            style: TextStyle(color: mutedText, fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: register && !terms
                ? null
                : () => showConnection('Google'),
            icon: const ExcludeSemantics(
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white,
                child: Text(
                  'G',
                  style: TextStyle(
                    color: brandTeal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            label: const Text('Tiếp tục với Google'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'hoặc dùng email',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedText),
            ),
          ),
          if (register) ...[
            TextFormField(
              key: const ValueKey('account-name'),
              controller: name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            key: const ValueKey('account-email'),
            controller: email,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email mẫu',
              hintText: 'ban@example.com',
            ),
            validator: FormValidators.email,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('account-password'),
            controller: password,
            enableSuggestions: false,
            autocorrect: false,
            textInputAction: register
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!register) submit();
            },
            obscureText: hide,
            decoration: InputDecoration(
              labelText: 'Mật khẩu mẫu',
              suffixIcon: IconButton(
                tooltip: hide ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: () => setState(() => hide = !hide),
                icon: Icon(
                  hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: FormValidators.password,
          ),
          if (register) ...[
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('account-confirmation'),
              controller: confirmation,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => submit(),
              obscureText: hide,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Xác nhận mật khẩu mẫu',
              ),
              validator: (value) =>
                  FormValidators.confirmation(value, password.text),
            ),

            TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const DetailScaffold(
                    title: 'Điều khoản và riêng tư',
                    body: PolicyScreen(),
                  ),
                ),
              ),
              child: const Text('Đọc điều khoản và quyền riêng tư'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: terms,
              onChanged: (v) => setState(() {
                terms = v ?? false;
                termsError = false;
              }),
              title: const Text(
                'Tôi đồng ý Điều khoản sử dụng',
                style: TextStyle(fontSize: 15),
              ),
            ),
            if (termsError)
              const Text(
                'Cần đồng ý điều khoản để xem bước đăng ký tiếp theo.',
                style: TextStyle(color: Color(0xFFB42318)),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: training,
              onChanged: (v) => setState(() => training = v ?? false),
              title: const Text(
                'Cho phép góp dữ liệu học để cải thiện mô hình (tùy chọn)',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const RecoveryScreen()),
                ),
                child: const Text('Quên mật khẩu?'),
              ),
            ),
          const SizedBox(height: 8),
          const Divider(color: surfaceBorder),
          OutlinedButton(
            onPressed: () => setState(() {
              register = !register;
              termsError = false;
            }),
            child: Text(
              register
                  ? 'Đã có tài khoản? Đăng nhập'
                  : 'Chưa có tài khoản? Đăng ký',
            ),
          ),
        ],
      ),
    ),
  );
}

class AccountPreviewLink extends StatelessWidget {
  const AccountPreviewLink({
    required this.intent,
    required this.label,
    super.key,
  });

  final AccountIntent intent;
  final String label;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () {
      FocusScope.of(context).unfocus();
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => AuthScreen(returnTo: intent)),
      );
    },
    child: Text(label),
  );
}
