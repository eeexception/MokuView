import os
import json
from PIL import Image

def generate_icons(source_path, output_dir):
    if not os.path.exists(source_path):
        print(f"Error: Source icon not found at {source_path}")
        return

    icon_set_path = os.path.join(output_dir, "AppIcon.appiconset")
    os.makedirs(icon_set_path, exist_ok=True)

    with Image.open(source_path) as img:
        # Define icons for macOS
        icons = [
            {"size": "16x16", "idiom": "mac", "filename": "icon-16.png", "scale": "1x"},
            {"size": "16x16", "idiom": "mac", "filename": "icon-16@2x.png", "scale": "2x"},
            {"size": "32x32", "idiom": "mac", "filename": "icon-32.png", "scale": "1x"},
            {"size": "32x32", "idiom": "mac", "filename": "icon-32@2x.png", "scale": "2x"},
            {"size": "128x128", "idiom": "mac", "filename": "icon-128.png", "scale": "1x"},
            {"size": "128x128", "idiom": "mac", "filename": "icon-128@2x.png", "scale": "2x"},
            {"size": "256x256", "idiom": "mac", "filename": "icon-256.png", "scale": "1x"},
            {"size": "256x256", "idiom": "mac", "filename": "icon-256@2x.png", "scale": "2x"},
            {"size": "512x512", "idiom": "mac", "filename": "icon-512.png", "scale": "1x"},
            {"size": "512x512", "idiom": "mac", "filename": "icon-512@2x.png", "scale": "2x"}
        ]

        contents = {
            "images": [],
            "info": {
                "version": 1,
                "author": "xcode"
            }
        }

        for icon in icons:
            size_val = float(icon["size"].split('x')[0])
            scale_val = int(icon["scale"].replace('x', ''))
            pixel_size = int(size_val * scale_val)
            
            resized_img = img.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
            resized_img.save(os.path.join(icon_set_path, icon["filename"]))
            
            contents["images"].append({
                "size": icon["size"],
                "idiom": icon["idiom"],
                "filename": icon["filename"],
                "scale": icon["scale"]
            })

        with open(os.path.join(icon_set_path, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)

    print(f"Icons generated successfully in {icon_set_path}")

if __name__ == "__main__":
    source = "assets/icon.png"
    output = "Sources/Assets.xcassets"
    generate_icons(source, output)
