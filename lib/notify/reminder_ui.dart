import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import 'reminder_logic.dart';
import 'reminder_nav.dart';
import 'reminder_service.dart';

/// İlk ücretsiz yayından hemen sonra (kutlama ekranı görünürken) kısa açıklama + bildirim izni.
/// Uygulama açılışında ASLA izin istenmez. Yalnız bir kez sorulur (sonradan Ayarlar > Hatırlatmalar'dan açılır);
/// izin gerekmeyen sürümlerde (Android 12 ve öncesi) hiçbir pencere gösterilmez.
Future<void> askReminderPermissionAfterPublish() async {
  try {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    final r = Reminders.instance;
    if (!await r.shouldAskPermission()) return;
    final ctx = zarflaNavKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final yes = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text(d.t('notifAskTitle'), style: headStyle(20, color: AppColors.ink)),
        content: Text(d.t('notifAskBody', {'n': kExpiryLead.inHours}), style: bodyStyle(14.5, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(d.t('notifAskNo'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(d.t('notifAskYes')),
          ),
        ],
      ),
    );
    await r.markAsked();
    if (yes == true) await r.requestPermission();
  } catch (e) {
    debugPrint('zarfla: reminder permission prompt failed: $e');
  }
}

/// "⋯ > Hatırlatmalar": hatırlatmaları açıp kapatan ayar penceresi.
Future<void> showReminderSettings(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _ReminderSettings());
}

class _ReminderSettings extends StatefulWidget {
  const _ReminderSettings();

  @override
  State<_ReminderSettings> createState() => _ReminderSettingsState();
}

class _ReminderSettingsState extends State<_ReminderSettings> {
  final Reminders _r = Reminders.instance;
  late bool _on = _r.enabled;
  bool _busy = false;
  bool _blocked = false; // açık ama sistem bildirimi kapalı

  @override
  void initState() {
    super.initState();
    _refreshBlocked();
  }

  Future<void> _refreshBlocked() async {
    final blocked = _r.ready && _r.enabled && !await _r.notificationsEnabled();
    if (mounted) setState(() => _blocked = blocked);
  }

  Future<void> _toggle(bool v) async {
    if (_busy) return;
    setState(() {
      _on = v;
      _busy = true;
    });
    final granted = await _r.setEnabled(v);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _blocked = v && !granted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('remSettingsTitle'), style: headStyle(20, color: AppColors.ink)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('remSettingsSwitch'), style: bodyStyle(15, weight: FontWeight.w600)),
              value: _on,
              onChanged: _r.ready && !_busy ? _toggle : null,
            ),
            const SizedBox(height: 4),
            Text(context.t('remSettingsHint', {'n': kExpiryLead.inHours}), style: bodyStyle(13, color: AppColors.muted, height: 1.45)),
            if (_blocked) ...[
              const SizedBox(height: 10),
              Text(context.t('remSettingsBlocked'), style: bodyStyle(13, weight: FontWeight.w600, color: AppColors.err, height: 1.4)),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t('close')))],
    );
  }
}
