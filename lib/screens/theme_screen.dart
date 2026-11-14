import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../logic/lock_rules.dart';
import '../logic/text_utils.dart';
import '../models/invitation.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_slot.dart';
import '../widgets/common.dart';
import '../widgets/ornament.dart';
import 'editor_screen.dart';

/// Tasarım galerisi. [draft]: yeni (henüz kaydedilmemiş) davetiye; [existing]: düzenlenen davetiye.
class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key, this.draft, this.existing}) : assert(draft != null || existing != null);

  final Invitation? draft;
  final Invitation? existing;

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  Invitation get inv => widget.existing ?? widget.draft!;

  void _select(String themeId) {
    if (!canChangeTypeOrTheme(inv)) {
      showToast(context, context.t('lockedNote'), ms: 3500);
      return;
    }
    setState(() => inv.theme = themeId);
    if (widget.existing != null) context.read<AppState>().save();
  }

  Future<void> _continue() async {
    final st = context.read<AppState>();
    if (widget.existing != null) {
      Navigator.of(context).pop();
      return;
    }
    final d = widget.draft!;
    await st.add(d);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => EditorScreen(invId: d.id)),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final lang = st.lang;
    final sample = inv.isCouple
        ? '${inv.n1.isNotEmpty ? inv.n1 : 'Pelin'} & ${inv.n2.isNotEmpty ? inv.n2 : 'Burak'}'
        : (inv.n1.isNotEmpty ? inv.n1 : (lang == 'ar' ? 'يوسف' : 'Ali Kerem'));
    final order = kRecommended[inv.type] ?? kThemes.keys.toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ZTopBar(title: context.t('type_${inv.type}'), leading: const BackBtn()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  H2(context.t('chooseTheme')),
                  Para(context.t('chooseThemeP')),
                  for (final id in order)
                    if (kThemes[id] != null)
                      _ThemeCard(
                        theme: kThemes[id]!,
                        lang: lang,
                        sample: sample,
                        eyebrow: upperFor(context.t('eyebrow_${inv.type}'), lang),
                        selected: inv.theme == id,
                        freeLabel: context.t('free'),
                        paidLabel: context.t('premium'),
                        onTap: () => _select(id),
                      ),
                  if (!st.premiumUser) AdSlot(label: context.t('ad')),
                ],
              ),
            ),
            ZBottomBar(children: [PrimaryButton(label: '${context.t('edit')} →', onPressed: _continue)]),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.lang,
    required this.sample,
    required this.eyebrow,
    required this.selected,
    required this.freeLabel,
    required this.paidLabel,
    required this.onTap,
  });

  final InviteTheme theme;
  final String lang;
  final String sample;
  final String eyebrow;
  final bool selected;
  final String freeLabel;
  final String paidLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: selected,
        label: theme.nameIn(lang),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: 1.5),
              boxShadow: selected
                  ? const [BoxShadow(color: Color(0x381F3D36), spreadRadius: 3)]
                  : AppShadows.card,
            ),
            child: Column(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  color: c.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Ornament(theme.orn, size: 46),
                      const SizedBox(height: 4),
                      Text(sample,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: headStyle(28, weight: FontWeight.w400, color: c.accent, fontStyle: lang == 'ar' ? FontStyle.normal : FontStyle.italic)),
                      const SizedBox(height: 4),
                      Text(eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: bodyStyle(11, color: c.muted, letterSpacing: lang == 'ar' ? 0 : 2.6)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(theme.nameIn(lang), style: bodyStyle(15, weight: FontWeight.w700))),
                      theme.premium
                          ? ZBadge(label: '♛ $paidLabel', bg: AppColors.crownBg, fg: AppColors.crownInk)
                          : ZBadge(label: freeLabel, bg: AppColors.tint, fg: AppColors.ok),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
