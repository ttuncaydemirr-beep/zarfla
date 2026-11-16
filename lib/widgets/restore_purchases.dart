import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../billing/billing_logic.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// "Satın alımı geri yükle": Play'deki tüketilmemiş alımları yeniden sorgular ve tamamlar
/// (redeemPurchase ile hak → tüket); sonucu yerelleştirilmiş kısa mesajla bildirir.
Future<void> runRestorePurchases(BuildContext context) async {
  final st = context.read<AppState>();
  final key = await st.restorePurchases();
  if (!context.mounted) return;
  showToast(context, context.t(key, {'n': st.creditBalance}), ms: 6000);
}

/// Yayınla ekranı alt bilgisi ve benzeri yerler için sade metin düğmesi.
class RestorePurchasesButton extends StatelessWidget {
  const RestorePurchasesButton({super.key});

  @override
  Widget build(BuildContext context) {
    final busy = context.select<AppState, bool>((s) => s.restoring);
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(48, 48)),
      icon: busy
          ? const SizedBox(width: 18, height: 18, child: ZLoader(size: 18))
          : const ZGlyph(ZGlyphs.retry, size: 18, color: AppColors.primary),
      label: Text(
        context.t(busy ? 'restoreBusy' : 'restoreBtn'),
        style: bodyStyle(14, weight: FontWeight.w600, color: AppColors.primary),
      ),
      onPressed: busy ? null : () => runRestorePurchases(context),
    );
  }
}

/// Ana ekran bandı: ödeme alındı ama henüz doğrulanmadı ("Ödemeniz doğrulanıyor…") + "Tekrar dene".
class PayVerifyBanner extends StatelessWidget {
  const PayVerifyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (!st.payVerifying) return const SizedBox.shrink();
    return ActionCard(
      title: context.t('payVerifyT'),
      text: context.t('payVerifyP'),
      icon: Icons.hourglass_top_rounded,
      actions: [
        GhostButton(
          label: context.t(st.restoring ? 'restoreBusy' : 'retry'),
          icon: const ZGlyph(ZGlyphs.retry, size: 18, color: AppColors.primary),
          onPressed: st.restoring ? null : () => runRestorePurchases(context),
        ),
      ],
    );
  }
}

/// "2 hakkınız kaldı": sunucudaki "Düğün Zinciri" paket hakkı bakiyesi (yalnız > 0 iken görünür).
class CreditsBadge extends StatelessWidget {
  const CreditsBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.select<AppState, int>((s) => s.creditBalance);
    if (n <= 0) return const SizedBox.shrink();
    return Semantics(
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.x3),
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.x3, AppSpace.x3, AppSpace.x4, AppSpace.x3),
        decoration: BoxDecoration(
          color: AppColors.tint,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(top: 1), child: ZGlyph(ZGlyphs.crown, size: 18, color: AppColors.primary)),
            const SizedBox(width: AppSpace.x2 + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t(creditsLeftKey(n), {'n': n}), style: bodyStyle(14.5, weight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(context.t('creditsLeftP'), style: bodyStyle(13, color: AppColors.muted, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
