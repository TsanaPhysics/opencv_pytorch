#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
스คริปต์สำหรับการวินิจฉัยโรคใบทุเรียนขั้นสูง (Advanced Inference & Explainable AI Pipeline)
ผสานเทคโนโลยี:
1. PyTorch Deep Learning (MobileNetV3 / EfficientNet)
2. Explainable AI: Grad-CAM (Gradient-weighted Class Activation Mapping)
3. ระบบประเมินระดับความรุนแรงของโรค (Disease Severity Estimation)
4. คำแนะนำเชิงพยาธิวิทยาพืช (Pathology Prescription) จาก Agri-Microbiology SmartFarm RBRU
"""

import os
import sys
import json
import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import models, transforms
from PIL import Image
import numpy as np

class GradCAM:
    """
    Grad-CAM: Gradient-weighted Class Activation Mapping
    สำหรับสร้างแผนที่ความร้อน (Heatmap) ชี้ตำแหน่งรอยโรคที่โมเดลใช้ในการตัดสินใจ
    """
    def __init__(self, model, target_layer):
        self.model = model
        self.target_layer = target_layer
        self.gradients = None
        self.activations = None
        self.hook_handles = []
        self._register_hooks()

    def _register_hooks(self):
        def forward_hook(module, input, output):
            self.activations = output.detach()

        def backward_hook(module, grad_in, grad_out):
            self.gradients = grad_out[0].detach()

        self.hook_handles.append(self.target_layer.register_forward_hook(forward_hook))
        self.hook_handles.append(self.target_layer.register_backward_hook(backward_hook))

    def generate_cam(self, input_tensor, target_class=None):
        self.model.eval()
        self.model.zero_grad()
        output = self.model(input_tensor)

        if target_class is None:
            target_class = torch.argmax(output, dim=1).item()

        score = output[0, target_class]
        score.backward()

        # Global average pooling of gradients
        weights = torch.mean(self.gradients, dim=[2, 3], keepdim=True)
        cam = torch.sum(weights * self.activations, dim=1).squeeze(0)
        cam = F.relu(cam)

        cam_np = cam.cpu().numpy()
        cam_min, cam_max = cam_np.min(), cam_np.max()
        if cam_max - cam_min > 1e-8:
            cam_np = (cam_np - cam_min) / (cam_max - cam_min)
        else:
            cam_np = np.zeros_like(cam_np)

        return cam_np, target_class, output

    def remove_hooks(self):
        for handle in self.hook_handles:
            handle.remove()

def load_durian_expert_pipeline(
    model_path="models/durian_disease_model.pth",
    config_path="configs/model_config.json",
    device=None
):
    """โหลดโมเดลและคอนฟิกผู้เชี่ยวชาญโรคพืช"""
    if device is None:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    if not os.path.exists(config_path):
        raise FileNotFoundError(f"ไม่พบไฟล์คอนฟิก: {config_path}")

    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    classes = config.get("classes", [])
    num_classes = len(classes)

    # โหลด MobileNetV3-Small
    model = models.mobilenet_v3_small(weights=None)
    num_ftrs = model.classifier[3].in_features
    model.classifier[3] = nn.Linear(num_ftrs, num_classes)

    if os.path.exists(model_path):
        checkpoint = torch.load(model_path, map_location=device)
        if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
            model.load_state_dict(checkpoint["model_state_dict"])
        elif isinstance(checkpoint, dict):
            model.load_state_dict(checkpoint)
        print(f"[*] โหลดน้ำหนักโมเดลจาก: {model_path}")
    else:
        print(f"[!] ไม่พบน้ำหนักที่บันทึก {model_path} กำลังจำลองสถาปัตยกรรมตั้งต้น")

    model = model.to(device)
    model.eval()

    transform = transforms.Compose([
        transforms.Resize(tuple(config.get("image_size", [224, 224]))),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=config.get("normalize_mean", [0.485, 0.456, 0.406]),
            std=config.get("normalize_std", [0.229, 0.224, 0.225])
        )
    ])

    return model, config, transform, device

def analyze_leaf_expert(image_path, model, config, transform, device, generate_heatmap=False):
    """
    วิเคราะห์ภาพถ่ายใบทุเรียนแบบองค์รวม:
    1. วินิจฉัยโรค + เชื้อสาเหตุ
    2. คำนวณความมั่นใจ (Confidence Score %)
    3. คำนวณสัดส่วนพื้นที่แผล (Lesion Area / Severity)
    4. ดึงคำแนะนำการรักษา + เงื่อนไขสภาพอากาศกระตุ้นโรค
    """
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"ไม่พบภาพ: {image_path}")

    raw_image = Image.open(image_path).convert("RGB")
    input_tensor = transform(raw_image).unsqueeze(0).to(device)

    # วิเคราะห์ด้วย Grad-CAM
    target_layer = model.features[-1]
    grad_cam = GradCAM(model, target_layer)
    cam_map, pred_class_idx, outputs = grad_cam.generate_cam(input_tensor)
    grad_cam.remove_hooks()

    probabilities = F.softmax(outputs[0], dim=0)
    confidence = probabilities[pred_class_idx].item() * 100

    pred_en = config["classes"][pred_class_idx]
    pred_th = config.get("th_translations", {}).get(pred_en, pred_en)
    pathogen = config.get("pathogen_scientific_names", {}).get(pred_en, "-")
    guideline = config.get("treatment_guidelines", {}).get(pred_en, "-")
    env_trigger = config.get("environmental_correlation", {}).get(pred_en, None)

    # ประเมินสัดส่วนรอยโรคเบื้องต้นจาก Activation Area (> 0.50)
    lesion_ratio = float(np.mean(cam_map > 0.50) * 100) if pred_en != "Healthy" else 0.0
    if lesion_ratio < 10.0:
        severity = config.get("disease_severity_levels", {}).get("Level_1", "ระดับเริ่มต้น")
    elif lesion_ratio <= 30.0:
        severity = config.get("disease_severity_levels", {}).get("Level_2", "ระดับปานกลาง")
    else:
        severity = config.get("disease_severity_levels", {}).get("Level_3", "ระดับรุนแรง")

    all_scores = {}
    for idx, c_name in enumerate(config["classes"]):
        th = config.get("th_translations", {}).get(c_name, c_name)
        all_scores[f"{th} ({c_name})"] = round(probabilities[idx].item() * 100, 2)

    result = {
        "prediction_th": pred_th,
        "prediction_en": pred_en,
        "pathogen": pathogen,
        "confidence_percentage": round(confidence, 2),
        "estimated_lesion_percentage": round(lesion_ratio, 2),
        "severity_level": severity if pred_en != "Healthy" else "ปกติ",
        "treatment_guideline": guideline,
        "environmental_correlation": env_trigger,
        "all_class_probabilities": all_scores
    }

    return result

if __name__ == "__main__":
    test_img = sys.argv[1] if len(sys.argv) > 1 else "data/sample_leaf.jpg"
    try:
        model, config, transform, device = load_durian_expert_pipeline()
        if os.path.exists(test_img):
            res = analyze_leaf_expert(test_img, model, config, transform, device)
            print("\n" + "="*65)
            print("🌿 รายงานการวินิจฉัยโรคใบทุเรียนขั้นสูง (RBRU Agri-AI Diagnostic)")
            print("="*65)
            print(f"ผลวินิจฉัยหลัก:     {res['prediction_th']} ({res['prediction_en']})")
            print(f"เชื้อสาเหตุโรค:      {res['pathogen']}")
            print(f"ระดับความเชื่อมั่น:   {res['confidence_percentage']}%")
            print(f"ความรุนแรงของโรค:    {res['severity_level']} (พื้นที่แผล ~{res['estimated_lesion_percentage']}%)")
            print(f"แนวทางจัดการแปลง:   {res['treatment_guideline']}")
            if res['environmental_correlation']:
                print(f"ปัจจัยอากาศกระตุ้น:  ความชื้น {res['environmental_correlation']['trigger_rh']} | ฤดูกาล: {res['environmental_correlation']['risk_season']}")
            print("\nความน่าจะเป็นทุกลำดับอาการ:")
            for k, v in res['all_class_probabilities'].items():
                print(f"  • {k}: {v}%")
            print("="*65)
        else:
            print(f"[*] ไม่พบภาพ {test_img} สามารถส่งภาพผ่าน: python src/predict.py path/to/image.jpg")
    except Exception as e:
        print(f"[!] เกิดข้อผิดพลาด: {e}")
