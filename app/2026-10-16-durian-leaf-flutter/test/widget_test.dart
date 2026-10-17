// ทดสอบตรรกะที่ไม่ต้องใช้มือถือ: เกณฑ์ความมั่นใจ วันที่ภาษาไทย และการเตรียมภาพ
import 'dart:typed_data';

import 'package:durian_leaf_doctor/src/disease.dart';
import 'package:durian_leaf_doctor/src/image_prep.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('เกณฑ์ความมั่นใจตรงกับเว็บแอป', () {
    expect(confidenceLevel(94, 90), Confidence.high);
    expect(confidenceLevel(86, 20), Confidence.medium);
    expect(confidenceLevel(70, 50), Confidence.medium);
    expect(confidenceLevel(55, 30), Confidence.low);
  });

  test('วันที่แบบไทย (พ.ศ.)', () {
    expect(thaiDateTime(DateTime(2026, 10, 16, 15, 3)), '16 ต.ค. 2569 15:03');
  });

  test('ลำดับคลาสตรงกับโมเดล', () {
    expect(kClasses, ['Algal Leaf Spot', 'Healthy', 'Leaf Blight', 'Leaf Spot']);
    for (final c in kClasses) {
      expect(kInfo.containsKey(c), isTrue);
    }
  });

  test('เตรียมภาพ: ได้เทนเซอร์ 3x224x224 และภาพแสดงผล', () {
    final im = img.Image(width: 640, height: 480);
    img.fill(im, color: img.ColorRgb8(255, 0, 0));
    final prep = prepareImage(PrepRequest(Uint8List.fromList(img.encodeJpg(im)), cropSquare: true));
    expect(prep.tensor.length, 3 * 224 * 224);
    // สีแดงล้วน: ช่อง R ≈ (1-0.485)/0.229, ช่อง G ≈ (0-0.456)/0.224
    expect(prep.tensor[0], closeTo((1 - 0.485) / 0.229, 0.05));
    expect(prep.tensor[224 * 224], closeTo((0 - 0.456) / 0.224, 0.05));
    expect(img.decodeJpg(prep.previewJpg)!.width, 448);
  });

  test('เฟรมกล้อง YUV420 สีเทากลาง → ค่ากลาง ๆ', () {
    const w = 320, h = 240;
    final f = FrameData(
      planes: [Uint8List(w * h)..fillRange(0, w * h, 128), Uint8List(w * h ~/ 2)..fillRange(0, w * h ~/ 2, 128), Uint8List(w * h ~/ 2)..fillRange(0, w * h ~/ 2, 128)],
      rowStrides: [w, w, w],
      pixelStrides: [1, 2, 2],
      width: w,
      height: h,
      rotation: 90,
      bgra: false,
    );
    final r = frameToTensor(f);
    expect(r.tensor.length, 3 * 224 * 224);
    expect(r.brightness, closeTo(128, 1));
  });
}
