import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../ui_tokens.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.large = false, super.key});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final (asset, size, radius) = large
        ? ('welcome-ha', 56.0, 14.0)
        : ('brand-ha', 34.0, 9.0);
    return Semantics(
      label: 'Logo Hanyu AI',
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: brandTeal,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: SvgPicture.asset(
          'assets/figma/$asset.svg',
          width: size,
          height: size,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
