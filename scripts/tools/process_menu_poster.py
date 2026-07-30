import os
import sys
import requests
from PIL import Image

API_KEY = "1acZABw6JLjCPhk9qY6RFSee"
INPUT_IMG = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\0005c68b-4f37-4941-b049-8a813d3a8a4c\menu_batman_poster_blue_bg_1785395190147.png"
OUTPUT_PATH = r"D:\godot-test-project\assets\menu_poster_nobg.png"

def clean_alpha_edges(img):
    img = img.convert("RGBA")
    datas = img.getdata()
    new_data = []
    for item in datas:
        r, g, b, a = item
        if a < 100:
            new_data.append((0, 0, 0, 0))
        # 蓝色残余滤波
        elif b > r + 20 and b > g + 20 and a < 240:
            new_data.append((0, 0, 0, 0))
        else:
            clean_a = 255 if a >= 160 else a
            new_data.append((r, g, b, clean_a))
    img.putdata(new_data)
    return img

def remove_bg_menu_poster(input_path, output_path, api_key):
    print(f"[Menu Poster Matting] Calling remove.bg API for {input_path}...")
    headers = {"X-Api-Key": api_key}
    try:
        with open(input_path, "rb") as f:
            response = requests.post(
                "https://api.remove.bg/v1.0/removebg",
                files={"image_file": f},
                data={"size": "preview", "format": "png", "type": "auto"},
                headers=headers,
                timeout=25
            )
        if response.status_code == 200:
            with open(output_path, "wb") as out:
                out.write(response.content)
            raw = Image.open(output_path)
            cleaned = clean_alpha_edges(raw)
            cleaned.save(output_path)
            print(f"[Menu Poster Matting] Success -> {output_path}")
            return True
        else:
            print(f"remove.bg Warning {response.status_code}: {response.text}")
            return False
    except Exception as e:
        print(f"remove.bg Exception: {e}")
        return False

def main():
    if not os.path.exists(INPUT_IMG):
        print(f"Input file not found: {INPUT_IMG}")
        return
    success = remove_bg_menu_poster(INPUT_IMG, OUTPUT_PATH, API_KEY)
    if not success:
        print("[Fallback] Fallback PIL blue matting...")
        raw = Image.open(INPUT_IMG)
        cleaned = clean_alpha_edges(raw)
        cleaned.save(OUTPUT_PATH)
        print(f"[Fallback] Saved fallback to {OUTPUT_PATH}")

if __name__ == "__main__":
    main()
