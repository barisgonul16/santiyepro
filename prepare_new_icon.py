
import sys
import os

try:
    from PIL import Image
    
    # Yüklenen görsel (jpg)
    input_path = r"c:\Users\baris\santiyepro\assets\new_icon.jpg"
    output_path = r"c:\Users\baris\santiyepro\assets\app_icon_new.png"
    
    if not os.path.exists(input_path):
        print(f"Error: {input_path} not found")
        sys.exit(1)
        
    img = Image.open(input_path).convert("RGBA")
    width, height = img.size
    print(f"Original size: {width}x{height}")
    
    # Kare yap (adaptive icon için gerekli)
    # Görselin daha küçük kenarını baz al ve merkezden kare kırp
    size = min(width, height)
    
    left = (width - size) / 2
    top = (height - size) / 2
    right = (width + size) / 2
    bottom = (height + size) / 2
    
    img_square = img.crop((left, top, right, bottom))
    
    # 1024x1024 olarak yeniden boyutlandır (yüksek kalite ikon için)
    img_resized = img_square.resize((1024, 1024), Image.Resampling.LANCZOS)
    
    img_resized.save(output_path, "PNG")
    print(f"Square icon saved to {output_path} (1024x1024)")
    
except ImportError:
    print("PIL library not found.")
    sys.exit(1)
except Exception as e:
    print(f"An error occurred: {e}")
    sys.exit(1)
