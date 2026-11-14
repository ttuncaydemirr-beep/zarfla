import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../logic/date_utils.dart';
import '../logic/text_utils.dart';
import '../models/invitation.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_slot.dart';
import '../widgets/common.dart';
import '../widgets/ornament.dart';
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
              actions: [_LangSelect(value: st.lang, onChanged: (l) => st.setLang(l))],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  H2(context.t('myInv')),
                  if (list.isEmpty) const _Empty() else ...list.map((inv) => _InvItem(inv: inv)),
                  const SizedBox(height: 6),
                  PrimaryButton(
                    label: '+ ${context.t('newInv')}',
                    block: true,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TypeScreen())),
                  ),
                  if (!st.premiumUser) AdSlot(label: context.t('ad')),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 10),
      child: Column(
        children: [
          const Ornament('o-papatya', size: 72),
          const SizedBox(height: 10),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(invId: inv.id))),
          child: ZCard(
            margin: EdgeInsets.zero,
            child: Row(
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
                      Text('${context.t('type_${inv.type}')}$dateTxt', style: bodyStyle(13, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                live
                    ? ZBadge(label: context.t('live'), bg: AppColors.tint, fg: AppColors.ok, icon: Icons.check)
                    : ZBadge(label: context.t('draft'), bg: AppColors.sand, fg: AppColors.draftInk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
