import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud/invite_contract.dart';
import '../data/catalog.dart';
import '../logic/date_utils.dart';
import '../logic/share_text.dart';
import '../l10n/strings.dart';
import '../notify/review_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/invite_mini.dart';
import '../widgets/ornament.dart';
import 'guest_screen.dart';

/// Tamamlandı / Paylaş: kısa kutlama (tema süsleriyle hafif konfeti, hareket azaltmada kapalı),
/// davetiyenin minik önizlemesi, güzel kırılan bağlantı, isim + tarih + bağlantı içeren paylaşım mesajı
/// (davetiye dilinde), WhatsApp, kopyala ve "Davetli gözüyle aç".
class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key, required this.invId});

  final String invId;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final inv = st.byId(invId);
    if (inv == null) return const Scaffold(body: SizedBox.shrink());
    final th = kThemes[inv.theme] ?? kThemes['papatya']!;
    final cid = inv.cloudId;
    if (cid == null) return const Scaffold(body: SizedBox.shrink());
    final link = inviteUrlDisplay(cid);
    final full = inviteUrl(cid);
    final expired = st.isExpired(inv);
    final exp = inv.expiresAt == null ? null : DateTime.fromMillisecondsSinceEpoch(inv.expiresAt!);
    final expTxt = exp == null
        ? ''
        : context.t('untilDate', {
            'd': '${formatShortDate(isoOf(DateTime.utc(exp.year, exp.month, exp.day)), st.lang)} '
                '${exp.hour.toString().padLeft(2, '0')}:${exp.minute.toString().padLeft(2, '0')}',
          });
    final il = inv.lang;
    String textFor(String link) => buildShareText(
          headTpl: context.tIn(il, 'shareHead'),
          whenTpl: context.tIn(il, 'shareWhen'),
          linkTpl: context.tIn(il, 'shareLink'),
          names: shareNames(inv, context.tIn(il, 'amp')),
          event: context.tIn(il, 'type_${inv.type}'),
          when: formatShareWhen(inv, il),
          link: link,
        );
    final shareText = textFor(full);
    Future<void> copy() async {
      final msg = context.t('copied');
      await Clipboard.setData(ClipboardData(text: full));
      if (context.mounted) showToast(context, msg);
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                ZTopBar(title: context.t('liveTitle'), leading: const BrandMark()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpace.edge, AppSpace.x2, AppSpace.edge, AppSpace.x6),
                    children: [
                      Center(child: _SealedMini(child: InviteMiniFor(inv: inv))),
                      const SizedBox(height: AppSpace.x4),
                      Text(context.t('doneHero'), textAlign: TextAlign.center, style: headStyle(28)),
                      const SizedBox(height: AppSpace.x2),
                      Text(context.t('doneP'), textAlign: TextAlign.center, style: bodyStyle(14.5, color: AppColors.muted, height: 1.5)),
                      const SizedBox(height: AppSpace.x6),
                      // Bağlantı kartı
                      Text(context.t('linkL'), style: bodyStyle(13, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _LinkBox(display: link, onCopy: copy, copyLabel: context.t('copy')),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: AppSpace.x4),
                        child: Text(
                          expired ? context.t('expiredNote') : '${context.t('linkNoteApp')} $expTxt'.trim(),
                          style: bodyStyle(12.5, color: expired ? AppColors.err : AppColors.muted, height: 1.4),
                        ),
                      ),
                      PrimaryButton(
                        label: context.t('shareWa'),
                        block: true,
                        icon: const WaIcon(),
                        onPressed: () {
                          launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareText)}'), mode: LaunchMode.externalApplication)
                              .then((ok) {
                            if (ok) ReviewPrompter.instance.onShare();
                          });
                        },
                      ),
                      const SizedBox(height: AppSpace.x3),
                      // İkincil eylemler: simge üstte, etiket altta (uzun etiketler sıkışmaz).
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _ActionTile(glyph: ZGlyphs.copy, label: context.t('copyLink'), onTap: copy)),
                            const SizedBox(width: AppSpace.x3),
                            Expanded(
                              child: _ActionTile(
                                glyph: ZGlyphs.eye,
                                label: context.t('openAsGuest'),
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuestScreen(invId: inv.id))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.x3),
                      // Kişiye özel bağlantı: davetli sayfası ?g=Ad ile davetliyi adıyla karşılar (isim sunucuya yazılmaz).
                      GhostButton(
                        label: context.t('guestLinkBtn'),
                        block: true,
                        dimmed: expired,
                        icon: const ZGlyph(ZGlyphs.sparkle, size: 18, color: AppColors.primary),
                        onPressed: expired
                            ? () => showToast(context, context.t('expiredNote'), ms: 3500)
                            : () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  backgroundColor: AppColors.bg,
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
                                  builder: (_) => _GuestLinksSheet(
                                    cloudId: cid,
                                    messageFor: (guest, link) => personalShareText(
                                      hiTpl: context.tIn(il, 'guestShareHi'),
                                      guest: guest,
                                      body: textFor(link),
                                    ),
                                  ),
                                ),
                      ),
                      const SizedBox(height: AppSpace.x6),
                      // Paylaşım mesajı önizlemesi (davetlinin göreceği metin)
                      _MessagePreview(title: context.t('shareMsgL'), text: shareText, dir: il == 'ar' ? TextDirection.rtl : TextDirection.ltr),
                      const SizedBox(height: AppSpace.x4),
                      _Tips(title: context.t('doneTipsT'), tips: [context.t('doneTip0'), context.t('doneTip1'), context.t(inv.plan == 'premium' ? 'doneTip2' : 'doneTip2Free')]),
                      const SizedBox(height: AppSpace.x4),
                      Center(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(48, 48)),
                          icon: const ZGlyph(ZGlyphs.home, size: 18, color: AppColors.primary),
                          label: Text(context.t('backHome'), style: bodyStyle(15, weight: FontWeight.w600, color: AppColors.primary)),
                          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned.fill(child: IgnorePointer(child: OrnamentConfetti(orn: th.fall))),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.glyph, required this.label, required this.onTap});

  final String glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        minimumSize: const Size(48, 64),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        side: const BorderSide(color: AppColors.field),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ZGlyph(glyph, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(14, weight: FontWeight.w600, height: 1.25)),
        ],
      ),
    );
  }
}

/// Minik önizleme altın halkalı bir "mühür" gibi yerine oturur (0.9 → 1.0 yaylanma).
class _SealedMini extends StatelessWidget {
  const _SealedMini({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduced(context);
    final card = Container(
      width: 148,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md + 5),
        border: Border.all(color: AppColors.brandRing, width: 1.5),
        boxShadow: AppShadows.hero,
        color: AppColors.surface,
      ),
      child: child,
    );
    if (reduce) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, v, c) => Transform.scale(scale: v, child: Opacity(opacity: ((v - 0.9) * 10).clamp(0.0, 1.0).toDouble(), child: c)),
      child: card,
    );
  }
}

class _LinkBox extends StatelessWidget {
  const _LinkBox({required this.display, required this.onCopy, required this.copyLabel});

  final String display;
  final VoidCallback onCopy;
  final String copyLabel;

  @override
  Widget build(BuildContext context) {
    // Bağlantı her dilde soldan sağa; satır yalnız '/' sonrasında kırılır (tasarım #10).
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.x3, AppSpace.x2, AppSpace.x1, AppSpace.x2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.field),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                softBreakUrl(display),
                semanticsLabel: display,
                style: bodyStyle(14.5, weight: FontWeight.w600, color: AppColors.primary, height: 1.35),
              ),
            ),
            Semantics(
              button: true,
              label: copyLabel,
              child: InkResponse(
                onTap: onCopy,
                radius: 24,
                child: const SizedBox(width: 48, height: 48, child: Center(child: ZGlyph(ZGlyphs.copy, size: 20, color: AppColors.primary))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({required this.title, required this.text, required this.dir});

  final String title;
  final String text;
  final TextDirection dir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: bodyStyle(13, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.x3),
          decoration: BoxDecoration(
            color: AppColors.tint,
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(AppRadii.md),
              topEnd: Radius.circular(AppRadii.md),
              bottomEnd: Radius.circular(AppRadii.md),
              bottomStart: Radius.circular(4),
            ),
          ),
          child: Directionality(textDirection: dir, child: Text(softBreakUrl(text), style: bodyStyle(13.5, height: 1.5))),
        ),
      ],
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips({required this.title, required this.tips});

  final String title;
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: headStyle(17)),
          const SizedBox(height: AppSpace.x2),
          for (var i = 0; i < tips.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: bodyStyle(12, weight: FontWeight.w700, color: AppColors.primary)),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(child: Text(tips[i], style: bodyStyle(14, height: 1.45))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tek seferlik, hafif konfeti: temanın kendi süs parçaları yukarıdan süzülür (≈2.6 sn).
/// Sistem "animasyonları kaldır" tercihi açıksa hiç çizilmez.
class OrnamentConfetti extends StatefulWidget {
  const OrnamentConfetti({super.key, required this.orn, this.count = 18});

  final String orn;
  final int count;

  @override
  State<OrnamentConfetti> createState() => _OrnamentConfettiState();
}

class _OrnamentConfettiState extends State<OrnamentConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final List<_Bit> _bits;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.orn.hashCode);
    _bits = [
      for (var i = 0; i < widget.count; i++)
        _Bit(
          x: r.nextDouble(),
          delay: r.nextDouble() * 0.35,
          drift: (r.nextDouble() - 0.5) * 0.16,
          size: 14 + r.nextDouble() * 14,
          spin: (r.nextDouble() - 0.5) * 4,
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || AppMotion.reduced(context)) return;
    _started = true;
    HapticFeedback.lightImpact();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_c.isCompleted) return const SizedBox.shrink();
          return Stack(
            children: [
              for (final b in _bits)
                () {
                  final t = ((_c.value - b.delay) / (1 - b.delay)).clamp(0.0, 1.0).toDouble();
                  final y = -40 + Curves.easeIn.transform(t) * (box.maxHeight * 0.75);
                  final x = (b.x + b.drift * t) * box.maxWidth;
                  final o = t < 0.1 ? t * 10 : (t > 0.75 ? (1 - t) * 4 : 1.0);
                  return Positioned(
                    left: x,
                    top: y,
                    child: Opacity(
                      opacity: o.clamp(0.0, 1.0).toDouble() * 0.9,
                      child: Transform.rotate(angle: b.spin * t, child: Ornament(widget.orn, size: b.size)),
                    ),
                  );
                }(),
            ],
          );
        },
      );
    });
  }
}

class _Bit {
  const _Bit({required this.x, required this.delay, required this.drift, required this.size, required this.spin});

  final double x, delay, drift, size, spin;
}

/// Kişiye özel bağlantılar: isimler (her satıra bir) → her davetli için ?g=Ad bağlantısı,
/// kişiye özel WhatsApp mesajı ve kopyala. İsimler yalnız cihazda/bağlantıda; hiçbir yere kaydedilmez.
class _GuestLinksSheet extends StatefulWidget {
  const _GuestLinksSheet({required this.cloudId, required this.messageFor});

  final String cloudId;
  final String Function(String guest, String link) messageFor;

  @override
  State<_GuestLinksSheet> createState() => _GuestLinksSheetState();
}

class _GuestLinksSheetState extends State<_GuestLinksSheet> {
  final _ctl = TextEditingController();
  List<String>? _names;
  bool _empty = false;
  bool _truncated = false;
  final Set<String> _sent = {};

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _make() {
    final raw = _ctl.text.split(RegExp(r'[\r\n]+')).where((l) => cleanGuestName(l).isNotEmpty).length;
    final names = parseGuestNames(_ctl.text);
    setState(() {
      _empty = names.isEmpty;
      _names = names.isEmpty ? null : names;
      _truncated = raw > kGuestLinksMax;
    });
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppSpace.edge, AppSpace.x4, AppSpace.edge, AppSpace.x6),
          children: [
            Text(context.t('guestLinkBtn'), style: headStyle(AppType.h1)),
            const SizedBox(height: AppSpace.x2),
            Text(context.t('guestLinkP'), style: bodyStyle(13.5, color: AppColors.muted, height: 1.5)),
            const SizedBox(height: AppSpace.x4),
            if (names == null) ...[
              FieldBlock(
                label: context.t('guestLinkL'),
                error: _empty ? context.t('guestLinkEmpty') : null,
                child: TextField(
                  controller: _ctl,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(kGuestLinksMax * (kGuestNameMax + 1))],
                  decoration: fieldDecoration(hint: context.t('guestLinkPh')),
                  style: bodyStyle(16),
                  onChanged: (_) {
                    if (_empty) setState(() => _empty = false);
                  },
                ),
              ),
              PrimaryButton(label: context.t('guestLinkMake'), block: true, onPressed: _make),
            ] else ...[
              Text(context.t('guestLinkReady', {'n': names.length}), style: bodyStyle(14, weight: FontWeight.w700)),
              if (_truncated)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.x1),
                  child: Text(context.t('guestLinkMax', {'n': kGuestLinksMax}), style: bodyStyle(12.5, color: AppColors.muted)),
                ),
              const SizedBox(height: AppSpace.x3),
              for (final g in names) _row(g),
              const SizedBox(height: AppSpace.x3),
              GhostButton(label: context.t('guestLinkEdit'), block: true, onPressed: () => setState(() => _names = null)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String guest) {
    final link = personalInviteUrl(widget.cloudId, guest);
    final sent = _sent.contains(guest);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.x2),
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.x3, AppSpace.x1, AppSpace.x1, AppSpace.x1),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: sent ? AppColors.primary : AppColors.field),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          if (sent) const Padding(padding: EdgeInsetsDirectional.only(end: 6), child: ZGlyph(ZGlyphs.check, size: 18, color: AppColors.ok)),
          Expanded(child: Text(guest, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(15, weight: FontWeight.w600))),
          ZIconButton(
            glyph: ZGlyphs.copy,
            tooltip: context.t('copyLink'),
            onPressed: () async {
              final msg = context.t('copied');
              await Clipboard.setData(ClipboardData(text: link));
              if (mounted) showToast(context, msg);
            },
          ),
          Semantics(
            button: true,
            label: '${context.t('shareWa')}: $guest',
            child: Tooltip(
              message: context.t('shareWa'),
              child: InkResponse(
                radius: 24,
                onTap: () {
                  setState(() => _sent.add(guest));
                  launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(widget.messageFor(guest, link))}'),
                          mode: LaunchMode.externalApplication)
                      .then((ok) {
                    if (ok) ReviewPrompter.instance.onShare();
                  });
                },
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadii.sm)),
                  child: const Center(child: WaIcon(size: 20)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
