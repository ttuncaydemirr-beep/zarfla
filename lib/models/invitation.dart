import '../data/catalog.dart';

/// Program satırı (saat + açıklama). Önizlemedeki {t, x}.
class ProgramStep {
  ProgramStep({this.t = '', this.x = ''});

  String t;
  String x;

  Map<String, dynamic> toJson() => {'t': t, 'x': x};

  factory ProgramStep.fromJson(Map<String, dynamic> j) =>
      ProgramStep(t: (j['t'] ?? '').toString(), x: (j['x'] ?? '').toString());
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
    this.cover = '',
    List<String>? photos,
    this.status = 'draft',
    this.plan,
    this.nameEditsLeft = 3,
    this.dateEditsLeft = 2,
    this.originalDate,
  })  : program = program ?? <ProgramStep>[],
        photos = photos ?? <String>[];

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
        'cover': cover,
        'photos': photos,
        'status': status,
        'plan': plan,
        'nameEditsLeft': nameEditsLeft,
        'dateEditsLeft': dateEditsLeft,
        'originalDate': originalDate,
        'created': created,
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
    final photos = <String>[];
    if (j['photos'] is List) {
      for (final e in j['photos'] as List) {
        if (e is String && e.isNotEmpty) photos.add(e);
      }
    }
    final plan = j['plan'] == null ? null : j['plan'].toString();
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
      cover: s('cover'),
      photos: photos,
      status: s('status') == 'live' ? 'live' : 'draft',
      plan: (plan == 'free' || plan == 'premium') ? plan : null,
      nameEditsLeft: n('nameEditsLeft', 3),
      dateEditsLeft: n('dateEditsLeft', 2),
      originalDate: j['originalDate']?.toString(),
    );
  }

  /// Davetli sayfasına (invite.html → window.renderInvite) giden veri.
  /// Fotoğraflar çağıran tarafından data URI (önizleme) ya da URL (Aşama 2) olarak verilir.
  Map<String, dynamic> toInviteData({required String coverSrc, required List<String> photoSrcs}) => {
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
        'cover': coverSrc,
        'photos': photoSrcs,
        'status': status,
        'plan': plan,
      };
}
