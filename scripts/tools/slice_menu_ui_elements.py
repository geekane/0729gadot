import os
import cv2
import numpy as np
from PIL import Image

INPUT_IMG = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\0005c68b-4f37-4941-b049-8a813d3a8a4c\master_chinese_ui_design_1785398150206.png"
OUTPUT_DIR = r"D:\godot-test-project\assets\ui"

def chroma_key_blue(img_np):
    """蓝幕抠图算法，将纯蓝/浅蓝背景设为 100% 透明"""
    hsv = cv2.cvtColor(img_np, cv2.COLOR_BGR2HSV)
    # 蓝幕 HSV 范围
    lower_blue = np.array([90, 80, 80])
    upper_blue = np.array([135, 255, 255])
    mask = cv2.inRange(hsv, lower_blue, upper_blue)
    
    rgba = cv2.cvtColor(img_np, cv2.COLOR_BGR2BGRA)
    rgba[mask > 0, 3] = 0
    return rgba

def slice_and_export():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        
    print(f"[UI Slicer] Loading master Chinese UI design sheet: {INPUT_IMG}")
    img_bgr = cv2.imread(INPUT_IMG)
    if img_bgr is None:
        print("[Error] Could not read master image")
        return
        
    matted_rgba = chroma_key_blue(img_bgr)
    alpha = matted_rgba[:, :, 3]
    
    # 查找非透明像素的外接轮廓
    contours, _ = cv2.findContours(alpha, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # 筛选面积足够大的块 (去除点状杂质噪点)
    valid_boxes = []
    h_img, w_img = alpha.shape[:2]
    min_area = (w_img * h_img) * 0.002
    
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        if w * h >= min_area:
            valid_boxes.append((x, y, w, h))
            
    # 按从上到下 (y 坐标) 排序
    valid_boxes.sort(key=lambda b: b[1])
    print(f"[UI Slicer] Detected {len(valid_boxes)} major Chinese UI elements")
    
    names = [
        "chinese_title_logo.png",
        "chinese_btn_start.png",
        "chinese_btn_level.png",
        "chinese_btn_controls.png",
        "chinese_btn_scores.png",
        "chinese_btn_exit.png"
    ]
    
    for idx, (x, y, w, h) in enumerate(valid_boxes):
        if idx >= len(names):
            out_name = f"ui_element_{idx}.png"
        else:
            out_name = names[idx]
            
        crop_rgba = matted_rgba[y:y+h, x:x+w]
        out_path = os.path.join(OUTPUT_DIR, out_name)
        cv2.imwrite(out_path, crop_rgba)
        print(f"  -> Sliced element {idx+1}: [{out_name}] Size: ({w}x{h}) at ({x}, {y})")

    # 如果自动连通域未分割成 6 块，则按垂直比例强制划分为 6 等份作为保底切片
    if len(valid_boxes) < 4:
        print("[UI Slicer] Fallback grid vertical slicing...")
        slice_h = h_img // 6
        for idx, out_name in enumerate(names):
            y_start = idx * slice_h
            y_end = (idx + 1) * slice_h
            crop = matted_rgba[y_start:y_end, :]
            # 裁剪内缩空白边缘
            crop_alpha = crop[:, :, 3]
            coords = cv2.findNonZero(crop_alpha)
            if coords is not None:
                x_b, y_b, w_b, h_b = cv2.boundingRect(coords)
                crop = crop[y_b:y_b+h_b, x_b:x_b+w_b]
            out_path = os.path.join(OUTPUT_DIR, out_name)
            cv2.imwrite(out_path, crop)
            print(f"  -> Fallback element {idx+1}: [{out_name}] Saved to {out_path}")

if __name__ == "__main__":
    slice_and_export()
