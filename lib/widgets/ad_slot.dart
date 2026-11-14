import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Banner reklam yer tutucusu: sabit 50dp yükseklik (ekran zıplamaz).
/// Yalnız Davetiyelerim ve Tasarım galerisinde; ödeme yapmış kullanıcıda gösterilmez.
/// Aşama 3'te AdMob banner (320x50) ile değiştirilecek.
class AdSlot extends StatelessWidget {
  const AdSlot({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 24, bottom: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.sand,
        border: Border.all(color: AppColors.field),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(label, style: bodyStyle(12, color: AppColors.muted)),
    );
  }
}
