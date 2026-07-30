import os
import sys
import math
from PIL import Image, ImageFilter

INPUT_IMG = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\0005c68b-4f37-4941-b049-8a813d3a8a4c\boss_clean_keyframes_sheet_1785391931858.png"
OUTPUT_DIR = r"D:\godot-test-project\assets\boss_anim"
ARTIFACTS_DIR = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\0005c68b-4f37-4941-b049-8a813d3a8a4c"

def remove_isolated_dots(img):
    """清除四周连通域均为透明的孤立黑点噪点 (Isolated Pixel Denoising)"""
    w, h = img.size
    pixels = img.load()
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            r, g, b, a = pixels[x, y]
            if a > 0:
                # 检查 8 邻域
                transparent_neighbors = 0
                for dy in [-1, 0, 1]:
                    for dx in [-1, 0, 1]:
                        if dx == 0 and dy == 0: continue
                        if pixels[x + dx, y + dy][3] == 0:
                            transparent_neighbors += 1
                # 如果 8 个邻居中有 7 个以上全透明，判定为孤立噪点
                if transparent_neighbors >= 7:
                    pixels[x, y] = (0, 0, 0, 0)
    return img

def apply_chroma_preset(crop_img, preset_type):
    """根据预设类型执行高精抠图与降噪算法"""
    img = crop_img.convert("RGBA")
    w, h = img.size
    datas = img.getdata()
    
    bg_r, bg_g, bg_b = datas[0][0], datas[0][1], datas[0][2]
    new_data = []
    
    # 预设参数设定
    if preset_type == 1:
        # 预设 1: 均衡去噪 (Threshold 100, 剔除杂散点)
        thresh = 100.0
        for item in datas:
            r, g, b, a = item
            dist = math.sqrt((r - bg_r)**2 + (g - bg_g)**2 + (b - bg_b)**2)
            is_green = (g > r + 10 and g > b + 10)
            if dist < thresh or is_green:
                new_data.append((0, 0, 0, 0))
            else:
                clean_g = min(g, max(r, b)) if (g > r and g > b) else g
                new_data.append((r, clean_g, b, 255 if a >= 140 else 0))
                
    elif preset_type == 2:
        # 预设 2: 紧凑收缩 (Threshold 115, 彻底消解黑刺边)
        thresh = 115.0
        for item in datas:
            r, g, b, a = item
            dist = math.sqrt((r - bg_r)**2 + (g - bg_g)**2 + (b - bg_b)**2)
            is_green = (g > r + 8 and g > b + 8)
            # 偏黑/偏灰噪点擦除
            is_dark_noise = (r < 40 and g < 40 and b < 40 and a < 220)
            if dist < thresh or is_green or is_dark_noise:
                new_data.append((0, 0, 0, 0))
            else:
                clean_g = min(g, max(r, b)) if (g > r and g > b) else g
                new_data.append((r, clean_g, b, 255))
                
    elif preset_type == 3:
        # 预设 3: 硬核像素二值化 (Sharp Binary Edge)
        thresh = 92.0
        for item in datas:
            r, g, b, a = item
            dist = math.sqrt((r - bg_r)**2 + (g - bg_g)**2 + (b - bg_b)**2)
            is_green = (g > r + 15 and g > b + 15)
            if dist < thresh or is_green:
                new_data.append((0, 0, 0, 0))
            else:
                new_data.append((r, g, b, 255))
                
    elif preset_type == 4:
        # 预设 4: 柔和抗锯齿平滑 (Soft Alpha Feathering)
        thresh = 88.0
        for item in datas:
            r, g, b, a = item
            dist = math.sqrt((r - bg_r)**2 + (g - bg_g)**2 + (b - bg_b)**2)
            is_green = (g > r + 20 and g > b + 20)
            if dist < thresh or is_green:
                new_data.append((0, 0, 0, 0))
            else:
                # 色差在 88~120 之间的进行 alpha 渐变羽化
                alpha_factor = min(1.0, max(0.0, (dist - 88.0) / 32.0))
                clean_a = int(255 * alpha_factor)
                new_data.append((r, g, b, clean_a))
                
    img.putdata(new_data)
    # 统一应用 8 邻域孤立噪点过滤
    img = remove_isolated_dots(img)
    return img

def build_preset_sheet(preset_type):
    sheet_img = Image.open(INPUT_IMG).convert("RGBA")
    w, h = sheet_img.size
    rows, cols = 4, 4
    cell_w, cell_h = w // cols, h // rows
    
    target_frame_size = (128, 128)
    spritesheet = Image.new("RGBA", (target_frame_size[0] * cols, target_frame_size[1] * rows), (0, 0, 0, 0))
    
    for r in range(rows):
        for c in range(cols):
            box = (c * cell_w, r * cell_h, (c + 1) * cell_w, (r + 1) * cell_h)
            sub_crop = sheet_img.crop(box)
            
            matted_frame = apply_chroma_preset(sub_crop, preset_type)
            
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
            
    out_path = os.path.join(OUTPUT_DIR, f"boss_spritesheet_preset{preset_type}.png")
    spritesheet.save(out_path)
    
    # 拷贝到 artifacts 供预览
    art_path = os.path.join(ARTIFACTS_DIR, f"preset_{preset_type}_preview.png")
    spritesheet.save(art_path)
    print(f"Preset {preset_type} generated -> {art_path}")

def main():
    print("Generating 4 Chroma Key presets for user evaluation...")
    for p in range(1, 5):
        build_preset_sheet(p)
    print("All 4 presets generated successfully!")

if __name__ == "__main__":
    main()
