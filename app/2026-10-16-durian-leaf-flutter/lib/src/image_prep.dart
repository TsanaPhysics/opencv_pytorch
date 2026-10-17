// เตรียมภาพก่อนเข้าโมเดล: ทำงานใน isolate แยก (compute) เพื่อไม่ให้หน้าจอค้าง
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

const int kInputSize = 224;
const List<double> kMean = [0.485, 0.456, 0.406];
const List<double> kStd = [0.229, 0.224, 0.225];

class PreparedImage {
  final Float32List tensor; // [1,3,224,224] เรียงแบบ NCHW
  final Uint8List previewJpg; // ภาพ 448x448 สำหรับแสดงผล/เก็บประวัติ
  const PreparedImage(this.tensor, this.previewJpg);
}

class PrepRequest {
  final Uint8List bytes;
  final bool cropSquare; // true = ตัดเฉพาะสี่เหลี่ยมกลางภาพ (ใช้กับภาพจากโหมดสด)
  const PrepRequest(this.bytes, {this.cropSquare = false});
}

/// แปลงภาพ 224x224 (RGB 8 บิต) เป็นเทนเซอร์ที่ normalize แล้ว
Float32List imageToTensor(img.Image im) {
  final n = kInputSize * kInputSize;
  final out = Float32List(3 * n);
  for (var y = 0; y < kInputSize; y++) {
    for (var x = 0; x < kInputSize; x++) {
      final p = im.getPixel(x, y);
      final i = y * kInputSize + x;
      out[i] = (p.r / 255.0 - kMean[0]) / kStd[0];
      out[n + i] = (p.g / 255.0 - kMean[1]) / kStd[1];
      out[2 * n + i] = (p.b / 255.0 - kMean[2]) / kStd[2];
    }
  }
  return out;
}

/// ถอดรหัสไฟล์รูป → หมุนตาม EXIF → (ตัดสี่เหลี่ยม) → ย่อเป็น 224 (เหมือนตอนฝึกโมเดล) และ 448 สำหรับแสดงผล
PreparedImage prepareImage(PrepRequest req) {
  var im = img.decodeImage(req.bytes);
  if (im == null) {
    throw const FormatException('เปิดรูปนี้ไม่ได้ กรุณาเลือกไฟล์รูป .jpg หรือ .png');
  }
  im = img.bakeOrientation(im);
  if (req.cropSquare) {
    final side = im.width < im.height ? im.width : im.height;
    im = img.copyCrop(im, x: (im.width - side) ~/ 2, y: (im.height - side) ~/ 2, width: side, height: side);
  }
  // ย่อเป็นขั้น ๆ เพื่อลดรอยหยัก (ใกล้เคียงการย่อแบบ antialias ตอนฝึก)
  var work = im;
  while (work.width > kInputSize * 4 && work.height > kInputSize * 4) {
    work = img.copyResize(work, width: work.width ~/ 2, height: work.height ~/ 2, interpolation: img.Interpolation.average);
  }
  final small = img
      .copyResize(work, width: kInputSize, height: kInputSize, interpolation: img.Interpolation.average)
      .convert(format: img.Format.uint8, numChannels: 3);
  final view = img.copyResize(work, width: 448, height: 448, interpolation: img.Interpolation.average);
  return PreparedImage(imageToTensor(small), Uint8List.fromList(img.encodeJpg(view, quality: 85)));
}

// ------------------- เฟรมจากกล้อง (โหมดสด) -------------------

/// ข้อมูลเฟรมที่ส่งข้าม isolate ได้
class FrameData {
  final List<Uint8List> planes;
  final List<int> rowStrides;
  final List<int> pixelStrides;
  final int width;
  final int height;
  final int rotation; // องศาที่ต้องหมุนตามเข็มนาฬิกาให้ภาพตั้งตรง (sensorOrientation)
  final bool bgra; // iOS = BGRA8888, Android = YUV420

  const FrameData({
    required this.planes,
    required this.rowStrides,
    required this.pixelStrides,
    required this.width,
    required this.height,
    required this.rotation,
    required this.bgra,
  });

  factory FrameData.fromCameraImage(CameraImage ci, int rotation) => FrameData(
        planes: [for (final p in ci.planes) Uint8List.fromList(p.bytes)],
        rowStrides: [for (final p in ci.planes) p.bytesPerRow],
        pixelStrides: [for (final p in ci.planes) p.bytesPerPixel ?? 1],
        width: ci.width,
        height: ci.height,
        rotation: rotation,
        bgra: ci.format.group == ImageFormatGroup.bgra8888,
      );
}

class FrameResult {
  final Float32List tensor;
  final double brightness; // ความสว่างเฉลี่ย 0..255
  const FrameResult(this.tensor, this.brightness);
}

/// ตัดสี่เหลี่ยมกลางภาพ (ส่วนเดียวกับที่เห็นบนจอ) หมุนให้ตั้งตรง แล้วย่อเป็น 224x224 พร้อม normalize
FrameResult frameToTensor(FrameData f) {
  const s = kInputSize;
  final n = s * s;
  final out = Float32List(3 * n);
  final side = f.width < f.height ? f.width : f.height;
  final ox = (f.width - side) / 2.0, oy = (f.height - side) / 2.0;
  final step = side / s;
  double brightSum = 0;

  void rgbAt(int bx, int by, List<double> rgb) {
    if (f.bgra) {
      final i = by * f.rowStrides[0] + bx * 4;
      final b = f.planes[0];
      rgb[0] = b[i + 2].toDouble();
      rgb[1] = b[i + 1].toDouble();
      rgb[2] = b[i].toDouble();
    } else {
      final yv = f.planes[0][by * f.rowStrides[0] + bx].toDouble();
      final uvIndex = (by >> 1) * f.rowStrides[1] + (bx >> 1) * f.pixelStrides[1];
      final u = f.planes[1][uvIndex] - 128.0;
      final v = f.planes[2][(by >> 1) * f.rowStrides[2] + (bx >> 1) * f.pixelStrides[2]] - 128.0;
      rgb[0] = (yv + 1.402 * v).clamp(0, 255).toDouble();
      rgb[1] = (yv - 0.344136 * u - 0.714136 * v).clamp(0, 255).toDouble();
      rgb[2] = (yv + 1.772 * u).clamp(0, 255).toDouble();
    }
  }

  final rgb = List<double>.filled(3, 0);
  final acc = List<double>.filled(3, 0);
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      acc[0] = acc[1] = acc[2] = 0;
      // เฉลี่ย 2x2 จุดในช่องของพิกเซลปลายทาง เพื่อลดรอยหยัก
      for (var sy = 0; sy < 2; sy++) {
        for (var sx = 0; sx < 2; sx++) {
          // พิกัดในภาพที่ตั้งตรงแล้ว (ภายในสี่เหลี่ยม)
          final ux = ((x + 0.25 + 0.5 * sx) * step).floor().clamp(0, side - 1).toInt();
          final uy = ((y + 0.25 + 0.5 * sy) * step).floor().clamp(0, side - 1).toInt();
          int qx, qy; // พิกัดในบัฟเฟอร์ของเซนเซอร์ (ภายในสี่เหลี่ยม)
          switch (f.rotation) {
            case 90:
              qx = uy;
              qy = side - 1 - ux;
              break;
            case 180:
              qx = side - 1 - ux;
              qy = side - 1 - uy;
              break;
            case 270:
              qx = side - 1 - uy;
              qy = ux;
              break;
            default:
              qx = ux;
              qy = uy;
          }
          rgbAt((ox + qx).toInt(), (oy + qy).toInt(), rgb);
          acc[0] += rgb[0];
          acc[1] += rgb[1];
          acc[2] += rgb[2];
        }
      }
      final r = acc[0] / 4, g = acc[1] / 4, b = acc[2] / 4;
      brightSum += 0.299 * r + 0.587 * g + 0.114 * b;
      final i = y * s + x;
      out[i] = (r / 255.0 - kMean[0]) / kStd[0];
      out[n + i] = (g / 255.0 - kMean[1]) / kStd[1];
      out[2 * n + i] = (b / 255.0 - kMean[2]) / kStd[2];
    }
  }
  return FrameResult(out, brightSum / n);
}
