// ปรับไฟล์ Android/iOS ที่ `flutter create` สร้างให้ใช้กับหมอใบทุเรียน
// รัน: dart run tool/setup_platforms.dart  (setup.sh เรียกให้อัตโนมัติ)
import 'dart:io';

void log(String s) => stdout.writeln('  • $s');

void main() {
  stdout.writeln('ตั้งค่าแพลตฟอร์มสำหรับหมอใบทุเรียน');
  _android();
  _ios();
  stdout.writeln('เสร็จสิ้น');
}

void _android() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    log('ไม่พบโฟลเดอร์ android — ข้าม (รัน flutter create ก่อน)');
    return;
  }
  var m = manifest.readAsStringSync();
  m = m.replaceAll(RegExp(r'android:label="[^"]*"'), 'android:label="หมอใบทุเรียน"');
  manifest.writeAsStringSync(_ensureCamera(m));
  log('AndroidManifest: ชื่อแอปภาษาไทย + สิทธิ์ใช้กล้อง');

  for (final name in ['android/app/build.gradle.kts', 'android/app/build.gradle']) {
    final f = File(name);
    if (!f.existsSync()) continue;
    var g = f.readAsStringSync();
    g = g
        .replaceAll(RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'), 'minSdk = 24')
        .replaceAll(RegExp(r'minSdkVersion\s+flutter\.minSdkVersion'), 'minSdkVersion 24');
    f.writeAsStringSync(g);
    log('$name: minSdk = 24 (Android 7.0 ขึ้นไป)');
  }

  for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
    final src = File('assets/icon/ic_launcher_$d.png');
    final dst = File('android/app/src/main/res/mipmap-$d/ic_launcher.png');
    if (src.existsSync() && dst.parent.existsSync()) src.copySync(dst.path);
  }
  log('ไอคอนแอป Android');
}

/// แทรกสิทธิ์กล้องหลังแท็ก <manifest ...> (กรณีที่ยังไม่มี)
String _ensureCamera(String m) {
  if (m.contains('android.permission.CAMERA')) return m;
  final match = RegExp(r'<manifest[^>]*>').firstMatch(m);
  if (match == null) return m;
  return '${m.substring(0, match.end)}\n    <uses-permission android:name="android.permission.CAMERA" />${m.substring(match.end)}';
}

void _ios() {
  final plist = File('ios/Runner/Info.plist');
  if (!plist.existsSync()) {
    log('ไม่พบโฟลเดอร์ ios — ข้าม');
    return;
  }
  var p = plist.readAsStringSync();
  void put(String key, String value) {
    final re = RegExp('<key>$key</key>\\s*<string>[^<]*</string>');
    final entry = '<key>$key</key>\n\t<string>$value</string>';
    if (re.hasMatch(p)) {
      p = p.replaceFirst(re, entry);
    } else {
      final i = p.lastIndexOf('</dict>');
      p = '${p.substring(0, i)}\t$entry\n${p.substring(i)}';
    }
  }

  put('CFBundleDisplayName', 'หมอใบทุเรียน');
  put('NSCameraUsageDescription', 'ใช้กล้องถ่ายรูปใบทุเรียนเพื่อตรวจโรค (ประมวลผลในเครื่อง ไม่ส่งรูปออกไป)');
  put('NSPhotoLibraryUsageDescription', 'เลือกรูปใบทุเรียนจากคลังรูปเพื่อตรวจโรค');
  plist.writeAsStringSync(p);
  log('Info.plist: ชื่อแอปภาษาไทย + ข้อความขอสิทธิ์กล้อง/คลังรูป');

  final podfile = File('ios/Podfile');
  if (podfile.existsSync()) {
    var pf = podfile.readAsStringSync();
    pf = pf.replaceFirst(RegExp(r"#?\s*platform :ios, '[0-9.]+'"), "platform :ios, '13.0'");
    podfile.writeAsStringSync(pf);
    log("Podfile: platform :ios, '13.0'");
  }
}
