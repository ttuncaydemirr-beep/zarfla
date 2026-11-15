import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/logic/progress.dart';
import 'package:zarfla/models/invitation.dart';

Invitation _inv(String type) => Invitation.create(id: 'p1', type: type, lang: 'tr', now: 0);

void main() {
  final today = DateTime(2026, 11, 15);

  test('tamamlanma: zorunlu 4 bilgiye göre yüzde ve eksikler (UX fikir 4)', () {
    final inv = _inv('dugun');
    expect(readyPercent(inv, today: today), 0);
    expect(missingRequired(inv, today: today), ['names', 'date', 'venue', 'wa']);
    inv
      ..n1 = 'Test A'
      ..n2 = 'Test B'
      ..date = '2027-01-10';
    expect(readyPercent(inv, today: today), 50);
    inv.venue = 'Salon';
    expect(missingRequired(inv, today: today), ['wa']);
    expect(readyPercent(inv, today: today), 75);
    inv.wa = '905321234567';
    expect(readyPercent(inv, today: today), 100);
    // Geçmiş tarih "tarih eksik" sayılır.
    inv.date = '2025-01-10';
    expect(missingRequired(inv, today: today), ['date']);
  });

  test('örnek program: çiftlerde karşılama/yemek/pasta, diğerlerinde karşılama/program/ikram', () {
    expect(sampleProgramFor('dugun').map((s) => s.key), ['progExWelcome', 'progExDinner', 'progExCake']);
    expect(sampleProgramFor('dogum').map((s) => s.key), ['progExWelcome', 'progExMain', 'progExTreat']);
    expect(addMinutesHm('19:00', 60), '20:00');
    expect(addMinutesHm('23:30', 90), '01:00');
    expect(addMinutesHm('', 30), '19:30');
  });

  test('etkinliğe kalan gün ve hatırlatma önerisi (yalnız yayındaki, süresi dolmamış davetiyede)', () {
    expect(daysUntil('2026-11-18', today), 3);
    expect(daysUntil('2026-11-15', today), 0);
    expect(daysUntil('2026-11-14', today), -1);
    expect(daysUntil('', today), isNull);
    final inv = _inv('dugun')..date = '2026-11-20';
    expect(shouldSuggestReminder(inv, today), isFalse); // taslak
    inv
      ..status = 'live'
      ..plan = 'premium'
      ..expiresAt = DateTime(2027, 11, 15).millisecondsSinceEpoch;
    expect(shouldSuggestReminder(inv, today), isTrue);
    inv.date = '2026-12-20';
    expect(shouldSuggestReminder(inv, today), isFalse); // 7 günden uzak
    inv
      ..date = '2026-11-20'
      ..expiresAt = DateTime(2026, 11, 1).millisecondsSinceEpoch;
    expect(shouldSuggestReminder(inv, today), isFalse); // süresi dolmuş
  });
}
