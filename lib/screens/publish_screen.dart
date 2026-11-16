import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../billing/billing_logic.dart';
import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../notify/reminder_ui.dart';
import '../notify/review_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/consent_note.dart';
import '../widgets/invite_mini.dart';
import '../widgets/ornament.dart';
import '../widgets/restore_purchases.dart';
import 'done_screen.dart';

/// Yayınla (paywall): kullanıcının KENDİ davetiyesinin kahraman önizlemesi, önerilen zümrüt "1 Davetiye Hakkı"
/// kartı (radyo seçimi), değer listesi, ödeme ÖNCESİ sade dille kilit kuralları (UX #4), ücretli tasarımda
/// bile dokunulabilir ücretsiz seçenek + "Ücretsiz Papatya ile yayınla" (UX #3) ve ödeme durumları için
/// ekranda kalan durum paneli (UX #8).
/// Ücretsiz: Firestore + Storage. Ücretli: Google Play'de tek seferlik, tüketilebilir zarfla_invite_1 alımı →
/// redeemPurchase sunucuda doğrular ve yazar → uygulama alımı tüketir.
/// "Düğün Zinciri" (zarfla_invite_3, 3 hak): Play'de ürün varsa ikinci kart; tasarruf rozeti Play fiyatlarından
/// hesaplanır. Sunucuda paket hakkı varsa ödeme yapılmaz, 1 hak kullanılır (kalan sayı gösterilir).
class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key, required this.invId});

  final String invId;

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

/// Durum anahtarı → panel tonu ve "Tekrar dene" gösterilip gösterilmeyeceği.
ZStatusTone statusToneOf(String key) {
  switch (key) {
    case 'payPending':
      return ZStatusTone.pending;
    case 'payCancelled':
      return ZStatusTone.info;
    default:
      return ZStatusTone.error;
  }
}

const Set<String> kRetryableStatus = {'payErr', 'payVerifyErr', 'netErr', 'cloudErr', 'cloudSetup'};

class _PublishScreenState extends State<PublishScreen> {
  String? _plan;
  bool _busy = false;
  String? _status;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _publish(String plan) async {
    if (_busy) return;
    final st = context.read<AppState>();
    final inv = st.byId(widget.invId);
    if (inv == null) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    final nav = Navigator.of(context);
    // UX #3: ücretli tasarım seçiliyken ücretsiz yol = Papatya'ya geç (bilgiler korunur), sonra yayınla.
    if (plan == 'free' && (kThemes[inv.theme]?.premium ?? false)) {
      inv.theme = 'papatya';
      await st.save();
    }
    final err = plan == 'free'
        ? await st.publishFree(inv)
        : await st.publishPaid(inv, productId: plan == 'bundle' ? kBundleProductId : kInviteProductId);
    if (!mounted) return;
    setState(() => _busy = false);
    // 'paidPhotoErr': ödeme alındı ve davetiye yayında, yalnız bazı fotoğraflar yüklenemedi.
    // Bekleyen ödeme sonradan onaylanırsa davetiye arka planda yayınlanmış olabilir.
    if (err != null && err != 'paidPhotoErr' && !inv.isLive) {
      setState(() => _status = err);
      if (_scroll.hasClients) _scroll.animateTo(0, duration: AppMotion.slow, curve: AppMotion.enter);
      return;
    }
    if (err != null) showToast(context, context.t(err), ms: 6000);
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => DoneScreen(invId: inv.id)), (r) => r.isFirst);
    // İlk ücretsiz yayından sonra kısa açıklamayla bildirim izni; ücretli yayından sonra (nadiren) değerlendirme istemi.
    if (inv.isLive && inv.plan == 'free') unawaited(askReminderPermissionAfterPublish());
    if (inv.isLive && inv.plan == 'premium' && (err == null || err == 'paidPhotoErr')) ReviewPrompter.instance.onPaidPublish();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final inv = st.byId(widget.invId);
    if (inv == null) return const Scaffold(body: SizedBox.shrink());
    final prem = kThemes[inv.theme]?.premium ?? false;
    final price = st.playPrice ?? context.t('price');
    final bundlePrice = st.bundlePrice;
    final credits = st.creditBalance;
    // Paket kartı: Play'de ürün var ve elde kullanılacak hak yok.
    final showBundle = bundlePrice != null && !st.hasCredit;
    var plan = _plan ?? (prem ? 'premium' : 'free');
    if (plan == 'bundle' && !showBundle) plan = 'premium';
    final paid = plan != 'free';
    final payReady = st.canPayOrUseCredit;
    final status = _status;
    final String label;
    if (_busy) {
      label = context.t(plan == 'free' ? 'cloudPublishing' : 'payProcessing');
    } else if (plan == 'free') {
      label = prem ? context.t('publishFreePapatya') : context.t('publishFree');
    } else if (st.hasCredit) {
      label = context.t('payUseCredit');
    } else {
      label = context.t('pay', {'p': plan == 'bundle' ? bundlePrice! : price});
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ZTopBar(title: context.t('publish'), leading: const BackBtn()),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(AppSpace.edge, AppSpace.x1, AppSpace.edge, AppSpace.x6),
                children: [
                  _Hero(child: InviteMiniFor(inv: inv)),
                  const SizedBox(height: AppSpace.x4),
                  Text(context.t('pubHero'), textAlign: TextAlign.center, style: headStyle(AppType.h1)),
                  const SizedBox(height: AppSpace.x2),
                  Text(context.t('pubHeroP'), textAlign: TextAlign.center, style: bodyStyle(14.5, color: AppColors.muted, height: 1.5)),
                  const SizedBox(height: AppSpace.x6),
                  if (status != null)
                    StatusPanel(
                      tone: statusToneOf(status),
                      text: context.t(status),
                      actionLabel: kRetryableStatus.contains(status) ? context.t('retry') : null,
                      onAction: kRetryableStatus.contains(status) ? () => _publish(plan) : null,
                      onClose: () => setState(() => _status = null),
                    ),
                  _PremiumCard(
                    on: plan == 'premium',
                    price: price,
                    onTap: () => setState(() => _plan = 'premium'),
                  ),
                  const SizedBox(height: AppSpace.x3),
                  if (showBundle) ...[
                    _BundleCard(
                      on: plan == 'bundle',
                      price: bundlePrice!,
                      savePct: st.bundleSavePct,
                      onTap: () => setState(() => _plan = 'bundle'),
                    ),
                    const SizedBox(height: AppSpace.x3),
                  ],
                  _FreeCard(
                    on: plan == 'free',
                    premTheme: prem,
                    onTap: () => setState(() => _plan = 'free'),
                  ),
                  if (paid && !payReady)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.x3),
                      child: StatusPanel(tone: ZStatusTone.error, text: context.t('payUnavailable')),
                    ),
                  if (paid && st.hasUnconsumed)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.x3),
                      child: StatusPanel(tone: ZStatusTone.success, text: context.t('payCredit')),
                    )
                  else if (paid && credits > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.x3),
                      child: StatusPanel(
                        tone: ZStatusTone.success,
                        text: [context.t(creditsLeftKey(credits), {'n': credits}), context.t('creditWillUse')].join(' · '),
                      ),
                    ),
                  const SizedBox(height: AppSpace.x3),
                  // Güven şeridi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ZGlyph(ZGlyphs.lock, size: 15, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Flexible(child: Text(context.t('trustLine'), textAlign: TextAlign.center, style: bodyStyle(12, color: AppColors.muted))),
                    ],
                  ),
                  // Alt bilgi: daha önce ödenmiş ama tamamlanmamış alımı geri yükle.
                  const SizedBox(height: AppSpace.x2),
                  const Center(child: RestorePurchasesButton()),
                ],
              ),
            ),
            _PayBar(
              lockLine: paid ? context.t('lockRulesShort') : null,
              consent: paid && !st.hasCredit,
              button: PrimaryButton(
                label: label,
                block: true,
                icon: paid && !_busy ? const ZGlyph(ZGlyphs.crown, size: 18, color: AppColors.brandRing) : null,
                onPressed: (_busy || (paid && !payReady)) ? null : () => _publish(plan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kahraman: kendi davetiyenizin hafif eğik minik önizlemesi, sıcak zemin üzerinde.
class _Hero extends StatelessWidget {
  const _Hero({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 236,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sand, AppColors.bg],
        ),
      ),
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: -0.04,
        child: Container(
          width: 150,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.md), boxShadow: AppShadows.hero),
          child: child,
        ),
      ),
    );
  }
}

/// Radyo düğmesi görünümü (UX #19): seçili = dolu nokta + halka.
class _Radio extends StatelessWidget {
  const _Radio({required this.on, required this.color});

  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: on ? 2 : 1.5)),
      child: AnimatedScale(
        duration: AppMotion.fast,
        scale: on ? 1 : 0,
        child: Container(width: 11, height: 11, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.on, required this.price, required this.onTap});

  final bool on;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: on,
      button: true,
      label: '${context.t('pass')}, $price',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.enter,
          padding: const EdgeInsets.all(AppSpace.x4 + 2),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: on ? AppColors.brandRing : AppColors.accentOnDark.withValues(alpha: 0.45), width: on ? 2 : 1),
            boxShadow: on ? [const BoxShadow(color: AppColors.focusRing, spreadRadius: 3), ...AppShadows.up] : AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Radio(on: on, color: AppColors.brandRing),
                  const SizedBox(width: AppSpace.x3),
                  const ZGlyph(ZGlyphs.crown, size: 18, color: AppColors.brandRing),
                  const SizedBox(width: 6),
                  Expanded(child: Text(context.t('pass'), style: headStyle(18, color: AppColors.onPrimary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.brandRing, borderRadius: BorderRadius.circular(AppRadii.pill)),
                    child: Text(context.t('recommended'), style: bodyStyle(11.5, weight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.x3),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: AppSpace.x2,
                children: [
                  Text(price, style: headStyle(AppType.display, color: AppColors.onPrimary, height: 1.05)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(context.t('oneTime'), style: bodyStyle(13, color: AppColors.onPrimary.withValues(alpha: 0.85))),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.x3),
              Container(height: 1, color: AppColors.accentOnDark.withValues(alpha: 0.45)),
              const SizedBox(height: AppSpace.x3),
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 1), child: ZGlyph(ZGlyphs.check, size: 18, color: AppColors.brandRing)),
                      const SizedBox(width: AppSpace.x2 + 2),
                      Expanded(child: Text(context.t('premV$i'), style: bodyStyle(14.5, color: AppColors.onPrimary, height: 1.45))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Düğün Zinciri": 3 Davetiye Hakkı. Tasarruf rozeti yalnız Play fiyatlarından hesaplanabildiğinde görünür.
class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.on, required this.price, required this.savePct, required this.onTap});

  final bool on;
  final String price;
  final int? savePct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final save = savePct;
    final saveText = save == null ? null : context.t('bundleSave', {'n': save});
    final parts = [context.t('bundleName'), context.t('bundleSub'), price, if (saveText != null) saveText];
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: on,
      button: true,
      label: parts.join(', '),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.enter,
          padding: const EdgeInsets.all(AppSpace.x4),
          decoration: BoxDecoration(
            color: on ? AppColors.surface : AppColors.sand,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: on ? AppColors.primary : AppColors.lineStrong, width: on ? 2 : 1),
            boxShadow: on ? const [BoxShadow(color: AppColors.focusRing, spreadRadius: 3)] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Radio(on: on, color: AppColors.primary),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.t('bundleName'), style: headStyle(17, color: AppColors.ink)),
                        Text(context.t('bundleSub'), style: bodyStyle(13, weight: FontWeight.w600, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  if (saveText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.brandRing, borderRadius: BorderRadius.circular(AppRadii.pill)),
                      child: Text(saveText, style: bodyStyle(11.5, weight: FontWeight.w700, color: AppColors.primary)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.x2),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: AppSpace.x2,
                      children: [
                        Text(price, style: headStyle(22, color: AppColors.ink)),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(context.t('oneTime'), style: bodyStyle(12.5, color: AppColors.mutedOnSand)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.x1),
                    Text(context.t('bundleP'), style: bodyStyle(13.5, color: AppColors.mutedOnSand, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeCard extends StatelessWidget {
  const _FreeCard({required this.on, required this.premTheme, required this.onTap});

  final bool on;
  final bool premTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: on,
      button: true,
      label: context.t('free'),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.enter,
          padding: const EdgeInsets.all(AppSpace.x4),
          decoration: BoxDecoration(
            color: on ? AppColors.surface : AppColors.sand,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: on ? AppColors.primary : AppColors.lineStrong, width: on ? 2 : 1),
            boxShadow: on ? const [BoxShadow(color: AppColors.focusRing, spreadRadius: 3)] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Radio(on: on, color: AppColors.primary),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(child: Text(context.t('free'), style: headStyle(17, color: AppColors.ink))),
                  Text('0', style: headStyle(20, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: AppSpace.x2),
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 34, top: 2, bottom: 2),
                  child: Text('· ${context.t('freeL$i')}', style: bodyStyle(13.5, color: AppColors.mutedOnSand, height: 1.45)),
                ),
              // UX #3: ücretli tasarım seçiliyken ücretsiz seçenek ölü değil; ne olacağı açıkça söylenir.
              if (premTheme)
                AnimatedSize(
                  duration: AppMotion.base,
                  curve: AppMotion.enter,
                  child: on
                      ? Container(
                          margin: const EdgeInsetsDirectional.only(start: 34, top: AppSpace.x3),
                          padding: const EdgeInsets.all(AppSpace.x3),
                          decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(AppRadii.sm)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: kThemes['papatya']!.colors.bg,
                                  borderRadius: BorderRadius.circular(AppRadii.xs),
                                  border: Border.all(color: kThemes['papatya']!.colors.line),
                                ),
                                child: const Ornament('o-papatya', size: 30),
                              ),
                              const SizedBox(width: AppSpace.x3),
                              Expanded(child: Text(context.t('freeSwitchP'), style: bodyStyle(13, color: AppColors.ink, height: 1.45))),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsetsDirectional.only(start: 34, top: AppSpace.x2),
                          child: Text(context.t('freeSwitchHint'), style: bodyStyle(13, weight: FontWeight.w600, color: AppColors.primary)),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alt çubuk: (ücretli seçiliyse) düğmenin hemen üstünde kilit kuralları + ana düğme.
class _PayBar extends StatelessWidget {
  const _PayBar({required this.button, this.lockLine, this.consent = false});

  final Widget button;
  final bool consent;
  final String? lockLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.edge, AppSpace.x3, AppSpace.edge, AppSpace.x3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lockLine != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x2 + 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 1), child: ZGlyph(ZGlyphs.lock, size: 16, color: AppColors.primary)),
                      const SizedBox(width: AppSpace.x2),
                      Expanded(child: Text(lockLine!, style: bodyStyle(12.5, color: AppColors.ink, height: 1.4))),
                    ],
                  ),
                ),
              if (consent)
                const Padding(padding: EdgeInsets.only(bottom: AppSpace.x2), child: WithdrawalConsentNote()),
              button,
            ],
          ),
        ),
      ),
    );
  }
}
