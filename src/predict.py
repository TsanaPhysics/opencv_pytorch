#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
สคริปต์สำหรับการวินิจฉัยโรคใบทุเรียน (Inference Pipeline)
โหลดโมเดล durian_disease_model.pth และจับคู่กับ model_config.json
เพื่อแสดงผลการวินิจฉัย ความน่าจะเป็น (Confidence Score) และคำแนะนำสำหรับเกษตรกร
"""

import os
import sys
import json
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image

def load_inference_pipeline(
    model_path="models/durian_disease_model.pth",
    config_path="configs/model_config.json",
    device=None
):
    """โหลดโมเดลและไฟล์คอนฟิกข้อมูลคลาส"""
    if device is None:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    if not os.path.exists(config_path):
        raise FileNotFoundError(f"ไม่พบไฟล์คอนฟิก: {config_path}")

    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    classes = config.get("classes", [])
    num_classes = len(classes)

    # สถาปัตยกรรม MobileNetV3-Small
    model = models.mobilenet_v3_small(weights=None)
    num_ftrs = model.classifier[3].in_features
    model.classifier[3] = nn.Linear(num_ftrs, num_classes)

    if os.path.exists(model_path):
        checkpoint = torch.load(model_path, map_location=device)
        if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
            model.load_state_dict(checkpoint["model_state_dict"])
        elif isinstance(checkpoint, dict):
            model.load_state_dict(checkpoint)
        else:
            model.load_state_dict(checkpoint)
        print(f"[*] โหลดน้ำหนักโมเดลจาก: {model_path}")
    else:
        print(f"[!] คำเตือน: ยังไม่พบไฟล์น้ำหนัก {model_path} (ใช้งานโมเดลสถาปัตยกรรมตั้งต้น)")

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

def predict_durian_leaf(image_path, model, config, transform, device):
    """
    วิเคราะห์ภาพถ่ายใบทุเรียน
    คืนค่า: Dict ผลการทำนาย, ความมั่นใจ (%), และคำแนะนำการดูแล
    """
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"ไม่พบภาพ: {image_path}")

    image = Image.open(image_path).convert('RGB')
    input_tensor = transform(image).unsqueeze(0).to(device)

    with torch.no_grad():
        outputs = model(input_tensor)
        probabilities = torch.nn.functional.softmax(outputs[0], dim=0)
        confidence, pred_idx = torch.max(probabilities, 0)

    pred_class_en = config["classes"][pred_idx.item()]
    pred_class_th = config.get("th_translations", {}).get(pred_class_en, pred_class_en)
    guideline = config.get("treatment_guidelines", {}).get(pred_class_en, "ไม่มีคำแนะนำเฉพาะ")
    conf_score = confidence.item() * 100

    # จัดอันดับทุกลำดับความน่าจะเป็น
    all_scores = {}
    for idx, c_name in enumerate(config["classes"]):
        th = config.get("th_translations", {}).get(c_name, c_name)
        all_scores[f"{th} ({c_name})"] = round(probabilities[idx].item() * 100, 2)

    return {
        "prediction_th": pred_class_th,
        "prediction_en": pred_class_en,
        "confidence_percentage": round(conf_score, 2),
        "treatment_guideline": guideline,
        "all_class_probabilities": all_scores
    }

if __name__ == "__main__":
    if len(sys.argv) > 1:
        test_img = sys.argv[1]
    else:
        test_img = "data/sample_leaf.jpg"
        print(f"[*] ไม่ได้ระบุภาพ ทดสอบด้วย: {test_img}")

    try:
        model, config, transform, device = load_inference_pipeline()
        if os.path.exists(test_img):
            result = predict_durian_leaf(test_img, model, config, transform, device)
            print("\n" + "="*50)
            print("ผลการวิเคราะห์โรคใบทุเรียนด้วย AI")
            print("="*50)
            print(f"ผลวินิจฉัยหลัก: {result['prediction_th']} ({result['prediction_en']})")
            print(f"ความเชื่อมั่น:   {result['confidence_percentage']}%")
            print(f"แนวทางรักษา:   {result['treatment_guideline']}")
            print("\nสัดส่วนความน่าจะเป็นทุกคลาส:")
            for k, v in result['all_class_probabilities'].items():
                print(f"  - {k}: {v}%")
            print("="*50)
        else:
            print(f"โปรดระบุไฟล์ภาพจริง เช่น: python src/predict.py path/to/leaf.jpg")
    except Exception as e:
        print(f"[!] เกิดข้อผิดพลาด: {e}")
