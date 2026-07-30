"""
对 UI 抠图艺术大字进行极致紧凑外接矩形 (Tight Bounding Box) 裁剪
去除周围的多余透明背景，获得纯净、长宽比紧凑的艺术字边框。
"""
import os
import cv2
import numpy as np

def tight_crop(png_path):
    if not os.path.exists(png_path):
        print(f"[Tight Crop] File not found: {png_path}")
        return
        
    img = cv2.imread(png_path, cv2.IMREAD_UNCHANGED)
    if img is None or img.shape[2] < 4:
        return
        
    alpha = img[:, :, 3]
    non_zero = np.argwhere(alpha > 15)
    if len(non_zero) == 0:
        return
        
    y_min, x_min = non_zero.min(axis=0)
    y_max, x_max = non_zero.max(axis=0)
    
    # 增加 4px 微小 padding
    h_img, w_img = img.shape[:2]
    x_min = max(0, x_min - 4)
    y_min = max(0, y_min - 4)
    x_max = min(w_img, x_max + 4)
    y_max = min(h_img, y_max + 4)
    
    cropped = img[y_min:y_max, x_min:x_max]
    cv2.imwrite(png_path, cropped)
    print(f"[Tight Crop] Refined {png_path} -> New Size: {cropped.shape[1]}x{cropped.shape[0]} (Aspect Ratio: {cropped.shape[1]/cropped.shape[0]:.2f})")

if __name__ == "__main__":
    ui_dir = r"D:\godot-test-project\assets\ui"
    tight_crop(os.path.join(ui_dir, "chinese_victory_logo.png"))
    tight_crop(os.path.join(ui_dir, "chinese_gameover_logo.png"))
    print("[Tight Crop] Completed!")
