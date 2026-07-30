import os
import cv2
import numpy as np

def mat_and_crop(img_path, output_path):
    print(f"[Combat UI Slicer] Processing: {img_path}")
    if not os.path.exists(img_path):
        print(f"[Combat UI Slicer] Error: File not found {img_path}")
        return False
        
    img = cv2.imread(img_path, cv2.IMREAD_UNCHANGED)
    if img is None:
        return False
        
    if img.shape[2] == 3:
        b, g, r = cv2.split(img)
        alpha = np.ones(b.shape, dtype=b.dtype) * 255
        img = cv2.merge([b, g, r, alpha])
        
    hsv = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2HSV)
    lower_blue = np.array([90, 70, 70])
    upper_blue = np.array([135, 255, 255])
    
    blue_mask = cv2.inRange(hsv, lower_blue, upper_blue)
    img[:, :, 3][blue_mask > 0] = 0
    
    non_zero = np.argwhere(img[:, :, 3] > 20)
    if len(non_zero) == 0:
        return False
        
    y_min, x_min = non_zero.min(axis=0)
    y_max, x_max = non_zero.max(axis=0)
    
    h_img, w_img = img.shape[:2]
    x_min = max(0, x_min - 8)
    y_min = max(0, y_min - 8)
    x_max = min(w_img, x_max + 8)
    y_max = min(h_img, y_max + 8)
    
    cropped = img[y_min:y_max, x_min:x_max]
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    cv2.imwrite(output_path, cropped)
    print(f"[Combat UI Slicer] Saved: {output_path} ({cropped.shape[1]}x{cropped.shape[0]})")
    return True

if __name__ == "__main__":
    art_dir = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\0005c68b-4f37-4941-b049-8a813d3a8a4c"
    
    crit_in = os.path.join(art_dir, "chinese_crit_blue_sheet_1785404380401.png")
    hit_in = os.path.join(art_dir, "chinese_hit_blue_sheet_1785404395878.png")
    hurt_in = os.path.join(art_dir, "chinese_hurt_blue_sheet_1785404413682.png")
    
    mat_and_crop(crit_in, r"D:\godot-test-project\assets\ui\hit_text_crit.png")
    mat_and_crop(hit_in, r"D:\godot-test-project\assets\ui\hit_text_hit.png")
    mat_and_crop(hurt_in, r"D:\godot-test-project\assets\ui\hit_text_hurt.png")
