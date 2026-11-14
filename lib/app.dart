import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/catalog.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class ZarflaApp extends StatelessWidget {
  const ZarflaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return MaterialApp(
      title: 'Zarfla',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: Locale(st.lang),
      supportedLocales: [for (final l in kLangs) Locale(l)],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
