
import sys
import os

try:
    from PIL import Image
    
    # 1. Kaynak ikon yolunu al (crop edilmiş kare ikon)
    # create_transparent_icon.py ile oluşturulan şeffaf background var mı kontrol edebiliriz ama
    # biz şeffaf bir canvas üzerine shrink edilmiş ikonu koyacağız.
    
    icon_path = r"c:\Users\baris\santiyepro\assets\app_icon.png"
    output_path = r"c:\Users\baris\santiyepro\assets\app_icon_scaled.png"
    
    if not os.path.exists(icon_path):
        print(f"Error: {icon_path} not found")
        sys.exit(1)
        
    img = Image.open(icon_path).convert("RGBA")
    width, height = img.size
    print(f"Original size: {width}x{height}")
    
    # Scale factor 0.7
    scale = 0.7
    new_width = int(width * scale)
    new_height = int(height * scale)
    
    # Resize image high quality
    img_resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Create new transparent canvas of original size
    # Adaptive icons need consistent size layers usually.
    # The original file is used as 'background' in pubspec currently.
    # But usually adaptive icon background is a solid color or full bleed image.
    # If the user wants the ICON to fit, we should probably set a background color 
    # and put this scaled image as FOREGROUND.
    # Let's create a scaled foreground image with transparent padding.
    
    final_img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    
    # Center paste
    offset_x = (width - new_width) // 2
    offset_y = (height - new_height) // 2
    
    final_img.paste(img_resized, (offset_x, offset_y))
    
    final_img.save(output_path)
    print(f"Scaled image saved to {output_path}")

    # Also create a background color image if needed, but for now we will just use this new image.
    
except ImportError:
    print("PIL library not found.")
    sys.exit(1)
except Exception as e:
    print(f"An error occurred: {e}")
    sys.exit(1)
