import os
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


def prepare_masters(source_path):
    """
    Loads the source icon, detects and cleans up any faux checkerboard or
    alpha fringe, and produces:
    - master_squircle: 1024x1024 RGBA image with smooth anti-aliased transparent corners.
    - master_round: 1024x1024 RGBA image masked into a perfect circle on transparent canvas.
    - master_adaptive_fg: 1024x1024 RGBA image scaled to the 72dp safe zone in 108dp canvas (~70%).
    - master_solid: 1024x1024 RGB image (no alpha) for iOS App Store and systems requiring opaque icons.
    """
    raw_img = Image.open(source_path).convert("RGB")
    w, h = raw_img.size

    # Square canvas based on max dimension
    max_dim = max(w, h)
    offset_x = (max_dim - w) // 2
    offset_y = (max_dim - h) // 2

    # Navy background color sampled from inside the squircle
    bg_color = (0, 15, 35)

    sq_orig = Image.new("RGB", (max_dim, max_dim), bg_color)
    sq_orig.paste(raw_img, (offset_x, offset_y))

    # Resize base to 1024x1024
    img_1024 = sq_orig.resize((1024, 1024), Image.Resampling.LANCZOS)

    # 1. Generate master_squircle with smooth anti-aliased transparent corners (superellipse / rounded rect)
    # Render mask at 4x (4096x4096) for crisp sub-pixel anti-aliasing
    mask_hires = Image.new("L", (4096, 4096), 0)
    draw_sq = ImageDraw.Draw(mask_hires)
    # Inset slightly (60px on 4096 = 15px on 1024) to eliminate any edge fringe from the raw image
    draw_sq.rounded_rectangle((60, 60, 4036, 4036), radius=900, fill=255)
    squircle_mask = mask_hires.resize((1024, 1024), Image.Resampling.LANCZOS)

    master_squircle = img_1024.copy().convert("RGBA")
    master_squircle.putalpha(squircle_mask)

    # 2. Generate master_round: smooth circular icon on transparent background
    mask_round_hires = Image.new("L", (4096, 4096), 0)
    draw_rnd = ImageDraw.Draw(mask_round_hires)
    draw_rnd.ellipse((60, 60, 4036, 4036), fill=255)
    round_mask = mask_round_hires.resize((1024, 1024), Image.Resampling.LANCZOS)

    # Scale squircle artwork to ~90% so it fits comfortably inside the circle boundary
    sq_scaled_for_round = master_squircle.resize((920, 920), Image.Resampling.LANCZOS)
    canvas_round = Image.new("RGBA", (1024, 1024), (*bg_color, 255))
    canvas_round.paste(sq_scaled_for_round, ((1024 - 920) // 2, ((1024 - 920) // 2)), sq_scaled_for_round)

    master_round = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    master_round.paste(canvas_round, (0, 0), round_mask)

    # 3. Generate master_adaptive_fg: artwork centered in 72dp safe zone of 108dp canvas (720x720 in 1024x1024 = 70.3%)
    fg_scaled = master_squircle.resize((720, 720), Image.Resampling.LANCZOS)
    master_adaptive_fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    master_adaptive_fg.paste(fg_scaled, ((1024 - 720) // 2, (1024 - 720) // 2), fg_scaled)

    # 4. Generate master_solid (RGB without alpha for iOS App Store requirements)
    master_solid = Image.new("RGB", (1024, 1024), bg_color)
    master_solid.paste(master_squircle, (0, 0), master_squircle)

    return master_squircle, master_round, master_adaptive_fg, master_solid


def generate_icons(source_path, mobile_app_dir, root_dir=None):
    print(f"Loading and optimizing source image: {source_path}")
    master_squircle, master_round, master_adaptive_fg, master_solid = prepare_masters(source_path)
    print("Master icons (squircle, round, adaptive foreground, solid) prepared successfully.")

    android_res = os.path.join(mobile_app_dir, "android", "app", "src", "main", "res")

    # Ensure values/colors.xml contains ic_launcher_background
    values_dir = os.path.join(android_res, "values")
    os.makedirs(values_dir, exist_ok=True)
    colors_xml_path = os.path.join(values_dir, "colors.xml")
    if not os.path.exists(colors_xml_path):
        with open(colors_xml_path, "w", encoding="utf-8") as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#000F23</color>\n</resources>\n')
        print("Created values/colors.xml with ic_launcher_background.")
    else:
        with open(colors_xml_path, "r", encoding="utf-8") as f:
            content = f.read()
        if "ic_launcher_background" not in content:
            updated = content.replace("</resources>", '    <color name="ic_launcher_background">#000F23</color>\n</resources>')
            with open(colors_xml_path, "w", encoding="utf-8") as f:
                f.write(updated)
            print("Updated values/colors.xml with ic_launcher_background.")

    # 1. Android Adaptive Icons (API 26+)
    anydpi_dir = os.path.join(android_res, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    adaptive_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(adaptive_xml)
    with open(os.path.join(anydpi_dir, "ic_launcher_round.xml"), "w", encoding="utf-8") as f:
        f.write(adaptive_xml)
    print("Generated mipmap-anydpi-v26/ic_launcher.xml and ic_launcher_round.xml")

    # 2. Android Density Mipmaps (Legacy icons, Round icons, and Adaptive Foreground)
    android_specs = {
        "mipmap-mdpi": {"legacy": 48, "foreground": 108},
        "mipmap-hdpi": {"legacy": 72, "foreground": 162},
        "mipmap-xhdpi": {"legacy": 96, "foreground": 216},
        "mipmap-xxhdpi": {"legacy": 144, "foreground": 324},
        "mipmap-xxxhdpi": {"legacy": 192, "foreground": 432},
    }
    for folder, specs in android_specs.items():
        dir_path = os.path.join(android_res, folder)
        os.makedirs(dir_path, exist_ok=True)
        leg_size = specs["legacy"]
        fg_size = specs["foreground"]

        # Legacy squircle icon with transparent corners (rendered in package installer)
        out_launcher = os.path.join(dir_path, "ic_launcher.png")
        master_squircle.resize((leg_size, leg_size), Image.Resampling.LANCZOS).save(out_launcher, format="PNG", optimize=True)

        # Legacy round icon with transparent background
        out_round = os.path.join(dir_path, "ic_launcher_round.png")
        master_round.resize((leg_size, leg_size), Image.Resampling.LANCZOS).save(out_round, format="PNG", optimize=True)

        # Adaptive icon foreground
        out_fg = os.path.join(dir_path, "ic_launcher_foreground.png")
        master_adaptive_fg.resize((fg_size, fg_size), Image.Resampling.LANCZOS).save(out_fg, format="PNG", optimize=True)

        print(f"Generated Android {folder}: ic_launcher.png ({leg_size}x{leg_size}), ic_launcher_round.png, ic_launcher_foreground.png ({fg_size}x{fg_size})")

    # 3. iOS AppIcon
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
            if resized.mode != "RGB":
                resized = resized.convert("RGB")
            resized.save(out_path, format="PNG", optimize=True)
            print(f"Generated iOS {filename} ({w}x{h})")

    # 4. macOS AppIcon
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
            resized = master_squircle.resize((size, size), Image.Resampling.LANCZOS)
            resized.save(out_path, format="PNG", optimize=True)
            print(f"Generated macOS {filename} ({size}x{size})")

    # 5. Web Icons
    web_dir = os.path.join(mobile_app_dir, "web")
    if os.path.exists(web_dir):
        favicon_path = os.path.join(web_dir, "favicon.png")
        master_squircle.resize((32, 32), Image.Resampling.LANCZOS).save(favicon_path, format="PNG", optimize=True)
        print("Generated Web favicon.png (32x32)")

        web_icons_dir = os.path.join(web_dir, "icons")
        if os.path.exists(web_icons_dir):
            web_sizes = {
                "Icon-192.png": (master_squircle, 192),
                "Icon-512.png": (master_squircle, 512),
                "Icon-maskable-192.png": (master_round, 192),
                "Icon-maskable-512.png": (master_round, 512),
            }
            for filename, (img_src, size) in web_sizes.items():
                out_path = os.path.join(web_icons_dir, filename)
                img_src.resize((size, size), Image.Resampling.LANCZOS).save(out_path, format="PNG", optimize=True)
                print(f"Generated Web {filename} ({size}x{size})")

    # 6. Windows ICO
    windows_res = os.path.join(mobile_app_dir, "windows", "runner", "resources")
    if os.path.exists(windows_res):
        ico_path = os.path.join(windows_res, "app_icon.ico")
        ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        master_squircle.save(ico_path, format="ICO", sizes=ico_sizes)
        print("Generated Windows app_icon.ico")

    # 7. Mobile App in-app assets: app_icon.webp & app_icon.png
    assets_dir = os.path.join(mobile_app_dir, "assets", "images")
    os.makedirs(assets_dir, exist_ok=True)

    app_icon_webp = os.path.join(assets_dir, "app_icon.webp")
    master_512 = master_squircle.resize((512, 512), Image.Resampling.LANCZOS)
    master_512.save(app_icon_webp, format="WEBP", quality=92, method=6)
    print("Generated mobile-app assets/images/app_icon.webp (512x512, optimized WebP)")

    app_icon_png = os.path.join(assets_dir, "app_icon.png")
    master_512.save(app_icon_png, format="PNG", optimize=True)
    print("Generated mobile-app assets/images/app_icon.png (512x512, optimized PNG)")

    # 8. Root icon.png
    if root_dir:
        root_icon = os.path.join(root_dir, "icon.png")
        master_squircle.save(root_icon, format="PNG", optimize=True)
        print("Generated root icon.png (1024x1024, clean transparent squircle PNG)")


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
