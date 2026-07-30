"""
精确提取并智能缩放 `chinese_victory_logo.png` 和 `chinese_gameover_logo.png`
提取核心中文文字，并去除庞大的外围空白与背景边框，使其完美契合 UI 面板！
"""
import os
import cv2
import numpy as np

def process_banner(input_name, output_name, target_width=320):
    ui_dir = r"D:\godot-test-project\assets\ui"
    src_path = os.path.join(ui_dir, input_name)
    out_path = os.path.join(ui_dir, output_name)
    
    if not os.path.exists(src_path):
        print(f"[Banner Crop] File missing: {src_path}")
        return
        
    img = cv2.imread(src_path, cv2.IMREAD_UNCHANGED)
    if img is None or img.shape[2] < 4:
        print(f"[Banner Crop] Invalid image: {src_path}")
        return
        
    alpha = img[:, :, 3]
    # 提取非透明文字轮廓
    non_zero = np.argwhere(alpha > 30)
    if len(non_zero) == 0:
        return
        
    y_min, x_min = non_zero.min(axis=0)
    y_max, x_max = non_zero.max(axis=0)
    
    crop = img[y_min:y_max+1, x_min:x_max+1]
    
    h, w = crop.shape[:2]
    aspect = w / float(h)
    
    # 缩放到适中的标准尺寸
    target_height = int(target_width / aspect)
    resized = cv2.resize(crop, (target_width, target_height), interpolation=cv2.INTER_AREA)
    
    cv2.imwrite(out_path, resized)
    print(f"[Banner Crop] Processed {input_name} -> {output_name} ({resized.shape[1]}x{resized.shape[0]}, Aspect: {aspect:.2f})")

if __name__ == "__main__":
    process_banner("chinese_victory_logo.png", "chinese_victory_banner_clean.png", target_width=300)
    process_banner("chinese_gameover_logo.png", "chinese_gameover_banner_clean.png", target_width=300)
    print("[Banner Crop] Clean UI Banners successfully generated!")
