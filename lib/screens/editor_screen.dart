import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../cloud/invite_contract.dart';
import '../data/catalog.dart';
import '../data/countries.dart';
import '../l10n/strings.dart';
import '../logic/date_utils.dart';
import '../logic/iban.dart';
import '../logic/lock_rules.dart';
import '../logic/phone.dart';
import '../logic/text_utils.dart';
import '../logic/url_check.dart';
import '../logic/validation.dart';
import '../models/invitation.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/invite_view.dart';
import '../widgets/layout_thumb.dart';
import '../widgets/music_picker.dart';
import '../widgets/ornament.dart';
import 'done_screen.dart';
import 'publish_screen.dart';
import 'theme_screen.dart';
import 'type_screen.dart';

/// Davetiye editörü: Bilgiler ve Önizleme sekmeleri.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.invId});

  final String invId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int _tab = 0; // 0 = Bilgiler, 1 = Önizleme
  bool _showErr = false;
  DateTime? _delArmedAt;
  int _previewKey = 0;
  bool _cloudBusy = false;

  void _goPreview(int tab) {
    FocusScope.of(context).unfocus();
    setState(() {
      _tab = tab;
      if (tab == 1) _previewKey++;
    });
  }

  Future<void> _delete(Invitation inv) async {
    final now = DateTime.now();
    final armed = _delArmedAt;
    if (armed != null && now.difference(armed).inMilliseconds < 3500) {
      if (_cloudBusy) return;
      _delArmedAt = null;
      final nav = Navigator.of(context);
      if (inv.cloudId != null) {
        setState(() => _cloudBusy = true);
        showToast(context, context.t('deleting'), ms: 20000);
      }
      final err = await context.read<AppState>().deleteInvitation(inv);
      if (!mounted) return;
      setState(() => _cloudBusy = false);
      if (err != null) {
        showToast(context, context.t(err), ms: 5000);
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      nav.pop();
      return;
    }
    _delArmedAt = now;
    showToast(context, context.t('delQ'), ms: 3500);
  }

  void _toPublish(Invitation inv) {
    FocusScope.of(context).unfocus();
    final e = validateInvitation(inv);
    if (e.isNotEmpty) {
      setState(() {
        _showErr = true;
        _tab = 0;
      });
      showToast(context, context.t('fixFirst'));
      return;
    }
    final st = context.read<AppState>();
    if (inv.isLive) {
      _pushUpdate(st, inv);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublishScreen(invId: inv.id)));
  }

  Future<void> _pushUpdate(AppState st, Invitation inv) async {
    if (_cloudBusy) return;
    if (st.isExpired(inv)) {
      showToast(context, context.t('expiredNote'), ms: 5000);
      return;
    }
    setState(() => _cloudBusy = true);
    showToast(context, context.t('cloudUpdating'), ms: 30000);
    final nav = Navigator.of(context);
    final err = await st.pushUpdate(inv);
    if (!mounted) return;
    setState(() => _cloudBusy = false);
    if (err != null) {
      showToast(context, context.t(err), ms: 5000);
      return;
    }
    showToast(context, context.t('updated'));
    nav.push(MaterialPageRoute(builder: (_) => DoneScreen(invId: inv.id)));
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final inv = st.byId(widget.invId);
    if (inv == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ZTopBar(
              title: invitationTitle(inv, context.t('untitled')),
              leading: const BackBtn(),
              actions: [ZIconButton(icon: Icons.delete_outline, tooltip: context.t('del'), onPressed: () => _delete(inv))],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  Expanded(child: _TabButton(label: context.t('details'), on: _tab == 0, onTap: () => _goPreview(0))),
                  const SizedBox(width: 6),
                  Expanded(child: _TabButton(label: context.t('preview'), on: _tab == 1, onTap: () => _goPreview(1))),
                ],
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? DetailsForm(inv: inv, showErr: _showErr)
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: InviteView(key: ValueKey('pv$_previewKey'), inv: inv),
                    ),
            ),
            ZBottomBar(children: [
              GhostButton(
                label: _tab == 0 ? context.t('preview') : context.t('details'),
                onPressed: () => _goPreview(_tab == 0 ? 1 : 0),
              ),
              PrimaryButton(
                label: _cloudBusy ? context.t('cloudUpdating') : (inv.isLive ? context.t('update') : context.t('publish')),
                onPressed: _cloudBusy ? null : () => _toPublish(inv),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
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
            padding: const EdgeInsets.all(10),
            child: Text(label, style: bodyStyle(15, weight: FontWeight.w600, color: on ? AppColors.onPrimary : AppColors.ink)),
          ),
        ),
      ),
    );
  }
}

/// Bilgiler sekmesi.
class DetailsForm extends StatefulWidget {
  const DetailsForm({super.key, required this.inv, required this.showErr});

  final Invitation inv;
  final bool showErr;

  @override
  State<DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends State<DetailsForm> {
  late final TextEditingController _n1, _n2, _host, _msg, _venue, _address, _wa;
  late final TextEditingController _liveUrl, _liveNote, _giftHolder, _giftIban, _giftBank;
  late String _dial; // WhatsApp ülke kodu (artısız); boş = "diğer"
  late final FocusNode _n1Focus, _n2Focus;
  final Map<ProgramStep, TextEditingController> _stepCtl = {};
  final List<TextEditingController> _noteCtl = [];
  final _picker = ImagePicker();
  String? _photoWarn; // ARB anahtarı (dil değişince doğru dilde gösterilir)
  bool _busy = false;

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
    final deviceCountry = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    final parts = parsePhone(inv.wa, fallbackDial: defaultDial(deviceCountry: deviceCountry, lang: inv.lang));
    _dial = parts.dial;
    _wa = TextEditingController(text: parts.local);
    // Eski kayıtta başında 0 / artı / boşluk varsa bozuk wa.me bağlantısı olmasın: tek biçime çevir.
    if (inv.wa.isNotEmpty) {
      final composed = composeWa(_dial, parts.local);
      if (composed.isNotEmpty && composed != inv.wa) inv.wa = composed;
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
    _n1Focus.dispose();
    _n2Focus.dispose();
    super.dispose();
  }

  /// Numara alanı: başta +/00 ile yapıştırılan uluslararası numarada ülkeyi seç, başta 0'ı at; saklanan değer yalnız rakamdır.
  void _onWaChanged(String v) {
    final r = normalizeLocalInput(v, _dial);
    if (r.changed) {
      setState(() => _dial = r.parts.dial);
      _wa.value = TextEditingValue(text: r.parts.local, selection: TextSelection.collapsed(offset: r.parts.local.length));
    }
    _set(() => inv.wa = composeWa(_dial, _wa.text));
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
    final current = parseIsoDate(inv.date);
    DateTime first = DateTime(now.year - 1, 1, 1), last = DateTime(now.year + 10, 12, 31);
    if (win != null) {
      final a = parseIsoDate(win.$1)!, b = parseIsoDate(win.$2)!;
      first = DateTime(a.year, a.month, a.day);
      last = DateTime(b.year, b.month, b.day);
    }
    var initial = current == null ? DateTime(now.year, now.month, now.day) : DateTime(current.year, current.month, current.day);
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
    if (_busy) return;
    XFile? f;
    try {
      f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
    } catch (_) {
      if (mounted) setState(() => _photoWarn = 'photoErr');
      return;
    }
    if (f == null || !mounted) return;
    setState(() => _busy = true);
    showToast(context, context.t('photoBusy'));
    final Uint8List bytes = await f.readAsBytes();
    final err = await st.setCover(inv, bytes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _photoWarn = err;
    });
  }

  Future<void> _pickGallery() async {
    if (_busy) return;
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
    setState(() => _busy = true);
    showToast(context, context.t('photoBusy'));
    final room = kMaxGallery - inv.photos.length;
    final list = <Uint8List>[];
    for (final f in files.take(room)) {
      list.add(await f.readAsBytes());
    }
    var warn = await st.addPhotos(inv, list);
    if (files.length > room && warn == null) warn = 'galFull';
    if (!mounted) return;
    setState(() {
      _busy = false;
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

  /// Hazır not: önce boş bir satırı doldurur, boş satır yoksa yeni satır ekler.
  void _useNoteSuggestion(String m) {
    final e = inv.notes.indexOf('');
    if (e >= 0 && e < _noteCtl.length) {
      _set(() => inv.notes[e] = m);
      _noteCtl[e].text = m;
    } else {
      _addNote(m);
    }
  }

  TextEditingController _ctlFor(ProgramStep s) => _stepCtl.putIfAbsent(s, () => TextEditingController(text: s.x));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.lang;
    final errs = widget.showErr ? validateInvitation(inv) : const <String, String>{};
    String? err(String k) => errs[k] == null ? null : context.t(errs[k]!);
    final th = kThemes[inv.theme] ?? kThemes['papatya']!;
    final locked = isLocked(inv);
    final nameRO = locked && inv.nameEditsLeft <= 0;
    final dateRO = locked && inv.dateEditsLeft <= 0;
    final win = dateWindow(inv);
    final msgs = kMessages[inv.lang]?[inv.type] ?? const <String>[];
    _syncNoteCtl();
    final noteSug = kNoteSuggestions[inv.lang] ?? kNoteSuggestions['tr'] ?? const <String>[];

    Widget lockHint(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            const Icon(Icons.lock_outline, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: bodyStyle(12.5, weight: FontWeight.w600, color: AppColors.primary))),
          ]),
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
          child: TextField(
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
        );

    final namesLeftText = inv.nameEditsLeft > 0 ? context.t('namesLeft', {'n': inv.nameEditsLeft}) : context.t('namesNone');
    final datesLeftText = inv.dateEditsLeft > 0
        ? context.t('datesLeft', {
            'n': inv.dateEditsLeft,
            'a': win == null ? '' : formatShortDate(win.$1, lang),
            'b': win == null ? '' : formatShortDate(win.$2, lang),
          })
        : context.t('datesNone');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (app.isExpired(inv)) NoteBox(context.t('expiredNote'), icon: Icons.timer_off_outlined),
        // Tür + tasarım
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
                big: th.nameIn(lang) + (th.premium ? '  ♛' : ''),
                action: changeBtn(() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ThemeScreen(existing: inv)))),
              ),
              if (locked) NoteBox(context.t('lockedNote'), icon: Icons.lock_outline),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // İsimler
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
        if (err('names') != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(err('names')!, style: bodyStyle(13, color: AppColors.err)),
          ),
        if (locked) lockHint(namesLeftText),
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
                  for (final m in msgs)
                    _Chip(
                      label: chipLabel(m),
                      onTap: () {
                        _set(() => inv.msg = m);
                        _msg.text = m;
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        FieldBlock(
          label: context.t('date'),
          child: PickerField(
            text: formatShortDate(inv.date, lang),
            placeholder: context.t('selectDate'),
            readOnly: dateRO,
            icon: Icons.calendar_today_outlined,
            semanticLabel: context.t('date'),
            onTap: _pickDate,
          ),
        ),
        if (locked) lockHint(datesLeftText),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FieldBlock(
                label: context.t('time'),
                child: PickerField(
                  text: inv.time,
                  placeholder: context.t('selectTime'),
                  icon: Icons.schedule,
                  semanticLabel: context.t('time'),
                  onTap: () async {
                    final v = await _pickTime(inv.time);
                    if (v != null) _set(() => inv.time = v);
                  },
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
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _set(() => inv.end = ''),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (err('date') != null)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err('date')!, style: bodyStyle(13, color: AppColors.err))),
        FieldBlock(
          label: context.t('venue'),
          error: err('venue'),
          child: TextField(
            controller: _venue,
            inputFormatters: maxLen(60),
            decoration: fieldDecoration(hint: context.t('phVenue')),
            style: bodyStyle(16),
            onChanged: (v) => _set(() => inv.venue = v),
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
        FieldBlock(
          label: context.t('wa'),
          hint: context.t('waHint'),
          error: err('wa'),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: context.t('waCode'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.field),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _dial,
                          menuMaxHeight: 360,
                          items: [
                            for (final c in kCountries)
                              DropdownMenuItem<String>(
                                value: c.dial,
                                child: Text('${c.flag} +${c.dial}  ${c.name}', style: bodyStyle(15)),
                              ),
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text('\u{1F310} +  ${context.t('waCodeOther')}', style: bodyStyle(15)),
                            ),
                          ],
                          selectedItemBuilder: (_) => [
                            for (final c in kCountries) Center(child: Text('${c.flag} +${c.dial}', style: bodyStyle(16))),
                            Center(child: Text('\u{1F310} +', style: bodyStyle(16))),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _dial = v);
                            _set(() => inv.wa = composeWa(_dial, _wa.text));
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _wa,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')), LengthLimitingTextInputFormatter(24)],
                      decoration: fieldDecoration(hint: context.t('phWa')),
                      style: bodyStyle(16),
                      onChanged: _onWaChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Program
        FieldBlock(
          label: context.t('program'),
          hint: context.t('progHint'),
          child: Column(
            children: [
              for (var i = 0; i < inv.program.length; i++) _stepRow(i),
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
                    for (final m in noteSug) _Chip(label: chipLabel(m), onTap: () => _useNoteSuggestion(m)),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Canlı yayın bağlantısı (ücretsiz ve ücretli)
        FieldBlock(
          label: context.t('streamSec'),
          hint: context.t('streamHint'),
          error: err('live'),
          child: Column(
            children: [
              TextField(
                controller: _liveUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                inputFormatters: [LengthLimitingTextInputFormatter(kLiveUrlMax + 40), FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                decoration: fieldDecoration(hint: context.t('streamPh')),
                style: bodyStyle(16),
                onChanged: (v) => _set(() => inv.liveUrl = v.trim()),
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
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.0,
            children: [
              for (final k in kOpenings)
                _SegButton(label: context.t('opn_$k'), on: inv.opening == k, onTap: () => _set(() => inv.opening = k)),
            ],
          ),
        ),
        // Kapak
        FieldBlock(
          label: context.t('cover'),
          hint: context.t('coverHint'),
          child: inv.cover.isNotEmpty
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
          error: _photoWarn == null ? null : context.t(_photoWarn!),
          child: Column(
            children: [
              if (inv.photos.isNotEmpty)
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
                    ],
                  ),
                ),
              if (inv.photos.length < kMaxGallery)
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
      ],
    );
  }

  /// Hediye IBAN'ı bölümü. Ücretsiz davetiyede kilitli (alanlar kapalı, "1 Davetiye Hakkı ile" rozeti).
  Widget _giftBlock(String? Function(String) err) {
    final open = isPaidInvite(inv);
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
            Text(context.t('giftHolderL'), style: bodyStyle(12, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: _giftHolder,
              enabled: open,
              maxLength: kGiftHolderMax,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
              decoration: fieldDecoration(hint: context.t('giftHolderPh')),
              style: bodyStyle(16),
              onChanged: (v) => _set(() => inv.giftHolder = v),
            ),
            if (err('giftHolder') != null)
              Text(err('giftHolder')!, style: bodyStyle(13, color: AppColors.err)),
            const SizedBox(height: 8),
            Text(context.t('giftIbanL'), style: bodyStyle(12, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: _giftIban,
              enabled: open,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              keyboardType: TextInputType.visiblePassword,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')), LengthLimitingTextInputFormatter(42)],
              decoration: fieldDecoration(hint: context.t('giftIbanPh')),
              style: bodyStyle(16),
              onChanged: (v) => _set(() => inv.giftIban = normalizeIban(v)),
            ),
            if (err('giftIban') != null)
              Text(err('giftIban')!, style: bodyStyle(13, color: AppColors.err)),
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
            icon: Icons.close,
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
            icon: Icons.close,
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
  const _DRow({required this.swatch, required this.small, required this.big, required this.action});

  final Widget swatch;
  final String small;
  final String big;
  final Widget action;

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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.field)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            widthFactor: 1,
            child: Text(label, style: bodyStyle(12.5)),
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

class _SegButton extends StatelessWidget {
  const _SegButton({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.tint : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          side: BorderSide(color: on ? AppColors.primary : AppColors.field, width: on ? 2 : 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(label, textAlign: TextAlign.center, style: bodyStyle(14, weight: FontWeight.w600)),
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
