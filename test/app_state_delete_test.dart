import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zarfla/l10n/strings.dart';
import 'package:zarfla/models/invitation.dart';
import 'package:zarfla/state/app_state.dart';
import 'package:zarfla/storage/invitation_store.dart';
import 'package:zarfla/storage/photo_store.dart';

/// Silme: onay → gizle → 5 sn "Geri al" → gerçekten sil (UX #9).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> make() async {
    SharedPreferences.setMockInitialValues({});
    final st = AppState(strings: AppStrings({'tr': {}}), store: InvitationStore(), photos: PhotoStore());
    await st.add(Invitation.create(id: 'a1', type: 'dugun', lang: 'tr', now: 1));
    await st.add(Invitation.create(id: 'b2', type: 'nisan', lang: 'tr', now: 2));
    return st;
  }

  test('gizlenen davetiye listede görünmez, geri alınınca döner; cihazdan silinmez', () async {
    final st = await make();
    st.hideForDelete(st.byId('a1')!);
    expect(st.sorted.map((i) => i.id), ['b2']);
    expect(st.isHidden('a1'), isTrue);
    expect(st.invitations.length, 2); // uygulama kapanırsa kaybolmaz
    st.undoDelete('a1');
    expect(st.sorted.map((i) => i.id), ['b2', 'a1']);
    expect(await st.commitDelete('a1'), isNull); // gizli değilse hiçbir şey silinmez
    expect(st.invitations.length, 2);
  });

  test('süre dolunca commitDelete gerçekten siler (taslak: bulut yok)', () async {
    final st = await make();
    st.hideForDelete(st.byId('a1')!);
    expect(await st.commitDelete('a1'), isNull);
    expect(st.byId('a1'), isNull);
    expect(st.isHidden('a1'), isFalse);
    expect(st.sorted.map((i) => i.id), ['b2']);
  });

  test('bulut silinemezse davetiye geri gelir ve hata anahtarı döner', () async {
    final st = await make();
    final inv = st.byId('a1')!
      ..status = 'live'
      ..cloudId = 'AbCdEf123456';
    st.hideForDelete(inv);
    expect(await st.commitDelete('a1'), 'delCloudErr'); // testte bulut yok
    expect(st.byId('a1'), isNotNull);
    expect(st.sorted.map((i) => i.id), contains('a1'));
  });

  test('her kayıtta "Kaydedildi" sayacı artar', () async {
    final st = await make();
    final before = st.savedTick.value;
    await st.save();
    expect(st.savedTick.value, before + 1);
  });
}
