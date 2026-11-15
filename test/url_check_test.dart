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

  test('alan bırakılınca https:// eklenir (UX #15); başka şemaya dokunulmaz', () {
    expect(withHttps('youtube.com/live/abc'), 'https://youtube.com/live/abc');
    expect(withHttps(' www.youtube.com/watch?v=1 '), 'https://www.youtube.com/watch?v=1');
    expect(withHttps('youtu.be:443/x'), 'https://youtu.be:443/x');
    expect(withHttps('http://zoom.us/j/1'), 'https://zoom.us/j/1');
    expect(withHttps('//meet.google.com/a'), 'https://meet.google.com/a');
    expect(withHttps('https://youtu.be/a'), 'https://youtu.be/a');
    expect(withHttps('javascript:alert(1)'), 'javascript:alert(1)');
    expect(withHttps('ftp://x.com/a'), 'ftp://x.com/a');
    expect(withHttps('canli yayin'), 'canli yayin');
    expect(withHttps('localhost/x'), 'localhost/x');
    expect(withHttps(''), '');
    expect(isValidLiveUrl(withHttps('youtube.com/live/abc')), isTrue);
    expect(isValidLiveUrl(withHttps('javascript:alert(1)')), isFalse);
  });
}
