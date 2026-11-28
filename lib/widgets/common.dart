import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Kısa bilgi mesajı (önizlemedeki toast).
void showToast(BuildContext context, String msg, {int ms = 2200}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: Duration(milliseconds: ms)));
}

/// Ana düğme (en az 48dp).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.block = false});

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool block;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      minimumSize: const Size(64, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      elevation: 2,
      shadowColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
      textStyle: bodyStyle(15, weight: FontWeight.w600),
    );
    final Widget child = icon == null
        ? Text(label, textAlign: TextAlign.center)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            // Flexible: uzun (ör. Almanca) etiket simgeyle birlikte taşmaz, satıra sarılır.
            children: [icon!, const SizedBox(width: 8), Flexible(child: Text(label, textAlign: TextAlign.center))],
          );
    final b = FilledButton(onPressed: onPressed, style: style, child: child);
    return block ? SizedBox(width: double.infinity, child: b) : b;
  }
}

/// İkincil (çerçeveli) düğme.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed, this.icon, this.block = false, this.dimmed = false});

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool block;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      side: const BorderSide(color: AppColors.field),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
      textStyle: bodyStyle(15, weight: FontWeight.w600),
    );
    final Widget child = icon == null
        ? Text(label, textAlign: TextAlign.center)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [icon!, const SizedBox(width: 6), Flexible(child: Text(label, textAlign: TextAlign.center))],
          );
    Widget b = OutlinedButton(onPressed: onPressed, style: style, child: child);
    if (dimmed) b = Opacity(opacity: 0.7, child: b);
    return block ? SizedBox(width: double.infinity, child: b) : b;
  }
}

/// Kart kutusu (yüzey, ince çizgi, 14 köşe, ana renge boyalı gölge).
class ZCard extends StatelessWidget {
  const ZCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.margin = const EdgeInsets.only(bottom: 12)});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

/// Üst çubuk (önizlemedeki .topbar).
class ZTopBar extends StatelessWidget {
  const ZTopBar({super.key, required this.title, this.subtitle, this.leading, this.actions = const []});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 10),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: headStyle(19, color: AppColors.ink)),
                if (subtitle != null)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(AppType.min, weight: FontWeight.w500, color: AppColors.muted, letterSpacing: 0.2)),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 10), a],
        ],
      ),
    );
  }
}

/// 44x44 çerçeveli simge düğmesi (dokunma alanı 48dp).
class ZIconButton extends StatelessWidget {
  const ZIconButton({super.key, this.icon, this.glyph, required this.onPressed, required this.tooltip}) : assert(icon != null || glyph != null);

  final IconData? icon;
  /// Zarfla çizgi simgesi (tercih edilir); verilirse [icon] yerine kullanılır.
  final String? glyph;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: glyph != null ? ZGlyph(glyph!, size: 20, color: AppColors.ink) : Icon(icon, size: 20, color: AppColors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BackBtn extends StatelessWidget {
  const BackBtn({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(context).backButtonTooltip;
    return ZIconButton(glyph: ZGlyphs.back, tooltip: label, onPressed: onPressed ?? () => Navigator.of(context).maybePop());
  }
}

/// Alt çubuk (önizlemedeki .bottombar).
class ZBottomBar extends StatelessWidget {
  const ZBottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bölüm başlığı (h2).
class H2 extends StatelessWidget {
  const H2(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(text, style: headStyle(24)),
      );
}

/// Açıklama paragrafı.
class Para extends StatelessWidget {
  const Para(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(text, style: bodyStyle(14.5, color: AppColors.muted, height: 1.5)),
      );
}

/// Bilgi notu kutusu.
class NoteBox extends StatelessWidget {
  const NoteBox(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(AppRadii.sm)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: AppColors.primary), const SizedBox(width: 8)],
          Expanded(child: Text(text, style: bodyStyle(12.5, color: AppColors.mutedOnSand, height: 1.5))),
        ],
      ),
    );
  }
}

/// Rozet (taslak / yayında / ücretli / ücretsiz).
class ZBadge extends StatelessWidget {
  const ZBadge({super.key, required this.label, required this.bg, required this.fg, this.icon});

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(12, weight: FontWeight.w600, color: fg))),
        ],
      ),
    );
  }
}

/// Form alanı etiketi + içerik + ipucu + hata.
class FieldBlock extends StatelessWidget {
  const FieldBlock({super.key, this.label, required this.child, this.hint, this.error, this.requiredLabel, this.frameError = true, this.labelMinLines = 1});

  final String? label;
  final Widget child;
  final String? hint;
  final String? error;
  /// Hata varken alanın etrafına hata çerçevesi çizilsin mi (bilgi amaçlı hatalarda false).
  final bool frameError;

  /// Yan yana iki alanda etiketler farklı satır sayısına sarılsa da alanlar hizalı kalsın diye
  /// etiket alanına ayrılan en az satır sayısı (1 ya da 2).
  final int labelMinLines;

  /// Zorunlu alanlarda etiketin yanında yazıyla "zorunlu" (yalnız renk/yıldız değil).
  final String? requiredLabel;

  @override
  Widget build(BuildContext context) {
    final hasErr = error != null && frameError;
    final labelStyle = bodyStyle(13, weight: FontWeight.w600, color: hasErr ? AppColors.err : AppColors.ink);
    return Padding(
      // Hatalı alandan sonra bir sonraki alan 18 px aşağıda başlar (hata metni etikete yapışmaz).
      padding: EdgeInsets.only(bottom: hasErr ? 18 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _FieldLabel(label!, labelStyle, requiredLabel, labelMinLines),
            ),
          hasErr ? ErrorFrame(child: child) : child,
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(hint!, style: bodyStyle(12, color: AppColors.muted, height: 1.4)),
            ),
          if (error != null)
            Padding(
              padding: EdgeInsets.only(top: hasErr ? 8 : 6),
              child: Semantics(liveRegion: true, child: Text(error!, style: bodyStyle(13, color: AppColors.err))),
            ),
        ],
      ),
    );
  }
}

/// Alan etiketi: "zorunlu" etiketi metnin satır içi son eki (WidgetSpan) olduğundan etiketi ayrı satıra itmez.
/// [minLines] 2 ise görünmez ikinci satır yer tutar (komşu alanla hizalama).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, this.style, this.requiredLabel, this.minLines);

  final String label;
  final TextStyle style;
  final String? requiredLabel;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(
      TextSpan(children: [
        TextSpan(text: label, style: style),
        if (requiredLabel != null) ...[
          const TextSpan(text: ' '),
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: RequiredTag(requiredLabel!)),
        ],
      ]),
    );
    if (minLines <= 1) return text;
    return Stack(
      children: [
        // Görünmez yer tutucu: minLines satır yüksekliği (etiket daha uzunsa o belirler).
        ExcludeSemantics(
          child: Opacity(opacity: 0, child: Text('\n' * (minLines - 1), style: style.copyWith(height: 1.6))),
        ),
        text,
      ],
    );
  }
}

/// "zorunlu" etiketi (küçük, çerçeveli; renk tek başına anlam taşımaz).
class RequiredTag extends StatelessWidget {
  const RequiredTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.field),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: bodyStyle(11, weight: FontWeight.w600, color: AppColors.muted)),
    );
  }
}

/// Kalıcı bilgi/hata kartı (toast yerine): metin + isteğe bağlı eylem düğmeleri + kapatma.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.text,
    this.title,
    this.icon = Icons.info_outline,
    this.error = false,
    this.actions = const [],
    this.onClose,
    this.closeTooltip,
  });

  final String text;
  final String? title;
  final IconData icon;
  final bool error;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final String? closeTooltip;

  @override
  Widget build(BuildContext context) {
    final fg = error ? AppColors.err : AppColors.primary;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: error ? AppColors.surface : AppColors.sand,
          border: Border.all(color: error ? AppColors.err : AppColors.line, width: error ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 18, color: fg)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(title!, style: bodyStyle(14.5, weight: FontWeight.w700, color: AppColors.ink)),
                    ),
                  Text(text, style: bodyStyle(13.5, color: AppColors.ink, height: 1.45)),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                ],
              ),
            ),
            if (onClose != null)
              IconButton(
                tooltip: closeTooltip,
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Metin alanı süslemesi (alan kenarı #8A8372, odakta ana renk).
InputDecoration fieldDecoration({String? hint, bool readOnly = false}) {
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: bodyStyle(16, color: AppColors.muted),
    filled: true,
    fillColor: readOnly ? AppColors.sand : AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: b(AppColors.field),
    enabledBorder: b(AppColors.field),
    focusedBorder: b(AppColors.primary, 1.5),
    disabledBorder: b(AppColors.line),
    errorBorder: b(AppColors.err, 1.5),
    focusedErrorBorder: b(AppColors.err, 2),
    errorStyle: bodyStyle(13, color: AppColors.err),
    counterText: '',
  );
}

/// Hatalı alan çerçevesi (tasarım incelemesi #6): 1.5 px hata rengi kenar + 3 px açık halka.
/// Alanın kendi kenarının üstüne çizilir; editör yapısını değiştirmeden her [FieldBlock] hatasında kullanılır.
class ErrorFrame extends StatelessWidget {
  const ErrorFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadii.sm);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: const [BoxShadow(color: AppColors.errRing, spreadRadius: 3)]),
      position: DecorationPosition.background,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: r, border: Border.all(color: AppColors.err, width: 1.5)),
        position: DecorationPosition.foreground,
        child: child,
      ),
    );
  }
}

/// Sayaç yalnız sınıra yaklaşınca (>= [from]) görünür; aksi halde hiçbir şey çizmez.
InputCounterWidgetBuilder nearLimitCounter(int from) => (context, {required currentLength, required isFocused, required maxLength}) {
      if (maxLength == null || currentLength < from) return const SizedBox.shrink();
      return Text('$currentLength/$maxLength', style: bodyStyle(12, color: AppColors.muted));
    };

/// Uzunluk sınırı (sayaç göstermeden).
List<TextInputFormatter> maxLen(int n) => [LengthLimitingTextInputFormatter(n)];

/// Seçim kutusu görünümlü dokunulabilir alan (tarih/saat).
class PickerField extends StatelessWidget {
  const PickerField({super.key, required this.text, required this.placeholder, required this.onTap, this.readOnly = false, this.glyph, this.semanticLabel});

  final String text;
  final String placeholder;
  final VoidCallback? onTap;
  final bool readOnly;

  /// Sağdaki çizgi simgesi ([ZGlyphs] yolu; tasarım #18).
  final String? glyph;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final empty = text.isEmpty;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: readOnly ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: readOnly ? AppColors.sand : AppColors.surface,
            border: Border.all(color: AppColors.field),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  empty ? placeholder : text,
                  style: bodyStyle(16, color: (empty || readOnly) ? AppColors.muted : AppColors.ink),
                ),
              ),
              if (glyph != null) ZGlyph(glyph!, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}


/// Zarfla çizgi simge seti (tasarım incelemesi #18): 24 px ızgara, 1.6 px çizgi, yuvarlak uç.
/// Web önizlemedeki SVG sembolleriyle aynı çizim dili.
class ZGlyphs {
  ZGlyphs._();
  static const String back = '<path d="M19 12H5M11 6l-6 6 6 6"/>';
  static const String check = '<path d="M5 12.5l4.5 4.5L19 7"/>';
  static const String lock = '<rect x="5.5" y="10.5" width="13" height="9.5" rx="2"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>';
  static const String crown = '<path d="M4.5 18h15M5.5 15.5L4 7.5l4.8 3.8L12 5l3.2 6.3L20 7.5l-1.5 8z"/>';
  static const String copy = '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h8"/>';
  static const String eye = '<path d="M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>';
  static const String home = '<path d="M4 11l8-6.5 8 6.5M6.5 9.5V19h11V9.5"/>';
  static const String close = '<path d="M6 6l12 12M18 6L6 18"/>';
  static const String info = '<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5M12 7.8v.2"/>';
  static const String alert = '<path d="M12 4l9 16H3z"/><path d="M12 10v4.5M12 17.3v.2"/>';
  static const String retry = '<path d="M20 12a8 8 0 1 1-2.4-5.7M20 4.5V9h-4.5"/>';
  static const String clock = '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>';
  static const String skip = '<path d="M5.5 6.5l7 5.5-7 5.5zM13 6.5l7 5.5-7 5.5z"/>';
  static const String calendar = '<rect x="4" y="5.5" width="16" height="14.5" rx="2"/><path d="M4 10h16M8.5 3.5v4M15.5 3.5v4"/>';
  static const String trash = '<path d="M4.5 7h15M9.5 7V4.8h5V7M6.5 7l.9 12.2a1.5 1.5 0 0 0 1.5 1.3h6.2a1.5 1.5 0 0 0 1.5-1.3L17.5 7M10.2 10.5v6.5M13.8 10.5v6.5"/>';
  static const String sparkle = '<path d="M12 3.5l1.8 5 5 1.8-5 1.8-1.8 5-1.8-5-5-1.8 5-1.8z"/>';

  /// Sağdan sola dilde aynalanacak (yön belirten) simgeler.
  static const Set<String> mirrored = {back, skip};
}

/// Tek renkli çizgi simgesi.
class ZGlyph extends StatelessWidget {
  const ZGlyph(this.paths, {super.key, this.size = 20, this.color = AppColors.ink, this.semanticLabel});

  final String paths;
  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.6" '
        'stroke-linecap="round" stroke-linejoin="round">$paths</svg>';
    Widget g = SvgPicture.string(
      svg,
      width: size,
      height: size,
      excludeFromSemantics: semanticLabel == null,
      semanticsLabel: semanticLabel,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
    if (ZGlyphs.mirrored.contains(paths) && Directionality.of(context) == TextDirection.rtl) {
      g = Transform.flip(flipX: true, child: g);
    }
    return g;
  }
}

/// Yükleniyor göstergesi (tasarım incelemesi #20a): zümrüt mühür + dönen altın halka ve hafif nabız.
/// Hareket azaltma açıksa durağan.
class ZLoader extends StatefulWidget {
  const ZLoader({super.key, this.size = 36, this.label});

  final double size;
  final String? label;

  @override
  State<ZLoader> createState() => _ZLoaderState();
}

class _ZLoaderState extends State<ZLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      liveRegion: widget.label != null,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _SealPainter(_c.value),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final pulse = 1 + 0.04 * math.sin(t * 2 * math.pi);
    canvas.drawCircle(c, r * 0.62 * pulse, Paint()..color = AppColors.primary);
    // Mühürdeki zarf çizgisi
    final env = Paint()
      ..color = AppColors.brandRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeJoin = StrokeJoin.round;
    final w = r * 0.62, h = r * 0.42;
    final rect = Rect.fromCenter(center: c, width: w, height: h);
    canvas.drawRect(rect, env);
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top)
        ..lineTo(c.dx, c.dy + h * 0.1)
        ..lineTo(rect.right, rect.top),
      env,
    );
    // Dönen altın halka
    final ring = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    final rr = Rect.fromCircle(center: c, radius: r * 0.86);
    canvas.drawArc(rr, t * 2 * math.pi, math.pi * 0.9, false, ring);
    canvas.drawArc(rr, t * 2 * math.pi + math.pi, math.pi * 0.35, false, ring..color = AppColors.brandRing);
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.t != t;
}

/// Kalıcı durum paneli (UX #8): ödeme / yayın sonuçları toast yerine ekranda kalır.
enum ZStatusTone { info, pending, error, success }

class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key, required this.tone, required this.text, this.title, this.actionLabel, this.onAction, this.onClose, this.closeLabel});

  final ZStatusTone tone;
  final String? title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;
  final String? closeLabel;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color edge, String glyph) = switch (tone) {
      ZStatusTone.error => (AppColors.errBg, AppColors.err, AppColors.err, ZGlyphs.alert),
      ZStatusTone.pending => (AppColors.crownBg, AppColors.crownInk, AppColors.accent, ZGlyphs.clock),
      ZStatusTone.success => (AppColors.tint, AppColors.ok, AppColors.ok, ZGlyphs.check),
      ZStatusTone.info => (AppColors.sand, AppColors.primary, AppColors.lineStrong, ZGlyphs.info),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpace.x3),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.md)),
        // Başlangıç kenarında 3 px ton şeridi (yöne göre sol/sağ).
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: edge),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.x3 - 3, AppSpace.x3, AppSpace.x2, AppSpace.x3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 1), child: ZGlyph(glyph, size: 20, color: fg)),
                      const SizedBox(width: AppSpace.x2 + 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null) Text(title!, style: bodyStyle(14, weight: FontWeight.w700, color: fg)),
                            if (title != null) const SizedBox(height: 2),
                            Text(text, style: bodyStyle(13.5, color: AppColors.ink, height: 1.45)),
                            if (actionLabel != null && onAction != null) ...[
                              const SizedBox(height: AppSpace.x2),
                              GhostButton(label: actionLabel!, icon: const ZGlyph(ZGlyphs.retry, size: 18), onPressed: onAction),
                            ],
                          ],
                        ),
                      ),
                      if (onClose != null)
                        Semantics(
                          button: true,
                          label: closeLabel ?? MaterialLocalizations.of(context).closeButtonTooltip,
                          child: InkResponse(
                            onTap: onClose,
                            radius: 22,
                            child: const SizedBox(width: 44, height: 44, child: Center(child: ZGlyph(ZGlyphs.close, size: 18, color: AppColors.muted))),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
