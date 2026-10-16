#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
สคริปต์สำหรับการเทรนโมเดลตรวจจับโรคใบทุเรียน (Durian Leaf Disease Detection)
สถาปัตยกรรม: MobileNetV3-Small (Transfer Learning) ด้วย PyTorch & Torchvision
รองรับทั้งการรันบน Google Colab (GPU) และ Local Environment
"""

import os
import json
import urllib.request
import zipfile
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, random_split
from torchvision import datasets, transforms, models

def get_transforms():
    """ส่งคืน Data Pipeline Transform ทั้งสำหรับ Train และ Validation"""
    return {
        'train': transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(20),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ]),
        'val': transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ])
    }

def create_model(num_classes, weights_preset=models.MobileNet_V3_Small_Weights.DEFAULT):
    """สร้างและปรับแต่ง Layer ปลายทางของ MobileNetV3-Small"""
    model = models.mobilenet_v3_small(weights=weights_preset)
    num_ftrs = model.classifier[3].in_features
    model.classifier[3] = nn.Linear(num_ftrs, num_classes)
    return model

def train_durian_model(
    data_dir="data/durian_dataset",
    output_dir="models",
    config_dir="configs",
    epochs=10,
    batch_size=16,
    lr=0.0005,
    device=None
):
    if device is None:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[*] อุปกรณ์ที่ใช้งาน (Compute Device): {device}")

    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(config_dir, exist_ok=True)

    tforms = get_transforms()

    # ตรวจสอบการมีอยู่ของ Dataset
    if not os.path.exists(data_dir):
        print(f"[!] ไม่พบโฟลเดอร์ {data_dir} กำลังสร้าง Mock Dataset สำหรับทดสอบระบบ...")
        mock_classes = ["Algal Leaf Spot", "Leaf Blight", "Leaf Spot", "Healthy"]
        for c in mock_classes:
            os.makedirs(os.path.join(data_dir, c), exist_ok=True)
            # สร้างภาพจำลอง dummy 1 ภาพต่อคลาส
            dummy_img_path = os.path.join(data_dir, c, "sample_dummy.png")
            if not os.path.exists(dummy_img_path):
                from PIL import Image
                img = Image.new('RGB', (224, 224), color=(73, 109, 137))
                img.save(dummy_img_path)

    full_dataset = datasets.ImageFolder(data_dir, transform=tforms['train'])
    class_names = full_dataset.classes
    num_classes = len(class_names)
    print(f"[*] คลาสโรคที่ตรวจพบ ({num_classes} คลาส): {class_names}")

    # แบ่ง Train 80% / Val 20%
    train_size = int(0.8 * len(full_dataset))
    val_size = len(full_dataset) - train_size
    train_dataset, val_dataset = random_split(full_dataset, [train_size, val_size])
    val_dataset.dataset.transform = tforms['val']

    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, num_workers=0)
    val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False, num_workers=0)

    model = create_model(num_classes).to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)

    best_val_acc = 0.0

    print(f"\n[*] เริ่มต้นการเทรน {epochs} Epochs...")
    for epoch in range(epochs):
        print(f"\n--- Epoch {epoch + 1}/{epochs} ---")
        # Training Phase
        model.train()
        train_loss, train_corrects, total_train = 0.0, 0, 0
        for inputs, labels in train_loader:
            inputs, labels = inputs.to(device), labels.to(device)
            optimizer.zero_grad()
            outputs = model(inputs)
            _, preds = torch.max(outputs, 1)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            train_loss += loss.item() * inputs.size(0)
            train_corrects += torch.sum(preds == labels.data).item()
            total_train += inputs.size(0)

        epoch_train_loss = train_loss / total_train if total_train > 0 else 0
        epoch_train_acc = (train_corrects / total_train * 100) if total_train > 0 else 0
        print(f"Train Loss: {epoch_train_loss:.4f} | Train Acc: {epoch_train_acc:.2f}%")

        # Validation Phase
        model.eval()
        val_loss, val_corrects, total_val = 0.0, 0, 0
        with torch.no_grad():
            for inputs, labels in val_loader:
                inputs, labels = inputs.to(device), labels.to(device)
                outputs = model(inputs)
                _, preds = torch.max(outputs, 1)
                loss = criterion(outputs, labels)

                val_loss += loss.item() * inputs.size(0)
                val_corrects += torch.sum(preds == labels.data).item()
                total_val += inputs.size(0)

        epoch_val_loss = val_loss / total_val if total_val > 0 else 0
        epoch_val_acc = (val_corrects / total_val * 100) if total_val > 0 else 0
        print(f"Val Loss:   {epoch_val_loss:.4f} | Val Acc:   {epoch_val_acc:.2f}%")

        # บันทึก Best Model
        if epoch_val_acc >= best_val_acc:
            best_val_acc = epoch_val_acc
            best_model_path = os.path.join(output_dir, "durian_disease_model.pth")
            checkpoint = {
                'epoch': epoch + 1,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'classes': class_names,
                'val_acc': best_val_acc,
                'architecture': 'mobilenet_v3_small'
            }
            torch.save(checkpoint, best_model_path)
            print(f"  [+] บันทึก Best Checkpoint ลง: {best_model_path} (Acc: {best_val_acc:.2f}%)")

    print(f"\n[✓] การเทรนเสร็จสมบูรณ์! Best Validation Accuracy: {best_val_acc:.2f}%")

if __name__ == "__main__":
    train_durian_model()
