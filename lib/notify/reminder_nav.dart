import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/editor_screen.dart';
import '../state/app_state.dart';
import 'reminder_logic.dart';

/// Uygulamanın kök gezgin anahtarı (MaterialApp.navigatorKey): bildirime dokunma ve izin penceresi için.
final GlobalKey<NavigatorState> zarflaNavKey = GlobalKey<NavigatorState>(debugLabel: 'zarfla');

/// Bildirime dokunulunca ilgili davetiyenin düzenleyicisini açar.
/// - süre hatırlatması: ücretsiz yayındaki davetiyenin düzenleyicisi; en üstteki "1 yıla çıkar" kartı ödeme akışını başlatır
///   (yayınla/ödeme ekranı yayındaki davetiyeye uygun olmadığından mevcut yükseltme yüzeyi kullanılır),
/// - taslak hatırlatması: taslağın düzenleyicisi.
/// Davetiye artık yoksa (silinmiş) bir şey açılmaz. Uygulama bildirimle soğuk açılıyorsa gezgin hazır olana kadar
/// kısa aralıklarla yeniden denenir.
void openFromReminder(ReminderPayload payload, {int attempt = 0}) {
  final nav = zarflaNavKey.currentState;
  final ctx = zarflaNavKey.currentContext;
  if (nav == null || ctx == null) {
    if (attempt < 20) {
      Future<void>.delayed(const Duration(milliseconds: 500), () => openFromReminder(payload, attempt: attempt + 1));
    }
    return;
  }
  final st = Provider.of<AppState>(ctx, listen: false);
  if (st.byId(payload.invId) == null || st.isHidden(payload.invId)) return;
  nav.push(MaterialPageRoute<void>(builder: (_) => EditorScreen(invId: payload.invId)));
}
