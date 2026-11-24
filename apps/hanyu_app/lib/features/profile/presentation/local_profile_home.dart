import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/local/local_models.dart';
import '../../../shared/ui_tokens.dart';
import '../../../shared/widgets/learner_surface.dart';

class LocalProfileHome extends StatelessWidget {
  const LocalProfileHome({required this.data, super.key});
  final LocalSnapshot data;

  @override
  Widget build(BuildContext context) {
    final name = data.preferences.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cá nhân', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        LearnerSurface(
          color: brandInk,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_outline, color: brandTeal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Góc của bạn' : 'Chào $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Học trên thiết bị · chưa đăng nhập',
                      style: TextStyle(color: softSurface, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LearnerSplit(
          main: _ProfileGroup(
            title: 'Học tập & cài đặt',
            items: [
              (
                Icons.tune,
                'Mục tiêu và âm thanh',
                'HSK ${data.preferences.level} · ${data.preferences.minutes} phút mỗi ngày',
                '/settings',
              ),
              (
                Icons.phonelink_lock_outlined,
                'Camera và microphone',
                'Quản lý quyền và xem cách thay thế',
                '/permissions',
              ),
              (
                Icons.explore_outlined,
                'Xem thử Hanyu',
                'Đọc từ mẫu và quan sát nét chữ',
                '/guest',
              ),
              (
                Icons.preview_outlined,
                'Khu xem mẫu',
                'Tài khoản và các luồng thực hành mẫu',
                '/preview',
              ),
            ],
          ),
          aside: _ProfileGroup(
            title: 'Dữ liệu & trợ giúp',
            items: [
              (
                Icons.storage_outlined,
                'Dữ liệu và backup',
                'Xuất hoặc khôi phục dữ liệu trên thiết bị',
                '/data',
              ),
              (
                Icons.privacy_tip_outlined,
                'Thông tin riêng tư',
                'Nơi lưu ảnh, audio và dữ liệu học',
                '/privacy',
              ),
              (
                Icons.help_outline,
                'Hướng dẫn sử dụng',
                data.helpVersionSeen == null
                    ? 'Bắt đầu học, lưu dữ liệu và backup'
                    : 'Xem lại hướng dẫn trên thiết bị',
                '/help',
              ),
              (
                Icons.flag_outlined,
                'Báo lỗi của bạn',
                'Lưu, xuất file và nhập kết quả xử lý',
                '/feedback',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.title, required this.items});
  final String title;
  final List<(IconData, String, String, String)> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(color: brandTeal, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      LearnerSurface(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: surfaceBorder),
                ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: softSurface,
                    child: Icon(items[i].$1, color: brandTeal, size: 17),
                  ),
                  title: Text(
                    items[i].$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(items[i].$3),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(items[i].$4),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}
