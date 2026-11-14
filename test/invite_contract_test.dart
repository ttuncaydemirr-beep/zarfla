import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/cloud/invite_contract.dart';
import 'package:zarfla/models/invitation.dart';

Invitation _inv({String plan = 'free'}) => Invitation(
      id: 'yerel123',
      type: 'nisan',
      theme: 'papatya',
      lang: 'tr',
      created: 0,
      n1: 'Pelin Su',
      n2: 'Burak',
      msg: 'Sizi "aramızda" görmek isteriz.\nSevgiyle',
      date: '2027-06-12',
      venue: 'Baler Garden',
      wa: '905551112233',
      program: [ProgramStep(t: '19:00', x: 'Karşılama')],
      cover: 'c.jpg',
      photos: ['a.jpg', 'b.jpg'],
      plan: plan,
    );

void main() {
  group('kimlik', () {
    test('12 karakter, yalnız [A-Za-z0-9], benzersiz', () {
      final ids = <String>{};
      for (var i = 0; i < 2000; i++) {
        final id = generateInviteId();
        expect(id.length, 12);
        expect(RegExp(r'^[A-Za-z0-9]{12}$').hasMatch(id), isTrue, reason: id);
        expect(isValidInviteId(id), isTrue);
        ids.add(id);
      }
      expect(ids.length, 2000);
    });

    test('tüm karakter kümesini kullanır (dağılım)', () {
      final seen = <String>{};
      final r = Random(42);
      for (var i = 0; i < 3000; i++) {
        seen.addAll(generateInviteId(r).split(''));
      }
      expect(seen.length, 62);
    });

    test('geçersiz kimlikler', () {
      expect(isValidInviteId('kisa'), isFalse);
      expect(isValidInviteId('AbCdEf12345_'), isFalse);
      expect(isValidInviteId('AbCdEf1234567'), isFalse);
    });
  });

  group('bağlantı', () {
    test('biçim', () {
      expect(inviteUrl('AbCdEf123456'), 'https://ttuncaydemirr-beep.github.io/davetiye/?id=AbCdEf123456');
      expect(inviteUrlDisplay('AbCdEf123456'), 'ttuncaydemirr-beep.github.io/davetiye/?id=AbCdEf123456');
    });

    test('kodda eski "davet/" bağlantısı kalmadı', () {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        expect(f.readAsStringSync().contains('github.io/davet/'), isFalse, reason: f.path);
      }
    });
  });

  group('süreler', () {
    final t = DateTime.utc(2026, 11, 15, 10, 30);
    test('free +24 saat, paid +365 gün, deleteAt +30 gün', () {
      expect(expiresAtFor('free', t), DateTime.utc(2026, 11, 16, 10, 30));
      expect(expiresAtFor('paid', t), DateTime.utc(2027, 11, 15, 10, 30));
      expect(deleteAtFor(DateTime.utc(2026, 11, 16, 10, 30)), DateTime.utc(2026, 12, 16, 10, 30));
    });
    test('plan eşlemesi', () {
      expect(cloudPlanOf('premium'), 'paid');
      expect(cloudPlanOf('free'), 'free');
      expect(cloudPlanOf(null), 'free');
    });
  });

  group('data JSON', () {
    test('kurallardaki önek ve anahtar sırası', () {
      final j = inviteDataJson(_inv(),
          publicId: 'AbCdEf123456', localPlan: 'free', coverUrl: 'https://x/c', photoUrls: ['https://x/1', 'https://x/2']);
      expect(j.startsWith('{"id":"AbCdEf123456","type":"nisan","theme":"papatya",'), isTrue, reason: j);
      final m = jsonDecode(j) as Map<String, dynamic>;
      expect(m.keys.toList(), [
        'id', 'type', 'theme', 'lang', 'layout', 'opening', 'n1', 'n2', 'host', 'msg', 'date', 'time', 'end', //
        'venue', 'address', 'wa', 'program', 'cover', 'photos', 'status', 'plan',
      ]);
      expect(m['status'], 'live');
      expect(m['plan'], 'free');
      expect(m['cover'], 'https://x/c');
      expect(m['photos'], ['https://x/1', 'https://x/2']);
      // Kuralların aradığı birebir parçalar
      expect(j.contains('"n1":"Pelin Su"'), isTrue);
      expect(j.contains('"n2":"Burak"'), isTrue);
      expect(j.contains('"date":"2027-06-12"'), isTrue);
      expect(j.contains('"status":"live"'), isTrue);
      expect(j.contains('"plan":"free"'), isTrue);
      // Kullanıcı metnindeki tırnaklar kaçışlı → anahtar sahteciliği yok; \u00XX harf kaçışı üretilmez
      expect(RegExp(r'\\u00[2-7][0-9a-fA-F]').hasMatch(j), isFalse);
      expect('"theme"'.allMatches(j).length, 1);
    });

    test('ücretli → plan "premium" (alt yazı gizlenir)', () {
      final j = inviteDataJson(_inv(plan: 'premium'), publicId: 'AbCdEf123456', localPlan: 'premium', coverUrl: '', photoUrls: []);
      expect(jsonDecode(j)['plan'], 'premium');
    });
  });

  group('belge alanları', () {
    test('alan seti kurallardaki whitelist ile aynı', () {
      final inv = _inv();
      final f = newInviteFields(
        ownerUid: 'u1',
        plan: 'free',
        dataJson: '{}',
        expiresAt: DateTime.utc(2026, 11, 16),
        lock: lockFields(inv, origDate: inv.date),
      );
      expect({...f.keys, 'createdAt'}, kInviteDocKeys.toSet());
      expect(f['schema'], 1);
      expect(f['status'], 'live');
      expect(f['deleteAt'], DateTime.utc(2026, 12, 16));
      expect(f['nameEdits'], 0);
      expect(f['dateEdits'], 0);
      expect(f['origDate'], '2027-06-12');

      final rules = File('firestore.rules').readAsStringSync();
      final m = RegExp(r'hasOnly\(\[([^\]]*)\]\)').firstMatch(rules)!;
      final keys = RegExp(r"'([A-Za-z]+)'").allMatches(m.group(1)!).map((x) => x.group(1)).toSet();
      expect(keys, kInviteDocKeys.toSet());
    });

    test('düzeltme sayaçları kalan haklardan', () {
      final inv = _inv(plan: 'premium')
        ..nameEditsLeft = 1
        ..dateEditsLeft = 2;
      final l = lockFields(inv, origDate: '2027-06-01');
      expect(l['nameEdits'], 2);
      expect(l['dateEdits'], 0);
      expect(l['origDate'], '2027-06-01');
    });

    test('isimde yasak karakterler', () {
      expect(cloudSafeName('Pe"lin\\ Su'), 'Pelin Su');
      expect(cloudSafeName('Çağla & Şükrü'), 'Çağla & Şükrü');
      expect(cloudSafeName('نورة'), 'نورة');
    });
  });

  group('Storage', () {
    test('yol ve dosya adları', () {
      expect(storagePath('AbCdEf123456', storageFileName('cover', 'image/webp')), 'invites/AbCdEf123456/cover.webp');
      expect(storageFileName('g1', 'image/jpeg'), 'g1.jpg');
      expect(storageFileName('g6', 'image/png'), 'g6.png');
    });
    test('boş galeri yuvası', () {
      const id = 'AbCdEf123456';
      expect(freeGallerySlot(id, []), 'g1');
      expect(freeGallerySlot(id, ['invites/$id/cover.jpg', 'invites/$id/g1.jpg', 'invites/$id/g2.webp']), 'g3');
      expect(freeGallerySlot(id, [for (var i = 1; i <= 6; i++) 'invites/$id/g$i.jpg']), isNull);
    });
  });

  group('ücretsiz sınırı ve süre', () {
    test('aktif ücretsiz sayısı', () {
      final now = DateTime.now();
      final a = _inv()
        ..id = 'a'
        ..status = 'live'
        ..cloudId = 'AbCdEf123456'
        ..expiresAt = now.add(const Duration(hours: 3)).millisecondsSinceEpoch;
      final b = _inv()
        ..id = 'b'
        ..status = 'live'
        ..cloudId = 'ZyXwVu987654'
        ..expiresAt = now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      final c = _inv()..id = 'c';
      expect(activeFreeCount([a, b, c], now), 1);
      expect(activeFreeCount([a, b, c], now, exceptId: 'a'), 0);
      expect(a.isExpiredAt(now), isFalse);
      expect(b.isExpiredAt(now), isTrue);
      expect(c.isExpiredAt(now), isFalse);
    });

    test('bulut alanları JSON gidiş-dönüş', () {
      final i = _inv()
        ..status = 'live'
        ..cloudId = 'AbCdEf123456'
        ..expiresAt = 123456789
        ..cloudFiles = {'a.jpg': const CloudFile(path: 'invites/AbCdEf123456/g1.jpg', url: 'https://x/1')};
      final r = Invitation.fromJson(jsonDecode(jsonEncode(i.toJson())) as Map<String, dynamic>);
      expect(r.cloudId, 'AbCdEf123456');
      expect(r.expiresAt, 123456789);
      expect(r.cloudFiles['a.jpg']!.path, 'invites/AbCdEf123456/g1.jpg');
      expect(r.cloudFiles['a.jpg']!.url, 'https://x/1');
    });
  });
}
