
import sys
import os

try:
    from PIL import Image
    
    img_path = r"c:\Users\baris\santiyepro\assets\app_icon.png"
    if not os.path.exists(img_path):
        print(f"Error: {img_path} not found")
        sys.exit(1)
        
    img = Image.open(img_path)
    width, height = img.size
    print(f"Original size: {width}x{height}")
    
    if width == height:
        print("Image is already square.")
        sys.exit(0)
    
    min_dim = min(width, height)
    
    # Calculate crop box (center crop)
    left = (width - min_dim) / 2
    top = (height - min_dim) / 2
    right = (width + min_dim) / 2
    bottom = (height + min_dim) / 2
    
    img_cropped = img.crop((left, top, right, bottom))
    img_cropped.save(img_path)
    print(f"Cropped to {min_dim}x{min_dim} and saved.")
    
except ImportError:
    print("PIL (Pillow) library not found. Please install it using 'pip install pillow'")
    sys.exit(1)
except Exception as e:
    print(f"An error occurred: {e}")
    sys.exit(1)
