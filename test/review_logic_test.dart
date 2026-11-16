import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/notify/review_logic.dart';

int at(int d, int h) => DateTime.utc(2026, 11, d, h).millisecondsSinceEpoch;
const int hour = 3600 * 1000;

void main() {
  final first = at(1, 10);
  final now = at(17, 12);

  bool ask({int? f, int? last, int shares = 0, bool paid = false, int? n}) => shouldPromptReview(
        nowMs: n ?? now,
        firstLaunchMs: f ?? first,
        lastPromptMs: last,
        shareCount: shares,
        paidPublish: paid,
      );

  test('başarı anı yoksa istenmez: 0-1 paylaşım, ücretli yayın yok', () {
    expect(ask(), isFalse);
    expect(ask(shares: 1), isFalse);
  });

  test('ikinci paylaşım ya da ücretli yayın başarı anıdır', () {
    expect(ask(shares: 2), isTrue);
    expect(ask(shares: 5), isTrue);
    expect(ask(paid: true), isTrue);
  });

  test('ilk açılışın hemen ardından istenmez (en az 1 saat), ilk açılış bilinmiyorsa da istenmez', () {
    expect(ask(paid: true, f: now - 10 * 60 * 1000), isFalse);
    expect(ask(paid: true, f: now - hour), isTrue);
    expect(shouldPromptReview(nowMs: now, firstLaunchMs: null, lastPromptMs: null, shareCount: 9, paidPublish: true), isFalse);
    expect(ask(paid: true, f: now + hour), isFalse); // saat geriye alınmış
  });

  test('90 günde en çok bir kez', () {
    final d = 24 * hour;
    expect(ask(paid: true, last: now - 89 * d), isFalse);
    expect(ask(paid: true, last: now - 90 * d), isTrue);
    expect(ask(paid: true, last: now - 400 * d), isTrue);
    expect(ask(paid: true, last: now + hour), isFalse); // gelecekteki kayıt: güvenli taraf
  });
}
