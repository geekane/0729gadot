"""
生成通关星级评价 UI 元素 (1星/2星/3星)
使用 Python Pillow 直接绘制高质量金色星星，无需 AI 图片生成。
"""
import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUTPUT_DIR = r"D:\godot-test-project\assets\ui"

def draw_star(draw, cx, cy, outer_r, inner_r, fill_color, outline_color, filled=True):
    """绘制五角星"""
    points = []
    for i in range(10):
        angle = math.radians(i * 36 - 90)
        r = outer_r if i % 2 == 0 else inner_r
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    if filled:
        draw.polygon(points, fill=fill_color, outline=outline_color)
    else:
        draw.polygon(points, fill=(80, 80, 80, 180), outline=(120, 120, 120, 200))

def create_star_rating(num_stars, filename):
    """创建星级评价图片 (透明背景)"""
    star_size = 64
    spacing = 16
    total_stars = 3
    width = total_stars * star_size + (total_stars - 1) * spacing + 40
    height = star_size + 40
    
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    start_x = 20
    cy = height // 2
    
    for i in range(total_stars):
        cx = start_x + i * (star_size + spacing) + star_size // 2
        filled = i < num_stars
        if filled:
            # 金色实心星
            draw_star(draw, cx, cy, star_size // 2, star_size // 5,
                     fill_color=(255, 210, 50, 255),
                     outline_color=(200, 150, 0, 255),
                     filled=True)
            # 高光小星
            draw_star(draw, cx - 5, cy - 8, star_size // 5, star_size // 10,
                     fill_color=(255, 255, 200, 180),
                     outline_color=None,
                     filled=True)
        else:
            # 灰色空心星
            draw_star(draw, cx, cy, star_size // 2, star_size // 5,
                     fill_color=(80, 80, 80, 150),
                     outline_color=(120, 120, 120, 200),
                     filled=False)
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, filename)
    img.save(out_path)
    print(f"[Star Rating] Saved: {out_path} ({img.width}x{img.height})")

def create_level_clear_banner():
    """创建 '关卡通关' 通用标题条 (透明背景金色渐变文字)"""
    width, height = 400, 80
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 绘制底部装饰光晕条
    for y in range(height):
        alpha = int(120 * math.sin(math.pi * y / height))
        draw.line([(20, y), (width - 20, y)], fill=(255, 200, 50, alpha))
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, "level_clear_glow.png")
    img.save(out_path)
    print(f"[Level Clear] Saved: {out_path} ({img.width}x{img.height})")

if __name__ == "__main__":
    create_star_rating(1, "star_rating_1.png")
    create_star_rating(2, "star_rating_2.png")
    create_star_rating(3, "star_rating_3.png")
    create_level_clear_banner()
    print("[Done] All star rating UI elements generated!")
