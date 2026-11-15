import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zarfla/l10n/strings.dart';
import 'package:zarfla/models/invitation.dart';
import 'package:zarfla/startup/startup_log.dart';
import 'package:zarfla/state/app_state.dart';
import 'package:zarfla/storage/invitation_store.dart';
import 'package:zarfla/storage/photo_store.dart';

/// Güncelleme yolu: eski sürümlerin (versionCode 111–141) cihazda bıraktığı veriyle açılış asla çökmemeli.
/// Kayıtlar ilgili commit'lerdeki toJson çıktılarından yeniden kuruldu.

/// Aşama 1 (ed6fe68): notes/live/gift/music/cloud alanları yok; wa yerel biçimde; "yayında" ama bulut kimliği yok.
Map<String, dynamic> stage1Record() => {
      'id': 'old111',
      'type': 'dugun',
      'theme': 'kemer',
      'lang': 'tr',
      'layout': 'klasik',
      'opening': 'door',
      'n1': 'Pelin Su',
      'n2': 'Burak',
      'host': 'Demir ve Yılmaz aileleri',
      'msg': 'Merhaba',
      'date': '2027-06-12',
      'time': '19:00',
      'end': '',
      'venue': 'Salon',
      'address': '',
      'wa': '0532 123 45 67',
      'program': [
        {'t': '19:00', 'x': 'Karşılama'},
      ],
      'cover': '',
      'photos': <String>[],
      'status': 'live',
      'plan': 'premium',
      'nameEditsLeft': 1,
      'dateEditsLeft': 0,
      'originalDate': '2027-06-12',
      'created': 1731000000000,
    };

/// Aşama 2 (650bbef): bulut alanları var; Dalga 1 öncesi (notes yok), müzik/canlı/hediye yok.
Map<String, dynamic> stage2Record() => {
      'id': 'old120',
      'type': 'nisan',
      'theme': 'papatya',
      'lang': 'de',
      'layout': 'kemer',
      'opening': 'env',
      'n1': 'A',
      'n2': 'B',
      'date': '2027-01-05',
      'time': '18:30',
      'venue': 'X',
      'wa': '+49 151 2345678',
      'program': [],
      'cover': 'c.jpg',
      'photos': ['p1.jpg', 'p2.jpg'],
      'status': 'live',
      'plan': 'free',
      'nameEditsLeft': 3,
      'dateEditsLeft': 2,
      'originalDate': null,
      'created': 1732000000000,
      'cloudId': 'AbCdEf123456',
      'expiresAt': 1764000000000,
      'cloudFiles': {
        'c.jpg': {'p': 'invites/AbCdEf123456/c.jpg', 'u': 'https://x/c.jpg'},
        'bad': {'p': 5},
      },
    };

/// Elle bozulmuş / beklenmedik türlerle dolu kayıt: hiçbiri istisnaya yol açmamalı.
Map<String, dynamic> weirdRecord({bool encodable = false}) => {
      'id': 77,
      'type': null,
      'theme': 'silinmis_tema',
      'lang': 'fr',
      'layout': 3,
      'opening': ['x'],
      'n1': {'a': 1},
      'n2': true,
      'msg': 12.0,
      'date': 20270101,
      'time': null,
      'wa': '+90 532 123 45 67',
      'program': [
        'Sadece metin',
        {'time': '20:00', 'text': 'Eski biçim'},
        if (encodable) {'1': 'sayı anahtarlı'} else {1: 'sayı anahtarlı'},
        null,
        42,
      ],
      'notes': 'tek metin',
      'photos': [null, '', 'a.jpg', 'a.jpg', 7],
      'status': 'yayinda',
      'plan': 3,
      'nameEditsLeft': '2',
      'dateEditsLeft': 9,
      'created': 1.7e12,
      'cloudId': 0,
      'expiresAt': '1764000000000',
      'cloudFiles': ['x'],
      'music': {'id': 'y'},
      'liveUrl': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Invitation.fromJson eski biçimler', () {
    test('Aşama 1 kaydı yüklenir, eksik alanlar varsayılan; wa normalleşir', () {
      final inv = Invitation.fromJson(stage1Record());
      expect(inv.id, 'old111');
      expect(inv.theme, 'kemer');
      expect(inv.notes, isEmpty);
      expect(inv.liveUrl, '');
      expect(inv.giftIban, '');
      expect(inv.music, '');
      expect(inv.cloudId, isNull);
      expect(inv.cloudFiles, isEmpty);
      expect(inv.wa, '905321234567');
      expect(inv.program.single.x, 'Karşılama');
      // Yeniden kaydedilip okunabilir
      expect(Invitation.fromJson(jsonDecode(jsonEncode(inv.toJson())) as Map<String, dynamic>).toJson(), inv.toJson());
    });

    test('Aşama 2 kaydı: bulut alanları korunur, bozuk cloudFiles girdisi atlanır', () {
      final inv = Invitation.fromJson(stage2Record());
      expect(inv.cloudId, 'AbCdEf123456');
      expect(inv.expiresAt, 1764000000000);
      expect(inv.cloudFiles.keys, ['c.jpg']);
      expect(inv.originalDate, isNull);
      expect(inv.wa, '491512345678');
      expect(inv.lang, 'de');
      expect(inv.photos, ['p1.jpg', 'p2.jpg']);
    });

    test('beklenmedik türler: istisna yok, güvenli varsayılanlar', () {
      final inv = Invitation.fromJson(weirdRecord());
      expect(inv.id, '77');
      expect(inv.type, 'diger');
      expect(inv.theme, 'papatya');
      expect(inv.lang, 'tr');
      expect(inv.layout, 'klasik');
      expect(inv.opening, 'door');
      expect(inv.n1, '');
      expect(inv.n2, '');
      expect(inv.msg, '12');
      expect(inv.date, '20270101');
      expect(inv.time, '19:00');
      expect(inv.wa, '905321234567');
      expect(inv.program.map((e) => e.x), ['Sadece metin', 'Eski biçim', '']);
      expect(inv.program[1].t, '20:00');
      expect(inv.notes, isEmpty);
      expect(inv.photos, ['a.jpg']);
      expect(inv.status, 'draft');
      expect(inv.plan, isNull);
      expect(inv.nameEditsLeft, 2);
      expect(inv.dateEditsLeft, 2);
      expect(inv.created, 1700000000000);
      expect(inv.cloudId, isNull);
      expect(inv.expiresAt, 1764000000000);
      expect(inv.cloudFiles, isEmpty);
      expect(inv.music, '');
      expect(() => jsonEncode(inv.toJson()), returnsNormally);
    });

    test('boş harita ve eski wa biçimleri', () {
      expect(() => Invitation.fromJson(<String, dynamic>{}), returnsNormally);
      expect(normalizeStoredWa('905321234567', 'tr'), '905321234567');
      expect(normalizeStoredWa('0090 532 123 45 67', 'tr'), '905321234567');
      expect(normalizeStoredWa('0151 2345678', 'de'), '491512345678');
      expect(normalizeStoredWa('', 'tr'), '');
      expect(normalizeStoredWa('abc', 'tr'), 'abc');
    });
  });

  group('decodeInvitations', () {
    test('bozuk JSON: boş liste, ham metin yedeğe', () {
      final r = decodeInvitations('{bozuk');
      expect(r.invitations, isEmpty);
      expect(r.unreadable, ['{bozuk']);
    });

    test('liste olmayan, null, boş metin', () {
      expect(decodeInvitations(null).invitations, isEmpty);
      expect(decodeInvitations('').invitations, isEmpty);
      expect(decodeInvitations('42').unreadable, isNotEmpty);
      expect(decodeInvitations(jsonEncode(stage1Record())).invitations.single.id, 'old111'); // tek kayıt
    });

    test('tek tek çözülür: harita olmayan girdiler atlanır, diğerleri yüklenir; kimlikler benzersiz', () {
      final raw = jsonEncode([
        stage1Record(),
        'çöp',
        stage2Record(),
        {'id': 'old111', 'type': 'kina'},
        {'type': 'dogum'},
        {'id': '', 'type': 'dogum', 'created': 5},
        weirdRecord(encodable: true),
      ]);
      final r = decodeInvitations(raw);
      expect(r.invitations.length, 6);
      expect(r.unreadable, ['çöp']);
      final ids = r.invitations.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.first, 'old111');
      expect(ids, contains('old111_1'));
    });
  });

  group('AppState.init eski verilerle', () {
    test('Aşama 1 + 2 + bozuk kayıtlar ve yanlış türdeki ayarlar: açılır, geçişler uygulanır', () async {
      SharedPreferences.setMockInitialValues({
        'zarfla_invs_v1': jsonEncode([stage1Record(), stage2Record(), weirdRecord(encodable: true), 5]),
        'zarfla_lang': 7, // yanlış tür
        'zarfla_premium_user': 'true', // yanlış tür
        'zarfla_pending_paid_v1': 'bozuk',
      });
      final st = AppState(strings: AppStrings({'tr': {}}), store: InvitationStore(), photos: PhotoStore());
      await st.init(); // testte path_provider yok: fotoğraf klasörü adımı hata kaydeder ama açılış sürer
      expect(st.lang, 'tr');
      expect(st.premiumUser, isTrue);
      expect(st.invitations.length, 3);
      final a = st.byId('old111')!;
      expect(a.status, 'draft'); // Aşama 1 "yayını" taslağa döndü
      expect(a.plan, isNull);
      expect(a.n1, ''); // örnek isim temizlendi
      expect(a.host, '');
      expect(st.byId('old120')!.isLive, isTrue);
      expect(st.sorted, hasLength(3));
      // Geçiş kalıcı ve yeniden açılış aynı sonucu verir
      final st2 = AppState(strings: AppStrings({'tr': {}}), store: InvitationStore(), photos: PhotoStore());
      await st2.init();
      expect(st2.invitations.map((e) => e.id), st.invitations.map((e) => e.id));
      expect(st2.byId('old111')!.status, 'draft');
      expect(() => st.photoFile('x.jpg'), returnsNormally);
    });

    test('tamamen bozuk liste: boş açılır, ham veri yedeklenir ve kaydetmeden sonra da durur', () async {
      SharedPreferences.setMockInitialValues({'zarfla_invs_v1': '[{"id": "x",'});
      final st = AppState(strings: AppStrings({'tr': {}}), store: InvitationStore(), photos: PhotoStore());
      await st.init();
      expect(st.invitations, isEmpty);
      await st.add(Invitation.create(id: 'n1', type: 'dugun', lang: 'tr', now: 1));
      final p = await SharedPreferences.getInstance();
      expect(p.getString('zarfla_invs_unreadable_v1'), contains('[{\\"id\\": \\"x\\",'));
    });

    test('anahtar başka türde yazılmış (liste): açılış sürer', () async {
      SharedPreferences.setMockInitialValues({
        'zarfla_invs_v1': <String>['a', 'b'],
        'zarfla_sample_names_cleared_v1': 'yes',
      });
      final st = AppState(strings: AppStrings({'tr': {}}), store: InvitationStore(), photos: PhotoStore());
      await st.init();
      expect(st.invitations, isEmpty);
    });

    test('startBilling faturalandırma yokken sessizce döner', () async {
      SharedPreferences.setMockInitialValues({});
      final st = AppState(strings: AppStrings({'tr': {}}), store: InvitationStore(), photos: PhotoStore());
      await st.init();
      await st.startBilling();
      await st.warmUpCloud();
    });
  });

  group('metinler ve hata kaydı', () {
    test('eksik ARB anahtarı anahtarın kendisini döner, bozuk ARB boş harita', () {
      final s = AppStrings({
        'tr': {'a': 'A {n}'},
        'en': {},
      });
      expect(s.get('en', 'a', {'n': 1}), 'A 1');
      expect(s.get('de', 'yok'), 'yok');
      expect(AppStrings.parseArb('[1,2]'), isEmpty);
      expect(AppStrings.parseArb('{"k": 5, "x": "y", "@x": {}}'), {'x': 'y'});
    });

    test('StartupLog.record istisna fırlatmaz ve rapora sürüm yazılır', () async {
      SharedPreferences.setMockInitialValues({});
      StartupLog.record('test', StateError('boom'), StackTrace.current);
      StartupLog.record('test', StateError('boom'));
      expect(StartupLog.entries, isNotEmpty);
      expect(StartupLog.report(), contains('Zarfla $appVersionName'));
      expect(StartupLog.report(), contains('boom'));
      await StartupLog.clear();
      expect(StartupLog.entries, isEmpty);
    });
  });
}
