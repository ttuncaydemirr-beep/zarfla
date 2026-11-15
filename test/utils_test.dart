import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/logic/date_utils.dart';
import 'package:zarfla/logic/text_utils.dart';
import 'package:zarfla/models/invitation.dart';

void main() {
  test('shiftIsoDate ay/yıl/artık yıl sınırları', () {
    expect(shiftIsoDate('2027-01-31', 1), '2027-02-01');
    expect(shiftIsoDate('2027-12-31', 1), '2028-01-01');
    expect(shiftIsoDate('2028-02-28', 1), '2028-02-29');
    expect(shiftIsoDate('2027-03-01', -60), '2026-12-31');
    expect(parseIsoDate('2027-02-30'), isNull);
  });

  test('Türkçe büyük harf (i→İ, ı→I)', () {
    expect(upperFor('istanbul ılık', 'tr'), 'İSTANBUL ILIK');
    expect(upperFor('Düğün Davetiyesi', 'tr'), 'DÜĞÜN DAVETİYESİ');
    expect(upperFor('invitation', 'en'), 'INVITATION');
  });

  test('başlık ve çip etiketi', () {
    final inv = Invitation.create(id: 'a', type: 'nisan', lang: 'tr', now: 0);
    expect(invitationTitle(inv, 'İsimsiz'), 'İsimsiz');
    inv.n1 = 'Test A';
    expect(invitationTitle(inv, 'İsimsiz'), 'Test A');
    inv.n2 = 'Test B';
    expect(invitationTitle(inv, 'İsimsiz'), 'Test A & Test B');
    expect(chipLabel('a' * 50), 'a' * 50);
    expect(chipLabel('a' * 100).length, 95);
  });

  test('Invitation JSON gidiş-dönüş ve normalleştirme', () {
    final inv = Invitation.create(id: 'abc', type: 'dugun', lang: 'de', now: 5)
      ..program.add(ProgramStep(t: '19:00', x: 'Empfang'))
      ..photos.add('p1.jpg');
    final back = Invitation.fromJson(inv.toJson());
    expect(back.toJson(), inv.toJson());
    expect(back.theme, 'kemer'); // REC.dugun[0]
    final bad = Invitation.fromJson({'id': 'x', 'type': '??', 'layout': 'yok', 'opening': 'yok', 'theme': 'yok'});
    expect(bad.type, 'diger');
    expect(bad.layout, 'klasik');
    expect(bad.opening, 'door');
    expect(bad.theme, 'papatya');
  });

  test('notes: depolamada boş satır korunur, en çok 4 satır ve 140 karakter; yeni açılış/tasarım geçerli', () {
    final inv = Invitation.fromJson({
      'id': 'n',
      'theme': 'nar',
      'opening': 'sarmasik',
      'notes': ['a', '', 7, 'b' * 150, 'c', 'd', 'e'],
    });
    expect(inv.theme, 'nar');
    expect(inv.opening, 'sarmasik');
    expect(inv.notes.length, 4);
    expect(inv.notes[1], '');
    expect(inv.notes[2].length, 140);
    expect(Invitation.fromJson(inv.toJson()).notes, inv.notes);
    expect(Invitation.fromJson({'id': 'm'}).notes, isEmpty);
  });
}
