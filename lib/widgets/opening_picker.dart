import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Açılış animasyonu seçici (tasarım incelemesi #15): her seçenek seçili tasarımın renkleriyle
/// çizilmiş minik görsel + ad. Seçili: 2 px zümrüt çerçeve + altın köşe işareti.
class OpeningPicker extends StatelessWidget {
  const OpeningPicker({super.key, required this.value, required this.theme, required this.onChanged});

  final String value;
  final InviteTheme theme;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpace.x2,
      crossAxisSpacing: AppSpace.x2,
      childAspectRatio: 0.86,
      children: [
        for (final k in kOpenings)
          _OpeningTile(
            label: context.t('opn_$k'),
            svg: openingThumbSvg(k, theme.css),
            on: value == k,
            onTap: () => onChanged(k),
          ),
      ],
    );
  }
}

class _OpeningTile extends StatelessWidget {
  const _OpeningTile({required this.label, required this.svg, required this.on, required this.onTap});

  final String label;
  final String svg;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          side: BorderSide(color: on ? AppColors.primary : AppColors.lineStrong, width: on ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                child: Column(
                  children: [
                    Expanded(
                      child: ExcludeSemantics(
                        child: SvgPicture.string(svg, fit: BoxFit.contain, excludeFromSemantics: true),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle(12.5, weight: on ? FontWeight.w700 : FontWeight.w600, color: on ? AppColors.primary : AppColors.ink, height: 1.2)),
                  ],
                ),
              ),
              if (on)
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: CustomPaint(size: const Size(18, 18), painter: _CornerMark(Directionality.of(context))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seçili köşedeki altın üçgen işaret.
class _CornerMark extends CustomPainter {
  _CornerMark(this.dir);

  final TextDirection dir;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path();
    if (dir == TextDirection.rtl) {
      p
        ..moveTo(0, 0)
        ..lineTo(s.width, 0)
        ..lineTo(0, s.height);
    } else {
      p
        ..moveTo(0, 0)
        ..lineTo(s.width, 0)
        ..lineTo(s.width, s.height);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(_CornerMark old) => old.dir != dir;
}

/// Açılış küçük resmi SVG'si (80x64). Web önizlemedeki openingThumb ile aynı çizim (tek kaynaktan üretildi).
String openingThumbSvg(String k, Map<String, String> v) {
  String c(String key) => v[key] ?? '#000';
  final bg = '<rect width="80" height="64" rx="7" fill="${c('bg')}" stroke="${c('line')}"/>';
  final String body;
  switch (k) {
    case 'door':
      body = '<rect x="14" y="8" width="25" height="48" rx="2" fill="${c('door1')}" stroke="${c('doorLine')}"/><rect x="41" y="8" width="25" height="48" rx="2" fill="${c('door2')}" stroke="${c('doorLine')}"/><rect x="18" y="13" width="17" height="38" rx="1.5" fill="none" stroke="${c('doorLine')}"/><rect x="45" y="13" width="17" height="38" rx="1.5" fill="none" stroke="${c('doorLine')}"/><circle cx="36" cy="33" r="1.6" fill="${c('gold')}"/><circle cx="44" cy="33" r="1.6" fill="${c('gold')}"/>';
      break;
    case 'env':
      body = '<rect x="14" y="16" width="52" height="36" rx="3" fill="${c('paper')}" stroke="${c('line')}"/><path d="M14.5 17L40 37 65.5 17Z" fill="${c('door1')}" stroke="${c('doorLine')}"/><circle cx="40" cy="36" r="6" fill="${c('accent')}"/><circle cx="40" cy="36" r="3.6" fill="none" stroke="${c('gold')}" stroke-width="1"/>';
      break;
    case 'perde':
      body = '<rect x="10" y="9" width="60" height="2.4" rx="1.2" fill="${c('gold')}"/><path d="M11 11h26c-2 10-1 30 2 45H11z" fill="${c('door1')}"/><path d="M69 11H43c2 10 1 30-2 45h28z" fill="${c('door2')}"/><path d="M17 12c1 14 1 30-1 44M24 12c1 14 2 30 0 44M31 12c0 14 1 30 1 44M63 12c-1 14-1 30 1 44M56 12c-1 14-2 30 0 44M49 12c0 14-1 30-1 44" stroke="${c('doorLine')}" fill="none"/><circle cx="40" cy="34" r="3" fill="${c('leaf')}"/>';
      break;
    case 'kitap':
      body = '<path d="M40 14c-8-3-17-3-24 0v38c7-3 16-3 24 0z" fill="${c('paper')}" stroke="${c('line')}"/><path d="M40 14c8-3 17-3 24 0v38c-7-3-16-3-24 0z" fill="${c('door1')}" stroke="${c('doorLine')}"/><rect x="47" y="24" width="11" height="2" rx="1" fill="${c('gold')}"/><rect x="21" y="24" width="13" height="1.6" fill="${c('muted')}" opacity=".6"/><rect x="21" y="29" width="11" height="1.6" fill="${c('muted')}" opacity=".6"/><rect x="21" y="34" width="13" height="1.6" fill="${c('muted')}" opacity=".6"/>';
      break;
    case 'muhur':
      body = '<rect x="18" y="14" width="44" height="36" rx="3" fill="${c('paper')}" stroke="${c('line')}"/><path d="M50.0 32.0L47.4 35.1L47.1 39.1L43.1 39.4L40.0 42.0L36.9 39.4L32.9 39.1L32.6 35.1L30.0 32.0L32.6 28.9L32.9 24.9L36.9 24.6L40.0 22.0L43.1 24.6L47.1 24.9L47.4 28.9Z" fill="${c('accent')}"/><circle cx="40" cy="32" r="5.6" fill="none" stroke="${c('gold')}" stroke-width="1.2"/>';
      break;
    case 'isik':
      body = '<defs><radialGradient id="zgIsik"><stop offset="0" stop-color="${c('gold')}" stop-opacity=".95"/><stop offset="1" stop-color="${c('gold')}" stop-opacity="0"/></radialGradient></defs><circle cx="40" cy="32" r="24" fill="url(#zgIsik)"/><path d="M40 5v7M40 52v7M13 32h7M60 32h7M21 13l5 5M54 46l5 5M59 13l-5 5M26 46l-5 5" stroke="${c('gold')}" stroke-width="1.4" stroke-linecap="round"/><circle cx="40" cy="32" r="5" fill="${c('paper')}"/>';
      break;
    case 'sarmasik':
      body = '<path d="M8 59C20 50 22 34 36 30M72 5C60 14 58 30 44 34" stroke="${c('leaf')}" stroke-width="1.6" fill="none"/><ellipse cx="14" cy="53" rx="4.2" ry="2.1" transform="rotate(-40 14 53)" fill="${c('leaf')}"/><ellipse cx="21" cy="44" rx="4.2" ry="2.1" transform="rotate(-60 21 44)" fill="${c('leaf')}"/><ellipse cx="27" cy="35" rx="4.2" ry="2.1" transform="rotate(-20 27 35)" fill="${c('leaf')}"/><ellipse cx="33" cy="31" rx="4.2" ry="2.1" transform="rotate(10 33 31)" fill="${c('leaf')}"/><ellipse cx="66" cy="11" rx="4.2" ry="2.1" transform="rotate(-40 66 11)" fill="${c('leaf')}"/><ellipse cx="59" cy="20" rx="4.2" ry="2.1" transform="rotate(-60 59 20)" fill="${c('leaf')}"/><ellipse cx="53" cy="29" rx="4.2" ry="2.1" transform="rotate(-20 53 29)" fill="${c('leaf')}"/><ellipse cx="47" cy="33" rx="4.2" ry="2.1" transform="rotate(10 47 33)" fill="${c('leaf')}"/>';
      break;
    case 'cicek':
      body = '<g transform="translate(40 32)"><ellipse cx="0" cy="-10" rx="5" ry="10.5" transform="rotate(0)" fill="${c('accent')}" opacity=".85"/><ellipse cx="0" cy="-10" rx="5" ry="10.5" transform="rotate(60)" fill="${c('accent')}" opacity=".85"/><ellipse cx="0" cy="-10" rx="5" ry="10.5" transform="rotate(120)" fill="${c('accent')}" opacity=".85"/><ellipse cx="0" cy="-10" rx="5" ry="10.5" transform="rotate(180)" fill="${c('accent')}" opacity=".85"/><ellipse cx="0" cy="-10" rx="5" ry="10.5" transform="rotate(240)" fill="${c('accent')}" opacity=".85"/><ellipse cx="0" cy="-10" rx="5" ry="10.5" transform="rotate(300)" fill="${c('accent')}" opacity=".85"/><circle r="5" fill="${c('gold')}"/></g>';
      break;
    case 'kurdele':
      body = '<rect x="10" y="10" width="60" height="44" rx="3" fill="${c('paper')}" stroke="${c('line')}"/><rect x="36" y="10" width="8" height="44" fill="${c('accent')}"/><rect x="10" y="28" width="60" height="8" fill="${c('accent')}"/><path d="M40 32c-8-10-16-8-14-2s10 4 14 2c4 2 12 4 14-2s-6-8-14 2z" fill="${c('accent')}" stroke="${c('gold')}" stroke-width=".8"/>';
      break;
    case 'kelebek':
      body = '<path d="M40 32c-6-14-22-18-22-6 0 7 10 10 22 6zM40 32c6-14 22-18 22-6 0 7-10 10-22 6z" fill="${c('accent')}"/><path d="M40 33c-5 6-16 12-16 5 0-4 8-6 16-5zM40 33c5 6 16 12 16 5 0-4-8-6-16-5z" fill="${c('gold')}" opacity=".85"/><rect x="39.2" y="24" width="1.6" height="16" rx=".8" fill="${c('ink')}"/>';
      break;
    case 'yildiz':
      body = '<rect width="80" height="64" rx="7" fill="${c('door2')}"/><path d="M20 11L21.4 14.6 25 16 21.4 17.4 20 21 18.6 17.4 15 16 18.6 14.6Z" fill="${c('gold')}"/><path d="M56 8.5L56.98 11.02 59.5 12 56.98 12.98 56 15.5 55.02 12.98 52.5 12 55.02 11.02Z" fill="${c('gold')}"/><path d="M40 23L41.96 28.04 47 30 41.96 31.96 40 37 38.04 31.96 33 30 38.04 28.04Z" fill="${c('gold')}"/><path d="M64 33.5L65.26 36.74 68.5 38 65.26 39.26 64 42.5 62.74 39.26 59.5 38 62.74 36.74Z" fill="${c('gold')}"/><path d="M16 40.5L16.98 43.02 19.5 44 16.98 44.98 16 47.5 15.02 44.98 12.5 44 15.02 43.02Z" fill="${c('gold')}"/><path d="M32 48L33.12 50.88 36 52 33.12 53.12 32 56 30.88 53.12 28 52 30.88 50.88Z" fill="${c('gold')}"/><path d="M54 51L54.84 53.16 57 54 54.84 54.84 54 57 53.16 54.84 51 54 53.16 53.16Z" fill="${c('gold')}"/>';
      break;
    case 'pencere':
      body = '<path d="M22 56V26a18 18 0 0 1 36 0v30z" fill="${c('door1')}" stroke="${c('gold')}" stroke-width="1.4"/><path d="M40 8.5V56M22 34h36" stroke="${c('doorLine')}" stroke-width="1.2"/><circle cx="51" cy="19" r="3" fill="${c('paper')}" opacity=".8"/>';
      break;
    default:
      body = '';
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 64">$bg$body</svg>';
}
