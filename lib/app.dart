import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/catalog.dart';
import 'l10n/strings.dart';
import 'notify/reminder_nav.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

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
        // Arapça: Naskh x-yüksekliği küçük olduğundan metinler biraz büyütülür (tasarım incelemesi #24).
        builder: (context, child) {
          final c = child ?? const SizedBox.shrink();
          if (st.lang != 'ar') return c;
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(100) / 100 * kArabicTextScale)),
            child: c,
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}
