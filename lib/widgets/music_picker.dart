import 'package:flutter/material.dart';

import '../data/music.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'music_preview.dart';

/// Editördeki "Müzik" bölümü: kategori sekmeleri + parça listesi (dinle/durdur + seçim) + "Müzik yok".
/// Ücretsiz davetiyede seçim kilitli ("1 Davetiye Hakkı ile" rozeti) ama parçalar dinlenebilir (satın almadan önce duyulsun).
class MusicPicker extends StatefulWidget {
  const MusicPicker({
    super.key,
    required this.selected,
    required this.open,
    required this.type,
    required this.onChanged,
  });

  /// Seçili parça kimliği ('' = müzik yok).
  final String selected;

  /// Ücretli davetiye mi (seçim açık mı)?
  final bool open;

  /// Davetiye türü (ilk sekme buna göre seçilir).
  final String type;
  final ValueChanged<String> onChanged;

  @override
  State<MusicPicker> createState() => _MusicPickerState();
}

class _MusicPickerState extends State<MusicPicker> {
  final MusicPreviewPlayer _player = MusicPreviewPlayer();
  late String _cat;

  @override
  void initState() {
    super.initState();
    final sel = musicTrackById(widget.selected);
    _cat = sel?.category ?? musicCategoryForType(widget.type);
    _player.addListener(_onPlayer);
  }

  void _onPlayer() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayer);
    _player.dispose();
    super.dispose();
  }

  void _select(String id) {
    if (!widget.open) return;
    widget.onChanged(id);
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.open;
    final tracks = kMusicTracks.where((t) => t.category == _cat).toList();
    return FieldBlock(
      label: context.t('music'),
      hint: open ? context.t('musicHint') : context.t('musicLockHint'),
      error: _player.failed ? context.t('musicPreviewErr') : null,
      frameError: false,
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
                  Flexible(child: Text(context.t('musicLockBadge'), style: bodyStyle(12, weight: FontWeight.w600, color: AppColors.primary))),
                ],
              ),
            ),
          // "Müzik yok" (varsayılan)
          _row(
            selected: widget.selected.isEmpty,
            title: context.t('musicNone'),
            subtitle: null,
            onTap: open ? () => _select('') : null,
            leading: const SizedBox(width: 44, height: 44, child: Icon(Icons.music_off_outlined, color: AppColors.muted)),
          ),
          const SizedBox(height: 6),
          // Kategori sekmeleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in kMusicCategories)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(context.t('musicCat_$c'), style: bodyStyle(13, weight: FontWeight.w600, color: _cat == c ? AppColors.onPrimary : AppColors.primary)),
                      selected: _cat == c,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.line),
                      onSelected: (_) => setState(() => _cat = c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (final t in tracks)
            _row(
              selected: widget.selected == t.id,
              title: t.title,
              subtitle: t.credit,
              onTap: open ? () => _select(t.id) : null,
              leading: _previewButton(t),
            ),
          MusicPreviewHost(player: _player),
        ],
      ),
    );
  }

  Widget _previewButton(MusicTrack t) {
    final playing = _player.playingId == t.id;
    final label = playing ? context.t('musicStop') : context.t('musicPreview');
    return Semantics(
      button: true,
      label: '$label: ${t.title}',
      excludeSemantics: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          tooltip: label,
          onPressed: () => _player.toggle(t.id, t.url),
          style: IconButton.styleFrom(
            backgroundColor: playing ? AppColors.primary : AppColors.tint,
            foregroundColor: playing ? AppColors.onPrimary : AppColors.primary,
          ),
          icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
        ),
      ),
    );
  }

  Widget _row({required bool selected, required String title, required String? subtitle, required VoidCallback? onTap, required Widget leading}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.tint : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.line, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: bodyStyle(15, weight: FontWeight.w600)),
                      if (subtitle != null) Text(subtitle, style: bodyStyle(12, color: AppColors.muted)),
                    ],
                  ),
                ),
                Semantics(
                  selected: selected,
                  child: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: onTap == null ? AppColors.line : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
