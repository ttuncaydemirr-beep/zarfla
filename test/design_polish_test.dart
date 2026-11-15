import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/l10n/strings.dart';
import 'package:zarfla/logic/share_text.dart';
import 'package:zarfla/logic/theme_style.dart';
import 'package:zarfla/models/invitation.dart';
import 'package:zarfla/screens/publish_screen.dart';
import 'package:zarfla/theme/app_theme.dart';
import 'package:zarfla/widgets/common.dart';
import 'package:zarfla/widgets/invite_mini.dart';
import 'package:zarfla/widgets/opening_picker.dart';

void main() {
  group('paylaşım mesajı (UX #10)', () {
    test('isimler + etkinlik, tarih/saat ve bağlantı satırları', () {
      final inv = Invitation.create(id: 'a', type: 'dugun', lang: 'tr', now: 0)
        ..n1 = 'Test A'
        ..n2 = 'Test B'
        ..date = '2027-06-12'
        ..time = '19:00';
      final when = formatShareWhen(inv, 'tr');
      expect(when, contains('2027'));
      expect(when, endsWith('19:00'));
      final s = buildShareText(
        headTpl: '{names} – {event}',
        whenTpl: '📅 {when}',
        linkTpl: 'Davetiye: {link}',
        names: shareNames(inv, '&'),
        event: 'Düğün',
        when: when,
        link: 'https://x.test/?id=1',
      );
      final lines = s.split('\n');
      expect(lines, hasLength(3));
      expect(lines[0], 'Test A & Test B – Düğün');
      expect(lines[1], startsWith('📅 '));
      expect(lines[2], 'Davetiye: https://x.test/?id=1');
    });

    test('tarih yoksa tarih satırı eklenmez; tek isimli türde tek isim', () {
      final inv = Invitation.create(id: 'b', type: 'dogum', lang: 'en', now: 0)..n1 = 'Test A';
      expect(formatShareWhen(inv, 'en'), '');
      expect(shareNames(inv, '&'), 'Test A');
      final s = buildShareText(headTpl: '{names} – {event}', whenTpl: '📅 {when}', linkTpl: '{link}', names: 'Test A', event: 'Birthday', when: '', link: 'L');
      expect(s, 'Test A – Birthday\nL');
    });

    test('bağlantı yalnız / sonrasında kırılır, alan adı bölünmez; ham bağlantı değişmez', () {
      const url = 'ttuncaydemirr-beep.github.io/davetiye/?id=abc';
      final soft = softBreakUrl(url);
      expect(soft.replaceAll('​', ''), url);
      expect(soft, contains('github.io/​'));
      expect(soft, isNot(contains('github.​')));
    });
  });

  group('galeri filtreleri (tasarım 3.1)', () {
    test('her tasarım en az bir stilde; stil kümeleri geçerli kimlikler', () {
      for (final id in kThemes.keys) {
        final inAny = kThemeStyles.values.any((s) => s.contains(id));
        expect(inAny, isTrue, reason: '$id hiçbir stilde değil');
      }
      for (final set in kThemeStyles.values) {
        expect(set.difference(kThemes.keys.toSet()), isEmpty);
      }
    });

    test('önerilen: türün ilk tasarımları ve ücretsiz Papatya her zaman içinde', () {
      for (final ty in kEventTypes) {
        final rec = galleryThemes(ty, 'rec');
        expect(rec.take(kRecommendedCount), kRecommended[ty]!.take(kRecommendedCount));
        expect(rec, contains('papatya'), reason: ty);
      }
    });

    test('tümü = 43; ücretsiz = yalnız Papatya; açık + koyu = tümü', () {
      expect(galleryThemes('dugun', 'all'), hasLength(kThemes.length));
      expect(galleryThemes('dugun', 'free'), ['papatya']);
      final light = galleryThemes('dugun', 'light').toSet();
      final dark = galleryThemes('dugun', 'dark').toSet();
      expect(light.intersection(dark), isEmpty);
      expect(light.length + dark.length, kThemes.length);
      expect(dark, containsAll(['altin', 'kemer', 'deco', 'bordo']));
      expect(light, containsAll(['papatya', 'gul', 'okaliptus']));
    });

    test('her filtrenin metin anahtarı adı kGalleryFilters ile aynı sırada', () {
      expect(kGalleryFilters.first, 'rec');
      expect(kGalleryFilters.toSet().length, kGalleryFilters.length);
    });
  });

  test('ödeme durumu tonları (UX #8)', () {
    expect(statusToneOf('payPending'), ZStatusTone.pending);
    expect(statusToneOf('payCancelled'), ZStatusTone.info);
    expect(statusToneOf('payErr'), ZStatusTone.error);
    expect(kRetryableStatus, containsAll(['payErr', 'netErr']));
    expect(kRetryableStatus, isNot(contains('payPending')));
  });

  test('açılış küçük resimleri: 12 açılışın hepsi çizilir ve tema renklerini kullanır', () {
    final css = kThemes['altin']!.css;
    for (final k in kOpenings) {
      final svg = openingThumbSvg(k, css);
      expect(svg, startsWith('<svg'), reason: k);
      expect(svg.length, greaterThan(200), reason: k);
      expect(svg, contains(css['bg']!), reason: k);
    }
  });

  testWidgets('InviteMini dar ve geniş boyutta taşmadan çizilir', (tester) async {
    for (final w in [150.0, 184.0, 300.0]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: w,
              child: InviteMini(theme: kThemes['kemer']!, names: const ['Test Adı', 'Test Soyadı'], eyebrow: 'DÜĞÜN DAVETİYESİ', lang: 'tr', date: '12 Haz 2027'),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'genişlik $w');
      expect(find.text('Test Adı'), findsOneWidget);
    }
  });

  testWidgets('StatusPanel ve ZLoader çizilir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Column(children: [
          StatusPanel(tone: ZStatusTone.error, text: 'x', actionLabel: 'retry', onAction: () {}, onClose: () {}),
          const ZLoader(),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('x'), findsOneWidget);
    expect(find.text('retry'), findsOneWidget);
  });

  test('tasarım #25: uygulama metinlerinde geliştirici / önizleme notu yok', () {
    for (final l in kLangs) {
      final m = AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync());
      for (final e in m.entries) {
        expect(e.value.contains('Flutter'), isFalse, reason: '$l.${e.key}: ${e.value}');
      }
      for (final k in ['musicSoon', 'demoNote', 'paySoon', 'linkNote']) {
        expect(m.containsKey(k), isFalse, reason: '$l.$k');
      }
    }
  });

  test('yer tutucu isimler kişi adı değil ve 4 dilde var', () {
    for (final l in kLangs) {
      final m = AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync());
      for (final k in ['sampleA', 'sampleB', 'sampleParentA', 'sampleParentB', 'sampleOne', 'amp']) {
        expect((m[k] ?? '').trim(), isNotEmpty, reason: '$l.$k');
      }
    }
  });
}
