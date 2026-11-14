import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud/invite_contract.dart';
import '../data/catalog.dart';
import '../logic/date_utils.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/ornament.dart';
import 'guest_screen.dart';

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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ZTopBar(title: context.t('app')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const SizedBox(height: 24),
                  Center(child: Ornament(th.orn, size: 84)),
                  const SizedBox(height: 6),
                  Center(child: H2(context.t('done'))),
                  Text(context.t('doneP'), textAlign: TextAlign.center, style: bodyStyle(14.5, color: AppColors.muted, height: 1.5)),
                  const SizedBox(height: 14),
                  FieldBlock(
                    label: context.t('linkL'),
                    hint: expired ? context.t('expiredNote') : '${context.t('linkNoteApp')} $expTxt'.trim(),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.field),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: SelectableText(link, style: bodyStyle(14))),
                            const SizedBox(width: 8),
                            GhostButton(
                              label: context.t('copy'),
                              onPressed: () async {
                                final msg = context.t('copied');
                                await Clipboard.setData(ClipboardData(text: full));
                                if (context.mounted) showToast(context, msg);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PrimaryButton(
                    label: context.t('shareWa'),
                    block: true,
                    icon: const WaIcon(),
                    onPressed: () {
                      final text = context.t('shareText') + full;
                      launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
                    },
                  ),
                  const SizedBox(height: 10),
                  GhostButton(
                    label: context.t('openAsGuest'),
                    block: true,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuestScreen(invId: inv.id))),
                  ),
                  const SizedBox(height: 10),
                  GhostButton(
                    label: context.t('backHome'),
                    block: true,
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
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
