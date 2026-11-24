import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum FigmaGlyph {
  home('nav-home'),
  review('nav-review'),
  practice('nav-practice'),
  progress('nav-progress'),
  person('nav-person'),
  camera('camera'),
  conversation('conversation'),
  headphones('headphones'),
  search('search', size: 18),
  recoveryFlag('recovery-flag'),
  recoveryCheck('recovery-check');

  const FigmaGlyph(this.file, {this.size = 20});
  final String file;
  final double size;
}

class FigmaIcon extends StatelessWidget {
  const FigmaIcon(this.glyph, {this.color, super.key});

  final FigmaGlyph glyph;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/figma/${glyph.file}.svg',
    width: glyph.size,
    height: glyph.size,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}

const learnerNavigationGlyphs = [
  FigmaGlyph.home,
  FigmaGlyph.review,
  FigmaGlyph.practice,
  FigmaGlyph.progress,
  FigmaGlyph.person,
];
