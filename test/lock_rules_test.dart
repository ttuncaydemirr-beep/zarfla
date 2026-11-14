import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/logic/lock_rules.dart';
import 'package:zarfla/models/invitation.dart';

Invitation _ready() => Invitation.create(id: 'test01', type: 'dugun', lang: 'tr', now: 0)
  ..n1 = 'Test A'
  ..n2 = 'Test B'
  ..date = '2027-06-12';

void main() {
  test('taslak ve ücretsiz yayında kilit yok', () {
    final inv = _ready();
    expect(isLocked(inv), isFalse);
    markPublished(inv, 'free');
    expect(isLocked(inv), isFalse);
    expect(canChangeTypeOrTheme(inv), isTrue);
    expect(applyNameEdit(inv, first: true, value: 'X'), EditOutcome.applied);
    expect(inv.n1, 'X');
  });

  test('ücretli yayında tür/tasarım kilitli, haklar ve ilk tarih ayarlanır', () {
    final inv = _ready();
    markPublished(inv, 'premium');
    expect(isLocked(inv), isTrue);
    expect(canChangeTypeOrTheme(inv), isFalse);
    expect(inv.nameEditsLeft, 3);
    expect(inv.dateEditsLeft, 2);
    expect(inv.originalDate, '2027-06-12');
  });

  test('isim: 3 düzeltme, sonra hak yok; değişmeyen ve boş isim hak yemez', () {
    final inv = _ready();
    markPublished(inv, 'premium');
    expect(applyNameEdit(inv, first: true, value: ' Test A '), EditOutcome.unchanged);
    expect(applyNameEdit(inv, first: true, value: ''), EditOutcome.empty);
    expect(inv.nameEditsLeft, 3);
    expect(applyNameEdit(inv, first: true, value: 'Test A1'), EditOutcome.applied);
    expect(applyNameEdit(inv, first: false, value: 'Test B2'), EditOutcome.applied);
    expect(applyNameEdit(inv, first: true, value: 'Test A2'), EditOutcome.applied);
    expect(inv.nameEditsLeft, 0);
    expect(applyNameEdit(inv, first: false, value: 'Başka'), EditOutcome.noRightsLeft);
    expect(inv.n2, 'Test B2');
  });

  test('tarih: ±60 gün penceresi', () {
    final inv = _ready();
    markPublished(inv, 'premium');
    final w = dateWindow(inv)!;
    expect(w.$1, '2027-04-13');
    expect(w.$2, '2027-08-11');
    expect(applyDateEdit(inv, '2027-08-12'), EditOutcome.outOfRange); // +61
    expect(applyDateEdit(inv, '2027-04-12'), EditOutcome.outOfRange); // -61
    expect(inv.dateEditsLeft, 2);
    expect(applyDateEdit(inv, '2027-08-11'), EditOutcome.applied); // +60
    // Pencere ilk tarihe göre kalır, yeni tarihe göre kaymaz.
    expect(applyDateEdit(inv, '2027-09-01'), EditOutcome.outOfRange);
    expect(applyDateEdit(inv, '2027-04-13'), EditOutcome.applied); // -60
    expect(inv.dateEditsLeft, 0);
    expect(applyDateEdit(inv, '2027-06-12'), EditOutcome.noRightsLeft);
  });

  test('aynı tarih hak yemez', () {
    final inv = _ready();
    markPublished(inv, 'premium');
    expect(applyDateEdit(inv, '2027-06-12'), EditOutcome.unchanged);
    expect(inv.dateEditsLeft, 2);
  });
}
