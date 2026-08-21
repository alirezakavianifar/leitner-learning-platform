-- Migration V9: Seed 1100 Words You Need to Know Course
INSERT INTO courses (id, title, description, category, difficulty, price, is_published, download_url) VALUES
('11000000-0000-0000-0000-000000001100', '1100 Words You Need to Know', 'Master 1,100 essential English vocabulary words with sentences, Persian translations, and native audio pronunciations.', 'Vocabulary', 'Intermediate', 0.00, true, '/courses/11000000-0000-0000-0000-000000001100.zip')
ON CONFLICT (id) DO UPDATE SET 
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    download_url = EXCLUDED.download_url,
    is_published = true;
