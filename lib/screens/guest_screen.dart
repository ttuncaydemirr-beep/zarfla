import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../widgets/invite_view.dart';

/// "Davetli gibi aç": davetli sayfası tam ekran.
class GuestScreen extends StatelessWidget {
  const GuestScreen({super.key, required this.invId});

  final String invId;

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<AppState>().byId(invId);
    return Scaffold(
      backgroundColor: Colors.black,
      body: inv == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: Column(
                children: [
                  // İnce üst çubuk: kapat düğmesi davetiye içeriğini örtmez, içerik çubuğun altından başlar.
                  Container(
                    height: 48,
                    color: const Color(0xCC000000),
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: Semantics(
                      button: true,
                      label: context.t('close'),
                      child: IconButton(
                        tooltip: context.t('close'),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        style: IconButton.styleFrom(backgroundColor: const Color(0x33FFFFFF), foregroundColor: Colors.white),
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  Expanded(child: InviteView(inv: inv)),
                ],
              ),
            ),
    );
  }
}
