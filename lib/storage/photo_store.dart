import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Fotoğraflar uygulamanın belgeler klasöründe (photos/) tutulur; davetiyede
/// yalnız dosya adı saklanır. Küçültme ve sıkıştırma seçim anında image_picker
/// tarafından yapılır (maxWidth/maxHeight + imageQuality) — ek yerel eklenti gerekmez.
class PhotoStore {
  Directory? _dir;
  final _rnd = Random();

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/photos');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
  }

  Directory get dir {
    final d = _dir;
    if (d == null) throw StateError('PhotoStore.init çağrılmadı');
    return d;
  }

  File fileFor(String name) => File('${dir.path}/$name');

  /// Baytları kaydeder, dosya adını döner. Yer yoksa FileSystemException fırlatır.
  Future<String> saveBytes(Uint8List bytes) async {
    if (bytes.isEmpty || sniffMime(bytes) == null) {
      throw const FormatException('not an image');
    }
    final ext = _extFor(sniffMime(bytes)!);
    final name = '${DateTime.now().microsecondsSinceEpoch}_${_rnd.nextInt(1 << 30).toRadixString(36)}.$ext';
    final f = fileFor(name);
    try {
      await f.writeAsBytes(bytes, flush: true);
    } catch (e) {
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
      rethrow;
    }
    return name;
  }

  Future<void> delete(String name) async {
    if (name.isEmpty) return;
    try {
      final f = fileFor(name);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Önizleme için data URI (webview'a base64 olarak geçer).
  Future<String> dataUri(String name) async {
    if (name.isEmpty) return '';
    try {
      final bytes = await fileFor(name).readAsBytes();
      final mime = sniffMime(bytes) ?? 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      return '';
    }
  }

  static String _extFor(String mime) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }

  /// Dosya imzasından görüntü türü.
  static String? sniffMime(List<int> b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
    if (b.length >= 12 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'image/webp';
    }
    if (b.length >= 4 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return 'image/gif';
    return null;
  }
}
