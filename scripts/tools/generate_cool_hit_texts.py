"""
生成高清超酷炫中文打击艺术字贴图 (🎯 命中! / 💥 暴击! / ⚡ 受伤!)
彻底几何居中居于 500x250 全透明画布，带有多重深色立体边框与发光效果。
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_cool_hit_text(filename, text, main_color, border_color, glow_color):
    width, height = 500, 250
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    font_paths = [
        "C:/Windows/Fonts/msyhbd.ttc", # 微软雅黑 Bold
        "C:/Windows/Fonts/simhei.ttf",  # 黑体
        "C:/Windows/Fonts/simsun.ttc"   # 宋体
    ]
    font = None
    font_size = 80
    for p in font_paths:
        if os.path.exists(p):
            try:
                font = ImageFont.truetype(p, font_size)
                break
            except Exception:
                pass

    if font is None:
        font = ImageFont.load_default()

    # 🎯 精确计算文本 Bound Box，保证 100% 画布几何居中
    bbox = font.getbbox(text)
    left, top, right, bottom = bbox
    text_w = right - left
    text_h = bottom - top

    text_x = (width - text_w) / 2.0 - left
    text_y = (height - text_h) / 2.0 - top

    # 1. 绘制极强耀眼外发光 (Glow Layer)
    glow_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    for dx in range(-12, 13, 3):
        for dy in range(-12, 13, 3):
            glow_draw.text((text_x + dx, text_y + dy), text, font=font, fill=glow_color)
    glow_img = glow_img.filter(ImageFilter.GaussianBlur(radius=8))

    # 2. 绘制深色立体系粗轮廓 (Outline Layer)
    outline_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    outline_draw = ImageDraw.Draw(outline_img)
    for dx in range(-6, 7):
        for dy in range(-6, 7):
            if dx*dx + dy*dy <= 36:
                outline_draw.text((text_x + dx, text_y + dy), text, font=font, fill=border_color)

    # 3. 绘制高亮纯色主字 (Main Text Layer)
    main_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    main_draw = ImageDraw.Draw(main_img)
    main_draw.text((text_x, text_y), text, font=font, fill=main_color)

    # 4. 叠加白色高光内描边 (Inner Highlight)
    hl_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    hl_draw = ImageDraw.Draw(hl_img)
    hl_draw.text((text_x - 1, text_y - 1), text, font=font, fill=(255, 255, 255, 220))

    # 5. 顺序融合成最终 PNG
    final_img = Image.alpha_composite(glow_img, outline_img)
    final_img = Image.alpha_composite(final_img, main_img)
    final_img = Image.alpha_composite(final_img, hl_img)

    out_dir = r"D:\godot-test-project\assets\ui"
    save_path = os.path.join(out_dir, filename)
    final_img.save(save_path)
    print(f"[Hit Text Generator] SUCCESS: Saved text to {save_path} (Center Aligned 500x250)")

if __name__ == "__main__":
    # 🎯 命中！ (天空亮蓝主字 + 漆黑轮廓 + 炫金外发光)
    create_cool_hit_text(
        "hit_text_hit.png",
        "命中！",
        main_color=(60, 220, 255, 255),
        border_color=(10, 15, 40, 255),
        glow_color=(255, 215, 0, 255)
    )
    
    # 💥 暴击！ (太阳炫金主字 + 暗红轮廓 + 火焰橙红外发光)
    create_cool_hit_text(
        "hit_text_crit.png",
        "暴击！",
        main_color=(255, 240, 60, 255),
        border_color=(60, 5, 5, 255),
        glow_color=(255, 50, 0, 255)
    )

    # ⚡ 受伤！ (鲜艳警示红主字 + 深紫轮廓 + 电光紫发光)
    create_cool_hit_text(
        "hit_text_hurt.png",
        "受伤！",
        main_color=(255, 70, 70, 255),
        border_color=(25, 0, 35, 255),
        glow_color=(200, 40, 255, 255)
    )
