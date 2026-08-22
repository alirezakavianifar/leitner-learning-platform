-- Migration V10: Add Messenger and Support Links Configuration
INSERT INTO system_configs (key, value) VALUES
('telegram_url', 'https://t.me/RightlearnApp'),
('bale_url', 'https://ble.ir/rightlearnapp'),
('eitaa_url', 'https://eitaa.com/RightLearnApp'),
('support_url', 'https://t.me/RLAppSupport'),
('support_id', '@RLAppSupport')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
