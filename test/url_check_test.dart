import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/logic/url_check.dart';

void main() {
  test('https bağlantıları kabul edilir', () {
    for (final u in [
      'https://www.youtube.com/watch?v=abc123',
      'https://youtu.be/abc',
      'https://www.instagram.com/live/xyz/',
      'https://zoom.us/j/123456789?pwd=abcDEF',
      'https://meet.google.com/abc-defg-hij',
      'https://www.tiktok.com/@kullanici/live',
      'https://fb.watch/abc/',
    ]) {
      expect(isValidLiveUrl(u), isTrue, reason: u);
    }
    expect(cleanLiveUrl('  https://youtu.be/abc  '), 'https://youtu.be/abc');
  });

  test('https dışı, tehlikeli ve bozuk bağlantılar reddedilir', () {
    for (final u in [
      '',
      'http://youtu.be/abc',
      'javascript:alert(1)',
      'JAVASCRIPT:alert(1)',
      'data:text/html,<script>alert(1)</script>',
      'ftp://x.com/a',
      '//youtu.be/abc',
      'youtu.be/abc',
      'https://',
      'https://localhost/a',
      'https://user:pass@youtu.be/abc',
      'https://youtu.be/a b',
      'https://youtu.be/a"onclick="x',
      'https://youtu.be/<script>',
      'https://youtu.be/a\\b',
      'https://youtu.be/\u0000',
    ]) {
      expect(isValidLiveUrl(u), isFalse, reason: u);
    }
  });

  test('en çok 300 karakter', () {
    final base = 'https://youtu.be/';
    expect(isValidLiveUrl(base + 'a' * (300 - base.length)), isTrue);
    expect(isValidLiveUrl(base + 'a' * (301 - base.length)), isFalse);
  });
}
