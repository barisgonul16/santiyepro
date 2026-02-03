
from PIL import Image

try:
    img = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    img.save(r"c:\Users\baris\santiyepro\assets\transparent.png")
    print("Transparent PNG created.")
except Exception as e:
    print(f"Error: {e}")
