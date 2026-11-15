import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_config.dart';
import '../ads/ad_service.dart';

/// Banner reklam: uyarlanabilir (adaptive) sabit-alt (anchored) banner.
/// Yalnız Davetiyelerim ve Tasarım galerisinde; ödeme yapmış kullanıcıda gösterilmez.
/// Rıza alınmadan (AdService.ready) istek yapılmaz; reklam yüklenmezse yer kaplamaz.
class AdSlot extends StatefulWidget {
  const AdSlot({super.key});

  @override
  State<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends State<AdSlot> {
  BannerAd? _ad;
  AdSize? _size;
  int _loadedWidth = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    AdService.ready.addListener(_maybeLoad);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  @override
  void dispose() {
    AdService.ready.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _maybeLoad() async {
    if (!mounted || _loading || !AdService.supported || !AdService.ready.value) return;
    // Liste kenar boşlukları: 16 + 16.
    final width = (MediaQuery.of(context).size.width - 32).truncate();
    if (width <= 0 || (_ad != null && width == _loadedWidth)) return;
    _loading = true;
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) return;
    if (size == null) {
      _loading = false;
      return;
    }
    final old = _ad;
    final ad = BannerAd(
      adUnitId: kBannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (!mounted) {
            loaded.dispose();
            return;
          }
          setState(() {
            _ad = loaded as BannerAd;
            _size = size;
            _loadedWidth = width;
            _loading = false;
          });
          old?.dispose();
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          if (mounted) setState(() => _loading = false);
        },
      ),
    );
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final size = _size;
    if (ad == null || size == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 4),
      alignment: Alignment.center,
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
