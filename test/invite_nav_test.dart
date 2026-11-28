import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/widgets/invite_view.dart';

void main() {
  InviteNav nav(String s) => inviteNavAction(Uri.tryParse(s));

  test('yerel davetiye sayfası WebView içinde kalır', () {
    expect(nav('file:///android_asset/flutter_assets/assets/invite/invite.html'), InviteNav.stay);
    expect(nav('about:blank'), InviteNav.stay);
  });

  test('dış bağlantılar cihaz uygulamasında açılır', () {
    expect(nav('https://wa.me/905321234567?text=x'), InviteNav.external);
    expect(nav('https://calendar.google.com/calendar/render?action=TEMPLATE'), InviteNav.external);
    expect(nav('http://example.com'), InviteNav.external);
    expect(nav('mailto:a@b.co'), InviteNav.external);
    expect(nav('tel:+905321234567'), InviteNav.external);
  });

  test('data:, javascript: ve bilinmeyen şemalar engellenir (denetim D-1)', () {
    expect(nav('data:text/html,<script>alert(1)</script>'), InviteNav.block);
    expect(nav('DATA:text/html;base64,PGgxPg=='), InviteNav.block);
    expect(nav('javascript:alert(1)'), InviteNav.block);
    expect(nav('intent://scan#Intent;scheme=zxing;end'), InviteNav.block);
    expect(inviteNavAction(null), InviteNav.block);
  });
}
