import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/privacy/presentation/delete_account_screen.dart';
import 'package:doanchuyennganh2/features/privacy/presentation/policy_screen.dart';
import 'package:doanchuyennganh2/features/settings/presentation/device_permission_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
      buildPageTitle(
        'Bạn kiểm soát dữ liệu',
        'Bản xem thử không thu ảnh, audio hay thông tin tài khoản.',
      ),
      const SizedBox(height: 24),
      const PanelCard(
        child: Text(
          'Camera chỉ cần cho OCR. Microphone chỉ cần khi luyện nói. Bản hiện tại chưa yêu cầu các quyền này.\n\nGóp dữ liệu huấn luyện phải là lựa chọn riêng, mặc định tắt.\n\nĐiều khoản, chính sách lưu trữ và yêu cầu xóa tài khoản sẽ được bổ sung trước khi mở đăng ký thật.',
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => const DetailScaffold(
              title: 'Quyền thiết bị',
              body: DevicePermissionScreen(),
            ),
          ),
        ),
        child: const Text('Camera và microphone'),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => const DetailScaffold(
              title: 'Xóa tài khoản · minh họa',
              body: DeleteAccountScreen(),
            ),
          ),
        ),
        child: const Text('Xem quy trình xóa tài khoản'),
      ),
    ],
  );
}
