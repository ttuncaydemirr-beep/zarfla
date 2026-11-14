import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'done_screen.dart';

/// Yayınla: Ücretsiz (Papatya, 1 gün, alt yazı) ya da "1 Davetiye Hakkı".
/// Aşama 2: ücretsiz yayın buluta (Firestore + Storage) yazılır. Ücretli yayın Aşama 3'e kadar kapalı ("yakında").
class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key, required this.invId});

  final String invId;

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  String? _plan;
  bool _busy = false;

  Future<void> _publish(String plan) async {
    if (_busy) return;
    if (plan != 'free') {
      showToast(context, context.t('paidSoon'), ms: 4000);
      return;
    }
    final st = context.read<AppState>();
    final inv = st.byId(widget.invId);
    if (inv == null) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final err = await st.publishFree(inv);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showToast(context, context.t(err), ms: 5000);
      return;
    }
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => DoneScreen(invId: inv.id)), (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final inv = st.byId(widget.invId);
    if (inv == null) return const Scaffold(body: SizedBox.shrink());
    final prem = kThemes[inv.theme]?.premium ?? false;
    final plan = prem ? 'premium' : (_plan ?? 'free');
    final price = context.t('price');
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ZTopBar(title: context.t('publish'), leading: const BackBtn()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  H2(context.t('pubTitle')),
                  Para(context.t('pubP')),
                  Opacity(
                    opacity: prem ? 0.55 : 1,
                    child: _PlanCard(
                      title: context.t('free'),
                      price: '0',
                      items: [for (var i = 0; i < 3; i++) context.t('freeL$i')],
                      ok: false,
                      on: plan == 'free',
                      onTap: () {
                        if (prem) {
                          showToast(context, context.t('premThemeNeed'));
                          return;
                        }
                        setState(() => _plan = 'free');
                      },
                    ),
                  ),
                  _PlanCard(
                    title: '♛ ${context.t('pass')}',
                    price: price,
                    items: [for (var i = 0; i < 5; i++) context.t('premL$i')],
                    ok: true,
                    on: plan == 'premium',
                    onTap: () => setState(() => _plan = 'premium'),
                  ),
                  if (prem) NoteBox(context.t('premThemeNeed')),
                  NoteBox(context.t('paidSoon')),
                ],
              ),
            ),
            ZBottomBar(children: [
              PrimaryButton(
                label: _busy
                    ? context.t('cloudPublishing')
                    : plan == 'free'
                        ? context.t('publishFree')
                        : context.t('paidSoonBtn'),
                onPressed: (_busy || plan != 'free') ? null : () => _publish(plan),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.price, required this.items, required this.ok, required this.on, required this.onTap});

  final String title;
  final String price;
  final List<String> items;
  final bool ok;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: on ? AppColors.primary : AppColors.line, width: 1.5),
              boxShadow: on
                  ? const [BoxShadow(color: Color(0x331F3D36), spreadRadius: 3), ...AppShadows.up]
                  : AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: headStyle(17, color: AppColors.ink))),
                    Text(price, style: headStyle(20)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final it in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.check, size: 18, color: ok ? AppColors.ok : AppColors.muted),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(it, style: bodyStyle(14, height: 1.55))),
                      ],
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
