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
          : Stack(
              children: [
                Positioned.fill(child: SafeArea(child: InviteView(inv: inv))),
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0x8C000000),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 48),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(context.t('close')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
