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
    inv.n1 = 'Pelin';
    expect(invitationTitle(inv, 'İsimsiz'), 'Pelin');
    inv.n2 = 'Burak';
    expect(invitationTitle(inv, 'İsimsiz'), 'Pelin & Burak');
    expect(chipLabel('a' * 50).length, 47);
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
}
