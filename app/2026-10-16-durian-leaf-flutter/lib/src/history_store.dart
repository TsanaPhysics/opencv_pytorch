// เก็บประวัติการตรวจไว้ในเครื่อง (โฟลเดอร์ของแอป) — ไม่ส่งข้อมูลออกนอกเครื่อง
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'disease.dart';

class HistoryStore {
  static const int maxItems = 50;
  Directory? _dir;

  Future<Directory> _folder() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/history');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  Future<File> _index() async => File('${(await _folder()).path}/index.json');

  Future<List<Diagnosis>> load() async {
    try {
      final f = await _index();
      if (!await f.exists()) return [];
      final list = jsonDecode(await f.readAsString()) as List;
      return list.map((e) => Diagnosis.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Diagnosis> add(Diagnosis d, Uint8List jpg) async {
    final dir = await _folder();
    final name = 'leaf_${d.time.millisecondsSinceEpoch}.jpg';
    await File('${dir.path}/$name').writeAsBytes(jpg, flush: true);
    final saved = Diagnosis(probs: d.probs, cam: d.cam, time: d.time, ms: d.ms, imagePath: '${dir.path}/$name');
    final items = await load();
    items.insert(0, saved);
    while (items.length > maxItems) {
      final old = items.removeLast();
      if (old.imagePath != null) {
        try {
          await File(old.imagePath!).delete();
        } catch (_) {}
      }
    }
    await (await _index()).writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
    return saved;
  }

  Future<void> clear() async {
    final dir = await _folder();
    if (await dir.exists()) await dir.delete(recursive: true);
    _dir = null;
  }
}
