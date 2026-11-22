import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../logic/lock_rules.dart';
import '../logic/type_order.dart';
import '../models/invitation.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/ornament.dart';
import 'theme_screen.dart';

/// Etkinlik türü seçimi. [retype] verilirse mevcut davetiyenin türü değiştirilir.
class TypeScreen extends StatelessWidget {
  const TypeScreen({super.key, this.retype});

  final Invitation? retype;

  void _pick(BuildContext context, String type) {
    final st = context.read<AppState>();
    final inv = retype;
    if (inv != null) {
      if (!canChangeTypeOrTheme(inv)) {
        showToast(context, context.t('lockedNote'), ms: 3500);
        return;
      }
      final presets = kMessages[inv.lang]?[inv.type] ?? const <String>[];
      if (presets.contains(inv.msg)) {
        final next = kMessages[inv.lang]?[type] ?? const <String>[];
        if (next.isNotEmpty) inv.msg = next.first;
      }
      inv.type = type;
      st.save();
      Navigator.of(context).pop();
      return;
    }
    final draft = st.createDraft(type);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ThemeScreen(draft: draft)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ZTopBar(title: context.t('newInv'), leading: const BackBtn()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  H2(context.t('chooseType')),
                  Para(context.t('chooseTypeP')),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: [
                      for (final ty in eventTypesFor(lang))
                        _Tile(
                          label: context.t('type_$ty'),
                          orn: kTypeIcon[ty] ?? 'o-papatya',
                          dark: kTypeIconDark.contains(ty),
                          selected: retype?.type == ty,
                          onTap: () => _pick(context, ty),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.orn, required this.selected, required this.onTap, this.dark = false});

  final String label;
  final String orn;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: selected ? AppColors.primary : AppColors.lineStrong, width: selected ? 2 : 1.5),
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Simge, kendi dairesinde: açık zeminde beyaz/altın simgeler kaybolmasın.
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: dark ? AppColors.primary : AppColors.tint, shape: BoxShape.circle),
                  child: Ornament(orn, size: 32),
                ),
                const SizedBox(height: 8),
                // Uzun (özellikle Almanca) etiketler: en uzun sözcük sığmıyorsa yazı küçülür, sonra satıra sarılır.
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      const base = 14.5;
                      final style = bodyStyle(base, weight: FontWeight.w600, height: 1.2);
                      final scaler = MediaQuery.textScalerOf(context);
                      var widest = 0.0;
                      for (final w in label.split(RegExp(r'\s+'))) {
                        final tp = TextPainter(text: TextSpan(text: w, style: style), textDirection: Directionality.of(context), textScaler: scaler)..layout();
                        if (tp.width > widest) widest = tp.width;
                      }
                      final k = widest > c.maxWidth && widest > 0 ? (c.maxWidth / widest).clamp(0.78, 1.0).toDouble() : 1.0;
                      return Text(label, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: bodyStyle(base * k, weight: FontWeight.w600, height: 1.2));
                    },
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
