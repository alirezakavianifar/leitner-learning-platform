import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage


def prepare_optimized_master(source_path):
    """
    Loads the source icon, detects and cleans up any faux checkerboard or
    alpha fringe, squares the canvas preserving artwork proportions,
    and produces an optimized solid RGB 1024x1024 master image.
    """
    raw_img = Image.open(source_path).convert("RGB")
    arr = np.array(raw_img, dtype=float)
    h, w, _ = arr.shape

    # Detect faux checkerboard in outer corners:
    # Checkerboard squares are bright neutral pixels (R, G, B > 150 and nearly equal)
    is_gray = (
        (arr[:, :, 0] > 150)
        & (arr[:, :, 1] > 150)
        & (arr[:, :, 2] > 150)
        & (np.abs(arr[:, :, 0] - arr[:, :, 1]) < 25)
        & (np.abs(arr[:, :, 1] - arr[:, :, 2]) < 25)
        & (np.abs(arr[:, :, 0] - arr[:, :, 2]) < 25)
    )

    lbl, _ = ndimage.label(is_gray)
    corner_labels = set([lbl[0, 0], lbl[0, w - 1], lbl[h - 1, 0], lbl[h - 1, w - 1]]) - {0}
    has_checker = len(corner_labels) > 0 and (
        lbl[0, 0] in corner_labels
        or lbl[0, w - 1] in corner_labels
        or lbl[h - 1, 0] in corner_labels
        or lbl[h - 1, w - 1] in corner_labels
    )

    bg_color = np.array([0, 11, 25], dtype=float)

    if has_checker:
        outer_checker = np.isin(lbl, list(corner_labels))
        mask_float = outer_checker.astype(float)
        blurred_mask = ndimage.gaussian_filter(mask_float, sigma=1.5)
        alpha = np.clip(1.0 - blurred_mask, 0.0, 1.0) * 255.0
        norm_alpha = alpha / 255.0

        fg_rgb = arr.copy()
        for c in range(3):
            edge_zone = (norm_alpha > 0.05) & (norm_alpha < 0.98)
            fg_rgb[edge_zone, c] = np.clip(
                (arr[edge_zone, c] - (1.0 - norm_alpha[edge_zone]) * 245.0)
                / np.maximum(norm_alpha[edge_zone], 0.01),
                0,
                255,
            )
            fg_rgb[norm_alpha <= 0.05, c] = bg_color[c]

        solid_rgb = np.zeros_like(fg_rgb)
        for c in range(3):
            solid_rgb[:, :, c] = fg_rgb[:, :, c] * norm_alpha + bg_color[c] * (1.0 - norm_alpha)

        img_solid = Image.fromarray(solid_rgb.astype(np.uint8))
    else:
        img_solid = raw_img

    # Pad to square preserving artwork aspect ratio and centered
    max_dim = max(h, w)
    square_solid = Image.new("RGB", (max_dim, max_dim), tuple(bg_color.astype(int)))
    square_solid.paste(img_solid, ((max_dim - w) // 2, (max_dim - h) // 2))

    master_solid = square_solid.resize((1024, 1024), Image.Resampling.LANCZOS)
    return master_solid


def generate_icons(source_path, mobile_app_dir, root_dir=None):
    print(f"Loading and optimizing source image: {source_path}")
    master_solid = prepare_optimized_master(source_path)
    print("Master 1024x1024 optimized icon successfully prepared.")

    # 1. Android mipmaps
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
        resized = master_solid.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(out_path, format="PNG", optimize=True)
        print(f"Generated Android {folder}/ic_launcher.png ({size}x{size})")

    # 2. iOS AppIcon
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
            resized = master_solid.resize((w, h), Image.Resampling.LANCZOS)
            # App Store requires RGB without alpha
            if resized.mode != "RGB":
                resized = resized.convert("RGB")
            resized.save(out_path, format="PNG", optimize=True)
            print(f"Generated iOS {filename} ({w}x{h})")

    # 3. macOS AppIcon
    macos_iconset = os.path.join(mobile_app_dir, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(macos_iconset):
        macos_sizes = {
            "app_icon_16.png": 16,
            "app_icon_32.png": 32,
            "app_icon_64.png": 64,
            "app_icon_128.png": 128,
            "app_icon_256.png": 256,
            "app_icon_512.png": 512,
            "app_icon_1024.png": 1024,
        }
        for filename, size in macos_sizes.items():
            out_path = os.path.join(macos_iconset, filename)
            resized = master_solid.resize((size, size), Image.Resampling.LANCZOS)
            resized.save(out_path, format="PNG", optimize=True)
            print(f"Generated macOS {filename} ({size}x{size})")

    # 4. Web Icons
    web_dir = os.path.join(mobile_app_dir, "web")
    if os.path.exists(web_dir):
        favicon_path = os.path.join(web_dir, "favicon.png")
        master_solid.resize((32, 32), Image.Resampling.LANCZOS).save(favicon_path, format="PNG", optimize=True)
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
                master_solid.resize((size, size), Image.Resampling.LANCZOS).save(out_path, format="PNG", optimize=True)
                print(f"Generated Web {filename} ({size}x{size})")

    # 5. Windows ICO
    windows_res = os.path.join(mobile_app_dir, "windows", "runner", "resources")
    if os.path.exists(windows_res):
        ico_path = os.path.join(windows_res, "app_icon.ico")
        ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        master_solid.save(ico_path, format="ICO", sizes=ico_sizes)
        print("Generated Windows app_icon.ico")

    # 6. Mobile App in-app assets: app_icon.webp & app_icon.png
    assets_dir = os.path.join(mobile_app_dir, "assets", "images")
    os.makedirs(assets_dir, exist_ok=True)

    app_icon_webp = os.path.join(assets_dir, "app_icon.webp")
    master_512 = master_solid.resize((512, 512), Image.Resampling.LANCZOS)
    master_512.save(app_icon_webp, format="WEBP", quality=90, method=6)
    print("Generated mobile-app assets/images/app_icon.webp (512x512, optimized WebP)")

    app_icon_png = os.path.join(assets_dir, "app_icon.png")
    master_512.save(app_icon_png, format="PNG", optimize=True)
    print("Generated mobile-app assets/images/app_icon.png (512x512, optimized PNG)")

    # 7. Root icon.png
    if root_dir:
        root_icon = os.path.join(root_dir, "icon.png")
        master_solid.save(root_icon, format="PNG", optimize=True)
        print("Generated root icon.png (1024x1024, optimized master PNG)")


def generate_notification_icons(notification_source, mobile_app_dir):
    if not os.path.exists(notification_source):
        return
    print(f"Loading notification icon: {notification_source}")
    img = Image.open(notification_source).convert("RGBA")
    res_dir = os.path.join(mobile_app_dir, "android", "app", "src", "main", "res")
    sizes = {
        "drawable": 32,
        "drawable-mdpi": 24,
        "drawable-hdpi": 36,
        "drawable-xhdpi": 48,
        "drawable-xxhdpi": 72,
        "drawable-xxxhdpi": 96,
        "mipmap-mdpi": 24,
        "mipmap-hdpi": 36,
        "mipmap-xhdpi": 48,
        "mipmap-xxhdpi": 72,
        "mipmap-xxxhdpi": 96,
    }
    for folder, size in sizes.items():
        d = os.path.join(res_dir, folder)
        os.makedirs(d, exist_ok=True)
        out = os.path.join(d, "ic_notification.png")
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(out, format="PNG", optimize=True)
        print(f"Generated {folder}/ic_notification.png ({size}x{size})")


if __name__ == "__main__":
    current_script_dir = os.path.dirname(os.path.abspath(__file__))
    root_directory = os.path.dirname(current_script_dir)

    source_input = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root_directory, "icon", "icon.png")
    if not os.path.isabs(source_input):
        source_input = os.path.join(root_directory, source_input)

    notif_input = os.path.join(root_directory, "icon", "notification.png")
    mobile_directory = os.path.join(root_directory, "mobile-app")

    generate_icons(source_input, mobile_directory, root_directory)
    if os.path.exists(notif_input):
        generate_notification_icons(notif_input, mobile_directory)

