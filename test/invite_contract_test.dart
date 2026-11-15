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
      n1: 'Test A',
      n2: 'Test B',
      msg: 'Sizi "aramızda" görmek isteriz.\nSevgiyle',
      date: '2027-06-12',
      venue: 'Test Venue',
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
        'venue', 'address', 'wa', 'program', 'notes', 'cover', 'photos', 'status', 'plan',
      ]);
      expect(m['status'], 'live');
      expect(m['plan'], 'free');
      expect(m['cover'], 'https://x/c');
      expect(m['photos'], ['https://x/1', 'https://x/2']);
      // Kuralların aradığı birebir parçalar
      expect(j.contains('"n1":"Test A"'), isTrue);
      expect(j.contains('"n2":"Test B"'), isTrue);
      expect(j.contains('"date":"2027-06-12"'), isTrue);
      expect(j.contains('"status":"live"'), isTrue);
      expect(j.contains('"plan":"free"'), isTrue);
      // Kullanıcı metnindeki tırnaklar kaçışlı → anahtar sahteciliği yok; \u00XX harf kaçışı üretilmez
      expect(RegExp(r'\\u00[2-7][0-9a-fA-F]').hasMatch(j), isFalse);
      expect('"theme"'.allMatches(j).length, 1);
    });

    test('notes: temizlenir (kırp, boş ele, ≤4, ≤140) ve JSON\'da program\'dan sonra gelir', () {
      final inv = _inv()
        ..notes = ['  Birinci not  ', '', 'x' * 200, 'üç', 'dört', 'beş'];
      final j = inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'free', coverUrl: '', photoUrls: []);
      final m = jsonDecode(j) as Map<String, dynamic>;
      final notes = (m['notes'] as List).cast<String>();
      expect(notes.length, 4);
      expect(notes[0], 'Birinci not');
      expect(notes[1].length, 140);
      expect(notes.sublist(2), ['üç', 'dört']);
      final keys = m.keys.toList();
      expect(keys.indexOf('notes'), keys.indexOf('program') + 1);
      expect(jsonDecode(jsonEncode(Invitation.fromJson(inv.toJson()).toJson()))['notes'], hasLength(4));
    });

    test('live: geçerli https bağlantı her planda yazılır, geçersiz bağlantı yazılmaz', () {
      final inv = _inv()
        ..liveUrl = ' https://youtu.be/abc '
        ..liveNote = 'Yayın 19:00\'da';
      for (final plan in ['free', 'premium']) {
        final m = jsonDecode(inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: plan, coverUrl: '', photoUrls: [])) as Map<String, dynamic>;
        expect(m['live'], {'url': 'https://youtu.be/abc', 'note': 'Yayın 19:00\'da'});
      }
      inv.liveUrl = 'javascript:alert(1)';
      final m2 = jsonDecode(inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'premium', coverUrl: '', photoUrls: [])) as Map<String, dynamic>;
      expect(m2.containsKey('live'), isFalse);
    });

    test('gift: YALNIZ ücretli planda, geçerli IBAN + hesap sahibiyle yazılır; ücretsizde asla', () {
      final inv = _inv()
        ..giftHolder = 'Ali Demir'
        ..giftIban = 'tr33 0006 1005 1978 6457 8413 26'
        ..giftBank = 'Örnek Banka';
      final paid = inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'premium', coverUrl: '', photoUrls: []);
      final pm = jsonDecode(paid) as Map<String, dynamic>;
      expect(pm['gift'], {'holder': 'Ali Demir', 'iban': 'TR330006100519786457841326', 'bank': 'Örnek Banka'});
      final keys = pm.keys.toList();
      expect(keys.indexOf('gift'), keys.indexOf('notes') + 1);
      final free = inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'free', coverUrl: '', photoUrls: []);
      expect(free.contains('iban'), isFalse, reason: free);
      expect(RegExp(r'"iban"\s*:').hasMatch(free), isFalse);
      // geçersiz IBAN ya da boş hesap sahibi: ücretli planda bile yazılmaz
      inv.giftIban = 'TR330006100519786457841327';
      expect(jsonDecode(inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'premium', coverUrl: '', photoUrls: [])).containsKey('gift'), isFalse);
      inv
        ..giftIban = 'TR330006100519786457841326'
        ..giftHolder = '  ';
      expect(jsonDecode(inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'premium', coverUrl: '', photoUrls: [])).containsKey('gift'), isFalse);
    });

    test('music: YALNIZ ücretli planda ve seçkideki parçaysa üst düzeyde yazılır; ücretsizde asla', () {
      final inv = _inv()..music = 'dugun-wagner';
      final pm = jsonDecode(inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'premium', coverUrl: '', photoUrls: [])) as Map<String, dynamic>;
      expect(pm['music'], 'dugun-wagner');
      final keys = pm.keys.toList();
      expect(keys.indexOf('music'), keys.indexOf('notes') + 1); // live/gift yokken notes'tan hemen sonra
      expect(keys.indexOf('music'), lessThan(keys.indexOf('cover')));
      final free = inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'free', coverUrl: '', photoUrls: []);
      expect(RegExp(r'"music"\s*:').hasMatch(free), isFalse, reason: free);
      // bilinmeyen kimlik ücretli planda bile yazılmaz; yerel kayıtta da temizlenir
      inv.music = '../x';
      expect(jsonDecode(inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'premium', coverUrl: '', photoUrls: [])).containsKey('music'), isFalse);
      expect(Invitation.fromJson({'id': 'x', 'music': '../x'}).music, '');
      expect(Invitation.fromJson({'id': 'x', 'music': 5}).music, '');
      expect(Invitation.fromJson({'id': 'x'}).music, '');
      inv.music = 'kutlama-joplin';
      expect(Invitation.fromJson(inv.toJson()).music, 'kutlama-joplin');
      // müzik + IBAN + canlı yayın birlikte: sıra notes, live, gift, music
      inv
        ..liveUrl = 'https://youtu.be/a'
        ..giftHolder = 'Ali Demir'
        ..giftIban = 'TR330006100519786457841326';
      final all = (jsonDecode(inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'premium', coverUrl: '', photoUrls: [])) as Map<String, dynamic>).keys.toList();
      expect(all.sublist(all.indexOf('notes'), all.indexOf('notes') + 4), ['notes', 'live', 'gift', 'music']);
    });

    test('gift/live: tırnaklı metin anahtar sahteciliği yapmaz; eski kayıtta alanlar boş', () {
      final inv = _inv()
        ..giftHolder = '"theme":"altin"'
        ..giftIban = 'TR330006100519786457841326'
        ..liveUrl = 'https://youtu.be/a'
        ..liveNote = '"plan":"premium"';
      final j = inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'premium', coverUrl: '', photoUrls: []);
      expect('"theme"'.allMatches(j).length, 1);
      expect('"plan"'.allMatches(j).length, 1);
      expect(RegExp(r'\\u00[2-7][0-9a-fA-F]').hasMatch(j), isFalse);
      final old = Invitation.fromJson({'id': 'x'});
      expect([old.liveUrl, old.liveNote, old.giftHolder, old.giftIban, old.giftBank], everyElement(''));
      final rt = Invitation.fromJson(inv.toJson());
      expect(rt.giftIban, 'TR330006100519786457841326');
      expect(rt.liveUrl, 'https://youtu.be/a');
    });

    test('notes: boşsa [] gider; sahte tırnaklı not anahtar sahteciliği yapmaz', () {
      var j = inviteDataJson(_inv(), publicId: 'AbCdEf123456', localPlan: 'free', coverUrl: '', photoUrls: []);
      expect(jsonDecode(j)['notes'], isEmpty);
      final inv = _inv()..notes = ['"theme":"altin"'];
      j = inviteDataJson(inv, publicId: 'AbCdEf123456', localPlan: 'free', coverUrl: '', photoUrls: []);
      expect('"theme"'.allMatches(j).length, 1);
      expect(RegExp(r'\\u00[2-7][0-9a-fA-F]').hasMatch(j), isFalse);
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
      final keys = RegExp(r"'([A-Za-z0-9]+)'").allMatches(m.group(1)!).map((x) => x.group(1)).toSet();
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
      expect(cloudSafeName('Te"st\\ A'), 'Test A');
      expect(cloudSafeName('Çağla & Şükrü'), 'Çağla & Şükrü');
      expect(cloudSafeName('اختبار'), 'اختبار');
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
