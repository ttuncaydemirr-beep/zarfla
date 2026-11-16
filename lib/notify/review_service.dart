import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'review_logic.dart';

/// Uygulama içi değerlendirme istemi (Google Play sistem penceresi). Hiçbir ekran/düğme bağlanmaz.
/// Ödeme/paylaşım ekranları yalnız [onShare] ve [onPaidPublish] olaylarını bildirir; karar [shouldPromptReview]'dadır.
class ReviewPrompter with WidgetsBindingObserver {
  ReviewPrompter({int Function()? now}) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  static final ReviewPrompter instance = ReviewPrompter();

  static const _kFirst = 'zarfla_review_first_ms';
  static const _kLast = 'zarfla_review_last_ms';
  static const _kShares = 'zarfla_review_shares';

  final int Function() _now;
  bool _started = false;
  int? _first;
  int? _last;
  int _shares = 0;
  bool _paidThisSession = false;
  bool _afterShare = false;
  bool _busy = false;

  /// İlk açılış zamanını kaydeder, yaşam döngüsünü dinler. Hata olursa sessizce devre dışı kalır.
  Future<void> start() async {
    if (_started) return;
    try {
      final p = await SharedPreferences.getInstance();
      _first = p.getInt(_kFirst);
      if (_first == null) {
        _first = _now();
        await p.setInt(_kFirst, _first!);
      }
      _last = p.getInt(_kLast);
      _shares = p.getInt(_kShares) ?? 0;
      WidgetsBinding.instance.addObserver(this);
      _started = true;
    } catch (e) {
      debugPrint('zarfla: review start failed: $e');
    }
  }

  /// Davetiye WhatsApp ile paylaşıldı (WhatsApp açıldı). Kullanıcı uygulamaya dönünce değerlendirilir.
  void onShare() {
    if (!_started) return;
    _shares++;
    _afterShare = true;
    unawaited(_save(_kShares, _shares));
  }

  /// Ücretli yayın ya da yükseltme başarılı (kutlama ekranı açıldı).
  void onPaidPublish() {
    if (!_started) return;
    _paidThisSession = true;
    unawaited(Future<void>.delayed(const Duration(seconds: 3), _maybePrompt));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _afterShare) {
      _afterShare = false;
      unawaited(Future<void>.delayed(const Duration(seconds: 1), _maybePrompt));
    }
  }

  Future<void> _save(String key, int v) async {
    try {
      await (await SharedPreferences.getInstance()).setInt(key, v);
    } catch (_) {}
  }

  Future<void> _maybePrompt() async {
    if (!_started || _busy) return;
    // Yalnız uygulama ön plandayken (arka planda istek anlamsız ve kotayı harcar).
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    final now = _now();
    if (!shouldPromptReview(nowMs: now, firstLaunchMs: _first, lastPromptMs: _last, shareCount: _shares, paidPublish: _paidThisSession)) {
      return;
    }
    _busy = true;
    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      // Pencere gösterilsin ya da Play kotası yüzünden gösterilmesin, 90 günlük sayaç başlar (sık deneme yok).
      _last = now;
      _paidThisSession = false;
      await _save(_kLast, now);
      await review.requestReview();
    } catch (e) {
      debugPrint('zarfla: in-app review failed: $e');
    } finally {
      _busy = false;
    }
  }
}
