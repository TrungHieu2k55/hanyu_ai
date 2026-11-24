import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildPageTitle(
        'Điều khoản và riêng tư',
        'Nội dung hướng dẫn bản xem thử, chưa phải chính sách vận hành chính thức.',
      ),
      const SizedBox(height: 24),
      const Text(
        'Tài khoản và dữ liệu học',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text(
        'Bản hiện tại không tạo tài khoản, tải ảnh/audio lên máy chủ hoặc gửi nội dung cho AI. Các lựa chọn chỉ giữ trong bộ nhớ khi app đang mở.',
      ),
      const SizedBox(height: 24),
      const Text(
        'Góp dữ liệu huấn luyện',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text(
        'Đây là lựa chọn tự nguyện, độc lập với đồng ý điều khoản. Không chọn sẵn và không bắt buộc để thử giao diện.',
      ),
      const SizedBox(height: 24),
      const Text(
        'Quyền thiết bị',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text(
        'Camera dùng khi chọn chụp ảnh OCR; microphone dùng khi chọn ghi âm. Bản mẫu chưa xin quyền. Khi tích hợp, luôn có hướng dẫn xử lý quyền bị từ chối.',
      ),
    ],
  );
}
