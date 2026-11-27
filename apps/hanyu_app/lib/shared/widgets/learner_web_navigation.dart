import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../ui_tokens.dart';
import 'brand_mark.dart';

const learnerLabels = ['Học', 'Ôn tập', 'Luyện tập', 'Tiến độ', 'Cá nhân'];
const learnerPaths = [
  '/learn',
  '/review',
  '/practice',
  '/progress',
  '/profile',
];
const _icons = ['home', 'review', 'practice', 'progress', 'person'];

class LearnerWebNavigation extends StatelessWidget {
  const LearnerWebNavigation({
    required this.selectedIndex,
    required this.path,
    required this.navigate,
    this.compact = false,
    super.key,
  });

  final int selectedIndex;
  final String path;
  final ValueChanged<String> navigate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brand = Row(
      children: [
        const BrandMark(),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Hanyu AI',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
    final main = [
      for (var i = 0; i < learnerLabels.length; i++)
        _NavigationItem(
          label: learnerLabels[i],
          icon: _icons[i],
          selected: selectedIndex == i,
          onTap: () => navigate(learnerPaths[i]),
        ),
    ];
    if (compact) {
      final shortViewport = MediaQuery.sizeOf(context).height < 520;
      return Material(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            shortViewport ? 8 : 20,
            20,
            shortViewport ? 10 : 15,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              brand,
              SizedBox(height: shortViewport ? 8 : 30),
              Row(children: [for (final item in main) Expanded(child: item)]),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 232,
      child: Material(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            brand,
            const SizedBox(height: 58),
            for (final item in main) ...[item, const SizedBox(height: 10)],
            const SizedBox(height: 20),
            Text(
              'LỐI TẮT',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: mutedText),
            ),
            const SizedBox(height: 8),
            for (final (label, icon, destination) in const [
              ('Tra từ', 'search', '/learn/words'),
              ('Thi thử', 'exam', '/exams'),
              ('Hội thoại', 'conversation', '/conversations'),
            ])
              _NavigationItem(
                label: label,
                icon: icon,
                selected:
                    path == destination || path.startsWith('$destination/'),
                onTap: () => navigate(destination),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label, icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? brandTeal : brandInk;
    final radius = BorderRadius.circular(10);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? softSurface : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          focusColor: brandTeal.withValues(alpha: .18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/figma/web-$icon.svg',
                    colorFilter: ColorFilter.mode(
                      selected ? brandTeal : mutedText,
                      BlendMode.srcIn,
                    ),
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
