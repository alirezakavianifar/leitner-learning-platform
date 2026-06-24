-- Migration V6: Update download URLs and card counts for sample courses
UPDATE courses SET 
    download_url = '/courses/c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1.zip', 
    card_count = 5, 
    version = 1 
WHERE id = 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1';

UPDATE courses SET 
    download_url = '/courses/c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2.zip', 
    card_count = 5, 
    version = 1 
WHERE id = 'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2';

UPDATE courses SET 
    download_url = '/courses/c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3.zip', 
    card_count = 5, 
    version = 1 
WHERE id = 'c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3';
