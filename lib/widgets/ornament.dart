import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Tasarım süsü (assets/ornaments/<id>.svg — önizlemedeki SVG sembollerinden birebir).
class Ornament extends StatelessWidget {
  const Ornament(this.id, {super.key, this.size = 38});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/ornaments/$id.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}

/// Uygulama amblemi (önizlemedeki .brandmark).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30});

  final double size;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 30"><circle cx="15" cy="15" r="14" fill="#1F3D36"/><circle cx="15" cy="15" r="11.2" fill="none" stroke="#AD7F2E" stroke-width="1.2"/><path d="M9 11.5h12v8H9z M9 11.5l6 4.2 6-4.2" fill="none" stroke="#E3C58A" stroke-width="1.3" stroke-linejoin="round"/></svg>';

  @override
  Widget build(BuildContext context) => SvgPicture.string(_svg, width: size, height: size, excludeFromSemantics: true);
}

/// WhatsApp simgesi.
class WaIcon extends StatelessWidget {
  const WaIcon({super.key, this.size = 18, this.color = AppColors.onPrimary});

  final double size;
  final Color color;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#000" d="M20.5 3.5A11 11 0 0 0 3.2 17.1L2 22l5-1.3A11 11 0 1 0 20.5 3.5zM12 20.2a8.2 8.2 0 0 1-4.2-1.1l-.3-.2-3 .8.8-2.9-.2-.3A8.2 8.2 0 1 1 12 20.2zm4.5-6.1c-.2-.1-1.5-.7-1.7-.8s-.4-.1-.6.1-.7.8-.8 1-.3.2-.5.1a6.7 6.7 0 0 1-3.3-2.9c-.3-.4.3-.4.7-1.3.1-.2 0-.3 0-.4l-.8-1.8c-.2-.5-.4-.4-.6-.4h-.5a1 1 0 0 0-.7.3 3 3 0 0 0-.9 2.2 5.2 5.2 0 0 0 1.1 2.7 11.8 11.8 0 0 0 4.5 4c1.7.7 2.3.8 3.2.6a2.7 2.7 0 0 0 1.8-1.2 2.2 2.2 0 0 0 .1-1.3c0-.1-.2-.2-.4-.3z"/></svg>';

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        _svg,
        width: size,
        height: size,
        excludeFromSemantics: true,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}
