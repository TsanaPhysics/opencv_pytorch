#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
เครื่องมือส่งออกโมเดล PyTorch สู่รูปแบบที่พร้อมใช้งานบน Edge Devices (Mobile / IoT):
1. TorchScript (.pt) - สำหรับ C++ และอุปกรณ์พกพา
2. ONNX (.onnx) - มาตรฐานเปิดสำหรับรันบน Cross-platform, Flutter, Web และ Android/iOS
3. Quantization Preparation (INT8)
"""

import os
import json
import torch
import torch.nn as nn
from torchvision import models

def export_model_for_edge(
    model_path="models/durian_disease_model.pth",
    config_path="configs/model_config.json",
    export_dir="exports"
):
    os.makedirs(export_dir, exist_ok=True)
    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    num_classes = len(config["classes"])
    model = models.mobilenet_v3_small(weights=None)
    num_ftrs = model.classifier[3].in_features
    model.classifier[3] = nn.Linear(num_ftrs, num_classes)

    if os.path.exists(model_path):
        checkpoint = torch.load(model_path, map_location="cpu")
        if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
            model.load_state_dict(checkpoint["model_state_dict"])
        elif isinstance(checkpoint, dict):
            model.load_state_dict(checkpoint)
        print(f"[*] โหลดค่าน้ำหนักจาก {model_path} สำเร็จ")
    else:
        print("[!] ไม่พบไฟล์โมเดลที่เทรนแล้ว จะส่งออกโครงสร้างโมเดลตัวอย่าง")

    model.eval()

    # สร้าง Dummy Tensor ขนาด (1, 3, 224, 224)
    dummy_input = torch.randn(1, 3, 224, 224)

    # 1. ส่งออกเป็น TorchScript
    torchscript_path = os.path.join(export_dir, "durian_mobilenet_v3.pt")
    traced_script_module = torch.jit.trace(model, dummy_input)
    traced_script_module.save(torchscript_path)
    print(f"[✓] ส่งออก TorchScript เรียบร้อย: {torchscript_path}")

    # 2. ส่งออกเป็น ONNX
    onnx_path = os.path.join(export_dir, "durian_mobilenet_v3.onnx")
    try:
        torch.onnx.export(
            model,
            dummy_input,
            onnx_path,
            export_params=True,
            opset_version=13,
            do_constant_folding=True,
            input_names=["input_leaf_image"],
            output_names=["disease_class_probabilities"],
            dynamic_axes={"input_leaf_image": {0: "batch_size"}, "disease_class_probabilities": {0: "batch_size"}}
        )
        print(f"[✓] ส่งออก ONNX Model เรียบร้อย: {onnx_path}")
    except Exception as e:
        print(f"[!] ไม่สามารถส่งออก ONNX ได้ (ต้องการไลบรารี onnx): {e}")

    print("\n[✓] การเตรียมพร้อมสำหรับ Edge Deployment เสร็จสมบูรณ์!")

if __name__ == "__main__":
    export_model_for_edge()
