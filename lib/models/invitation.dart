import '../data/catalog.dart';
import '../data/music.dart';
import '../logic/iban.dart';
import '../logic/url_check.dart';

/// Program satırı (saat + açıklama). Önizlemedeki {t, x}.
class ProgramStep {
  ProgramStep({this.t = '', this.x = ''});

  String t;
  String x;

  Map<String, dynamic> toJson() => {'t': t, 'x': x};

  factory ProgramStep.fromJson(Map<String, dynamic> j) =>
      ProgramStep(t: (j['t'] ?? '').toString(), x: (j['x'] ?? '').toString());
}

/// "Ricalarımız" notları: en çok [kMaxNotes] satır, her biri en çok [kNoteLen] karakter.
/// [trim] true ise baştaki/sondaki boşluklar atılır ve boş satırlar elenir (yayın/yükleme);
/// false ise satırlar olduğu gibi (boş satır dahil) korunur (editörde yazarken).
List<String> sanitizeNotes(Object? src, {bool trim = true}) {
  final out = <String>[];
  if (src is! List) return out;
  for (final e in src) {
    if (e is! String) continue;
    var s = e;
    if (trim) s = s.trim();
    if (s.length > kNoteLen) s = s.substring(0, kNoteLen);
    if (trim) {
      s = s.trim();
      if (s.isEmpty) continue;
    }
    out.add(s);
    if (out.length >= kMaxNotes) break;
  }
  return out;
}

/// Buluta yüklenmiş bir fotoğraf: Storage yolu + indirme URL'si.
class CloudFile {
  const CloudFile({required this.path, required this.url});

  final String path;
  final String url;

  Map<String, dynamic> toJson() => {'p': path, 'u': url};

  static CloudFile? fromJson(Object? j) {
    if (j is! Map) return null;
    final p = j['p'], u = j['u'];
    if (p is! String || u is! String || p.isEmpty || u.isEmpty) return null;
    return CloudFile(path: p, url: u);
  }
}

/// Davetiye. Alan adları web önizlemesiyle (ve davetli sayfasının veri sözleşmesiyle) aynıdır.
class Invitation {
  Invitation({
    required this.id,
    required this.type,
    required this.theme,
    required this.lang,
    required this.created,
    this.layout = 'klasik',
    this.opening = 'door',
    this.n1 = '',
    this.n2 = '',
    this.host = '',
    this.msg = '',
    this.date = '',
    this.time = '19:00',
    this.end = '',
    this.venue = '',
    this.address = '',
    this.wa = '',
    List<ProgramStep>? program,
    List<String>? notes,
    this.liveUrl = '',
    this.liveNote = '',
    this.giftHolder = '',
    this.giftIban = '',
    this.giftBank = '',
    this.music = '',
    this.cover = '',
    List<String>? photos,
    this.status = 'draft',
    this.plan,
    this.nameEditsLeft = 3,
    this.dateEditsLeft = 2,
    this.originalDate,
    this.cloudId,
    this.expiresAt,
    Map<String, CloudFile>? cloudFiles,
  })  : program = program ?? <ProgramStep>[],
        notes = notes ?? <String>[],
        photos = photos ?? <String>[],
        cloudFiles = cloudFiles ?? <String, CloudFile>{};

  String id;
  String type;
  String theme;
  String lang;
  String layout;
  String opening;
  String n1;
  String n2;
  String host;
  String msg;

  /// yyyy-MM-dd
  String date;

  /// HH:mm
  String time;
  String end;
  String venue;
  String address;
  String wa;
  List<ProgramStep> program;

  /// Davetlilerden ricalar (en çok 4 not, her biri en çok 140 karakter). Editörde boş satır olabilir.
  List<String> notes;

  /// Canlı yayın bağlantısı (https) ve kısa notu; ücretsiz ve ücretli davetiyede kullanılabilir. '' = yok.
  String liveUrl;
  String liveNote;

  /// Hediye IBAN'ı (YALNIZ ücretli davetiye): hesap sahibi, IBAN (boşluksuz, büyük harf), banka adı. '' = yok.
  String giftHolder;
  String giftIban;
  String giftBank;

  /// Arka plan müziği: kMusicTracks'teki parça kimliği ('' = müzik yok). YALNIZ ücretli davetiyede yayımlanır.
  String music;

  /// Kapak fotoğrafının uygulama belgeler klasöründeki dosya adı ('' = yok).
  String cover;

  /// Galeri dosya adları (en çok 6).
  List<String> photos;

  /// 'draft' | 'live'
  String status;

  /// null | 'free' | 'premium'
  String? plan;

  /// Yayın sonrası (ücretli) kalan isim düzeltme hakkı.
  int nameEditsLeft;

  /// Yayın sonrası (ücretli) kalan tarih değişikliği hakkı.
  int dateEditsLeft;

  /// Ücretli yayın anındaki tarih (±60 gün penceresinin merkezi).
  String? originalDate;
  int created;

  /// Firestore belge kimliği (invites/{cloudId}); yayında değilse null.
  String? cloudId;

  /// Bağlantının kapanacağı an (ms, UTC epoch); yayında değilse null.
  int? expiresAt;

  /// Yerel fotoğraf dosya adı → buluttaki kopyası (yalnız değişen fotoğraflar yeniden yüklenir).
  Map<String, CloudFile> cloudFiles;

  /// Bağlantının süresi doldu mu?
  bool isExpiredAt(DateTime now) => isLive && expiresAt != null && now.millisecondsSinceEpoch >= expiresAt!;

  bool get isLive => status == 'live';
  bool get isCouple => kCoupleTypes.contains(type);

  /// Yeni taslak (önizlemedeki newInvite + REC ilk tasarım).
  factory Invitation.create({required String id, required String type, required String lang, required int now}) {
    final msgs = kMessages[lang]?[type] ?? const <String>[];
    final rec = kRecommended[type];
    return Invitation(
      id: id,
      type: type,
      theme: (rec != null && rec.isNotEmpty) ? rec.first : 'papatya',
      lang: lang,
      created: now,
      msg: msgs.isNotEmpty ? msgs.first : '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'theme': theme,
        'lang': lang,
        'layout': layout,
        'opening': opening,
        'n1': n1,
        'n2': n2,
        'host': host,
        'msg': msg,
        'date': date,
        'time': time,
        'end': end,
        'venue': venue,
        'address': address,
        'wa': wa,
        'program': program.map((e) => e.toJson()).toList(),
        'notes': sanitizeNotes(notes, trim: false),
        'liveUrl': liveUrl,
        'liveNote': liveNote,
        'giftHolder': giftHolder,
        'giftIban': giftIban,
        'giftBank': giftBank,
        'music': music,
        'cover': cover,
        'photos': photos,
        'status': status,
        'plan': plan,
        'nameEditsLeft': nameEditsLeft,
        'dateEditsLeft': dateEditsLeft,
        'originalDate': originalDate,
        'created': created,
        'cloudId': cloudId,
        'expiresAt': expiresAt,
        'cloudFiles': cloudFiles.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Invitation.fromJson(Map<String, dynamic> j) {
    String s(String k, [String d = '']) => j[k] == null ? d : j[k].toString();
    int n(String k, int d) => j[k] is int ? j[k] as int : int.tryParse('${j[k]}') ?? d;
    final type = kEventTypes.contains(s('type')) ? s('type') : 'diger';
    final theme = kThemes.containsKey(s('theme')) ? s('theme') : 'papatya';
    final lang = kLangs.contains(s('lang')) ? s('lang') : 'tr';
    final layout = kLayouts.contains(s('layout')) ? s('layout') : 'klasik';
    final opening = kOpenings.contains(s('opening')) ? s('opening') : 'door';
    final prog = <ProgramStep>[];
    if (j['program'] is List) {
      for (final e in j['program'] as List) {
        if (e is Map) prog.add(ProgramStep.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    final notes = sanitizeNotes(j['notes'], trim: false);
    final photos = <String>[];
    if (j['photos'] is List) {
      for (final e in j['photos'] as List) {
        if (e is String && e.isNotEmpty) photos.add(e);
      }
    }
    final plan = j['plan'] == null ? null : j['plan'].toString();
    final files = <String, CloudFile>{};
    if (j['cloudFiles'] is Map) {
      (j['cloudFiles'] as Map).forEach((k, v) {
        final f = CloudFile.fromJson(v);
        if (k is String && f != null) files[k] = f;
      });
    }
    final cloudId = j['cloudId'] is String && (j['cloudId'] as String).isNotEmpty ? j['cloudId'] as String : null;
    final expiresAt = j['expiresAt'] is int ? j['expiresAt'] as int : null;
    return Invitation(
      id: s('id'),
      type: type,
      theme: theme,
      lang: lang,
      created: n('created', 0),
      layout: layout,
      opening: opening,
      n1: s('n1'),
      n2: s('n2'),
      host: s('host'),
      msg: s('msg'),
      date: s('date'),
      time: s('time', '19:00'),
      end: s('end'),
      venue: s('venue'),
      address: s('address'),
      wa: s('wa'),
      program: prog,
      notes: notes,
      liveUrl: s('liveUrl'),
      liveNote: s('liveNote'),
      giftHolder: s('giftHolder'),
      giftIban: s('giftIban'),
      giftBank: s('giftBank'),
      music: cleanMusicId(j['music']),
      cover: s('cover'),
      photos: photos,
      status: s('status') == 'live' ? 'live' : 'draft',
      plan: (plan == 'free' || plan == 'premium') ? plan : null,
      nameEditsLeft: n('nameEditsLeft', 3),
      dateEditsLeft: n('dateEditsLeft', 2),
      originalDate: j['originalDate']?.toString(),
      cloudId: cloudId,
      expiresAt: expiresAt,
      cloudFiles: files,
    );
  }

  /// Davetli sayfasına (invite.html → window.renderInvite) giden veri.
  /// Fotoğraflar çağıran tarafından data URI (önizleme) ya da URL (Aşama 2) olarak verilir.
  /// ANAHTAR SIRASI SÖZLEŞMEDİR: Firestore kuralları JSON'un `{"id":…,"type":…,"theme":…,`
  /// ile başladığını denetler (bkz. firestore.rules). [publicId] verilirse id yerine o yazılır.
  Map<String, dynamic> toInviteData({
    required String coverSrc,
    required List<String> photoSrcs,
    String? publicId,
    String? planOverride,
  }) {
    final effPlan = planOverride ?? plan;
    final liveClean = cleanLiveUrl(liveUrl);
    final giftIbanN = normalizeIban(giftIban);
    final giftHolderC = cleanGiftText(giftHolder, kGiftHolderMax);
    // IBAN yalnız ücretli planda ve geçerliyse yazılır (ücretsizde asla; kurallar da reddeder).
    final giftOk = effPlan == 'premium' && giftHolderC.isNotEmpty && isValidIban(giftIbanN);
    // Müzik yalnız ücretli planda ve seçkideki bir parçaysa yazılır (ücretsizde asla; kurallar da reddeder).
    final musicId = effPlan == 'premium' ? cleanMusicId(music) : '';
    return {
        'id': publicId ?? id,
        'type': type,
        'theme': theme,
        'lang': lang,
        'layout': layout,
        'opening': opening,
        'n1': n1,
        'n2': n2,
        'host': host,
        'msg': msg,
        'date': date,
        'time': time,
        'end': end,
        'venue': venue,
        'address': address,
        'wa': wa,
        'program': program.map((e) => e.toJson()).toList(),
        'notes': sanitizeNotes(notes),
        if (liveClean.isNotEmpty) 'live': {'url': liveClean, 'note': cleanGiftText(liveNote, kLiveNoteMax)},
        if (giftOk) 'gift': {'holder': giftHolderC, 'iban': giftIbanN, 'bank': cleanGiftText(giftBank, kGiftBankMax)},
        if (musicId.isNotEmpty) 'music': musicId,
        'cover': coverSrc,
        'photos': photoSrcs,
        'status': status,
        'plan': effPlan,
      };
  }
}
