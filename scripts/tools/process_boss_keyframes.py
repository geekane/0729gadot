import os
import sys
from PIL import Image

# 输入用户亲自抠好图的完美透明 4x4 Spritesheet 大图
INPUT_IMG = r"D:\godot-test-project\boss.png"
OUTPUT_DIR = r"D:\godot-test-project\assets\boss_anim"
RAW_FRAMES_DIR = r"D:\godot-test-project\assets\boss_anim\raw_frames"

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def slice_user_matted_keyframes(sheet_path):
    """直接使用用户精细抠好图的 4x4 透明大图进行标准切片与 Ground-Snap 对齐"""
    print(f"[User Spritesheet] Loading user's matted sprite sheet: {sheet_path}")
    ensure_dir(OUTPUT_DIR)
    ensure_dir(RAW_FRAMES_DIR)
    
    sheet_img = Image.open(sheet_path).convert("RGBA")
    w, h = sheet_img.size
    rows, cols = 4, 4
    cell_w, cell_h = w // cols, h // rows
    anim_names = ["idle", "attack", "stunned", "enraged"]
    
    target_frame_size = (128, 128)
    spritesheet = Image.new("RGBA", (target_frame_size[0] * cols, target_frame_size[1] * rows), (0, 0, 0, 0))
    
    for r in range(rows):
        anim_name = anim_names[r]
        for c in range(cols):
            box = (c * cell_w, r * cell_h, (c + 1) * cell_w, (r + 1) * cell_h)
            sub_crop = sheet_img.crop(box)
            
            # 获取连通域边界
            bbox = sub_crop.getbbox()
            formatted_frame = Image.new("RGBA", target_frame_size, (0, 0, 0, 0))
            
            if bbox:
                cropped = sub_crop.crop(bbox)
                cw, ch = cropped.size
                max_dim = 104
                scale = min(max_dim / float(cw), max_dim / float(ch))
                if scale > 0 and scale != 1.0:
                    new_size = (int(cw * scale), int(ch * scale))
                    cropped = cropped.resize(new_size, Image.NEAREST)
                    cw, ch = new_size
                px = (target_frame_size[0] - cw) // 2
                # 🎯 底部 Ground Baseline 贴合对齐
                py = target_frame_size[1] - ch - 4
                formatted_frame.paste(cropped, (px, py), cropped)
            else:
                formatted_frame.paste(sub_crop, (0, 0))
                
            frame_path = os.path.join(OUTPUT_DIR, f"{anim_name}_{c}.png")
            formatted_frame.save(frame_path)
            
            spritesheet.paste(formatted_frame, (c * target_frame_size[0], r * target_frame_size[1]), formatted_frame)
            print(f"[User Spritesheet] Frame {anim_name}_{c} sliced & saved cleanly.")

    ss_path = os.path.join(OUTPUT_DIR, "boss_spritesheet.png")
    spritesheet.save(ss_path)
    print(f"[User Spritesheet] All 16 clean frames sliced & assembled to: {ss_path}")

def main():
    if not os.path.exists(INPUT_IMG):
        print(f"Error: User sprite sheet not found: {INPUT_IMG}")
        return
    slice_user_matted_keyframes(INPUT_IMG)

if __name__ == "__main__":
    main()
