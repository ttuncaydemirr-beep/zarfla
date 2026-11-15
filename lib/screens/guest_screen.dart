import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../logic/theme_style.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/invite_view.dart';

/// "Davetli gibi aç": davetli sayfası tam ekran.
class GuestScreen extends StatelessWidget {
  const GuestScreen({super.key, required this.invId});

  final String invId;

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<AppState>().byId(invId);
    final th = inv == null ? null : (kThemes[inv.theme] ?? kThemes['papatya']!);
    final dark = th != null && isDarkTheme(th);
    // Tasarım incelemesi #26: kapat çubuğu temadan türetilir (açık temada açık, koyu temada koyu).
    final barBg = th == null ? Colors.black : (dark ? th.colors.bg.withValues(alpha: 0.92) : th.colors.paper.withValues(alpha: 0.92));
    final fg = th == null ? Colors.white : th.colors.ink;
    return Scaffold(
      backgroundColor: th?.colors.bg ?? Colors.black,
      body: inv == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: Column(
                children: [
                  // İnce üst çubuk: kapat düğmesi davetiye içeriğini örtmez, içerik çubuğun altından başlar.
                  Container(
                    height: 52,
                    decoration: BoxDecoration(color: barBg, border: Border(bottom: BorderSide(color: th!.colors.line))),
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          backgroundColor: fg.withValues(alpha: 0.08),
                          minimumSize: const Size(48, 44),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: ZGlyph(ZGlyphs.close, size: 18, color: fg),
                        label: Text(context.t('close'), style: bodyStyle(14, weight: FontWeight.w600, color: fg)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(child: InviteView(inv: inv)),
                ],
              ),
            ),
    );
  }
}
