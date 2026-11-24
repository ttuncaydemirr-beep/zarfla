import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/catalog.dart';
import 'l10n/strings.dart';
import 'notify/reminder_nav.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// Uygulama genelinde metin ölçeği 1.0–[kMaxTextScale] aralığına sıkıştırılır (Arapça için ayrıca [kArabicTextScale]).
const double kMaxTextScale = 1.3;

TextScaler clampedTextScaler(TextScaler base, {bool arabic = false}) {
  final c = base.clamp(minScaleFactor: 1.0, maxScaleFactor: kMaxTextScale);
  if (!arabic) return c;
  return TextScaler.linear(c.scale(100) / 100 * kArabicTextScale);
}

class ZarflaApp extends StatelessWidget {
  const ZarflaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return LangScope(
      lang: st.lang,
      child: MaterialApp(
        title: 'Zarfla',
        navigatorKey: zarflaNavKey,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: Locale(st.lang),
        supportedLocales: [for (final l in kLangs) Locale(l)],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Sistem yazı boyutu sınırı: büyük sistem fontunda (sahibinin telefonu) düzen bozulmasın.
        // Arapça: Naskh x-yüksekliği küçük olduğundan metinler biraz büyütülür (tasarım incelemesi #24).
        builder: (context, child) {
          final c = child ?? const SizedBox.shrink();
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: clampedTextScaler(mq.textScaler, arabic: st.lang == 'ar')),
            child: c,
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}
