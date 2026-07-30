import os
import sys
import math
import numpy as np
from PIL import Image

try:
    import cv2
    HAS_OPENCV = True
except ImportError:
    HAS_OPENCV = False

INPUT_IMG = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\0005c68b-4f37-4941-b049-8a813d3a8a4c\boss_clean_keyframes_sheet_1785391931858.png"
OUTPUT_DIR = r"D:\godot-test-project\assets\boss_anim"
ARTIFACTS_DIR = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\0005c68b-4f37-4941-b049-8a813d3a8a4c"

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

# ==========================================
# 方式 A: 最大连通域分割 (Largest Component Only)
# 彻底过滤脱离蜘蛛主体的任何浮空烟雾/黑点/气泡
# ==========================================
def matting_largest_component(crop_img):
    img = crop_img.convert("RGBA")
    w, h = img.size
    arr = np.array(img)
    
    # 基础绿幕初筛
    bg_r, bg_g, bg_b = arr[0, 0, 0], arr[0, 0, 1], arr[0, 0, 2]
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    
    color_dist = np.sqrt((r.astype(float) - bg_r)**2 + (g.astype(float) - bg_g)**2 + (b.astype(float) - bg_b)**2)
    is_green = (g.astype(int) > r.astype(int) + 12) & (g.astype(int) > b.astype(int) + 12)
    
    mask = (color_dist > 90) & (~is_green)
    
    if HAS_OPENCV:
        # 使用 OpenCV 的 connectedComponentsWithStats
        binary = mask.astype(np.uint8) * 255
        num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(binary, connectivity=8)
        
        if num_labels > 1:
            # 找到面积最大的前景连通块 (label 0 为背景)
            max_label = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
            # 仅仅保留最大本体，丢弃所有离散碎片！
            clean_mask = (labels == max_label)
        else:
            clean_mask = mask
    else:
        clean_mask = mask

    # 应用 alpha
    arr[:, :, 3] = np.where(clean_mask, 255, 0)
    # 绿彩溢色消解
    green_spill = (arr[:, :, 1] > arr[:, :, 0]) & (arr[:, :, 1] > arr[:, :, 2])
    arr[:, :, 1] = np.where(green_spill, ((arr[:, :, 0].astype(int) + arr[:, :, 2].astype(int)) // 2).astype(np.uint8), arr[:, :, 1])
    
    return Image.fromarray(arr)

# ==========================================
# 方式 B: OpenCV GrabCut 智能图割算法 (Graph Cut)
# ==========================================
def matting_grabcut(crop_img):
    if not HAS_OPENCV:
        return matting_largest_component(crop_img)
        
    img = crop_img.convert("RGB")
    arr = np.array(img)
    h, w, _ = arr.shape
    
    mask = np.zeros((h, w), np.uint8)
    bgdModel = np.zeros((1, 65), np.float64)
    fgdModel = np.zeros((1, 65), np.float64)
    
    # 定义中央包围框为可能的 Foreground
    margin = 4
    rect = (margin, margin, w - margin*2, h - margin*2)
    
    try:
        cv2.grabCut(arr, mask, rect, bgdModel, fgdModel, 5, cv2.GC_INIT_WITH_RECT)
        mask2 = np.where((mask == 2) | (mask == 0), 0, 1).astype('uint8')
        
        # 形态学闭合
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
        mask2 = cv2.morphologyEx(mask2, cv2.MORPH_CLOSE, kernel)
        
        res = np.dstack((arr, mask2 * 255))
        return Image.fromarray(res)
    except Exception as e:
        print(f"GrabCut exception: {e}")
        return matting_largest_component(crop_img)

# ==========================================
# 方式 C: 形态学腐蚀紧致轮廓 (Morphological Tight Shrink)
# ==========================================
def matting_morphology_shrink(crop_img):
    img = crop_img.convert("RGBA")
    arr = np.array(img)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    
    bg_r, bg_g, bg_b = arr[0, 0, 0], arr[0, 0, 1], arr[0, 0, 2]
    color_dist = np.sqrt((r.astype(float) - bg_r)**2 + (g.astype(float) - bg_g)**2 + (b.astype(float) - bg_b)**2)
    is_green = (g.astype(int) > r.astype(int) + 10) & (g.astype(int) > b.astype(int) + 10)
    
    mask = (color_dist > 105) & (~is_green)
    
    if HAS_OPENCV:
        binary = mask.astype(np.uint8) * 255
        # 1. 消除孤立点
        kernel_clean = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
        binary = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel_clean)
        # 2. 微小腐蚀 1px，紧致消除粗糙边缘
        kernel_erode = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        binary = cv2.erode(binary, kernel_erode, iterations=1)
        clean_mask = binary > 0
    else:
        clean_mask = mask
        
    arr[:, :, 3] = np.where(clean_mask, 255, 0)
    return Image.fromarray(arr)

def process_and_save_all():
    sheet_img = Image.open(INPUT_IMG).convert("RGBA")
    w, h = sheet_img.size
    rows, cols = 4, 4
    cell_w, cell_h = w // cols, h // rows
    
    methods = [
        ("method_largest_component", matting_largest_component, "最大主体连通域分割 (只留本体，100% 滤除任何飞溅杂点)"),
        ("method_grabcut", matting_grabcut, "OpenCV GrabCut 智能图割 (基于高斯模型的图割算法)"),
        ("method_tight_shrink", matting_morphology_shrink, "形态学腐蚀紧致轮廓 (削平黑刺毛边)")
    ]
    
    for method_key, func, desc in methods:
        target_frame_size = (128, 128)
        spritesheet = Image.new("RGBA", (target_frame_size[0] * cols, target_frame_size[1] * rows), (0, 0, 0, 0))
        
        for r in range(rows):
            for c in range(cols):
                box = (c * cell_w, r * cell_h, (c + 1) * cell_w, (r + 1) * cell_h)
                sub_crop = sheet_img.crop(box)
                
                matted_frame = func(sub_crop)
                
                bbox = matted_frame.getbbox()
                formatted_frame = Image.new("RGBA", target_frame_size, (0, 0, 0, 0))
                if bbox:
                    cropped = matted_frame.crop(bbox)
                    cw, ch = cropped.size
                    max_dim = 104
                    scale = min(max_dim / float(cw), max_dim / float(ch))
                    if scale > 0 and scale != 1.0:
                        new_size = (int(cw * scale), int(ch * scale))
                        cropped = cropped.resize(new_size, Image.NEAREST)
                        cw, ch = new_size
                    px = (target_frame_size[0] - cw) // 2
                    py = target_frame_size[1] - ch - 4
                    formatted_frame.paste(cropped, (px, py), cropped)
                else:
                    formatted_frame.paste(matted_frame, (0, 0))
                    
                spritesheet.paste(formatted_frame, (c * target_frame_size[0], r * target_frame_size[1]), formatted_frame)
                
        # 导出至 assets 和 artifacts
        out_asset = os.path.join(OUTPUT_DIR, f"boss_spritesheet_{method_key}.png")
        spritesheet.save(out_asset)
        
        out_art = os.path.join(ARTIFACTS_DIR, f"{method_key}_preview.png")
        spritesheet.save(out_art)
        
        # 同时也复制到 project root 方便 HTML 引用
        out_root = os.path.join(r"D:\godot-test-project", f"{method_key}_preview.png")
        spritesheet.save(out_root)
        
        print(f"Generated {method_key} -> {out_art}")

def main():
    print("Testing advanced matting methods (Connected Components, GrabCut, Morphology)...")
    process_and_save_all()
    print("All advanced matting methods generated successfully!")

if __name__ == "__main__":
    main()
