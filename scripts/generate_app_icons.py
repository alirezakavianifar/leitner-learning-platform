import os
from PIL import Image

def generate_icons(source_path, mobile_app_dir):
    img = Image.open(source_path).convert("RGBA")
    print(f"Loaded source image: {source_path} ({img.size[0]}x{img.size[1]})")

    # Android mipmaps
    android_res = os.path.join(mobile_app_dir, "android", "app", "src", "main", "res")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        dir_path = os.path.join(android_res, folder)
        os.makedirs(dir_path, exist_ok=True)
        out_path = os.path.join(dir_path, "ic_launcher.png")
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(out_path, format="PNG")
        print(f"Generated Android {folder}/ic_launcher.png ({size}x{size})")

    # iOS AppIcon
    ios_iconset = os.path.join(mobile_app_dir, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_iconset):
        ios_sizes = {
            "Icon-App-20x20@1x.png": (20, 20),
            "Icon-App-20x20@2x.png": (40, 40),
            "Icon-App-20x20@3x.png": (60, 60),
            "Icon-App-29x29@1x.png": (29, 29),
            "Icon-App-29x29@2x.png": (58, 58),
            "Icon-App-29x29@3x.png": (87, 87),
            "Icon-App-40x40@1x.png": (40, 40),
            "Icon-App-40x40@2x.png": (80, 80),
            "Icon-App-40x40@3x.png": (120, 120),
            "Icon-App-60x60@2x.png": (120, 120),
            "Icon-App-60x60@3x.png": (180, 180),
            "Icon-App-76x76@1x.png": (76, 76),
            "Icon-App-76x76@2x.png": (152, 152),
            "Icon-App-83.5x83.5@2x.png": (167, 167),
            "Icon-App-1024x1024@1x.png": (1024, 1024),
        }
        for filename, (w, h) in ios_sizes.items():
            out_path = os.path.join(ios_iconset, filename)
            # iOS App Store icons should not contain alpha channel transparency if required, or convert to RGB if 1024x1024
            if filename == "Icon-App-1024x1024@1x.png":
                # Create RGB with white background if transparent
                bg = Image.new("RGBA", (w, h), (255, 255, 255, 255))
                res = img.resize((w, h), Image.Resampling.LANCZOS)
                composite = Image.alpha_composite(bg, res).convert("RGB")
                composite.save(out_path, format="PNG")
            else:
                resized = img.resize((w, h), Image.Resampling.LANCZOS)
                resized.save(out_path, format="PNG")
            print(f"Generated iOS {filename} ({w}x{h})")

    # Web Icons
    web_dir = os.path.join(mobile_app_dir, "web")
    if os.path.exists(web_dir):
        favicon_path = os.path.join(web_dir, "favicon.png")
        img.resize((32, 32), Image.Resampling.LANCZOS).save(favicon_path, format="PNG")
        print("Generated Web favicon.png (32x32)")

        web_icons_dir = os.path.join(web_dir, "icons")
        if os.path.exists(web_icons_dir):
            web_sizes = {
                "Icon-192.png": 192,
                "Icon-512.png": 512,
                "Icon-maskable-192.png": 192,
                "Icon-maskable-512.png": 512,
            }
            for filename, size in web_sizes.items():
                out_path = os.path.join(web_icons_dir, filename)
                img.resize((size, size), Image.Resampling.LANCZOS).save(out_path, format="PNG")
                print(f"Generated Web {filename} ({size}x{size})")

    # Windows ICO
    windows_res = os.path.join(mobile_app_dir, "windows", "runner", "resources")
    if os.path.exists(windows_res):
        ico_path = os.path.join(windows_res, "app_icon.ico")
        ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        img.save(ico_path, format="ICO", sizes=ico_sizes)
        print("Generated Windows app_icon.ico")

    # Mobile App assets/images/app_icon.png
    assets_dir = os.path.join(mobile_app_dir, "assets", "images")
    os.makedirs(assets_dir, exist_ok=True)
    app_icon_asset = os.path.join(assets_dir, "app_icon.png")
    img.resize((512, 512), Image.Resampling.LANCZOS).save(app_icon_asset, format="PNG")
    print("Generated mobile-app assets/images/app_icon.png (512x512)")

if __name__ == "__main__":
    import sys
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    source_arg = sys.argv[1] if len(sys.argv) > 1 else "icon.png"
    source = os.path.join(root_dir, source_arg) if not os.path.isabs(source_arg) else source_arg
    mobile_dir = os.path.join(root_dir, "mobile-app")
    generate_icons(source, mobile_dir)
