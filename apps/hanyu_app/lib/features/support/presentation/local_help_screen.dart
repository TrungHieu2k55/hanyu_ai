import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/local/local_providers.dart';
import '../../../core/local/local_models.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../../profile/domain/local_profile.dart';

class LocalHelpScreen extends ConsumerWidget {
  const LocalHelpScreen({required this.data, super.key});
  final LocalSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = data.helpVersionSeen == LocalProfile.currentHelpVersion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Hướng dẫn sử dụng',
          'Bắt đầu học và giữ dữ liệu của bạn trên thiết bị.',
        ),
        const SizedBox(height: 24),
        const _HelpSection(
          title: 'Học và ôn mỗi ngày',
          text: 'Ở tab Học, mở một từ để xem Hán tự, Pinyin và nghĩa Việt. Lưu từ vào bộ ôn; ở tab Ôn tập, lật thẻ rồi chọn mức nhớ phù hợp. Mục tiêu HSK và thời gian học có thể đổi trong Cá nhân.',
        ),
        const _HelpSection(
          title: 'Luyện tập theo cách của bạn',
          text: 'Bạn có thể lưu nét viết, ảnh kèm văn bản tự nhập và hội thoại thủ công. Bản hiện tại chưa nhận diện ảnh, chấm phát âm hoặc trả lời bằng AI. Bài nghe chỉ mở khi có audio phù hợp.',
        ),
        const _HelpSection(
          title: 'Khi chưa lưu được',
          text: 'Nội dung trên màn chưa có nghĩa là đã lưu. Chờ thông báo lưu thành công trước khi rời. Nếu dữ liệu đã đổi ở nơi khác, tải bản mới và kiểm tra bản đang sửa trước khi lưu lại.',
        ),
        const _HelpSection(
          title: 'Giữ bản sao dữ liệu',
          text: 'Dữ liệu chưa đồng bộ tài khoản. Xuất backup trước khi đổi thiết bị hoặc xóa dữ liệu trình duyệt. Khôi phục backup sẽ thay dữ liệu local sau khi bạn xác nhận.',
        ),
        const _HelpSection(
          title: 'Quyền camera và micro',
          text: 'Nếu từ chối quyền, bạn vẫn có thể nhập nội dung bằng tay hoặc chọn ảnh sẵn. Muốn bật lại, mở quyền của ứng dụng trong Cài đặt thiết bị, hoặc quyền của trang trong trình duyệt, rồi thử lại. Không cần cấp quyền để học từ hay ôn thẻ.',
        ),
        TextButton.icon(
          onPressed: () => context.push('/data'),
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Mở dữ liệu và backup'),
        ),
        TextButton.icon(
          onPressed: () => context.push('/privacy'),
          icon: const Icon(Icons.privacy_tip_outlined),
          label: const Text('Thông tin riêng tư'),
        ),
        const SizedBox(height: 24),
        AsyncCommitButton(
          label: 'Đã đọc hướng dẫn',
          enabled: !seen,
          intentKey: LocalProfile.currentHelpVersion,
          onCommit: (operationId) => ref
              .read(localControllerProvider.notifier)
              .commit(
                (r) => r.saveHelpSeen(
                  LocalProfile.currentHelpVersion,
                  revision: data.revision,
                  operationId: operationId,
                ),
              ),
        ),
        if (seen) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: const Text('Đã ghi nhận trên thiết bị.'),
          ),
        ],
      ],
    );
  }
}

class LocalPrivacyScreen extends StatelessWidget {
  const LocalPrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Thông tin riêng tư',
        'Áp dụng cho bản học trên thiết bị hiện tại.',
      ),
      const SizedBox(height: 24),
      const _HelpSection(
        title: 'Dữ liệu ở đâu?',
        text: 'Tên hiển thị, mục tiêu, ghi chú, tiến độ và nội dung luyện tập nằm trong vùng lưu trữ của ứng dụng hoặc trình duyệt này. Hồ sơ local không phải tài khoản đăng nhập và chưa được đồng bộ lên máy chủ.',
      ),
      const _HelpSection(
        title: 'Ảnh và bản ghi âm',
        text: 'Chỉ chọn ảnh hoặc ghi âm khi bạn chủ động dùng tính năng đó và cấp quyền. Bản local chưa gửi chúng đến dịch vụ AI. Thiết bị dùng chung có thể cho người khác mở dữ liệu trong cùng ứng dụng.',
      ),
      const _HelpSection(
        title: 'Backup và xóa dữ liệu',
        text: 'Backup có thể chứa ghi chú, ảnh và audio riêng. Chỉ chia sẻ với người bạn tin tưởng. Xóa dữ liệu trình duyệt hoặc gỡ ứng dụng có thể làm mất bản local; file backup đã xuất cần được quản lý riêng.',
      ),
      const _HelpSection(
        title: 'Khi có tài khoản và dịch vụ AI',
        text: 'Đăng nhập, gửi dữ liệu lên máy chủ và AI chưa kết nối ở bản này. Thông tin riêng tư sẽ cần cập nhật trước khi bật các dịch vụ đó; nội dung này không tuyên bố các dịch vụ đã hoạt động.',
      ),
    ],
  );
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(fontSize: 16, height: 1.5)),
      ],
    ),
  );
}
