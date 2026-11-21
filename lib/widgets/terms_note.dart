import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Kullanım Koşulları sayfası (stüdyo sitesi; 4 dil, tarayıcı diline göre). Play UGC politikası: içerik
/// oluşturmadan önce kullanıcı koşulları kabul edilir.
const String kTermsUrl = 'https://ttuncaydemirr-beep.github.io/terms/zarfla/';

const String kTermsAcceptedKey = 'zarfla_terms_ok_v1';

/// Koşulların bu cihazda kabul edildiği (ilk yayın) yerel olarak saklanır; sunucuya gönderilmez.
class TermsConsent {
  const TermsConsent._();

  static Future<bool> isAccepted() async {
    try {
      return (await SharedPreferences.getInstance()).getInt(kTermsAcceptedKey) != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> accept([int? nowMs]) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getInt(kTermsAcceptedKey) == null) await p.setInt(kTermsAcceptedKey, nowMs ?? DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}

/// İlk yayında yayın düğmesinin üstünde tek satır: "Yayınlayarak Kullanım Koşulları'nı kabul edersiniz."
/// (engelleyici kutu yok; düğmeye basmak kabuldür). Koşullar metni tıklanınca tarayıcıda açılır.
class TermsConsentNote extends StatefulWidget {
  const TermsConsentNote({super.key});

  @override
  State<TermsConsentNote> createState() => _TermsConsentNoteState();
}

class _TermsConsentNoteState extends State<TermsConsentNote> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()
    ..onTap = () => launchUrl(Uri.parse(kTermsUrl), mode: LaunchMode.externalApplication);

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = bodyStyle(11.5, color: AppColors.muted, height: 1.4);
    final parts = context.t('termsConsent').split('{n}');
    final link = TextSpan(
      text: context.t('termsLinkText'),
      style: base.copyWith(color: AppColors.primary, decoration: TextDecoration.underline),
      recognizer: _tap,
    );
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: parts.first),
        if (parts.length > 1) ...[link, TextSpan(text: parts.sublist(1).join('{n}'))] else link,
      ]),
      textAlign: TextAlign.center,
    );
  }
}
