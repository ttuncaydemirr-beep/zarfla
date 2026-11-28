import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/widgets/common.dart';

/// Ad alanları en çok [kNameMax] karakter; sayaç yalnız sınıra yaklaşınca görünür.
void main() {
  Future<TextEditingController> pump(WidgetTester t) async {
    final c = TextEditingController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(controller: c, maxLength: kNameMax, buildCounter: nearLimitCounter(kNameCounterFrom)),
      ),
    ));
    return c;
  }

  testWidgets('uzun ad kırpılır', (t) async {
    final c = await pump(t);
    await t.enterText(find.byType(TextField), 'v' * 40);
    expect(c.text.length, kNameMax);
  });

  testWidgets('sayaç sınıra yaklaşana dek gizli', (t) async {
    await pump(t);
    await t.enterText(find.byType(TextField), 'a' * (kNameCounterFrom - 1));
    await t.pump();
    expect(find.textContaining('/$kNameMax'), findsNothing);
    await t.enterText(find.byType(TextField), 'a' * kNameCounterFrom);
    await t.pump();
    expect(find.text('$kNameCounterFrom/$kNameMax'), findsOneWidget);
  });

  test('editör ad alanları kNameMax kullanır', () {
    final src = File('lib/screens/editor_screen.dart').readAsStringSync();
    expect(src.contains('maxLength: kNameMax'), isTrue);
    expect(src.contains('maxLen(40)'), isFalse);
  });
}
