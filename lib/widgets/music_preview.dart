import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../cloud/invite_contract.dart' show kGuestHostUrl;

/// Editörde parça önizlemesi için hafif oynatıcı: yeni ses paketi eklemek yerine zaten kullanılan
/// webview_flutter içinde gizli bir <audio> öğesi. Sayfa sitemizin adresiyle yüklenir (ses dosyaları aynı kökten).
/// Android'de WebView varsayılan olarak "kullanıcı hareketi" ister; çalma Flutter düğmesiyle başladığı için
/// bu gereksinim yalnız bu gizli WebView'de kapatılır (davetli sayfasının kendisi etkilenmez).
class MusicPreviewPlayer extends ChangeNotifier {
  WebViewController? _c;
  bool _ready = false;
  bool _disposed = false;
  String? _pendingUrl;

  /// Şu an çalan parça kimliği (yoksa null).
  String? playingId;

  /// Son çalma denemesi başarısız oldu mu (ağ yok vb.).
  bool failed = false;

  static const String _html = '''<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>
<audio id="a" preload="none"></audio>
<script>
const a=document.getElementById("a");
function post(m){try{ZarflaMusic.postMessage(m)}catch(e){}}
function zPlay(u){a.pause();a.src=u;a.currentTime=0;a.volume=.7;const p=a.play();if(p&&p.catch)p.catch(()=>post("err"));}
function zStop(){a.pause();a.removeAttribute("src");a.load();}
a.addEventListener("ended",()=>post("ended"));
a.addEventListener("error",()=>{if(a.getAttribute("src"))post("err")});
post("ready");
</script></body></html>''';

  /// Ekranda tutulması gereken 1×1 görünmez WebView (yalnız ilk önizlemeden sonra oluşur).
  WebViewController? get controller => _c;

  void _ensure() {
    if (_c != null) return;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('ZarflaMusic', onMessageReceived: _onMsg)
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (_) => NavigationDecision.prevent));
    final p = c.platform;
    if (p is AndroidWebViewController) {
      p.setMediaPlaybackRequiresUserGesture(false);
    }
    c.loadHtmlString(_html, baseUrl: '$kGuestHostUrl/');
    _c = c;
    notifyListeners();
  }

  void _onMsg(JavaScriptMessage m) {
    if (_disposed) return;
    switch (m.message) {
      case 'ready':
        _ready = true;
        final u = _pendingUrl;
        _pendingUrl = null;
        if (u != null) _run('zPlay(${_js(u)})');
        break;
      case 'ended':
        playingId = null;
        notifyListeners();
        break;
      case 'err':
        playingId = null;
        failed = true;
        notifyListeners();
        break;
    }
  }

  static String _js(String s) => "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

  void _run(String js) {
    _c?.runJavaScript(js).catchError((Object _) {});
  }

  void play(String id, String url) {
    if (_disposed) return;
    _ensure();
    failed = false;
    playingId = id;
    if (_ready) {
      _run('zPlay(${_js(url)})');
    } else {
      _pendingUrl = url;
    }
    notifyListeners();
  }

  void stop() {
    _pendingUrl = null;
    if (playingId == null) return;
    playingId = null;
    if (_ready) _run('zStop()');
    notifyListeners();
  }

  void toggle(String id, String url) => playingId == id ? stop() : play(id, url);

  @override
  void dispose() {
    if (_ready) _run('zStop()');
    _disposed = true;
    super.dispose();
  }
}

/// Oynatıcının WebView'ini ağaçta tutan görünmez kutu (1×1, erişilebilirlik ağacından hariç).
class MusicPreviewHost extends StatelessWidget {
  const MusicPreviewHost({super.key, required this.player});

  final MusicPreviewPlayer player;

  @override
  Widget build(BuildContext context) {
    final c = player.controller;
    if (c == null) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox(width: 1, height: 1, child: WebViewWidget(controller: c)),
      ),
    );
  }
}
