import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/logic/type_order.dart';
import 'package:zarfla/state/app_state.dart' show firstRunLang;

void main() {
  test('her dilde tür listesi katalogla aynı küme; yinelenen yok', () {
    for (final l in kLangs) {
      final order = eventTypesFor(l);
      expect(order.toSet(), kEventTypes.toSet(), reason: l);
      expect(order.length, kEventTypes.length, reason: '$l: yinelenen tür');
    }
  });

  test('tr/en/de/ar katalog sırasını korur', () {
    for (final l in ['tr', 'en', 'de', 'ar']) {
      expect(eventTypesFor(l), kEventTypes, reason: l);
    }
  });

  test('es/pt/id: genel türler üstte, diger sonda', () {
    for (final l in ['es', 'pt', 'id']) {
      final order = eventTypesFor(l);
      expect(order.take(4).toList(), ['dugun', 'nisan', 'dogum', 'baby'], reason: l);
      expect(order.last, 'diger', reason: l);
      expect(order.indexOf('kurumsal'), lessThan(order.indexOf('kina')), reason: l);
      expect(order.indexOf('dogum'), lessThan(order.indexOf('sunnet')), reason: l);
    }
    // Endonezce: nikâh / iftar / sünnet kına ve söz'den önce
    final id = eventTypesFor('id');
    expect(id.indexOf('nikah'), lessThan(id.indexOf('kina')));
    expect(id.indexOf('iftar'), lessThan(id.indexOf('soz')));
  });

  test('ilk açılışta cihaz dili: yalnız es/pt/id otomatik seçilir', () {
    expect(firstRunLang('es'), 'es');
    expect(firstRunLang('PT'), 'pt');
    expect(firstRunLang('id'), 'id');
    expect(firstRunLang('en'), isNull);
    expect(firstRunLang('de'), isNull);
    expect(firstRunLang(null), isNull);
  });
}
