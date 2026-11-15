import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../models/invitation.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'ornament.dart';

/// Davetli sayfasının uygulama içi önizlemesi.
/// assets/invite/invite.html (tek kaynak) yüklenir; veri window.renderInvite(json) ile verilir.
/// Dış bağlantılar (harita, takvim, WhatsApp) cihazın kendi uygulamasında açılır.
class InviteView extends StatefulWidget {
  const InviteView({super.key, required this.inv});

  final Invitation inv;

  @override
  State<InviteView> createState() => _InviteViewState();
}

class _InviteViewState extends State<InviteView> {
  late final WebViewController _c;
  bool _rendered = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final bg = (kThemes[widget.inv.theme] ?? kThemes['papatya']!).colors.bg;
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(bg)
      ..addJavaScriptChannel('ZarflaApp', onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _push(),
        onNavigationRequest: _onNav,
      ))
      ..loadFlutterAsset('assets/invite/invite.html');
  }

  void _onJsMessage(JavaScriptMessage m) {
    if (!mounted) return;
    if (m.message == 'rendered') {
      setState(() => _rendered = true);
    } else if (m.message.startsWith('error')) {
      setState(() => _failed = true);
    }
  }

  NavigationDecision _onNav(NavigationRequest req) {
    final u = Uri.tryParse(req.url);
    if (u == null) return NavigationDecision.prevent;
    if (u.scheme == 'file' || u.scheme == 'about' || u.scheme == 'data') {
      return NavigationDecision.navigate;
    }
    if (u.scheme == 'https' || u.scheme == 'http' || u.scheme == 'mailto' || u.scheme == 'tel') {
      launchUrl(u, mode: LaunchMode.externalApplication);
    }
    return NavigationDecision.prevent;
  }

  Future<void> _push() async {
    try {
      final data = await context.read<AppState>().inviteData(widget.inv);
      await _c.runJavaScript('window.renderInvite(${jsonEncode(data)});');
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _c),
        if (!_rendered && !_failed)
          Center(child: ZLoader(size: 40, label: context.t('loading'))),
        // Tasarım incelemesi #20c: hata = süs + 2 satır metin + "Tekrar dene".
        if (_failed)
          ColoredBox(
            color: AppColors.bg,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Ornament((kThemes[widget.inv.theme] ?? kThemes['papatya']!).orn, size: 56),
                    const SizedBox(height: AppSpace.x3),
                    Text(context.t('previewLoadErr'), textAlign: TextAlign.center, style: bodyStyle(15, weight: FontWeight.w600)),
                    const SizedBox(height: AppSpace.x1),
                    Text(context.t('tryAgainHint'), textAlign: TextAlign.center, style: bodyStyle(13.5, color: AppColors.muted, height: 1.45)),
                    const SizedBox(height: AppSpace.x4),
                    GhostButton(
                      label: context.t('retry'),
                      icon: const ZGlyph(ZGlyphs.retry, size: 18),
                      onPressed: () {
                        setState(() {
                          _failed = false;
                          _rendered = false;
                        });
                        _c.loadFlutterAsset('assets/invite/invite.html');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
