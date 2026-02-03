
import sys
import os

try:
    from PIL import Image
    
    input_path = r"c:\Users\baris\santiyepro\assets\app_icon_new.jpg"
    output_path = r"c:\Users\baris\santiyepro\assets\app_icon_padded.png"
    
    if not os.path.exists(input_path):
        print(f"Error: {input_path} not found")
        sys.exit(1)
        
    img = Image.open(input_path).convert("RGBA")
    width, height = img.size
    print(f"Original size: {width}x{height}")
    
    # Android adaptive icon safe zone: %66 (2/3)
    target_size = 1024
    scale = 0.66
    
    new_size = int(target_size * scale)
    img_resized = img.resize((new_size, new_size), Image.Resampling.LANCZOS)
    
    # Arka plan rengi - görselddeki yeşil
    bg_color = (46, 82, 60, 255)
    final_img = Image.new('RGBA', (target_size, target_size), bg_color)
    
    # Ortala
    offset = (target_size - new_size) // 2
    final_img.paste(img_resized, (offset, offset))
    
    final_img.save(output_path, "PNG")
    print(f"0.66 scale (safe zone) icon saved to {output_path}")
    
except ImportError:
    print("PIL library not found.")
    sys.exit(1)
except Exception as e:
    print(f"An error occurred: {e}")
    sys.exit(1)
