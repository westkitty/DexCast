import os
import subprocess
import shutil
import sys

raw_dir = "/Users/andrew/DexCast/assets/raw/DexCast_Project_Images/all_images"
assets_dir = "/Users/andrew/DexCast/assets"

image_mappings = {
    "dexter_idle.png": "1000094433.png",
    "dexter_setup.png": "1000105534.png",
    "dexter_connecting.png": "1000094452.png",
    "dexter_success.png": "1000094458.png",
    "dexter_failed.png": "1000094462.png"
}

icon_source = "1000094434.png"

def crop_center_and_resize(src_path, dst_path, size=(512, 512)):
    from PIL import Image
    with Image.open(src_path) as img:
        # Convert to RGB if needed
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        w, h = img.size
        min_dim = min(w, h)
        
        # Center crop bounding box
        left = (w - min_dim) / 2
        top = (h - min_dim) / 2
        right = (w + min_dim) / 2
        bottom = (h + min_dim) / 2
        
        cropped = img.crop((left, top, right, bottom))
        resized = cropped.resize(size, Image.Resampling.LANCZOS)
        resized.save(dst_path, "PNG")

def generate_icns(src_path, dst_path):
    from PIL import Image
    iconset_dir = os.path.join(assets_dir, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)
    
    sizes = [
        ("16x16", 16),
        ("16x16@2x", 32),
        ("32x32", 32),
        ("32x32@2x", 64),
        ("128x128", 128),
        ("128x128@2x", 256),
        ("256x256", 256),
        ("256x256@2x", 512),
        ("512x512", 512),
        ("512x512@2x", 1024)
    ]
    
    with Image.open(src_path) as img:
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
            
        w, h = img.size
        min_dim = min(w, h)
        left = (w - min_dim) / 2
        top = (h - min_dim) / 2
        right = (w + min_dim) / 2
        bottom = (h + min_dim) / 2
        cropped = img.crop((left, top, right, bottom))
        
        for name, sz in sizes:
            resized = cropped.resize((sz, sz), Image.Resampling.LANCZOS)
            resized.save(os.path.join(iconset_dir, f"icon_{name}.png"), "PNG")
            
    # Run iconutil
    try:
        subprocess.run(["iconutil", "-c", "icns", iconset_dir], check=True)
        # iconutil outputs AppIcon.icns in the parent folder of the iconset by default
        compiled_icns = os.path.join(assets_dir, "AppIcon.icns")
        if os.path.exists(compiled_icns):
            shutil.move(compiled_icns, dst_path)
            print(f"Compiled icon to {dst_path}")
        else:
            print("iconutil succeeded but output file not found in assets.")
    except Exception as e:
        print(f"Error running iconutil: {e}", file=sys.stderr)
    finally:
        shutil.rmtree(iconset_dir, ignore_errors=True)

def main():
    os.makedirs(assets_dir, exist_ok=True)
    
    try:
        from PIL import Image
    except ImportError:
        print("Pillow is not installed. Asset preparation skipped. SF Symbols will be used as fallbacks.")
        return 0
        
    print("Preparing assets...")
    
    # Render state images
    for name, raw_name in image_mappings.items():
        src_path = os.path.join(raw_dir, raw_name)
        dst_path = os.path.join(assets_dir, name)
        if os.path.exists(src_path):
            try:
                crop_center_and_resize(src_path, dst_path)
                print(f"Prepared state image {name} from {raw_name}")
            except Exception as e:
                print(f"Failed to prepare {name}: {e}", file=sys.stderr)
        else:
            print(f"Source file {raw_name} not found for {name}.", file=sys.stderr)
            
    # Render app icon
    src_icon = os.path.join(raw_dir, icon_source)
    dst_icon = os.path.join(assets_dir, "AppIcon.icns")
    if os.path.exists(src_icon):
        try:
            generate_icns(src_icon, dst_icon)
        except Exception as e:
            print(f"Failed to generate AppIcon.icns: {e}", file=sys.stderr)
    else:
        print(f"Source file {icon_source} not found for AppIcon.", file=sys.stderr)

    print("Asset preparation complete.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
