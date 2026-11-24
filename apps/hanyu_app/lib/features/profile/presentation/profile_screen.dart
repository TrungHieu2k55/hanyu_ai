import 'package:doanchuyennganh2/features/auth/presentation/auth_flow_screens.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/auth/presentation/auth_screen.dart';
import 'package:doanchuyennganh2/features/onboarding/presentation/welcome_screen.dart';
import 'package:doanchuyennganh2/features/privacy/presentation/privacy_screen.dart';
import 'package:doanchuyennganh2/features/profile/presentation/profile_editor.dart';
import 'package:doanchuyennganh2/features/settings/domain/learning_preferences.dart';
import 'package:doanchuyennganh2/features/settings/presentation/device_permission_screen.dart';
import 'package:doanchuyennganh2/features/settings/presentation/study_settings_screen.dart';
import 'package:doanchuyennganh2/features/support/presentation/feedback_screen.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.preferences,
    required this.onOpen,
    super.key,
  });
  final LearningPreferences preferences;
  final Future<void> Function(String, Widget) onOpen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildPageTitle('Góc của bạn', 'Thiết lập việc học theo nhịp riêng.'),
      const SizedBox(height: 24),
      PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: softSurface,
              child: Icon(Icons.person_outline, color: brandTeal, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              preferences.name.isEmpty ? 'Bạn đang xem thử' : preferences.name,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tài khoản sẽ giúp đồng bộ từ đã lưu và tiến độ trên các thiết bị.',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => AuthScreen(preferences: preferences),
                ),
              ),
              child: const Text('Xem đăng nhập / đăng ký'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      buildActionTile(
        Icons.security_outlined,
        'Bảo mật tài khoản (mẫu)',
        'Đổi mật khẩu và xác nhận đăng xuất.',
        () => onOpen('Bảo mật tài khoản', const AccountSecurityScreen()),
      ),
      buildActionTile(
        Icons.person_outline,
        'Sửa hồ sơ mẫu',
        'Tên hiển thị riêng, chưa tạo tài khoản.',
        () => onOpen('Hồ sơ', ProfileEditor(preferences: preferences)),
      ),
      buildActionTile(
        Icons.explore_outlined,
        'Hướng dẫn bắt đầu',
        'Giới thiệu cách học và giới hạn bản mẫu.',
        () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => WelcomeScreen(preferences: preferences),
          ),
        ),
      ),
      buildActionTile(
        Icons.phonelink_lock_outlined,
        'Quyền camera và microphone',
        'Cách xử lý khi quyền thiết bị bị từ chối.',
        () => onOpen('Quyền thiết bị', const DevicePermissionScreen()),
      ),
      buildActionTile(
        Icons.tune_rounded,
        'Mục tiêu và âm thanh',
        'HSK ${preferences.level} · ${preferences.minutes} phút mỗi ngày · mẫu',
        () => onOpen(
          'Cài đặt học tập',
          StudySettingsScreen(preferences: preferences),
        ),
      ),
      buildActionTile(
        Icons.privacy_tip_outlined,
        'Quyền riêng tư',
        'Dữ liệu của bạn và quyền thiết bị.',
        () => onOpen('Quyền riêng tư', const PrivacyScreen()),
      ),
      buildActionTile(
        Icons.help_outline_rounded,
        'Trợ giúp',
        'Cách sử dụng bản xem thử.',
        () => onOpen('Trợ giúp', const FeedbackScreen()),
      ),
    ],
  );
}
