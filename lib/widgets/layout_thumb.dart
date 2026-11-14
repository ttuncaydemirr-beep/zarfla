import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Sayfa düzeni küçük resmi (önizlemedeki layoutThumb birebir).
class LayoutThumb extends StatelessWidget {
  const LayoutThumb({super.key, required this.layout, required this.css, required this.rtl});

  final String layout;
  final Map<String, String> css;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(layoutThumbSvg(layout, css, rtl), width: 48, height: 61, excludeFromSemantics: true);
  }
}

String layoutThumbSvg(String k, Map<String, String> v, bool rtl) {
  String c(String key) => v[key] ?? '#000';
  final bg = '<rect width="60" height="76" rx="6" fill="${c('bg')}" stroke="${c('line')}"/>';
  String card(num y, num h) => '<rect x="8" y="$y" width="44" height="$h" rx="4" fill="${c('paper')}" stroke="${c('line')}"/>';
  String body;
  switch (k) {
    case 'kemer':
      body = '$bg<path d="M15 50V27a15 15 0 0 1 30 0v23z" fill="${c('paper')}" stroke="${c('gold')}" stroke-width="1.6"/><circle cx="30" cy="25" r="4.5" fill="${c('leaf')}"/><rect x="21" y="35" width="18" height="4" rx="2" fill="${c('accent')}"/><path d="M8 72V62a8 8 0 0 1 8-8h28a8 8 0 0 1 8 8v10z" fill="${c('paper')}" stroke="${c('line')}"/>';
      break;
    case 'monogram':
      body = '$bg<circle cx="30" cy="27" r="16" fill="${c('paper')}" stroke="${c('gold')}" stroke-width="1.6"/><circle cx="30" cy="27" r="12" fill="none" stroke="${c('line')}"/><text x="30" y="31.5" text-anchor="middle" font-family="Georgia,serif" font-style="italic" font-size="12" fill="${c('accent')}">A·B</text><rect x="19" y="48" width="22" height="3" rx="1.5" fill="${c('ink')}" opacity=".75"/>${card(56, 15)}';
      break;
    case 'editoryal':
      final g = rtl ? '<g transform="translate(60 0) scale(-1 1)">' : '<g>';
      body = '$bg$g<rect x="7" y="9" width="1.2" height="34" fill="${c('accent')}"/><rect x="12" y="11" width="34" height="8" rx="1" fill="${c('ink')}"/><rect x="12" y="22" width="24" height="8" rx="1" fill="${c('ink')}"/><rect x="12" y="34" width="40" height="1" fill="${c('accent')}"/><rect x="12" y="38" width="30" height="2.5" fill="${c('muted')}" opacity=".7"/><rect x="12" y="50" width="40" height="1" fill="${c('line')}"/><rect x="12" y="54" width="22" height="3" fill="${c('accent')}"/><rect x="12" y="63" width="40" height="1" fill="${c('line')}"/><rect x="12" y="67" width="18" height="3" fill="${c('accent')}"/></g>';
      break;
    case 'kartpostal':
      body = '<rect width="60" height="76" rx="6" fill="${c('door2')}"/><g transform="rotate(-6 30 38)"><rect x="10" y="10" width="40" height="56" rx="2" fill="${c('paper')}"/><rect x="14" y="14" width="32" height="18" fill="${c('leaf')}" opacity=".7"/><rect x="37" y="16" width="8" height="10" fill="${c('paper')}" stroke="${c('accent')}" stroke-dasharray="1.5 1"/><rect x="16" y="38" width="24" height="3.5" rx="1.5" fill="${c('accent')}"/><rect x="16" y="45" width="28" height="2" fill="${c('muted')}" opacity=".6"/><rect x="16" y="52" width="28" height="1" fill="${c('line')}"/></g>';
      break;
    case 'zamancizelgesi':
      final sb = StringBuffer('$bg<rect x="13" y="10" width="2" height="58" rx="1" fill="${c('accent')}"/>');
      const ys = [16, 31, 46, 61];
      for (var i = 0; i < ys.length; i++) {
        final odd = i.isOdd;
        final y = ys[i];
        sb.write('<circle cx="14" cy="$y" r="3.4" fill="${odd ? c('accent') : c('paper')}" stroke="${c('accent')}" stroke-width="1.4"/>');
        sb.write('<rect x="21" y="${y - 2.5}" width="${odd ? 18 : 28}" height="5" rx="1.5" fill="${odd ? c('muted') : c('ink')}" opacity="${odd ? '.6' : '.85'}"/>');
      }
      body = sb.toString();
      break;
    case 'bilet':
      body = '$bg<rect x="10" y="8" width="40" height="60" rx="5" fill="${c('paper')}" stroke="${c('line')}"/><rect x="10.5" y="8.5" width="39" height="11" rx="4.5" fill="${c('door1')}"/><circle cx="10" cy="50" r="4" fill="${c('bg')}" stroke="${c('line')}"/><circle cx="50" cy="50" r="4" fill="${c('bg')}" stroke="${c('line')}"/><line x1="16" y1="50" x2="44" y2="50" stroke="${c('muted')}" stroke-dasharray="2 2"/><rect x="17" y="27" width="26" height="4.5" rx="2" fill="${c('accent')}"/><rect x="21" y="35" width="18" height="2.5" rx="1" fill="${c('muted')}" opacity=".7"/><rect x="16" y="57" width="10" height="5" rx="1" fill="${c('ink')}" opacity=".7"/><rect x="34" y="57" width="10" height="5" rx="1" fill="${c('ink')}" opacity=".7"/>';
      break;
    default: // klasik
      body = '$bg<circle cx="30" cy="14" r="5" fill="${c('leaf')}"/><rect x="16" y="24" width="28" height="4.5" rx="2" fill="${c('accent')}"/><rect x="21" y="32" width="18" height="2.5" rx="1" fill="${c('muted')}" opacity=".7"/>${card(42, 13)}${card(59, 11)}';
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 76">$body</svg>';
}
