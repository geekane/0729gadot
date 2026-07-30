import os
import cv2
import numpy as np

def mat_and_crop_blue_screen(img_path, output_path):
    print(f"[Victory UI Slicer] Processing: {img_path}")
    if not os.path.exists(img_path):
        print(f"[Victory UI Slicer] Error: file not found {img_path}")
        return False
        
    img = cv2.imread(img_path, cv2.IMREAD_UNCHANGED)
    if img is None:
        print(f"[Victory UI Slicer] Error: Failed to read image {img_path}")
        return False
        
    if img.shape[2] == 3:
        b, g, r = cv2.split(img)
        alpha = np.ones(b.shape, dtype=b.dtype) * 255
        img = cv2.merge([b, g, r, alpha])
        
    hsv = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2HSV)
    
    # 纯蓝幕 HSV 容差范围
    lower_blue = np.array([90, 70, 70])
    upper_blue = np.array([135, 255, 255])
    
    blue_mask = cv2.inRange(hsv, lower_blue, upper_blue)
    
    # 将蓝幕部分 alpha 设为 0
    img[:, :, 3][blue_mask > 0] = 0
    
    # 提取非透明主体的连通外接矩形
    non_zero = np.argwhere(img[:, :, 3] > 20)
    if len(non_zero) == 0:
        print(f"[Victory UI Slicer] Error: No content found in {img_path}")
        return False
        
    y_min, x_min = non_zero.min(axis=0)
    y_max, x_max = non_zero.max(axis=0)
    
    # 适当留出 10px 边距
    h_img, w_img = img.shape[:2]
    x_min = max(0, x_min - 10)
    y_min = max(0, y_min - 10)
    x_max = min(w_img, x_max + 10)
    y_max = min(h_img, y_max + 10)
    
    cropped = img[y_min:y_max, x_min:x_max]
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    cv2.imwrite(output_path, cropped)
    print(f"[Victory UI Slicer] Successfully saved cropped transparent UI to: {output_path} (Size: {cropped.shape[1]}x{cropped.shape[0]})")
    return True

if __name__ == "__main__":
    artifacts_dir = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\0005c68b-4f37-4941-b049-8a813d3a8a4c"
    
    vic_file = os.path.join(artifacts_dir, "chinese_victory_blue_sheet_1785404050483.png")
    go_file = os.path.join(artifacts_dir, "chinese_gameover_blue_sheet_1785404064313.png")
    
    out_vic = r"D:\godot-test-project\assets\ui\chinese_victory_logo.png"
    out_go = r"D:\godot-test-project\assets\ui\chinese_gameover_logo.png"
    
    mat_and_crop_blue_screen(vic_file, out_vic)
    mat_and_crop_blue_screen(go_file, out_go)
