import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../shared/ui_tokens.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/learner_surface.dart';
import '../../auth/presentation/account_scaffold.dart';
import '../../auth/presentation/auth_screen.dart';

class GuestPreviewScreen extends StatelessWidget {
  const GuestPreviewScreen({this.onExit, super.key});

  final VoidCallback? onExit;

  static void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));

  static void _stroke(BuildContext context) =>
      _open(context, const _GuestStroke());

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Xem thử Hanyu',
    onBack: Navigator.canPop(context) ? null : onExit,
    action: FilledButton(
      onPressed: () => _open(context, const _GuestWord()),
      child: const Text('Xem từ 朋友'),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Khám phá một từ và xem cách viết trước khi tạo tài khoản.'),
        const SizedBox(height: 16),
        const LearnerSurface(color: softSurface, child: _WordDefinition()),
        const SizedBox(height: 16),
        LearnerSurface(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              _GuestAction(
                icon: const FigmaIcon(FigmaGlyph.practice, color: brandTeal),
                title: 'Xem nét chữ 人',
                subtitle: 'Chỉ xem mẫu, chưa ghi kết quả học.',
                onTap: () => _stroke(context),
              ),
              _GuestAction(
                icon: _asset('guest-camera', width: 18, height: 18),
                title: 'Lấy từ trong ảnh',
                subtitle: 'Xem bước đăng nhập trước khi chọn ảnh.',
                onTap: () => _open(
                  context,
                  const AuthScreen(returnTo: AccountIntent.photo),
                ),
              ),
              _GuestAction(
                icon: _asset('guest-conversation', width: 18, height: 18),
                title: 'Thử hội thoại',
                subtitle: 'Xem bước đăng nhập trước khi bắt đầu phiên.',
                onTap: () => _open(
                  context,
                  const AuthScreen(returnTo: AccountIntent.conversation),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GuestWord extends StatelessWidget {
  const _GuestWord();

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Từ mẫu',
    action: FilledButton(
      onPressed: () => GuestPreviewScreen._open(
        context,
        const AuthScreen(returnTo: AccountIntent.saveWord),
      ),
      child: const Text('Thêm vào ôn tập'),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _WordDefinition(centered: true),
        const SizedBox(height: 16),
        LearnerSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dùng trong câu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                '他是我的朋友。\nTā shì wǒ de péngyou.\nAnh ấy là bạn của tôi.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _GuestNotice(
          asset: 'guest-word-flag',
          title: 'Bạn đang xem thử',
          detail: 'Chưa tạo thẻ ôn hoặc ghi lịch sử cá nhân.',
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => GuestPreviewScreen._stroke(context),
          child: const Text('Xem thử nét chữ 人'),
        ),
      ],
    ),
  );
}

class _GuestStroke extends StatelessWidget {
  const _GuestStroke();

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Xem nét chữ 人',
    action: FilledButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Quay lại nội dung xem thử'),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'rén · người',
          style: TextStyle(color: brandTeal, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        LearnerSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Quan sát hướng từng nét',
                style: TextStyle(color: mutedText, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Semantics(
                image: true,
                label: 'Chữ 人 có hai nét. Nét một phẩy trái. Nét hai mác phải.',
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 314,
                    height: 228,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: _asset('guest-stroke-grid'),
                        ),
                        Positioned(
                          left: 73,
                          top: 10,
                          child: _asset('guest-stroke-one'),
                        ),
                        Positioned(
                          left: 150,
                          top: 101,
                          child: _asset('guest-stroke-two'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1 · Phẩy trái     2 · Mác phải',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _GuestNotice(
          asset: 'guest-stroke-flag',
          title: 'Chỉ xem mẫu',
          detail: 'Hai nét đang được minh họa. Màn này không thu nét hoặc lưu bài luyện.',
        ),
      ],
    ),
  );
}

class _WordDefinition extends StatelessWidget {
  const _WordDefinition({this.centered = false});

  final bool centered;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text(
        '朋友',
        style: TextStyle(
          fontFamily: 'Noto Sans SC',
          fontSize: centered ? 68 : 50,
          fontWeight: FontWeight.w700,
          color: brandInk,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        centered ? 'péngyou' : 'péngyou · Bạn bè',
        style: const TextStyle(color: brandTeal, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(centered ? 'Bạn; bạn bè' : '他是我的朋友。'),
    ],
  );
}

class _GuestNotice extends StatelessWidget {
  const _GuestNotice({
    required this.asset,
    required this.title,
    required this.detail,
  });

  final String asset, title, detail;

  @override
  Widget build(BuildContext context) => LearnerSurface(
    color: softSurface,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _asset(asset, width: 20, height: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                detail,
                style: const TextStyle(color: mutedText, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GuestAction extends StatelessWidget {
  const _GuestAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: softSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: icon,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward, color: mutedText),
      onTap: onTap,
    ),
  );
}

Widget _asset(String name, {double? width, double? height}) => SvgPicture.asset(
  'assets/figma/$name.svg',
  width: width,
  height: height,
  excludeFromSemantics: true,
);
