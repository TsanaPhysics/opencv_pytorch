// โหลดโมเดล ONNX และประมวลผลในเครื่อง (onnxruntime ผ่าน dart:ffi)
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'image_prep.dart';

class ModelOutput {
  final List<double> probs; // [4]
  final List<double> cam; // [49] = 7x7
  final double ms;
  const ModelOutput(this.probs, this.cam, this.ms);
}

class Classifier {
  OrtSession? _session;
  OrtSessionOptions? _options;
  bool _running = false;

  bool get ready => _session != null;

  Future<void> load() async {
    if (_session != null) return;
    OrtEnv.instance.init();
    final opts = OrtSessionOptions()
      ..setIntraOpNumThreads(2)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    final raw = await rootBundle.load('assets/model/app_model.onnx');
    _session = OrtSession.fromBuffer(raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes), opts);
    _options = opts;
  }

  /// tensor = Float32List ขนาด 3x224x224 (NCHW) ที่ normalize แล้ว
  Future<ModelOutput> run(Float32List tensor) async {
    final session = _session;
    if (session == null) throw StateError('โมเดลยังไม่พร้อม');
    // ONNX Runtime ทำงานทีละคำขอ ป้องกันการเรียกซ้อน
    while (_running) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    _running = true;
    final input = OrtValueTensor.createTensorWithDataList(tensor, [1, 3, kInputSize, kInputSize]);
    final runOptions = OrtRunOptions();
    final sw = Stopwatch()..start();
    List<OrtValue?>? outputs;
    try {
      outputs = await session.runAsync(runOptions, {'image': input});
      outputs ??= session.run(runOptions, {'image': input});
      final probsRaw = (outputs[0]!.value as List).first as List;
      final camRaw = (outputs[1]!.value as List).first as List;
      final probs = [for (final v in probsRaw) (v as num).toDouble()];
      final cam = <double>[
        for (final row in camRaw)
          for (final v in row as List) (v as num).toDouble()
      ];
      return ModelOutput(probs, cam, sw.elapsedMicroseconds / 1000.0);
    } finally {
      input.release();
      runOptions.release();
      if (outputs != null) {
        for (final o in outputs) {
          o?.release();
        }
      }
      _running = false;
    }
  }

  void dispose() {
    _session?.release();
    _options?.release();
    _session = null;
    OrtEnv.instance.release();
  }
}
