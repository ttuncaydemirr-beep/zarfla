import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ads/ad_service.dart';
import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../logic/date_utils.dart';
import '../logic/lock_rules.dart';
import '../logic/progress.dart';
import '../logic/text_utils.dart';
import '../models/invitation.dart';
import '../notify/reminder_ui.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/about_dialog.dart';
import '../widgets/ad_slot.dart';
import '../widgets/common.dart';
import '../widgets/ornament.dart';
import '../widgets/restore_purchases.dart';
import 'editor_screen.dart';
import 'type_screen.dart';

/// Davetiyelerim.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final list = st.sorted;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ZTopBar(
              title: context.t('app'),
              subtitle: context.t('by'),
              leading: const BrandMark(),
              actions: [
                ValueListenableBuilder<bool>(
                  valueListenable: AdService.privacyOptionsRequired,
                  builder: (context, required, _) => required
                      ? ZIconButton(
                          icon: Icons.privacy_tip_outlined,
                          tooltip: context.t('privacyOptions'),
                          onPressed: AdService.showPrivacyOptions,
                        )
                      : const SizedBox.shrink(),
                ),
                _LangSelect(value: st.lang, onChanged: (l) => st.setLang(l)),
                const _HomeMenu(),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const SafeModeBanner(),
                  const PayVerifyBanner(),
                  const CreditsBadge(),
                  H2(context.t('myInv')),
                  if (list.isEmpty) const _Empty() else ...list.map((inv) => _InvItem(inv: inv)),
                  const SizedBox(height: 6),
                  PrimaryButton(
                    label: '+ ${context.t('newInv')}',
                    block: true,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TypeScreen())),
                  ),
                ],
              ),
            ),
            // Banner ekranın altına sabit (SafeArea içinde, sistem gezinme çubuğunun üstünde); reklam yoksa yer kaplamaz.
            if (!st.premiumUser) const AdSlot(topGap: AppSpace.x2, horizontal: AppSpace.edge),
          ],
        ),
      ),
    );
  }
}

/// Başlıktaki "⋯" menüsü: satın alımı geri yükle, hakkında (sürüm).
class _HomeMenu extends StatelessWidget {
  const _HomeMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: context.t('more'),
      onSelected: (v) {
        if (v == 'restore') runRestorePurchases(context);
        if (v == 'reminders') showReminderSettings(context);
        if (v == 'about') showZarflaAbout(context);
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'restore',
          child: Row(children: [
            const ZGlyph(ZGlyphs.retry, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Flexible(child: Text(context.t('restoreBtn'), style: bodyStyle(15))),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'reminders',
          child: Row(children: [
            const Icon(Icons.notifications_none, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Flexible(child: Text(context.t('remMenu'), style: bodyStyle(15))),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'about',
          child: Row(children: [
            const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Flexible(child: Text(context.t('aboutBtn'), style: bodyStyle(15))),
          ]),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsetsDirectional.only(start: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: const Icon(Icons.more_horiz, size: 22, color: AppColors.ink),
      ),
    );
  }
}

class _LangSelect extends StatelessWidget {
  const _LangSelect({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.t('language'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.field),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            dropdownColor: AppColors.surface,
            style: bodyStyle(14),
            items: [
              for (final l in kLangs) DropdownMenuItem(value: l, child: Text(kLangNames[l]!)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.x8, horizontal: AppSpace.x3),
      child: Column(
        children: [
          // Tasarım incelemesi #21: soluk papatya yerine zümrüt daire içinde marka figürü.
          Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.up),
            child: const BrandMark(size: 96, round: true),
          ),
          const SizedBox(height: AppSpace.x4),
          Text(context.t('empty'), textAlign: TextAlign.center, style: bodyStyle(15, color: AppColors.muted, height: 1.6)),
        ],
      ),
    );
  }
}

class _InvItem extends StatelessWidget {
  const _InvItem({required this.inv});

  final Invitation inv;

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final th = kThemes[inv.theme] ?? kThemes['papatya']!;
    final dateTxt = inv.date.isEmpty ? '' : ' · ${formatShortDate(inv.date, st.lang)}';
    final live = inv.isLive;
    final expired = live && st.isExpired(inv);
    final now = DateTime.now();
    // Taslakta tamamlanma: "%75 hazır · Eksik: WhatsApp numarası" (yarım kalan taslak kolay tamamlansın).
    final missing = live ? const <String>[] : missingRequired(inv);
    final pct = live ? 100 : readyPercent(inv);
    final days = live && !expired ? daysUntil(inv.date, now) : null;
    void openEditor() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(invId: inv.id)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: openEditor,
          child: ZCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: th.colors.bg,
                        border: Border.all(color: th.colors.line),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Ornament(th.orn, size: 38),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invitationTitle(inv, context.t('untitled')),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(16, weight: FontWeight.w700)),
                          Text('${context.t('type_${inv.type}')}$dateTxt', maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(13, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    expired
                        ? ZBadge(label: context.t('expired'), bg: AppColors.sand, fg: AppColors.err, icon: Icons.timer_off_outlined)
                        : live
                            ? ZBadge(label: context.t('live'), bg: AppColors.tint, fg: AppColors.ok, icon: Icons.check)
                            : ZBadge(label: context.t('draft'), bg: AppColors.sand, fg: AppColors.draftInk),
                  ],
                ),
                if (!live) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 6,
                      color: pct == 100 ? AppColors.ok : AppColors.primary,
                      backgroundColor: AppColors.sand,
                      semanticsLabel: context.t('readyPct', {'n': pct}),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      context.t('readyPct', {'n': pct}),
                      missing.isEmpty ? context.t('readyDone') : context.t('readyMissing', {'a': missing.map((k) => context.t('errPart_$k')).join(', ')}),
                    ].join(' · '),
                    style: bodyStyle(12.5, color: AppColors.muted, height: 1.35),
                  ),
                  const SizedBox(height: 2),
                  Text(context.t('draftContinue'), style: bodyStyle(13, weight: FontWeight.w600, color: AppColors.primary)),
                ],
                if (expired && canUpgradeToPaid(inv)) ...[
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: context.t('upExpiredBtn', {'p': st.hasCredit ? context.t('creditOne') : (st.playPrice ?? context.t('price'))}),
                    block: true,
                    onPressed: openEditor,
                  ),
                ],
                if (days != null && days >= 0 && days <= 7) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        days == 0 ? context.t('remindToday') : context.t('remindT', {'n': days}),
                        style: bodyStyle(13, weight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
