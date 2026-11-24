import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zarfla/app.dart';
import 'package:zarfla/billing/billing_service.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/l10n/strings.dart';
import 'package:zarfla/models/invitation.dart';
import 'package:zarfla/notify/reminder_nav.dart';
import 'package:zarfla/notify/reminder_ui.dart';
import 'package:zarfla/screens/done_screen.dart';
import 'package:zarfla/screens/editor_screen.dart';
import 'package:zarfla/screens/home_screen.dart';
import 'package:zarfla/screens/publish_screen.dart';
import 'package:zarfla/screens/theme_screen.dart';
import 'package:zarfla/screens/type_screen.dart';
import 'package:zarfla/state/app_state.dart';
import 'package:zarfla/theme/app_theme.dart' show kArabicTextScale;
import 'package:zarfla/storage/invitation_store.dart';
import 'package:zarfla/storage/photo_store.dart';

/// Büyük sistem yazı boyutu (sahibinin telefonu) ve dar ekranda düzen taşması olmamalı:
/// ana ekranlar 320 px genişlikte, metin ölçeği 1.3 (ve sistem 2.0 iken uygulama sınırı 1.3'e çeker),
/// en uzun dillerde (de, pt, es, id) ve Arapça (sağdan sola) için sınanır. "overflowed" hatası = başarısızlık.
class _FakeBilling extends BillingService {
  @override
  String? get price => '₺479,99';
  @override
  String? get bundlePrice => '₺1.099,99';
  @override
  double? get singleRaw => 479.99;
  @override
  double? get bundleRaw => 1099.99;
  @override
  String? get singleCurrency => 'TRY';
  @override
  String? get bundleCurrency => 'TRY';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Gerçek yazı tipleri (yoksa Ahem: her harf 1 em genişliğinde, sahte taşma üretir). CI'da fetch_fonts.sh çalışır.
    Future<void> load(String family, List<String> files) async {
      final fl = FontLoader(family);
      var any = false;
      for (final f in files) {
        final file = File('assets/fonts/$f');
        if (file.existsSync()) {
          any = true;
          final bytes = file.readAsBytesSync();
          fl.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
        }
      }
      if (any) await fl.load();
    }

    await load('Manrope', ['Manrope.ttf']);
    await load('Fraunces', ['Fraunces.ttf']);
    await load('NotoNaskhArabic', ['NotoNaskhArabic.ttf']);
    await load('Amiri', ['Amiri-Regular.ttf']);
  });

  AppStrings arbStrings() => AppStrings({
        for (final l in kLangs) l: AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync()),
      });

  Invitation sample(String id, String type, String lang, {bool live = false}) {
    final inv = Invitation.create(id: id, type: type, lang: lang, now: 1760000000000)
      ..n1 = 'Alexandra'
      ..n2 = 'Maximilian'
      ..date = '2027-06-12'
      ..time = '19:00'
      ..venue = 'Bosphorus Garden'
      ..theme = 'avize';
    if (live) {
      inv
        ..status = 'live'
        ..plan = 'free'
        ..cloudId = 'AbCdEf123456'
        ..expiresAt = DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch;
    }
    return inv;
  }

  Future<AppState> makeState(String lang) async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState(strings: arbStrings(), store: InvitationStore(), photos: PhotoStore(), billing: _FakeBilling());
    st.lang = lang;
    st.invitations
      ..add(sample('d1', 'dugun', lang))
      ..add(sample('l1', 'nisan', lang, live: true))
      ..add(sample('b1', 'dogum', lang)..n2 = '');
    return st;
  }

  Future<void> pumpApp(WidgetTester t, AppState st, {double sysScale = 1.3, double width = 320, double height = 640}) async {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = sysScale;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearAllTestValues);
    await t.pumpWidget(ChangeNotifierProvider<AppState>.value(value: st, child: const ZarflaApp()));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> open(WidgetTester t, Widget screen) async {
    zarflaNavKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }

  /// Kaydırılabilir ana listeyi uçtan uca gezer (görünmeyen alt bölümler de kurulup ölçülsün).
  Future<void> scrollThrough(WidgetTester t, {int steps = 14}) async {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    for (var i = 0; i < steps; i++) {
      await t.drag(scrollables.first, const Offset(0, -380), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 60));
    }
  }

  /// [body] içinde ortaya çıkan "overflowed" hataları toplar; diğer (eklenti vb.) hatalar yok sayılır.
  Future<List<String>> collectOverflows(Future<void> Function() body) async {
    final old = FlutterError.onError;
    final overflows = <String>[];
    FlutterError.onError = (d) {
      final s = d.exceptionAsString();
      if (s.contains('overflowed')) {
        final deep = d.toStringDeep().split('\n').where((l) => l.contains('lib/') || l.contains('overflowed') || l.contains('creator') || l.contains('Row') || l.contains('Column')).take(12).join(' | ');
        overflows.add('${s.split('\n').first} :: $deep');
      }
    };
    try {
      await body();
    } finally {
      FlutterError.onError = old;
    }
    return overflows;
  }

  const langs = ['tr', 'de', 'pt', 'es', 'id', 'ar'];

  test('metin ölçeği sınırı: 1.0–1.3 (Arapça ayrıca ×1.08)', () {
    expect(clampedTextScaler(const TextScaler.linear(2.0)).scale(10), closeTo(13, 1e-6));
    expect(clampedTextScaler(const TextScaler.linear(0.8)).scale(10), closeTo(10, 1e-6));
    expect(clampedTextScaler(const TextScaler.linear(1.15)).scale(10), closeTo(11.5, 1e-6));
    expect(clampedTextScaler(const TextScaler.linear(2.0), arabic: true).scale(10), closeTo(13 * kArabicTextScale, 1e-6));
  });

  for (final lang in langs) {
    group('taşma yok · $lang · 320 px · ölçek 1.3', () {
      testWidgets('ana ekran (liste + hatırlatma)', (t) async {
        final st = await makeState(lang);
        final o = await collectOverflows(() async {
          await pumpApp(t, st);
          expect(find.byType(HomeScreen), findsOneWidget);
          await scrollThrough(t, steps: 4);
        });
        expect(o, isEmpty, reason: o.join('\n'));
      });

      testWidgets('etkinlik türü + tasarım galerisi', (t) async {
        final st = await makeState(lang);
        final o = await collectOverflows(() async {
          await pumpApp(t, st);
          await open(t, const TypeScreen());
          expect(find.byType(TypeScreen), findsOneWidget);
          await scrollThrough(t, steps: 6);
          await open(t, ThemeScreen(draft: st.createDraft('dugun')));
          expect(find.byType(ThemeScreen), findsOneWidget);
          await scrollThrough(t, steps: 10);
        });
        expect(o, isEmpty, reason: o.join('\n'));
      });

      testWidgets('editör: adım sekmeleri + tüm bölümler (çift isimli, ücretli tasarım)', (t) async {
        final st = await makeState(lang);
        final o = await collectOverflows(() async {
          await pumpApp(t, st);
          await open(t, const EditorScreen(invId: 'd1'));
          expect(find.byType(EditorScreen), findsOneWidget);
          await scrollThrough(t, steps: 22);
        });
        expect(o, isEmpty, reason: o.join('\n'));
      });

      testWidgets('editör: tek isimli tür', (t) async {
        final st = await makeState(lang);
        final o = await collectOverflows(() async {
          await pumpApp(t, st);
          await open(t, const EditorScreen(invId: 'b1'));
          await scrollThrough(t, steps: 8);
        });
        expect(o, isEmpty, reason: o.join('\n'));
      });

      testWidgets('yayın / ödeme ekranı (3\'lü paket kartı dahil)', (t) async {
        final st = await makeState(lang);
        final o = await collectOverflows(() async {
          await pumpApp(t, st);
          await open(t, const PublishScreen(invId: 'd1'));
          expect(find.byType(PublishScreen), findsOneWidget);
          await scrollThrough(t, steps: 8);
        });
        expect(o, isEmpty, reason: o.join('\n'));
      });

      testWidgets('yayında ekranı', (t) async {
        final st = await makeState(lang);
        final o = await collectOverflows(() async {
          await pumpApp(t, st);
          await open(t, const DoneScreen(invId: 'l1'));
          expect(find.byType(DoneScreen), findsOneWidget);
          await scrollThrough(t, steps: 8);
        });
        expect(o, isEmpty, reason: o.join('\n'));
      });
    });
  }

  for (final lang in ['tr', 'de']) {
    testWidgets('sistem ölçeği 2.0 iken de taşma yok (uygulama 1.3\'e sıkıştırır) · $lang', (t) async {
      final st = await makeState(lang);
      final o = await collectOverflows(() async {
        await pumpApp(t, st, sysScale: 2.0);
        final ctx = t.element(find.byType(HomeScreen));
        expect(MediaQuery.textScalerOf(ctx).scale(100), closeTo(130, 1e-6));
        await open(t, const EditorScreen(invId: 'd1'));
        await scrollThrough(t, steps: 22);
      });
      expect(o, isEmpty, reason: o.join('\n'));
    });
  }

  testWidgets('hatırlatma ayar penceresi 320 px, ölçek 1.3, de', (t) async {
    final st = await makeState('de');
    final o = await collectOverflows(() async {
      await pumpApp(t, st);
      final ctx = zarflaNavKey.currentContext!;
      showReminderSettings(ctx);
      await t.pump(const Duration(milliseconds: 400));
    });
    expect(o, isEmpty, reason: o.join('\n'));
  });
}
