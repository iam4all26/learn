import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';

/// Welcome-slide content set by the admin (Admin > App Onboarding).
/// Pictures are downloaded ONCE into the app's own files folder and reused from there.
/// This is plain files (not SharedPreferences), so logging out does not erase them.
class OnboardingService {
  static const String _endpoint = '${ApiConfig.baseUrl}/onboarding.php';

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/onboarding');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// What is saved on this phone (instant, works offline). Each slide: black, accent, subtitle, file (local path or '').
  static Future<List<Map<String, String>>> loadSaved() async {
    try {
      final f = File('${(await _dir()).path}/slides.json');
      if (!await f.exists()) return [];
      final data = json.decode(await f.readAsString());
      final out = <Map<String, String>>[];
      for (final s in (data['slides'] as List)) {
        final file = (s['file'] ?? '').toString();
        out.add({
          'black': (s['black'] ?? '').toString(),
          'accent': (s['accent'] ?? '').toString(),
          'subtitle': (s['subtitle'] ?? '').toString(),
          'file': (file.isNotEmpty && await File(file).exists()) ? file : '',
        });
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Asks the server for the slides. Returns true when something new was saved. Never throws.
  static Future<bool> refresh() async {
    try {
      final res = await http.get(Uri.parse(_endpoint)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return false;
      final data = json.decode(res.body);
      if (data['status'] != 'success') return false;
      final version = (data['version'] ?? '').toString();
      final dir = await _dir();
      final meta = File('${dir.path}/slides.json');

      if (await meta.exists()) {
        try {
          final old = json.decode(await meta.readAsString());
          if (old['version'] == version) {
            // same content: only make sure every picture file is still there
            final slides = (old['slides'] as List);
            bool allThere = true;
            for (final s in slides) {
              final p = (s['file'] ?? '').toString();
              if ((s['image'] ?? '').toString().isNotEmpty && (p.isEmpty || !await File(p).exists())) allThere = false;
            }
            if (allThere) return false;
          }
        } catch (_) {}
      }

      final saved = <Map<String, String>>[];
      final keep = <String>{'slides.json'};
      for (final s in (data['slides'] as List)) {
        final image = (s['image'] ?? '').toString();
        String file = '';
        if (image.isNotEmpty && image.startsWith('https://')) {
          try {
            final name = 'img_${image.hashCode.toUnsigned(32)}.bin';
            final target = File('${dir.path}/$name');
            if (!await target.exists()) {
              final r = await http.get(Uri.parse(image)).timeout(const Duration(seconds: 20));
              if (r.statusCode == 200 && r.bodyBytes.isNotEmpty && r.bodyBytes.length < 8 * 1024 * 1024) {
                await target.writeAsBytes(r.bodyBytes, flush: true);
              }
            }
            if (await target.exists()) { file = target.path; keep.add(name); }
          } catch (_) {}
        }
        saved.add({
          'black': (s['black'] ?? '').toString(),
          'accent': (s['accent'] ?? '').toString(),
          'subtitle': (s['subtitle'] ?? '').toString(),
          'image': image,
          'file': file,
        });
      }
      await meta.writeAsString(json.encode({'version': version, 'slides': saved}), flush: true);

      // remove pictures that are no longer used
      await for (final e in dir.list()) {
        final n = e.path.split('/').last;
        if (e is File && !keep.contains(n)) { try { await e.delete(); } catch (_) {} }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
