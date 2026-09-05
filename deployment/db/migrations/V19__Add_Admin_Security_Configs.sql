-- Migration V19: Add Admin Security & Emergency Access Configs
-- Allows dynamic in-panel administration of admin mobile numbers whitelist
-- and configurable emergency backup access for first-time setup or outages.

INSERT INTO system_configs (key, value) VALUES
('admin_allowed_mobile_numbers', '09120000000,+989120000000'),
('admin_emergency_bypass_enabled', 'true')
ON CONFLICT (key) DO NOTHING;
