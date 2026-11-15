import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../logic/lock_rules.dart';
import '../logic/theme_style.dart';
import '../models/invitation.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_slot.dart';
import '../widgets/common.dart';
import '../widgets/invite_mini.dart';
import '../widgets/invite_view.dart';
import 'editor_screen.dart';

/// Tasarım galerisi ("katalog"): 2 sütun canlı minik önizleme (kullanıcının kendi isimleriyle),
/// stil/tür filtreleri, ücretli tasarımlarda zarif taç işareti, ücretsiz Papatya açıkça etiketli,
/// tam ekran gerçek önizleme. [draft]: yeni davetiye; [existing]: düzenlenen davetiye.
class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key, this.draft, this.existing}) : assert(draft != null || existing != null);

  final Invitation? draft;
  final Invitation? existing;

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  Invitation get inv => widget.existing ?? widget.draft!;
  String _filter = 'rec';

  void _select(String themeId) {
    if (!canChangeTypeOrTheme(inv)) {
      showToast(context, context.t('lockedNote'), ms: 3500);
      return;
    }
    setState(() => inv.theme = themeId);
    if (widget.existing != null) context.read<AppState>().save();
  }

  Future<void> _continue() async {
    final st = context.read<AppState>();
    if (widget.existing != null) {
      Navigator.of(context).pop();
      return;
    }
    final d = widget.draft!;
    await st.add(d);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => EditorScreen(invId: d.id)),
      (r) => r.isFirst,
    );
  }

  /// Seçili tasarımın gerçek davetiye sayfasıyla (aynı görüntüleyici) tam ekran önizlemesi.
  Future<void> _preview(String themeId) async {
    final copy = Invitation.fromJson(inv.toJson())..theme = themeId;
    final pick = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bg,
      barrierColor: AppColors.scrim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
      clipBehavior: Clip.antiAlias,
      builder: (ctx) {
        final th = kThemes[themeId]!;
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.x4, AppSpace.x3, AppSpace.x2, AppSpace.x2),
                child: Row(
                  children: [
                    Expanded(child: Text(th.nameIn(context.read<AppState>().lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: headStyle(AppType.h2))),
                    _PlanMark(premium: th.premium),
                    const SizedBox(width: AppSpace.x1),
                    ZIconButton(glyph: ZGlyphs.close, tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip, onPressed: () => Navigator.of(ctx).pop(false)),
                  ],
                ),
              ),
              Expanded(child: InviteView(inv: copy)),
              ZBottomBar(children: [
                PrimaryButton(label: ctx.t('useThisDesign'), onPressed: () => Navigator.of(ctx).pop(true)),
              ]),
            ],
          ),
        );
      },
    );
    if (pick == true && mounted) _select(themeId);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final lang = st.lang;
    final ids = galleryThemes(inv.type, _filter);
    final price = st.playPrice ?? context.t('price');
    final locked = !canChangeTypeOrTheme(inv);
    // Kart yüksekliği: 3:4 küçük resim (+ çerçeve) + ad satırı.
    final tileW = (MediaQuery.sizeOf(context).width - 2 * AppSpace.edge - AppSpace.x3) / 2;
    final tileH = (tileW - 6) * 4 / 3 + 6 + AppSpace.x2 + MediaQuery.textScalerOf(context).scale(22);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ZTopBar(title: context.t('type_${inv.type}'), leading: const BackBtn()),
            // Yapışkan filtre şeridi (liste kaydırılırken üstte kalır).
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(AppSpace.edge, AppSpace.x1, AppSpace.edge, AppSpace.x2),
                children: [
                  for (final f in kGalleryFilters) ...[
                    _FilterChip(
                      label: f == 'rec' ? context.t('flt_rec', {'t': context.t('type_${inv.type}')}) : context.t('flt_$f'),
                      on: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                    const SizedBox(width: AppSpace.x2),
                  ],
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.edge, 0, AppSpace.edge, AppSpace.x3),
                    sliver: SliverList.list(children: [
                      H2(context.t('chooseTheme')),
                      // Fiyat bilgisi galeride (UX #12, tasarım #4): sürpriz yok.
                      _InfoLine(text: context.t('galleryInfo', {'p': price})),
                      if (locked) NoteBox(context.t('lockedNote')),
                    ]),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpace.x4,
                        crossAxisSpacing: AppSpace.x3,
                        mainAxisExtent: tileH,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final id = ids[i];
                          final th = kThemes[id]!;
                          return _ThemeTile(
                            inv: inv,
                            theme: th,
                            name: th.nameIn(lang),
                            selected: inv.theme == id,
                            onTap: () => _select(id),
                            onPreview: () => _preview(id),
                          );
                        },
                        childCount: ids.length,
                      ),
                    ),
                  ),
                  if (ids.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.x6),
                        child: Text(context.t('galleryEmpty'), textAlign: TextAlign.center, style: bodyStyle(14.5, color: AppColors.muted)),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x6)),
                ],
              ),
            ),
            ZBottomBar(children: [
              GhostButton(label: context.t('previewDesign'), icon: const ZGlyph(ZGlyphs.eye, size: 18), onPressed: () => _preview(inv.theme)),
              PrimaryButton(label: '${context.t('edit')} →', onPressed: _continue),
            ]),
            // Banner ekranın en altına sabit; düğmelerden en az 24 px uzak (topGap). Reklam yoksa yer kaplamaz.
            if (!st.premiumUser) const AdSlot(horizontal: AppSpace.edge),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.x1, bottom: AppSpace.x4),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x3, vertical: AppSpace.x2 + 2),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.sm), border: Border.all(color: AppColors.line)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 1), child: ZGlyph(ZGlyphs.crown, size: 18, color: AppColors.accent)),
          const SizedBox(width: AppSpace.x2),
          Expanded(child: Text(text, style: bodyStyle(13, color: AppColors.muted, height: 1.45))),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.on, required this.onTap});

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
        shape: StadiumBorder(side: BorderSide(color: on ? AppColors.primary : AppColors.lineStrong)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            child: Text(label, style: bodyStyle(13.5, weight: FontWeight.w600, color: on ? AppColors.onPrimary : AppColors.ink)),
          ),
        ),
      ),
    );
  }
}

/// Ücretli: zümrüt daire içinde altın taç (yalnız simge). Ücretsiz: yeşil "Ücretsiz" etiketi.
class _PlanMark extends StatelessWidget {
  const _PlanMark({required this.premium});

  final bool premium;

  @override
  Widget build(BuildContext context) {
    if (premium) {
      return Tooltip(
        message: context.t('premium'),
        child: Semantics(
          label: context.t('premium'),
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brandRing, width: 1),
              boxShadow: AppShadows.card,
            ),
            child: const ZGlyph(ZGlyphs.crown, size: 15, color: AppColors.brandRing),
          ),
        ),
      );
    }
    return ZBadge(label: context.t('free'), bg: AppColors.tint, fg: AppColors.ok);
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.inv, required this.theme, required this.name, required this.selected, required this.onTap, required this.onPreview});

  final Invitation inv;
  final InviteTheme theme;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final label = '$name, ${theme.premium ? context.t('premium') : context.t('free')}';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onPreview,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.enter,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md + 3),
                border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
                boxShadow: selected ? const [BoxShadow(color: AppColors.focusRing, spreadRadius: 3)] : AppShadows.card,
              ),
              padding: const EdgeInsets.all(1),
              child: Stack(
                children: [
                  ExcludeSemantics(child: InviteMiniFor(inv: inv, themeId: theme.id)),
                  PositionedDirectional(top: 8, end: 8, child: _PlanMark(premium: theme.premium)),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.x2),
            Row(
              children: [
                if (selected) ...[
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const ZGlyph(ZGlyphs.check, size: 13, color: AppColors.onPrimary),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(14, weight: FontWeight.w700, color: selected ? AppColors.primary : AppColors.ink)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
