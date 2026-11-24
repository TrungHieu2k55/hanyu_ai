import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/writing/presentation/prediction_result_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/status_panel.dart';

class StatesGallery extends StatefulWidget {
  const StatesGallery({super.key});
  @override
  State<StatesGallery> createState() => _StatesGalleryState();
}

class _StatesGalleryState extends State<StatesGallery> {
  PreviewState selected = PreviewState.notConfigured;
  bool tapped = false;
  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'QA · trạng thái UI',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Thư viện trạng thái mẫu',
          'Trang kiểm tra riêng, không đọc trạng thái mạng/tài khoản hoặc chạy provider thật.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final state in PreviewState.values)
              ChoiceChip(
                label: Text(
                  [
                    'Đang xử lý',
                    'Mất mạng',
                    'Thử lại',
                    'Hết phiên',
                    'Sai quyền',
                    'Rỗng',
                    'Thiếu audio',
                    'Chưa kết nối',
                  ][state.index],
                ),
                selected: selected == state,
                onSelected: (_) => setState(() {
                  selected = state;
                  tapped = false;
                }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        PreviewStatusPanel(
          state: selected,
          onAction: () => setState(() => tapped = true),
        ),
        if (tapped)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Đã bấm hành động mẫu; chưa gửi yêu cầu dịch vụ.'),
          ),
        const SizedBox(height: 24),
        buildSectionHeading('Kết quả CNN — chỉ là bố cục'),
        for (final entry in [
          (PredictionMode.candidates, 'Xem top-3 minh họa'),
          (PredictionMode.uncertain, 'Xem kết quả chưa chắc'),
          (PredictionMode.unsupported, 'Xem chữ chưa hỗ trợ'),
        ])
          TextButton(
            onPressed: () => Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScaffold(
                  title: entry.$2,
                  body: PredictionResultScreen(mode: entry.$1),
                ),
              ),
            ),
            child: Text(entry.$2),
          ),
      ],
    ),
  );
}
