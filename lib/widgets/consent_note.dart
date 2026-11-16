import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Mesafeli Sözleşmeler Yönetmeliği md.15(1)(ğ): anında ifa edilen dijital hizmette
/// satın alma düğmesinin yanında görünen bilgilendirme/onay satırı (engelleyici kutu yok).
class WithdrawalConsentNote extends StatelessWidget {
  const WithdrawalConsentNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t('withdrawalConsent'),
      textAlign: TextAlign.center,
      style: bodyStyle(11.5, color: AppColors.muted, height: 1.4),
    );
  }
}
