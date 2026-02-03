
import sys
import os

try:
    from PIL import Image
    
    # Orijinal görsel (kullanıcının son yüklediği veya ana görsel)
    # app_icon.png muhtemelen crop edilmiş versiyondu.
    # Kullanıcı 1.1 scale istedi, yani biraz zoom yapacağız, böylece kenarlardaki boşluklar gidecek ve daireye tam oturacak.
    
    input_path = r"c:\Users\baris\santiyepro\assets\app_icon.png"
    output_path = r"c:\Users\baris\santiyepro\assets\app_icon_full.png"
    
    if not os.path.exists(input_path):
        print(f"Error: {input_path} not found")
        sys.exit(1)
        
    img = Image.open(input_path).convert("RGBA")
    width, height = img.size
    print(f"Original size: {width}x{height}")
    
    # 1.1 kat büyüt (Zoom in)
    new_width = int(width * 1.1)
    new_height = int(height * 1.1)
    
    img_resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Merkezden orijinal boyut kadar kırp (Crop center)
    left = (new_width - width) / 2
    top = (new_height - height) / 2
    right = (new_width + width) / 2
    bottom = (new_height + height) / 2
    
    img_cropped = img_resized.crop((left, top, right, bottom))
    
    img_cropped.save(output_path)
    print(f"Zoomed and cropped image saved to {output_path}")
    
except ImportError:
    print("PIL library not found.")
    sys.exit(1)
except Exception as e:
    print(f"An error occurred: {e}")
    sys.exit(1)
