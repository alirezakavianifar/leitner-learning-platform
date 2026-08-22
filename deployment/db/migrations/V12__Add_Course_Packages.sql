-- V12: Add Course Packages and Bundle Purchases Tables

CREATE TABLE IF NOT EXISTS course_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    price DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    original_price DECIMAL(12, 2),
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS course_package_items (
    package_id UUID NOT NULL REFERENCES course_packages(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    display_order INT NOT NULL DEFAULT 0,
    PRIMARY KEY (package_id, course_id)
);

CREATE TABLE IF NOT EXISTS package_purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    package_id UUID NOT NULL REFERENCES course_packages(id) ON DELETE CASCADE,
    amount_paid DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    payment_provider VARCHAR(50) NOT NULL,
    transaction_id VARCHAR(150) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    purchased_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_course_packages_published ON course_packages(is_published, is_archived);
CREATE INDEX IF NOT EXISTS idx_course_package_items_pkg ON course_package_items(package_id);
CREATE INDEX IF NOT EXISTS idx_package_purchases_user_pkg ON package_purchases(user_id, package_id, status);
