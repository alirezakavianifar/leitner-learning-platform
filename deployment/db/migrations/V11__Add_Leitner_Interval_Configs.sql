-- Migration V11: Add configurable Leitner stage intervals
INSERT INTO system_configs (key, value) VALUES
('leitner_box2_interval', '3'),
('leitner_box3_interval', '7'),
('leitner_box4_interval', '16'),
('leitner_box5_interval', '31'),
('leitner_interval_unit', 'days')
ON CONFLICT (key) DO NOTHING;
