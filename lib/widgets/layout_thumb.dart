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
    case 'galeri':
      body = '<rect width="60" height="76" rx="6" fill="${c('bg')}" stroke="${c('line')}"/><path d="M1 7a6 6 0 0 1 6-6h46a6 6 0 0 1 6 6v27H1z" fill="${c('leaf')}" opacity=".55"/><path d="M1 34l14-12 10 8 12-13 22 17z" fill="${c('door2')}" opacity=".7"/><rect x="1" y="30" width="58" height="8" fill="${c('bg')}" opacity=".7"/><rect x="15" y="38" width="30" height="5" rx="2" fill="${c('accent')}"/><rect x="21" y="46" width="18" height="2" rx="1" fill="${c('muted')}" opacity=".7"/><rect x="7" y="53" width="46" height="9" rx="2.5" fill="${c('leaf')}" opacity=".45"/><rect x="7" y="64" width="22.5" height="8" rx="2.5" fill="${c('leaf')}" opacity=".35"/><rect x="30.5" y="64" width="22.5" height="8" rx="2.5" fill="${c('door1')}" opacity=".45"/>';
      break;
    case 'mektup':
      body = '<rect width="60" height="76" rx="6" fill="${c('bg')}" stroke="${c('line')}"/><rect x="8" y="7" width="44" height="60" rx="1.5" fill="${c('paper')}" stroke="${c('line')}"/><line x1="12" y1="22" x2="48" y2="22" stroke="${c('line')}"/><line x1="12" y1="28" x2="48" y2="28" stroke="${c('line')}"/><line x1="12" y1="34" x2="48" y2="34" stroke="${c('line')}"/><line x1="12" y1="40" x2="48" y2="40" stroke="${c('line')}"/><line x1="12" y1="46" x2="48" y2="46" stroke="${c('line')}"/><line x1="14" y1="9" x2="14" y2="65" stroke="${c('accent')}" opacity=".35"/><rect x="17" y="13" width="14" height="2" rx="1" fill="${c('accent')}"/><rect x="17" y="24.5" width="24" height="2" rx="1" fill="${c('muted')}" opacity=".7"/><rect x="17" y="30.5" width="28" height="2" rx="1" fill="${c('muted')}" opacity=".7"/><rect x="17" y="36.5" width="20" height="2" rx="1" fill="${c('muted')}" opacity=".7"/><rect x="30" y="50" width="16" height="4" rx="2" fill="${c('accent')}"/><circle cx="30" cy="66" r="6" fill="${c('accent')}"/><circle cx="30" cy="66" r="3.6" fill="none" stroke="${c('paper')}" stroke-opacity=".5"/>';
      break;
    case 'davetkarti':
      body = '<rect width="60" height="76" rx="6" fill="${c('door2')}"/><path d="M9.0 8.0 L11.1 8.9 L13.2 8.0 L15.3 8.9 L17.4 8.0 L19.5 8.9 L21.6 8.0 L23.7 8.9 L25.8 8.0 L27.9 8.9 L30.0 8.0 L32.1 8.9 L34.2 8.0 L36.3 8.9 L38.4 8.0 L40.5 8.9 L42.6 8.0 L44.7 8.9 L46.8 8.0 L48.9 8.9 L51.0 8.0 L51.0 8.0 L50.1 10.9 L51.0 13.8 L50.1 16.7 L51.0 19.6 L50.1 22.5 L51.0 25.4 L50.1 28.3 L51.0 31.2 L50.1 34.1 L51.0 37.0 L50.1 39.9 L51.0 42.8 L50.1 45.7 L51.0 48.6 L50.1 51.5 L51.0 54.4 L50.1 57.3 L51.0 60.2 L50.1 63.1 L51.0 66.0 L51.0 68.0 L48.9 67.1 L46.8 68.0 L44.7 67.1 L42.6 68.0 L40.5 67.1 L38.4 68.0 L36.3 67.1 L34.2 68.0 L32.1 67.1 L30.0 68.0 L27.9 67.1 L25.8 68.0 L23.7 67.1 L21.6 68.0 L19.5 67.1 L17.4 68.0 L15.3 67.1 L13.2 68.0 L11.1 67.1 L9.0 68.0 L9.0 68.0 L9.9 65.1 L9.0 62.2 L9.9 59.3 L9.0 56.4 L9.9 53.5 L9.0 50.6 L9.9 47.7 L9.0 44.8 L9.9 41.9 L9.0 39.0 L9.9 36.1 L9.0 33.2 L9.9 30.3 L9.0 27.4 L9.9 24.5 L9.0 21.6 L9.9 18.7 L9.0 15.8 L9.9 12.9 L9.0 10.0Z" fill="${c('paper')}"/><rect x="13" y="12" width="34" height="52" fill="none" stroke="${c('gold')}" stroke-width="1.1"/><rect x="15" y="14" width="30" height="48" fill="none" stroke="${c('gold')}" stroke-opacity=".5" stroke-width=".6"/><circle cx="30" cy="24" r="5" fill="${c('leaf')}"/><rect x="19" y="33" width="22" height="4.5" rx="2" fill="${c('accent')}"/><line x1="17" y1="44" x2="22" y2="44" stroke="${c('gold')}"/><rect x="24" y="43" width="12" height="2" rx="1" fill="${c('ink')}" opacity=".7"/><line x1="38" y1="44" x2="43" y2="44" stroke="${c('gold')}"/><rect x="21" y="50" width="18" height="2" rx="1" fill="${c('muted')}" opacity=".6"/>';
      break;
    case 'minimal':
      body = '<rect width="60" height="76" rx="6" fill="${c('bg')}" stroke="${c('line')}"/><rect x="24" y="12" width="12" height="1.4" rx=".7" fill="${c('muted')}" opacity=".7"/><rect x="17" y="19" width="26" height="3.6" rx="1.5" fill="${c('ink')}" opacity=".8"/><rect x="27" y="25.5" width="6" height=".9" fill="${c('accent')}"/><rect x="19" y="29" width="22" height="3.6" rx="1.5" fill="${c('ink')}" opacity=".8"/><rect x="22" y="36" width="16" height="1.6" rx=".8" fill="${c('accent')}"/><line x1="8" y1="44" x2="52" y2="44" stroke="${c('line')}"/><circle cx="14" cy="51" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="19.3" cy="51" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="24.6" cy="51" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="29.9" cy="51" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="35.2" cy="51" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="40.5" cy="51" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="45.8" cy="51" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="14" cy="56" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="19.3" cy="56" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="24.6" cy="56" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="29.9" cy="56" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="35.2" cy="56" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="40.5" cy="56" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="45.8" cy="56" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="14" cy="61" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="19.3" cy="61" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="24.6" cy="61" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="29.9" cy="61" r="2.4" fill="${c('accent')}" opacity="1"/><circle cx="35.2" cy="61" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="40.5" cy="61" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="45.8" cy="61" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="14" cy="66" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="19.3" cy="66" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="24.6" cy="66" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="29.9" cy="66" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="35.2" cy="66" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="40.5" cy="66" r="0.9" fill="${c('muted')}" opacity="0.55"/><circle cx="45.8" cy="66" r="0.9" fill="${c('muted')}" opacity="0.55"/>';
      break;
    case 'gece':
      body = '<rect width="60" height="76" rx="6" fill="${c('door2')}"/><rect width="60" height="76" rx="6" fill="#0b0a0f" opacity=".72"/><rect x="9" y="9" width="42" height="46" fill="none" stroke="${c('gold')}" stroke-width=".8"/><path d="M7 14V7h7M53 50v7h-7" fill="none" stroke="${c('gold')}" stroke-width="1.4"/><circle cx="30" cy="20" r="4" fill="${c('gold')}" opacity=".85"/><rect x="16" y="28" width="28" height="5" rx="2" fill="${c('gold')}"/><rect x="20" y="37" width="20" height="1.6" rx=".8" fill="${c('gold')}" opacity=".6"/><rect x="18" y="43" width="24" height="2" rx="1" fill="#f3ead8" opacity=".55"/><rect x="9" y="61" width="42" height="9" rx="1" fill="none" stroke="${c('gold')}" stroke-opacity=".5"/>';
      break;
    case 'hikaye':
      body = '<rect width="60" height="76" rx="6" fill="${c('bg')}" stroke="${c('line')}"/><rect x="7" y="5" width="10" height="1.6" rx=".8" fill="${c('accent')}"/><rect x="19" y="5" width="10" height="1.6" rx=".8" fill="${c('accent')}"/><rect x="31" y="5" width="10" height="1.6" rx=".8" fill="${c('line')}"/><rect x="43" y="5" width="10" height="1.6" rx=".8" fill="${c('line')}"/><rect x="7" y="9" width="46" height="62" rx="7" fill="${c('paper')}" stroke="${c('line')}"/><circle cx="14" cy="16" r="3.4" fill="${c('paper')}" stroke="${c('gold')}" stroke-width="1"/><rect x="20" y="14.5" width="16" height="1.8" rx=".9" fill="${c('ink')}" opacity=".7"/><circle cx="30" cy="34" r="9" fill="${c('leaf')}" opacity=".5"/><rect x="16" y="49" width="28" height="5" rx="2" fill="${c('accent')}"/><path d="M27 64l3-3 3 3" fill="none" stroke="${c('accent')}" stroke-width="1.2" stroke-linecap="round"/>';
      break;
    default: // klasik
      body = '$bg<circle cx="30" cy="14" r="5" fill="${c('leaf')}"/><rect x="16" y="24" width="28" height="4.5" rx="2" fill="${c('accent')}"/><rect x="21" y="32" width="18" height="2.5" rx="1" fill="${c('muted')}" opacity=".7"/>${card(42, 13)}${card(59, 11)}';
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 76">$body</svg>';
}
