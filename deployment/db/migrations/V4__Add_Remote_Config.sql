-- Migration V4: Add Remote Configuration support
CREATE TABLE system_configs (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO system_configs (key, value) VALUES
('maintenance_mode', 'false'),
('api_server', 'http://10.0.2.2:8080/api/v1'),
('content_server', 'http://10.0.2.2:8080/api/v1'),
('banner_server', 'http://10.0.2.2:8080/api/v1'),
('rotation_interval_seconds', '4'),
('max_banner_count', '5'),
('enable_ai_tutor', 'false'),
('enable_custom_themes', 'true'),
('enable_search_v2', 'true');
