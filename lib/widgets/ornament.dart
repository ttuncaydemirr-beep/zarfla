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

/// Uygulama amblemi: uygulama simgesiyle aynı figür (zümrüt zemin, krem zarf, altın mühür).
/// Tasarım incelemesi #7: eski daire+çizgi işareti yerine tek marka dili.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36, this.round = false});

  final double size;
  /// true: daire zemin (boş durum figürü), false: yuvarlatılmış kare (uygulama simgesi gibi).
  final bool round;

  static String svg({bool round = false}) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 36 36">'
      '${round ? '<circle cx="18" cy="18" r="18" fill="#1F3D36"/><circle cx="18" cy="18" r="15.6" fill="none" stroke="#AD7F2E" stroke-width=".7"/>' : '<rect width="36" height="36" rx="9" fill="#1F3D36"/>'}'
      '<rect x="8.2" y="10.6" width="19.6" height="13.8" rx="1.6" fill="#FFFCF7"/>'
      '<path d="M9.3 11.8 18 19 26.7 11.8" fill="none" stroke="#1F3D36" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round"/>'
      '<circle cx="21.4" cy="19.9" r="3.5" fill="#AD7F2E"/>'
      '<circle cx="21.4" cy="19.9" r="2.3" fill="none" stroke="#E3C58A" stroke-width=".55"/>'
      '<path d="M21.4 18.7 22.2 19.9 21.4 21.1 20.6 19.9z" fill="#E3C58A"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) => SvgPicture.string(svg(round: round), width: size, height: size, excludeFromSemantics: true);
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
