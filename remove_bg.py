
from PIL import Image
import os

def remove_background(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    datas = img.getdata()

    new_data = []
    # Hedef yeşil renk (logonun yeşili)
    # 0xFF1A4D33 -> R: 26, G: 77, B: 51
    target_r, target_g, target_b = 26, 77, 51
    tolerance = 60 # Biraz esneklik tanıyalım

    for item in datas:
        r, g, b, a = item
        # Eğer renk hedef yeşile yakınsa şeffaf yap
        if abs(r - target_r) < tolerance and abs(g - target_g) < tolerance and abs(b - target_b) < tolerance:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(item)

    img.putdata(new_data)
    img.save(output_path, "PNG")
    print(f"Bbackground removed: {output_path}")

input_icon = r"c:\Users\baris\santiyepro\assets\app_icon_padded.png"
output_icon = r"c:\Users\baris\santiyepro\assets\app_icon_no_bg.png"

if os.path.exists(input_icon):
    remove_background(input_icon, output_icon)
else:
    print("Input file not found.")
