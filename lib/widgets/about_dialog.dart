import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../startup/startup_log.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// "⋯ > Hakkında": yüklü sürüm ("Sürüm 1.0.<kod>") ve varsa hata kaydı (kopyalanıp geliştiriciye iletilir).
Future<void> showZarflaAbout(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final problems = StartupLog.hasProblems;
      final report = problems ? StartupLog.report() : '';
      return AlertDialog(
        title: Text(context.t('app'), style: headStyle(20, color: AppColors.ink)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('versionLbl', {'v': appVersionName}), style: bodyStyle(15, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(context.t('by'), style: bodyStyle(13, color: AppColors.muted)),
              if (problems) ...[
                const SizedBox(height: 14),
                Text(context.t('errLogTitle'), style: bodyStyle(14, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(context.t('errLogHint'), style: bodyStyle(12.5, color: AppColors.muted, height: 1.4)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      report,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (problems)
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: report));
                if (ctx.mounted) showToast(ctx, ctx.t('copied'));
              },
              child: Text(context.t('copy')),
            ),
          if (problems)
            TextButton(
              onPressed: () async {
                await StartupLog.clear();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(context.t('errLogClear')),
            ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.t('close'))),
        ],
      );
    },
  );
}

/// Ana ekran bandı: önceki açılış beklenmedik şekilde kapandıysa (güvenli kip) bilgi + "Ayrıntılar".
class SafeModeBanner extends StatelessWidget {
  const SafeModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!StartupLog.safeMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ZCard(
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 20, color: AppColors.err),
            const SizedBox(width: 10),
            Expanded(child: Text(context.t('safeModeNote'), style: bodyStyle(13, height: 1.4))),
            TextButton(onPressed: () => showZarflaAbout(context), child: Text(context.t('errLogDetails'))),
          ],
        ),
      ),
    );
  }
}
