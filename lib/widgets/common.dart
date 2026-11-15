import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
            children: [icon!, const SizedBox(width: 8), Text(label, textAlign: TextAlign.center)],
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
            children: [icon!, const SizedBox(width: 6), Text(label, textAlign: TextAlign.center)],
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
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(11, weight: FontWeight.w500, color: AppColors.muted, letterSpacing: 0.4)),
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
  const ZIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip});

  final IconData icon;
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
                child: Icon(icon, size: 20, color: AppColors.ink),
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
    return ZIconButton(icon: Icons.arrow_back, tooltip: label, onPressed: onPressed ?? () => Navigator.of(context).maybePop());
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
      decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: AppColors.primary), const SizedBox(width: 8)],
          Expanded(child: Text(text, style: bodyStyle(12.5, color: AppColors.muted, height: 1.5))),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(label, style: bodyStyle(12, weight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

/// Form alanı etiketi + içerik + ipucu + hata.
class FieldBlock extends StatelessWidget {
  const FieldBlock({super.key, this.label, required this.child, this.hint, this.error, this.requiredLabel});

  final String? label;
  final Widget child;
  final String? hint;
  final String? error;

  /// Zorunlu alanlarda etiketin yanında yazıyla "zorunlu" (yalnız renk/yıldız değil).
  final String? requiredLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: requiredLabel == null
                  ? Text(label!, style: bodyStyle(13, weight: FontWeight.w600))
                  : Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(label!, style: bodyStyle(13, weight: FontWeight.w600)),
                        RequiredTag(requiredLabel!),
                      ],
                    ),
            ),
          child,
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(hint!, style: bodyStyle(12, color: AppColors.muted, height: 1.4)),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Semantics(liveRegion: true, child: Text(error!, style: bodyStyle(13, color: AppColors.err))),
            ),
        ],
      ),
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
    counterText: '',
  );
}

/// Uzunluk sınırı (sayaç göstermeden).
List<TextInputFormatter> maxLen(int n) => [LengthLimitingTextInputFormatter(n)];

/// Seçim kutusu görünümlü dokunulabilir alan (tarih/saat).
class PickerField extends StatelessWidget {
  const PickerField({super.key, required this.text, required this.placeholder, required this.onTap, this.readOnly = false, this.icon, this.semanticLabel});

  final String text;
  final String placeholder;
  final VoidCallback? onTap;
  final bool readOnly;
  final IconData? icon;
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
              if (icon != null) Icon(icon, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
