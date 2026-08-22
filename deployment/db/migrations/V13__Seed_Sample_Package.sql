-- V13: Seed Vocabulary Master Bundle Package

INSERT INTO course_packages (id, title, description, category, price, original_price, is_published, is_archived, display_order, created_at)
VALUES (
    'b1000000-0000-0000-0000-000000000001',
    'پکیج جامع واژگان زبان انگلیسی (504 + 1100 واژه)',
    'مجموعه جامع و طلایی واژگان ضروری زبان انگلیسی شامل دو دوره پرطرفدار ۵۰۴ واژه کاملاً ضروری و ۱۱۰۰ واژه با تخفیف ویژه به همراه فایل‌های صوتی بومی و مثال‌های کاربردی.',
    'Vocabulary',
    3500.00,
    5000.00,
    TRUE,
    FALSE,
    1,
    CURRENT_TIMESTAMP
) ON CONFLICT (id) DO NOTHING;

INSERT INTO course_package_items (package_id, course_id, display_order)
VALUES
    ('b1000000-0000-0000-0000-000000000001', '50400000-0000-0000-0000-000000000504', 1),
    ('b1000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000001100', 2)
ON CONFLICT (package_id, course_id) DO NOTHING;
