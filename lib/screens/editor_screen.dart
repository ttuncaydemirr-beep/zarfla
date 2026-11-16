import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud/invite_contract.dart';
import '../data/catalog.dart';
import '../data/countries.dart';
import '../l10n/strings.dart';
import '../logic/date_utils.dart';
import '../logic/iban.dart';
import '../logic/lock_rules.dart';
import '../logic/phone.dart';
import '../logic/progress.dart';
import '../logic/text_utils.dart';
import '../logic/url_check.dart';
import '../logic/validation.dart';
import '../models/invitation.dart';
import '../notify/review_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/invite_view.dart';
import '../widgets/layout_thumb.dart';
import '../widgets/music_picker.dart';
import '../widgets/opening_picker.dart';
import '../widgets/ornament.dart';
import 'done_screen.dart';
import 'publish_screen.dart';
import 'theme_screen.dart';
import 'type_screen.dart';

/// Davetiye editörü: 1 Bilgiler · 2 Önizleme · 3 Yayınla (adım göstergesi).
/// Bilgiler formu sekme değişiminde ağaçta kalır (Offstage): kaydırma konumu ve odak kaybolmaz.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.invId});

  final String invId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int _tab = 0; // 0 = Bilgiler, 1 = Önizleme
  bool _showErr = false;
  int _previewKey = 0;
  bool _cloudBusy = false;
  bool _deleted = false;

  /// Kalıcı işlem hatası kartı (toast yerine): ARB anahtarı + varsa "Tekrar dene".
  String? _actionErr;
  VoidCallback? _actionRetry;

  final GlobalKey<_DetailsFormState> _formKey = GlobalKey<_DetailsFormState>();
  ScaffoldMessengerState? _messenger;
  AppState? _st;
  String _draftSavedMsg = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
    _st = Provider.of<AppState>(context, listen: false);
  }

  @override
  void dispose() {
    // Geri çıkınca "kayboldu mu?" belirsizliği olmasın: taslak için kısa güvence mesajı (silindiyse değil).
    final st = _st, m = _messenger, msg = _draftSavedMsg;
    final inv = st?.byId(widget.invId);
    if (!_deleted && st != null && m != null && inv != null && !inv.isLive && !st.isHidden(inv.id) && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        m
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 3000)));
      });
    }
    super.dispose();
  }

  void _goPreview(int tab) {
    FocusScope.of(context).unfocus();
    setState(() {
      _tab = tab;
      if (tab == 1) _previewKey++;
    });
  }

  /// Sil: onay penceresi → listeden gizle → 5 sn "Geri al" → gerçekten sil (bulut + cihaz).
  Future<void> _delete(Invitation inv) async {
    if (_cloudBusy) return;
    final name = invitationTitle(inv, context.t('untitled'));
    final body = [
      context.t(inv.isLive ? 'delBodyLive' : 'delBodyDraft'),
      if (inv.isLive && inv.plan == 'premium') context.t('delBodyPaid'),
    ].join('\n\n');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('delTitle', {'n': name}), style: headStyle(19, color: AppColors.ink)),
        content: Text(body, style: bodyStyle(14.5, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.t('dlgCancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.err, foregroundColor: AppColors.onPrimary, minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.t('del')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final st = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final msg = context.t('deletedMsg'), undo = context.t('undo');
    final id = inv.id;
    _deleted = true;
    st.hideForDelete(inv);
    Navigator.of(context).pop();
    messenger.hideCurrentSnackBar();
    final ctl = messenger.showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: undo, onPressed: () => st.undoDelete(id)),
    ));
    final reason = await ctl.closed;
    if (reason == SnackBarClosedReason.action) return;
    final err = await st.commitDelete(id);
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(st.t(err)), duration: const Duration(seconds: 6)));
    }
  }

  /// Hata varsa: kalıcı özet bandı + ilk hatalı alana kaydır ve odakla (toast yok).
  bool _checkErrors(Invitation inv) {
    final e = validateInvitation(inv);
    if (e.isEmpty) return true;
    setState(() {
      _showErr = true;
      _tab = 0;
    });
    final k = firstErrorKey(e);
    if (k != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _formKey.currentState?.goToError(k));
    }
    return false;
  }

  void _toPublish(Invitation inv) {
    FocusScope.of(context).unfocus();
    final st = context.read<AppState>();
    if (inv.isLive && st.isExpired(inv) && canUpgradeToPaid(inv)) {
      _upgrade(inv);
      return;
    }
    if (!_checkErrors(inv)) return;
    if (inv.isLive) {
      _pushUpdate(st, inv);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublishScreen(invId: inv.id)));
  }

  void _showActionErr(String key, [VoidCallback? retry]) {
    setState(() {
      _actionErr = key;
      _actionRetry = retry;
    });
  }

  Future<void> _pushUpdate(AppState st, Invitation inv) async {
    if (_cloudBusy) return;
    if (st.isExpired(inv)) {
      _showActionErr('expiredNote');
      return;
    }
    setState(() {
      _cloudBusy = true;
      _actionErr = null;
    });
    final nav = Navigator.of(context);
    final err = await st.pushUpdate(inv);
    if (!mounted) return;
    setState(() => _cloudBusy = false);
    if (err != null) {
      _showActionErr(err, () => _pushUpdate(st, inv));
      return;
    }
    showToast(context, context.t('updated'));
    nav.push(MaterialPageRoute(builder: (_) => DoneScreen(invId: inv.id)));
  }

  /// Ücretsiz (süresi dolmuş ya da dolacak) davetiyeyi "1 Davetiye Hakkı" ile aynı bağlantıda 1 yıla çıkarır.
  /// Mevcut ödeme akışı: Google Play → redeemPurchase (sunucu aynı belgeyi ücretli yazar) → tüketme.
  Future<void> _upgrade(Invitation inv) async {
    if (_cloudBusy || !canUpgradeToPaid(inv)) return;
    if (!_checkErrors(inv)) return;
    final st = context.read<AppState>();
    if (!st.canPayOrUseCredit) {
      _showActionErr('payUnavailable');
      return;
    }
    setState(() {
      _cloudBusy = true;
      _actionErr = null;
    });
    final nav = Navigator.of(context);
    final err = await st.publishPaid(inv);
    if (!mounted) return;
    setState(() => _cloudBusy = false);
    if (inv.plan == 'premium' && (err == null || err == 'paidPhotoErr')) {
      showToast(context, context.t(err ?? 'upgraded'), ms: err == null ? 3000 : 6000);
      nav.push(MaterialPageRoute(builder: (_) => DoneScreen(invId: inv.id)));
      ReviewPrompter.instance.onPaidPublish();
      return;
    }
    final key = err ?? 'payErr';
    final retryable = key == 'netErr' || key == 'payVerifyErr' || key == 'cloudErr';
    _showActionErr(key, retryable ? () => _upgrade(inv) : null);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final inv = st.byId(widget.invId);
    if (inv == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    _draftSavedMsg = context.t('draftSavedBack');
    final expiredFree = inv.isLive && st.isExpired(inv) && canUpgradeToPaid(inv);
    final price = st.playPrice ?? context.t('price');
    final primaryLabel = _cloudBusy
        ? context.t(expiredFree ? 'payProcessing' : 'cloudUpdating')
        : expiredFree
            ? context.t('upExpiredBtn', {'p': st.hasCredit ? context.t('creditOne') : price})
            : (inv.isLive ? context.t('update') : context.t('publish'));
    final errText = _actionErr == null ? null : context.t(_actionErr == 'netErr' ? 'netErrCard' : _actionErr!);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ZTopBar(
              title: invitationTitle(inv, context.t('untitled')),
              leading: const BackBtn(),
              actions: [_MoreMenu(onDelete: () => _delete(inv))],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: _SaveCue(live: inv.isLive),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(child: _StepTab(n: 1, label: context.t('details'), on: _tab == 0, onTap: () => _goPreview(0))),
                  const SizedBox(width: 6),
                  Expanded(child: _StepTab(n: 2, label: context.t('preview'), on: _tab == 1, onTap: () => _goPreview(1))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _StepTab(
                      n: 3,
                      label: inv.isLive ? context.t('update') : context.t('publish'),
                      on: false,
                      onTap: _cloudBusy ? null : () => _toPublish(inv),
                    ),
                  ),
                ],
              ),
            ),
            if (errText != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ActionCard(
                  text: errText,
                  error: true,
                  icon: _actionErr == 'netErr' ? Icons.wifi_off : Icons.error_outline,
                  closeTooltip: context.t('close'),
                  onClose: () => setState(() => _actionErr = null),
                  actions: [
                    if (_actionRetry != null) GhostButton(label: context.t('retry'), onPressed: _cloudBusy ? null : _actionRetry),
                  ],
                ),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Offstage(
                    offstage: _tab != 0,
                    child: TickerMode(
                      enabled: _tab == 0,
                      child: DetailsForm(
                        key: _formKey,
                        inv: inv,
                        showErr: _showErr,
                        busy: _cloudBusy,
                        onUpgrade: () => _upgrade(inv),
                        onPushUpdate: () => _pushUpdate(st, inv),
                      ),
                    ),
                  ),
                  if (_tab == 1)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: InviteView(key: ValueKey('pv$_previewKey'), inv: inv, showSkip: true),
                      ),
                    ),
                ],
              ),
            ),
            // Önizleme/Bilgiler geçişi yukarıdaki 1-2-3 adım sekmelerinde; alt çubukta yalnız ana eylem (tasarım #5).
            ZBottomBar(children: [
              PrimaryButton(
                label: primaryLabel,
                onPressed: _cloudBusy ? null : () => _toPublish(inv),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// "Kaydedildi ✓" göstergesi: her kayıtta 1,5 sn görünür, sonra sabit "Taslak otomatik kaydedilir" notuna döner.
/// Yayındaki davetiyede değişikliklerin davetlilere "Güncelle" ile gittiği hatırlatılır.
class _SaveCue extends StatefulWidget {
  const _SaveCue({required this.live});

  final bool live;

  @override
  State<_SaveCue> createState() => _SaveCueState();
}

class _SaveCueState extends State<_SaveCue> {
  ValueNotifier<int>? _tick;
  Timer? _t;
  bool _flash = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = Provider.of<AppState>(context, listen: false).savedTick;
    if (!identical(n, _tick)) {
      _tick?.removeListener(_onSaved);
      _tick = n..addListener(_onSaved);
    }
  }

  void _onSaved() {
    if (!mounted) return;
    _t?.cancel();
    setState(() => _flash = true);
    _t = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _tick?.removeListener(_onSaved);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failed = Provider.of<AppState>(context, listen: false).lastSaveFailed;
    final String text;
    final Color color;
    final IconData icon;
    if (failed) {
      text = context.t('saveFailCue');
      color = AppColors.err;
      icon = Icons.error_outline;
    } else if (_flash) {
      text = context.t('savedCue');
      color = AppColors.ok;
      icon = Icons.cloud_done_outlined;
    } else {
      text = context.t(widget.live ? 'liveSaveNote' : 'autoSaveNote');
      color = AppColors.muted;
      icon = Icons.save_outlined;
    }
    return Semantics(
      liveRegion: failed,
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(text, key: ValueKey(text), maxLines: 2, style: bodyStyle(12, weight: FontWeight.w500, color: color)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Başlıktaki "⋯" menüsü: silme başlıktaki isimden uzak, menü içinde (yanlış dokunma olmasın).
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: context.t('more'),
      onSelected: (v) {
        if (v == 'del') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'del',
          child: Row(children: [
            const ZGlyph(ZGlyphs.trash, size: 20, color: AppColors.err),
            const SizedBox(width: 10),
            Text(context.t('del'), style: bodyStyle(15, color: AppColors.err)),
          ]),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: const Icon(Icons.more_horiz, size: 22, color: AppColors.ink),
      ),
    );
  }
}

/// Adım sekmesi: numara + etiket. 3. adım (Yayınla) bir düğmedir, seçili olmaz.
class _StepTab extends StatelessWidget {
  const _StepTab({required this.n, required this.label, required this.on, required this.onTap});

  final int n;
  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = on ? AppColors.onPrimary : AppColors.ink;
    return Semantics(
      button: true,
      selected: on,
      label: '${context.t('stepOf', {'n': n})}: $label',
      excludeSemantics: true,
      child: Material(
        color: on ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          side: BorderSide(color: on ? AppColors.primary : AppColors.field),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? AppColors.onPrimary : AppColors.tint,
                  ),
                  child: Text('$n', style: bodyStyle(11.5, weight: FontWeight.w700, color: AppColors.primary)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(14, weight: FontWeight.w600, color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bilgiler sekmesi: zorunlu bilgiler üstte ("Temel bilgiler"), davet metni, katlanır "İsteğe bağlı ayrıntılar".
/// Yayına basınca hata varsa üstte kalıcı özet bandı; ilk hatalı alana kaydırılır ve odaklanılır.
class DetailsForm extends StatefulWidget {
  const DetailsForm({super.key, required this.inv, required this.showErr, this.busy = false, this.onUpgrade, this.onPushUpdate});

  final Invitation inv;
  final bool showErr;
  final bool busy;

  /// Ücretsiz davetiyeyi "1 Davetiye Hakkı" ile 1 yıla çıkar (aynı bağlantı).
  final VoidCallback? onUpgrade;

  /// Yayındaki davetiyeyi buluta yeniden yaz (eksik fotoğraflar için).
  final VoidCallback? onPushUpdate;

  @override
  State<DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends State<DetailsForm> {
  late final TextEditingController _n1, _n2, _host, _msg, _venue, _address, _wa;
  late final TextEditingController _liveUrl, _liveNote, _giftHolder, _giftIban, _giftBank;
  late String _dial; // WhatsApp ülke kodu (artısız); boş = "diğer"
  late final FocusNode _n1Focus, _n2Focus, _venueFocus, _waFocus, _liveFocus, _holderFocus, _ibanFocus;
  final Map<ProgramStep, TextEditingController> _stepCtl = {};
  final List<TextEditingController> _noteCtl = [];
  final _picker = ImagePicker();
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _anchors = {for (final k in kErrorOrder) k: GlobalKey()};
  String? _photoWarn; // ARB anahtarı (dil değişince doğru dilde gösterilir)
  String? _busyKind; // 'cover' | 'gal' : fotoğraf hazırlanırken yer tutucu
  String _lastPhotoKind = 'gal';
  bool _moreOpen = false;
  final Set<String> _touched = {}; // alan bırakılınca doğrulananlar (live, giftHolder, giftIban)
  String? _sugDismissed; // "Hayır, doğru" denilen yerel numara
  bool _devHintDismissed = false;
  String? _deviceCountry;

  Invitation get inv => widget.inv;
  late AppState st;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    st = Provider.of<AppState>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _n1 = TextEditingController(text: inv.n1);
    _n2 = TextEditingController(text: inv.n2);
    _host = TextEditingController(text: inv.host);
    _msg = TextEditingController(text: inv.msg);
    _venue = TextEditingController(text: inv.venue);
    _address = TextEditingController(text: inv.address);
    _deviceCountry = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    final parts = parsePhone(inv.wa, fallbackDial: defaultDial(deviceCountry: _deviceCountry, lang: inv.lang));
    _dial = parts.dial;
    _wa = TextEditingController(text: parts.local);
    // Eski kayıtta başında 0 / artı / boşluk varsa bozuk wa.me bağlantısı olmasın: tek biçime çevir.
    if (inv.wa.isNotEmpty) {
      final composed = composeWa(_dial, parts.local);
      if (composed.isNotEmpty && composed != inv.wa) inv.wa = composed;
      _devHintDismissed = true; // numara zaten kayıtlı: cihaz bölgesi uyarısı gereksiz
    }
    _liveUrl = TextEditingController(text: inv.liveUrl);
    _liveNote = TextEditingController(text: inv.liveNote);
    _giftHolder = TextEditingController(text: inv.giftHolder);
    _giftIban = TextEditingController(text: formatIban(inv.giftIban));
    _giftBank = TextEditingController(text: inv.giftBank);
    for (final n in inv.notes) {
      _noteCtl.add(TextEditingController(text: n));
    }
    _n1Focus = FocusNode()..addListener(() => _onNameFocus(true));
    _n2Focus = FocusNode()..addListener(() => _onNameFocus(false));
    _venueFocus = FocusNode();
    _waFocus = FocusNode();
    _liveFocus = FocusNode()..addListener(_onLiveFocus);
    _holderFocus = FocusNode()..addListener(() => _onBlurTouch(_holderFocus, 'giftHolder'));
    _ibanFocus = FocusNode()..addListener(() => _onBlurTouch(_ibanFocus, 'giftIban'));
    _moreOpen = _hasOptionalContent();
  }

  @override
  void dispose() {
    // Odak kaybında kilitli isim düzeltmesi uygulanır; sayfa kapanırken de uygula.
    if (isLocked(inv)) {
      _commitName(true, silent: true);
      _commitName(false, silent: true);
    }
    for (final c in [_n1, _n2, _host, _msg, _venue, _address, _wa, _liveUrl, _liveNote, _giftHolder, _giftIban, _giftBank, ..._stepCtl.values, ..._noteCtl]) {
      c.dispose();
    }
    for (final f in [_n1Focus, _n2Focus, _venueFocus, _waFocus, _liveFocus, _holderFocus, _ibanFocus]) {
      f.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  /// İsteğe bağlı bölümde içerik var mı? (Varsa bölüm açık başlar: yazılan hiçbir şey gizlenmez.)
  bool _hasOptionalContent() =>
      inv.program.isNotEmpty ||
      inv.notes.isNotEmpty ||
      inv.liveUrl.trim().isNotEmpty ||
      inv.giftIban.trim().isNotEmpty ||
      inv.giftHolder.trim().isNotEmpty ||
      inv.cover.isNotEmpty ||
      inv.photos.isNotEmpty ||
      inv.music.isNotEmpty ||
      inv.layout != 'klasik' ||
      inv.opening != 'door';

  FocusNode? _focusFor(String k) {
    switch (k) {
      case 'names':
        return (inv.n1.trim().isEmpty || !inv.isCouple) ? _n1Focus : _n2Focus;
      case 'venue':
        return _venueFocus;
      case 'wa':
        return _waFocus;
      case 'live':
        return _liveFocus;
      case 'giftHolder':
        return _holderFocus;
      case 'giftIban':
        return _ibanFocus;
    }
    return null; // tarih: seçici alanı; yalnız kaydırılır
  }

  /// Hatalı alana git: (gerekirse isteğe bağlı bölümü aç) kaydır + odakla. Özet bandındaki parçalar da bunu çağırır.
  void goToError(String k) {
    final inOptional = k == 'live' || k.startsWith('gift');
    if (inOptional && !_moreOpen) setState(() => _moreOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _anchors[k]?.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 320), curve: Curves.easeOut, alignment: 0.12);
      }
      final f = _focusFor(k);
      if (f != null && f.canRequestFocus) {
        Future<void>.delayed(const Duration(milliseconds: 340), () {
          if (mounted) f.requestFocus();
        });
      }
    });
  }

  /// Numara alanı: başta +/00 ile yapıştırılan uluslararası numarada ülkeyi seç, başta 0'ı at; saklanan değer yalnız rakamdır.
  void _onWaChanged(String v) {
    final r = normalizeLocalInput(v, _dial);
    if (r.changed) {
      setState(() => _dial = r.parts.dial);
      _wa.value = TextEditingValue(text: r.parts.local, selection: TextSelection.collapsed(offset: r.parts.local.length));
    }
    setState(() {}); // öneri ve canlı önizleme satırı
    _set(() => inv.wa = composeWa(_dial, _wa.text));
  }

  void _setDial(String v) {
    setState(() {
      _dial = v;
      _devHintDismissed = true;
    });
    _set(() => inv.wa = composeWa(_dial, _wa.text));
  }

  Future<void> _pickCountry() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.bg,
      builder: (ctx) => _CountrySheet(lang: st.lang, current: _dial),
    );
    if (v != null && mounted) _setDial(v);
  }

  void _onLiveFocus() {
    if (_liveFocus.hasFocus) return;
    final fixed = withHttps(_liveUrl.text);
    if (fixed != _liveUrl.text) {
      _liveUrl.value = TextEditingValue(text: fixed, selection: TextSelection.collapsed(offset: fixed.length));
      _set(() => inv.liveUrl = fixed);
    }
    if (mounted) setState(() => _touched.add('live'));
  }

  void _onBlurTouch(FocusNode f, String key) {
    if (!f.hasFocus && mounted) setState(() => _touched.add(key));
  }

  void _onNameFocus(bool first) {
    final f = first ? _n1Focus : _n2Focus;
    if (!f.hasFocus && isLocked(inv)) _commitName(first);
  }

  /// Kilitli davetiyede isim düzeltmesini uygula (önizlemedeki "change" olayı).
  void _commitName(bool first, {bool silent = false}) {
    final ctl = first ? _n1 : _n2;
    final old = first ? inv.n1 : inv.n2;
    final oldLeft = inv.nameEditsLeft;
    final r = applyNameEdit(inv, first: first, value: ctl.text);
    switch (r) {
      case EditOutcome.applied:
        st.save(notify: !silent);
        if (!silent) showToast(context, context.t('savedLeft', {'n': inv.nameEditsLeft}), ms: 3000);
        // Ücretli kilit: her düzeltme buluta ayrı yazılır (kural: nameEdits tam +1).
        _syncLocked(() {
          if (first) {
            inv.n1 = old;
          } else {
            inv.n2 = old;
          }
          inv.nameEditsLeft = oldLeft;
          if (!silent && mounted) ctl.text = old;
        });
        break;
      case EditOutcome.unchanged:
        break;
      case EditOutcome.noRightsLeft:
        ctl.text = old;
        if (!silent) showToast(context, context.t('namesNone'), ms: 3000);
        break;
      case EditOutcome.empty:
      case EditOutcome.outOfRange:
        ctl.text = old;
        if (!silent) showToast(context, context.t(inv.isCouple ? 'reqNames' : 'reqName'), ms: 3000);
        break;
    }
  }

  /// Yayındaki ücretli davetiyede kilitli düzeltmeyi hemen buluta yazar; olmazsa geri alır.
  Future<void> _syncLocked(void Function() revert) async {
    if (!inv.isLive || inv.cloudId == null) return;
    final err = await st.pushUpdate(inv);
    if (err == null) return;
    revert();
    await st.save();
    if (mounted) showToast(context, context.t(err), ms: 5000);
  }

  void _set(void Function() f) {
    f();
    st.save();
  }

  // ---- Tarih / saat ----
  Future<void> _pickDate() async {
    final win = dateWindow(inv);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = parseIsoDate(inv.date);
    // Geçmiş tarih seçilemez (bugün olur). Yayındaki ücretli davetiyede ilk tarihin ±60 gün kuralı geçerli.
    DateTime first = today, last = DateTime(now.year + 10, 12, 31);
    if (win != null) {
      final a = parseIsoDate(win.$1)!, b = parseIsoDate(win.$2)!;
      first = DateTime(a.year, a.month, a.day);
      last = DateTime(b.year, b.month, b.day);
    }
    if (last.isBefore(first)) last = first;
    var initial = current == null ? today : DateTime(current.year, current.month, current.day);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked == null || !mounted) return;
    final iso = isoOf(DateTime.utc(picked.year, picked.month, picked.day));
    final oldDate = inv.date, oldLeft = inv.dateEditsLeft, wasLocked = isLocked(inv);
    final r = applyDateEdit(inv, iso);
    switch (r) {
      case EditOutcome.applied:
        await st.save();
        if (wasLocked && mounted) showToast(context, context.t('savedLeft', {'n': inv.dateEditsLeft}), ms: 3000);
        if (wasLocked) {
          await _syncLocked(() {
            inv.date = oldDate;
            inv.dateEditsLeft = oldLeft;
          });
        }
        break;
      case EditOutcome.unchanged:
        break;
      case EditOutcome.noRightsLeft:
        showToast(context, context.t('datesNone'), ms: 3000);
        break;
      case EditOutcome.outOfRange:
      case EditOutcome.empty:
        showToast(context, context.t('dateRange'), ms: 3500);
        break;
    }
  }

  Future<String?> _pickTime(String current) async {
    final hm = parseHm(current);
    final picked = await showTimePicker(
      context: context,
      initialTime: hm == null ? const TimeOfDay(hour: 19, minute: 0) : TimeOfDay(hour: hm.$1, minute: hm.$2),
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return null;
    return formatHm(picked.hour, picked.minute);
  }

  // ---- Fotoğraflar ----
  Future<void> _pickCover() async {
    if (_busyKind != null) return;
    _lastPhotoKind = 'cover';
    XFile? f;
    try {
      f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
    } catch (_) {
      if (mounted) setState(() => _photoWarn = 'photoErr');
      return;
    }
    if (f == null || !mounted) return;
    setState(() {
      _busyKind = 'cover';
      _photoWarn = null;
    });
    String? err;
    try {
      final Uint8List bytes = await f.readAsBytes();
      err = await st.setCover(inv, bytes);
    } catch (_) {
      err = 'photoErr';
    }
    if (!mounted) return;
    setState(() {
      _busyKind = null;
      _photoWarn = err;
    });
  }

  Future<void> _pickGallery() async {
    if (_busyKind != null) return;
    _lastPhotoKind = 'gal';
    if (inv.photos.length >= kMaxGallery) {
      showToast(context, context.t('galFull'));
      return;
    }
    List<XFile> files;
    try {
      files = await _picker.pickMultiImage(maxWidth: 1200, maxHeight: 1200, imageQuality: 82);
    } catch (_) {
      if (mounted) setState(() => _photoWarn = 'photoErr');
      return;
    }
    if (files.isEmpty || !mounted) return;
    setState(() {
      _busyKind = 'gal';
      _photoWarn = null;
    });
    final room = kMaxGallery - inv.photos.length;
    String? warn;
    try {
      final list = <Uint8List>[];
      for (final f in files.take(room)) {
        list.add(await f.readAsBytes());
      }
      warn = await st.addPhotos(inv, list);
    } catch (_) {
      warn = 'photoErr';
    }
    if (files.length > room && warn == null) warn = 'galFull';
    if (!mounted) return;
    setState(() {
      _busyKind = null;
      _photoWarn = warn;
    });
  }

  /// Not denetleyicilerini inv.notes ile aynı uzunlukta tutar (satır başına bir denetleyici).
  void _syncNoteCtl() {
    while (_noteCtl.length < inv.notes.length) {
      _noteCtl.add(TextEditingController(text: inv.notes[_noteCtl.length]));
    }
    while (_noteCtl.length > inv.notes.length) {
      final c = _noteCtl.removeLast();
      WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
    }
  }

  void _addNote([String text = '']) {
    if (inv.notes.length >= kMaxNotes) return;
    _set(() {
      inv.notes.add(text);
      _noteCtl.add(TextEditingController(text: text));
    });
  }

  /// Hazır not: önce boş bir satırı doldurur, boş satır yoksa yeni satır ekler (yazılan not ezilmez).
  void _useNoteSuggestion(String m) {
    final e = inv.notes.indexOf('');
    if (e >= 0 && e < _noteCtl.length) {
      _set(() => inv.notes[e] = m);
      _noteCtl[e].text = m;
    } else {
      _addNote(m);
    }
  }

  /// Hazır davet metni: kullanıcının kendi yazdığı metnin yerine geçerse "Geri al" sunulur (veri kaybı hissi olmasın).
  void _useMessage(String m, List<String> presets) {
    final prev = inv.msg;
    if (prev == m) return;
    setState(() {});
    _set(() => inv.msg = m);
    _msg.text = m;
    final custom = prev.trim().isNotEmpty && !presets.contains(prev);
    if (!custom) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.t('msgReplaced')),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: context.t('undo'),
          onPressed: () {
            if (!mounted) return;
            _set(() => inv.msg = prev);
            _msg.text = prev;
          },
        ),
      ));
  }

  void _addSampleProgram() {
    final base = inv.time.isEmpty ? '19:00' : inv.time;
    _set(() {
      for (final s in sampleProgramFor(inv.type)) {
        if (inv.program.length >= kMaxSteps) break;
        inv.program.add(ProgramStep(t: addMinutesHm(base, s.offsetMin), x: context.tIn(inv.lang, s.key)));
      }
    });
    setState(() {});
  }

  Future<void> _sendReminder() async {
    final cid = inv.cloudId;
    if (cid == null) return;
    final couple = inv.isCouple;
    final who = couple ? '${inv.n1.trim()} & ${inv.n2.trim()}' : inv.n1.trim();
    final e = '$who · ${context.tIn(inv.lang, 'eyebrow_${inv.type}')}';
    final text = context.tIn(inv.lang, 'remindText', {
      'e': e,
      'd': formatShortDate(inv.date, inv.lang),
      't': inv.time,
      'l': inviteUrl(cid),
    });
    await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  }

  TextEditingController _ctlFor(ProgramStep s) => _stepCtl.putIfAbsent(s, () => TextEditingController(text: s.x));

  /// Bölüm başlığı.
  Widget _section(String text, {Widget? trailing}) => Container(
        margin: const EdgeInsets.only(top: 6, bottom: 10),
        padding: const EdgeInsets.only(top: 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(children: [
          Expanded(child: Text(text, style: headStyle(18))),
          if (trailing != null) trailing,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.lang;
    final allErrs = validateInvitation(inv);
    final errs = widget.showErr ? allErrs : const <String, String>{};
    String? err(String k) {
      // Alan bırakılınca doğrulanan alanlar (canlı yayın, IBAN) yayına basılmadan da hatasını gösterir.
      final key = errs[k] ?? (_touched.contains(k) ? allErrs[k] : null);
      return key == null ? null : context.t(key);
    }

    final th = kThemes[inv.theme] ?? kThemes['papatya']!;
    final locked = isLocked(inv);
    final nameRO = locked && inv.nameEditsLeft <= 0;
    final dateRO = locked && inv.dateEditsLeft <= 0;
    final win = dateWindow(inv);
    final msgs = kMessages[inv.lang]?[inv.type] ?? const <String>[];
    _syncNoteCtl();
    final noteSug = kNoteSuggestions[inv.lang] ?? kNoteSuggestions['tr'] ?? const <String>[];
    final reqL = context.t('required');
    final price = app.playPrice ?? context.t('price');

    Widget lockHint(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            const Icon(Icons.lock_outline, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: bodyStyle(12.5, weight: FontWeight.w600, color: AppColors.primary))),
          ]),
        );

    // Tasarım #6: hatalı alanın kendisi ErrorFrame ile çerçevelenir (FieldBlock hatalarıyla aynı görünüm).
    final namesErr = err('names') != null;
    final dateErr = err('date') != null;

    Widget errLine(String? text) => text == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 12),
            child: Semantics(liveRegion: true, child: Text(text, style: bodyStyle(13, color: AppColors.err, height: 1.4))),
          );

    Widget changeBtn(VoidCallback onTap) => locked
        ? GhostButton(
            label: context.t('locked'),
            icon: const Icon(Icons.lock_outline, size: 16),
            dimmed: true,
            onPressed: () => showToast(context, context.t('lockedNote'), ms: 3500),
          )
        : GhostButton(label: context.t('change'), onPressed: onTap);

    Widget nameField(bool first, String label, String ph) => FieldBlock(
          label: label,
          requiredLabel: reqL,
          child: _framed(
            namesErr && (first ? inv.n1 : inv.n2).trim().isEmpty,
            TextField(
            controller: first ? _n1 : _n2,
            focusNode: first ? _n1Focus : _n2Focus,
            readOnly: nameRO,
            // Bulut kuralı: isimlerde " \ ve kontrol karakteri yok (bkz. firestore.rules).
            inputFormatters: [...maxLen(40), FilteringTextInputFormatter.deny(kCloudNameForbidden)],
            textInputAction: TextInputAction.next,
            decoration: fieldDecoration(hint: ph, readOnly: nameRO),
            style: bodyStyle(16),
            onChanged: locked
                ? null
                : (v) => _set(() {
                      if (first) {
                        inv.n1 = v;
                      } else {
                        inv.n2 = v;
                      }
                    }),
            onSubmitted: locked ? (_) => _commitName(first) : null,
            ),
          ),
        );

    final namesLeftText = inv.nameEditsLeft > 0 ? context.t('namesLeft', {'n': inv.nameEditsLeft}) : context.t('namesNone');
    final datesLeftText = inv.dateEditsLeft > 0
        ? context.t('datesLeft', {
            'n': inv.dateEditsLeft,
            'a': win == null ? '' : formatShortDate(win.$1, lang),
            'b': win == null ? '' : formatShortDate(win.$2, lang),
          })
        : context.t('datesNone');

    final expired = app.isExpired(inv);
    final upgradable = canUpgradeToPaid(inv);
    final missingPhotos = inv.isLive && inv.cloudId != null && !expired
        ? [if (inv.cover.isNotEmpty) inv.cover, ...inv.photos].where((p) => !inv.cloudFiles.containsKey(p)).length
        : 0;

    final children = <Widget>[
      // ---- Süre / yükseltme (ücretsiz yayında) ----
      if (upgradable) _upsellCard(expired, price) else if (expired) NoteBox(context.t('expiredNote'), icon: Icons.timer_off_outlined),
      if (missingPhotos > 0)
        ActionCard(
          text: context.t('photoSyncNote'),
          icon: Icons.cloud_upload_outlined,
          actions: [GhostButton(label: context.t('photoSyncBtn'), onPressed: widget.busy ? null : widget.onPushUpdate)],
        ),
      if (shouldSuggestReminder(inv, DateTime.now())) _reminderCard(),
      // ---- Tür + tasarım (tasarımın ücreti burada da görünür: sürpriz olmasın) ----
      ZCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          children: [
            _DRow(
              swatch: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: kTypeIconDark.contains(inv.type) ? AppColors.primary : AppColors.tint, borderRadius: BorderRadius.circular(12)),
                child: Ornament(kTypeIcon[inv.type] ?? 'o-papatya', size: 32),
              ),
              small: context.t('evType'),
              big: context.t('type_${inv.type}'),
              action: changeBtn(() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TypeScreen(retype: inv)))),
            ),
            const Divider(height: 1, color: AppColors.line),
            _DRow(
              swatch: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: th.colors.bg, border: Border.all(color: th.colors.line), borderRadius: BorderRadius.circular(12)),
                child: Ornament(th.orn, size: 32),
              ),
              small: context.t('design'),
              big: th.nameIn(lang),
              badge: th.premium
                  ? ZBadge(label: inv.plan == 'premium' ? '♛' : '♛ $price', bg: AppColors.crownBg, fg: AppColors.crownInk)
                  : ZBadge(label: context.t('free'), bg: AppColors.tint, fg: AppColors.ok),
              action: changeBtn(() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ThemeScreen(existing: inv)))),
            ),
            if (locked) NoteBox(context.t('lockedNote'), icon: Icons.lock_outline),
          ],
        ),
      ),
      // ---- 1. Temel bilgiler (zorunlu dört bilgi) ----
      _section(context.t('secBasics')),
      KeyedSubtree(
        key: _anchors['names'],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (inv.isCouple)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: nameField(true, context.t('name1'), context.t('ph1'))),
                  const SizedBox(width: 10),
                  Expanded(child: nameField(false, context.t('name2'), context.t('ph2'))),
                ],
              )
            else
              nameField(true, context.tOr('nameLabel_${inv.type}', 'nameOne'), context.t('phOne')),
            errLine(err('names')),
          ],
        ),
      ),
      if (locked) lockHint(namesLeftText),
      KeyedSubtree(
        key: _anchors['date'],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldBlock(
              label: context.t('date'),
              requiredLabel: reqL,
              child: _framed(
                dateErr && (inv.date.isEmpty || inv.time.isNotEmpty),
                PickerField(
                  text: formatShortDate(inv.date, lang),
                  placeholder: context.t('selectDate'),
                  readOnly: dateRO,
                  glyph: ZGlyphs.calendar,
                  semanticLabel: context.t('date'),
                  onTap: _pickDate,
                ),
              ),
            ),
            if (locked) lockHint(datesLeftText),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FieldBlock(
                    label: context.t('time'),
                    requiredLabel: reqL,
                    child: _framed(
                      dateErr && inv.time.isEmpty,
                      PickerField(
                        text: inv.time,
                        placeholder: context.t('selectTime'),
                        glyph: ZGlyphs.clock,
                        semanticLabel: context.t('time'),
                        onTap: () async {
                          final v = await _pickTime(inv.time);
                          if (v != null) _set(() => inv.time = v);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FieldBlock(
                    label: context.t('end'),
                    child: Row(
                      children: [
                        Expanded(
                          child: PickerField(
                            text: inv.end,
                            placeholder: '—',
                            semanticLabel: context.t('end'),
                            onTap: () async {
                              final v = await _pickTime(inv.end.isEmpty ? inv.time : inv.end);
                              if (v != null) _set(() => inv.end = v);
                            },
                          ),
                        ),
                        if (inv.end.isNotEmpty)
                          IconButton(
                            tooltip: context.t('clear'),
                            icon: const ZGlyph(ZGlyphs.close, size: 18, color: AppColors.muted),
                            onPressed: () => _set(() => inv.end = ''),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            errLine(err('date')),
          ],
        ),
      ),
      KeyedSubtree(
        key: _anchors['venue'],
        child: FieldBlock(
          label: context.t('venue'),
          requiredLabel: reqL,
          error: err('venue'),
          child: TextField(
            controller: _venue,
            focusNode: _venueFocus,
            inputFormatters: maxLen(60),
            decoration: fieldDecoration(hint: context.t('phVenue')),
            style: bodyStyle(16),
            onChanged: (v) => _set(() => inv.venue = v),
          ),
        ),
      ),
      FieldBlock(
        label: context.t('address'),
        child: TextField(
          controller: _address,
          minLines: 2,
          maxLines: 4,
          inputFormatters: maxLen(160),
          decoration: fieldDecoration(hint: context.t('phAddress')),
          style: bodyStyle(16),
          onChanged: (v) => _set(() => inv.address = v),
        ),
      ),
      KeyedSubtree(key: _anchors['wa'], child: _waBlock(err('wa'), reqL, lang)),
      // ---- 2. Davet metni ----
      _section(context.t('secText')),
      FieldBlock(
        label: context.t('host'),
        child: TextField(
          controller: _host,
          inputFormatters: maxLen(80),
          decoration: fieldDecoration(hint: context.t('phHost')),
          style: bodyStyle(16),
          onChanged: (v) => _set(() => inv.host = v),
        ),
      ),
      FieldBlock(
        label: context.t('invLang'),
        child: _Dropdown<String>(
          value: inv.lang,
          items: {for (final l in kLangs) l: kLangNames[l]!},
          onChanged: (v) {
            final old = inv.lang;
            final presets = kMessages[old]?[inv.type] ?? const <String>[];
            _set(() {
              inv.lang = v;
              if (presets.contains(inv.msg)) {
                final next = kMessages[v]?[inv.type] ?? const <String>[];
                if (next.isNotEmpty) inv.msg = next.first;
              }
            });
            _msg.text = inv.msg;
          },
        ),
      ),
      FieldBlock(
        label: context.t('message'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _msg,
              minLines: 3,
              maxLines: 6,
              inputFormatters: maxLen(300),
              decoration: fieldDecoration(),
              style: bodyStyle(16, height: 1.45),
              onChanged: (v) => _set(() => inv.msg = v),
            ),
            const SizedBox(height: 5),
            Text(context.t('suggest'), style: bodyStyle(12, color: AppColors.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in msgs) _Chip(label: m, selected: inv.msg == m, onTap: () => _useMessage(m, msgs)),
              ],
            ),
          ],
        ),
      ),
      // ---- 3. İsteğe bağlı ayrıntılar (katlanır; içerik varsa açık başlar) ----
      _moreHeader(),
      if (_moreOpen) ..._optionalFields(app, th, err, noteSug),
    ];

    return Column(
      children: [
        if (errs.isNotEmpty) _ErrorSummary(errors: errs, onTap: goToError),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
  }

  Widget _upsellCard(bool expired, String price) {
    String until = '';
    final ms = inv.expiresAt;
    if (!expired && ms != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      until = '${formatShortDate(isoOf(DateTime.utc(d.year, d.month, d.day)), st.lang)} ${formatHm(d.hour, d.minute)}';
    }
    return ActionCard(
      title: expired ? context.t('upExpiredT') : context.t('upFreeT', {'d': until}),
      text: expired ? context.t('upExpiredP') : context.t('upFreeP'),
      icon: expired ? Icons.timer_off_outlined : Icons.timer_outlined,
      actions: [
        PrimaryButton(
          label: widget.busy ? context.t('payProcessing') : context.t(expired ? 'upExpiredBtn' : 'upFreeBtn', {'p': price}),
          onPressed: widget.busy ? null : widget.onUpgrade,
        ),
      ],
    );
  }

  Widget _reminderCard() {
    final n = daysUntil(inv.date, DateTime.now()) ?? 0;
    return ActionCard(
      title: n == 0 ? context.t('remindToday') : context.t('remindT', {'n': n}),
      text: context.t('remindBtn'),
      icon: Icons.notifications_active_outlined,
      actions: [
        PrimaryButton(
          label: context.t('remindBtn'),
          icon: const Icon(Icons.send_outlined, size: 18),
          onPressed: _sendReminder,
        ),
      ],
    );
  }

  /// WhatsApp bölümü: tam ad + kodla ülke seçici (arama kutulu alt sayfa), numara, ülke uyuşmazlığı önerisi,
  /// canlı "Yanıtlar … numarasına gidecek" satırı, tek satır ipucu ve açılır "Nasıl denerim?".
  Widget _waBlock(String? error, String reqL, String lang) {
    final c = countryByDial(_dial);
    final sug = suggestDial(_wa.text, _dial);
    final Country? sugC = sug == null ? null : countryByDial(sug);
    final showSug = sugC != null && _sugDismissed != _wa.text;
    final own = kMobilePatterns[_dial];
    final ownMatch = own != null && RegExp(own).hasMatch(digitsOnly(_wa.text));
    final dev = deviceDialHint(deviceCountry: _deviceCountry, currentDial: _dial);
    final showDev = dev != null && !_devHintDismissed && !showSug && !ownMatch;
    final devC = dev == null ? null : countryByDial(dev);
    final composed = composeWa(_dial, _wa.text);
    final preview = isValidWhatsApp(composed)
        ? '\u2066+${_dial.isEmpty ? digitsOnly(_wa.text) : '$_dial ${formatLocalNumber(_dial, _wa.text)}'}\u2069'
        : null;
    final label = c == null ? '\u{1F310}  ${context.t('waCodeOther')}' : '${c.flag}  ${countryNameIn(c, lang)}  \u2066(+${c.dial})\u2069';
    return FieldBlock(
      label: context.t('wa'),
      requiredLabel: reqL,
      error: error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: '${context.t('waCode')}: $label',
            excludeSemantics: true,
            child: InkWell(
              onTap: _pickCountry,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: showDev ? AppColors.tint : AppColors.surface,
                  border: Border.all(color: showDev ? AppColors.primary : AppColors.field, width: showDev ? 2 : 1),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Row(children: [
                  Expanded(child: Text(label, style: bodyStyle(16))),
                  const Icon(Icons.expand_more, color: AppColors.muted),
                ]),
              ),
            ),
          ),
          if (showDev && devC != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ActionCard(
                text: context.t('waDeviceHint', {'c': countryNameIn(devC, lang)}),
                icon: Icons.public,
                closeTooltip: context.t('close'),
                onClose: () => setState(() => _devHintDismissed = true),
                actions: [
                  GhostButton(label: '${devC.flag} ${context.t('waSuggestYes', {'d': '\u2066+${devC.dial}\u2069'})}', onPressed: () => _setDial(devC.dial)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _wa,
              focusNode: _waFocus,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')), LengthLimitingTextInputFormatter(24)],
              decoration: fieldDecoration(hint: context.t('phWa')).copyWith(
                prefixText: _dial.isEmpty ? '+ ' : '+$_dial ',
                prefixStyle: bodyStyle(16, color: AppColors.muted),
              ),
              style: bodyStyle(16),
              onChanged: _onWaChanged,
            ),
          ),
          if (showSug && sugC != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ActionCard(
                text: context.t('waSuggest', {'c': countryNameIn(sugC, lang), 'd': '\u2066+${sugC.dial}\u2069'}),
                icon: Icons.help_outline,
                actions: [
                  PrimaryButton(label: '${sugC.flag} ${context.t('waSuggestYes', {'d': '\u2066+${sugC.dial}\u2069'})}', onPressed: () => _setDial(sugC.dial)),
                  GhostButton(label: context.t('waSuggestNo'), onPressed: () => setState(() => _sugDismissed = _wa.text)),
                ],
              ),
            ),
          if (preview != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppColors.ok),
                const SizedBox(width: 6),
                Expanded(child: Text(context.t('waPreview', {'p': preview}), style: bodyStyle(13, weight: FontWeight.w600, color: AppColors.ok))),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(context.t('waHint'), style: bodyStyle(12.5, color: AppColors.muted, height: 1.4)),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: Text(context.t('waTestQ'), style: bodyStyle(13, weight: FontWeight.w600, color: AppColors.primary)),
              children: [Text(context.t('waTestA'), style: bodyStyle(12.5, color: AppColors.muted, height: 1.45))],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moreHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Semantics(
        button: true,
        expanded: _moreOpen,
        child: InkWell(
          onTap: () => setState(() => _moreOpen = !_moreOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('moreSec'), style: headStyle(18)),
                      const SizedBox(height: 2),
                      Text(context.t('moreSecHint'), style: bodyStyle(12, color: AppColors.muted, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(context.t(_moreOpen ? 'moreHide' : 'moreShow'), style: bodyStyle(13, weight: FontWeight.w600, color: AppColors.primary)),
                Icon(_moreOpen ? Icons.expand_less : Icons.expand_more, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _optionalFields(AppState app, InviteTheme th, String? Function(String) err, List<String> noteSug) {
    final lang = app.lang;
    final liveErr = err('live');
    return [
      // Program
      FieldBlock(
        label: context.t('program'),
        hint: context.t('progHint'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < inv.program.length; i++) _stepRow(i),
            if (inv.program.isEmpty) ...[
              GhostButton(label: context.t('progExAdd'), icon: const Icon(Icons.auto_awesome_outlined, size: 18), block: true, onPressed: _addSampleProgram),
              const SizedBox(height: 8),
            ],
            if (inv.program.length < kMaxSteps)
              GhostButton(
                label: context.t('addStep'),
                block: true,
                onPressed: () => _set(() => inv.program.add(ProgramStep())),
              ),
          ],
        ),
      ),
      // Ricalarımız (notlar)
      FieldBlock(
        label: context.t('notes'),
        hint: context.t('notesHint'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < inv.notes.length; i++) _noteRow(i),
            if (inv.notes.length < kMaxNotes) ...[
              GhostButton(label: context.t('addNote'), block: true, onPressed: _addNote),
              const SizedBox(height: 8),
              Text(context.t('noteSug'), style: bodyStyle(12, color: AppColors.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in noteSug) _Chip(label: m, selected: inv.notes.contains(m), onTap: () => _useNoteSuggestion(m)),
                ],
              ),
            ],
          ],
        ),
      ),
      // Canlı yayın bağlantısı (ücretsiz ve ücretli): bırakılınca https:// eklenir ve doğrulanır.
      KeyedSubtree(
        key: _anchors['live'],
        child: FieldBlock(
          label: context.t('streamSec'),
          hint: context.t('streamHint'),
          error: liveErr,
          child: Column(
            children: [
              TextField(
                controller: _liveUrl,
                focusNode: _liveFocus,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textDirection: TextDirection.ltr,
                inputFormatters: [LengthLimitingTextInputFormatter(kLiveUrlMax + 40), FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                decoration: fieldDecoration(hint: context.t('streamPh')),
                style: bodyStyle(16),
                onChanged: (v) => _set(() => inv.liveUrl = v.trim()),
                onSubmitted: (_) => _onLiveFocus(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _liveNote,
                maxLength: kLiveNoteMax,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
                decoration: fieldDecoration(hint: context.t('streamNotePh')),
                style: bodyStyle(16),
                onChanged: (v) => _set(() => inv.liveNote = v),
              ),
            ],
          ),
        ),
      ),
      // Hediye için IBAN (yalnız ücretli)
      _giftBlock(err),
      // Görünüm
      Container(
        margin: const EdgeInsets.only(top: 8, bottom: 10),
        padding: const EdgeInsets.only(top: 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: Text(context.t('look'), style: headStyle(18)),
      ),
      FieldBlock(
        label: context.t('layout'),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: [
            for (final k in kLayouts)
              _LayoutTile(
                label: context.t('lay_$k'),
                on: inv.layout == k,
                thumb: LayoutThumb(layout: k, css: th.css, rtl: lang == 'ar'),
                onTap: () => _set(() => inv.layout = k),
              ),
          ],
        ),
      ),
      FieldBlock(
        label: context.t('opening'),
        // Tasarım #15: her açılış için minik görsel.
        child: OpeningPicker(value: inv.opening, theme: kThemes[inv.theme] ?? kThemes['papatya']!, onChanged: (k) => _set(() => inv.opening = k)),
      ),
      // Kapak
      FieldBlock(
        label: context.t('cover'),
        hint: context.t('coverHint'),
        child: _busyKind == 'cover'
            ? const _PhotoPlaceholder(height: 160)
            : inv.cover.isNotEmpty
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          app.photoFile(inv.cover),
                          height: 230,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          semanticLabel: context.t('cover'),
                          errorBuilder: (_, __, ___) => const SizedBox(height: 60),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: GhostButton(label: context.t('change'), onPressed: _pickCover)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GhostButton(
                            label: context.t('removePhoto'),
                            onPressed: () {
                              setState(() => _photoWarn = null);
                              st.removeCover(inv);
                            },
                          ),
                        ),
                      ]),
                    ],
                  )
                : GhostButton(label: '+ ${context.t('addPhoto')}', block: true, onPressed: _pickCover),
      ),
      // Galeri
      FieldBlock(
        label: context.t('gallery'),
        hint: context.t('galHint', {'n': inv.photos.length}),
        error: (_photoWarn == null || _photoWarn == 'photoErr') ? null : context.t(_photoWarn!),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (inv.photos.isNotEmpty || _busyKind == 'gal')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                  children: [
                    for (var i = 0; i < inv.photos.length; i++) _photoThumb(app, i),
                    if (_busyKind == 'gal') const _PhotoPlaceholder(),
                  ],
                ),
              ),
            if (_photoWarn == 'photoErr')
              ActionCard(
                text: '${context.t('photoFailCard')} ${context.t('photoErr')}',
                error: true,
                icon: Icons.broken_image_outlined,
                closeTooltip: context.t('close'),
                onClose: () => setState(() => _photoWarn = null),
                actions: [
                  GhostButton(label: context.t('retry'), onPressed: _lastPhotoKind == 'cover' ? _pickCover : _pickGallery),
                ],
              ),
            if (inv.photos.length < kMaxGallery && _busyKind != 'gal')
              GhostButton(label: '+ ${context.t('addGal')}', block: true, onPressed: _pickGallery),
          ],
        ),
      ),
      MusicPicker(
        selected: inv.music,
        open: isPaidInvite(inv),
        type: inv.type,
        onChanged: (id) => setState(() => _set(() => inv.music = id)),
      ),
    ];
  }

  Widget _framed(bool on, Widget child) => on ? ErrorFrame(child: child) : child;

  /// Hediye IBAN'ı bölümü. Ücretsiz davetiyede kilitli (alanlar kapalı, "1 Davetiye Hakkı ile" rozeti).
  Widget _giftBlock(String? Function(String) err) {
    final open = isPaidInvite(inv);
    final ibanOk = open && inv.giftIban.trim().isNotEmpty && isValidIban(inv.giftIban);
    return Opacity(
      opacity: open ? 1 : 0.6,
      child: FieldBlock(
        label: context.t('giftSec'),
        hint: open ? null : context.t('giftLockHint'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!open)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Flexible(child: Text(context.t('giftLockBadge'), style: bodyStyle(12, weight: FontWeight.w600, color: AppColors.primary))),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(context.t('giftHostNote'), style: bodyStyle(12, color: AppColors.muted, height: 1.4)),
            ),
            KeyedSubtree(
              key: _anchors['giftHolder'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t('giftHolderL'), style: bodyStyle(12, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  _framed(
                    err('giftHolder') != null,
                    TextField(
                      controller: _giftHolder,
                      focusNode: _holderFocus,
                      enabled: open,
                      maxLength: kGiftHolderMax,
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
                      decoration: fieldDecoration(hint: context.t('giftHolderPh')),
                      style: bodyStyle(16),
                      onChanged: (v) => _set(() => inv.giftHolder = v),
                    ),
                  ),
                  if (err('giftHolder') != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(err('giftHolder')!, style: bodyStyle(13, color: AppColors.err)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _anchors['giftIban'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t('giftIbanL'), style: bodyStyle(12, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  _framed(
                    err('giftIban') != null,
                    Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      controller: _giftIban,
                      focusNode: _ibanFocus,
                      enabled: open,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')), LengthLimitingTextInputFormatter(42)],
                      decoration: fieldDecoration(hint: context.t('giftIbanPh')),
                      style: bodyStyle(16),
                      onChanged: (v) => setState(() => _set(() => inv.giftIban = normalizeIban(v))),
                    ),
                    ),
                  ),
                  if (err('giftIban') != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(err('giftIban')!, style: bodyStyle(13, color: AppColors.err)),
                    )
                  else if (ibanOk)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(context.t('ibanOk'), style: bodyStyle(13, weight: FontWeight.w600, color: AppColors.ok)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(context.t('giftBankL'), style: bodyStyle(12, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: _giftBank,
              enabled: open,
              maxLength: kGiftBankMax,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
              decoration: fieldDecoration(hint: context.t('giftBankPh')),
              style: bodyStyle(16),
              onChanged: (v) => _set(() => inv.giftBank = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteRow(int i) {
    return Padding(
      key: ObjectKey(_noteCtl[i]),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _noteCtl[i],
              maxLength: kNoteLen,
              minLines: 1,
              maxLines: 3,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
              decoration: fieldDecoration(hint: context.t('notePh')),
              style: bodyStyle(16),
              onChanged: (v) {
                if (i < inv.notes.length) inv.notes[i] = v;
                st.save(notify: false);
              },
            ),
          ),
          const SizedBox(width: 4),
          ZIconButton(
            glyph: ZGlyphs.close,
            tooltip: context.t('removeNote'),
            onPressed: () {
              if (i >= inv.notes.length || i >= _noteCtl.length) return;
              final c = _noteCtl.removeAt(i);
              _set(() => inv.notes.removeAt(i));
              WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
            },
          ),
        ],
      ),
    );
  }

  Widget _stepRow(int i) {
    final s = inv.program[i];
    return Padding(
      key: ObjectKey(s),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: PickerField(
              text: s.t,
              placeholder: context.t('stepTime'),
              semanticLabel: '${context.t('stepTime')} ${i + 1}',
              onTap: () async {
                final v = await _pickTime(s.t.isEmpty ? inv.time : s.t);
                if (v != null) _set(() => s.t = v);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctlFor(s),
              inputFormatters: maxLen(40),
              decoration: fieldDecoration(hint: context.t('stepPh')),
              style: bodyStyle(16),
              onChanged: (v) {
                s.x = v;
                st.save(notify: false);
              },
            ),
          ),
          const SizedBox(width: 4),
          ZIconButton(
            glyph: ZGlyphs.close,
            tooltip: context.t('removeStep'),
            onPressed: () {
              final c = _stepCtl.remove(s);
              _set(() => inv.program.removeAt(i));
              WidgetsBinding.instance.addPostFrameCallback((_) => c?.dispose());
            },
          ),
        ],
      ),
    );
  }

  Widget _photoThumb(AppState app, int i) {
    final name = inv.photos[i];
    return Container(
      key: ValueKey(name),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Image.file(
              app.photoFile(name),
              width: double.infinity,
              fit: BoxFit.cover,
              semanticLabel: '${context.t('gallery')} ${i + 1}',
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (i > 0)
                IconButton(
                  tooltip: context.t('moveEarlier'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  onPressed: () => st.movePhotoEarlier(inv, i),
                )
              else
                const SizedBox(width: 48, height: 48),
              IconButton(
                tooltip: '${context.t('removePhoto')} ${i + 1}',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() => _photoWarn = null);
                  st.removePhoto(inv, i);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DRow extends StatelessWidget {
  const _DRow({required this.swatch, required this.small, required this.big, required this.action, this.badge});

  final Widget swatch;
  final String small;
  final String big;
  final Widget action;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          swatch,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(small, style: bodyStyle(12, color: AppColors.muted)),
                Text(big, style: bodyStyle(15, weight: FontWeight.w700)),
                if (badge != null) Padding(padding: const EdgeInsets.only(top: 3), child: badge!),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}

/// Hazır metin çipi: tam metin, en çok 2 satır (kesik "…" tek satır yerine); seçili olan işaretli.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap, this.selected = false});

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.tint : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.field, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Align(
              widthFactor: 1,
              alignment: AlignmentDirectional.centerStart,
              // Tasarım #16: çip metni kesilmez, en çok 2 satır.
              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(12.5, height: 1.3)),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayoutTile extends StatelessWidget {
  const _LayoutTile({required this.label, required this.on, required this.thumb, required this.onTap});

  final String label;
  final bool on;
  final Widget thumb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.tint : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: on ? AppColors.primary : AppColors.field, width: on ? 2 : 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                thumb,
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(12.5, weight: FontWeight.w600, height: 1.25)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.value, required this.items, required this.onChanged});

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.field),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: bodyStyle(16),
          items: [for (final e in items.entries) DropdownMenuItem<T>(value: e.key, child: Text(e.value))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Yayına basınca hata varsa formun üstünde kalan özet bandı: "3 bilgi eksik: İsimler · Tarih ve saat …".
/// Her parça dokunulabilir: ilgili alana kaydırır ve odaklar. Hatalar düzeldikçe kendiliğinden küçülür/kaybolur.
class _ErrorSummary extends StatelessWidget {
  const _ErrorSummary({required this.errors, required this.onTap});

  final Map<String, String> errors;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final keys = [for (final k in kErrorOrder) if (errors.containsKey(k)) k];
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.err, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.error_outline, size: 18, color: AppColors.err),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.t('errSummary', {'n': keys.length}), style: bodyStyle(14, weight: FontWeight.w700, color: AppColors.err)),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in keys)
                  ActionChip(
                    label: Text(context.t('errPart_$k'), style: bodyStyle(13, weight: FontWeight.w600, color: AppColors.err)),
                    avatar: const Icon(Icons.arrow_forward, size: 16, color: AppColors.err),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.err),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: () => onTap(k),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(context.t('errSummaryTap'), style: bodyStyle(12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

/// Fotoğraf hazırlanırken yuvada dönen yer tutucu (donmuş sanılmasın).
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: context.t('photoBusy'),
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.sand,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(context.t('photoBusy'), textAlign: TextAlign.center, style: bodyStyle(12, color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ülke kodu seçimi: arama kutulu alt sayfa (ülke adı arayüz dilinde ve kendi dilinde, ya da kodla aranır).
class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.lang, required this.current});

  final String lang;
  final String current;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase().replaceAll('+', '');
    final list = [
      for (final c in kCountries)
        if (q.isEmpty || countryNameIn(c, widget.lang).toLowerCase().contains(q) || c.name.toLowerCase().contains(q) || c.dial.startsWith(q)) c,
    ];
    final h = MediaQuery.of(context).size.height * 0.75;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: h,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(context.t('waCountryTitle'), style: headStyle(19)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                decoration: fieldDecoration(hint: context.t('waSearch')).copyWith(prefixIcon: const Icon(Icons.search)),
                style: bodyStyle(16),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.t('waNoMatch'), textAlign: TextAlign.center, style: bodyStyle(14, color: AppColors.muted)),
                    ),
                  for (final c in list)
                    ListTile(
                      minVerticalPadding: 10,
                      selected: c.dial == widget.current,
                      selectedColor: AppColors.primary,
                      leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                      title: Text(countryNameIn(c, widget.lang), style: bodyStyle(16)),
                      subtitle: countryNameIn(c, widget.lang) == c.name ? null : Text(c.name, style: bodyStyle(12.5, color: AppColors.muted)),
                      trailing: Text('\u2066+${c.dial}\u2069', style: bodyStyle(15, weight: FontWeight.w600)),
                      onTap: () => Navigator.of(context).pop(c.dial),
                    ),
                  if (q.isEmpty)
                    ListTile(
                      selected: widget.current.isEmpty,
                      leading: const Text('\u{1F310}', style: TextStyle(fontSize: 22)),
                      title: Text(context.t('waCodeOther'), style: bodyStyle(16)),
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
