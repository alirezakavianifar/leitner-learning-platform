-- Migration V5: Seed Sample Courses and Cards for testing
INSERT INTO courses (id, title, description, category, difficulty, price, is_published, download_url) VALUES
('c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1', 'Essential English Vocabulary', 'Learn the most common English words for everyday conversations. Perfect for beginners.', 'Language', 'Beginner', 0.00, true, '/courses/c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1.zip'),
('c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2', 'Advanced Flutter & State Management', 'Master complex UI designs, architecture patterns, BLoC, and performance optimization in Flutter.', 'Software Development', 'Advanced', 19.99, true, '/courses/c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2.zip'),
('c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3', 'Data Structures & Algorithms', 'Learn arrays, linked lists, stacks, queues, trees, graphs, and sorting/searching algorithms.', 'Computer Science', 'Intermediate', 0.00, true, '/courses/c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3.zip'),
('50400000-0000-0000-0000-000000000504', '504 Absolutely Essential Words', 'Master 504 essential English vocabulary words with sentences, Persian translations, and native audio pronunciations.', 'Vocabulary', 'Intermediate', 0.00, true, '/courses/50400000-0000-0000-0000-000000000504.zip')
ON CONFLICT (id) DO NOTHING;

INSERT INTO cards (id, course_id, card_number, question_text, answer_text) VALUES
-- Essential English Vocabulary
('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1', 1, 'What is the synonym of "Happy"?', 'Cheerful, joyful, content, or delighted.'),
('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a2', 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1', 2, 'Translate "Thank you" to Spanish.', '"Gracias"'),
('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a3', 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1', 3, 'What does the idiom "Break a leg" mean?', 'It means "Good luck" (usually used in performing arts).'),
('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a4', 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1', 4, 'Complete the phrase: "A blessing in _______"', 'disguise (something good that isn''t recognized at first).'),
('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a5', 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1', 5, 'What is the opposite of "Generous"?', 'Stingy or selfish.'),

-- Advanced Flutter
('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a1', 'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2', 1, 'What is the main difference between StatelessWidget and StatefulWidget?', 'StatelessWidget is immutable (its configuration cannot change over time), while StatefulWidget is mutable and can maintain state across builds via the State class.'),
('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', 'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2', 2, 'What is the purpose of InheritedWidget?', 'It allows efficiently passing data down the widget tree to descendant widgets without constructor parameter drilling.'),
('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a3', 'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2', 3, 'Explain Dart''s Single-Threaded Event Loop model.', 'Dart executes all code on a single thread (isolate) using an Event Queue (for events like UI drawing, I/O, timers) and a Microtask Queue (for high-priority internal tasks), checking microtasks first before processing the next event.'),
('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a4', 'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2', 4, 'How does Tree Shaking help in Flutter web/mobile release builds?', 'It removes unused code (such as unused icons or unreachable classes/methods) from compilation, significantly reducing the final binary/asset size.'),
('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a5', 'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2', 5, 'What is the difference between hot reload and hot restart?', 'Hot reload injects updated source code files into the Dart VM and rebuilds the widget tree without destroying app state. Hot restart destroys the current app state and reinitializes the app from scratch.'),

-- Data Structures & Algorithms
('a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a1', 'c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3', 1, 'What is the average time complexity of searching in a Hash Table?', 'O(1) (constant time), assuming a good hash function with minimal collisions.'),
('a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a2', 'c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3', 2, 'What is the main difference between a Stack and a Queue?', 'A Stack is LIFO (Last In First Out), while a Queue is FIFO (First In First Out).'),
('a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a3', 'c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3', 3, 'Explain Binary Search complexity and prerequisites.', 'Prerequisite: The array must be sorted. Time complexity: O(log n) because it divides the search space in half at each step.'),
('a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a4', 'c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3', 4, 'What is a balanced Binary Search Tree?', 'A BST where the height difference between the left and right subtrees of any node is at most 1 (e.g., AVL trees or Red-Black trees), ensuring O(log n) lookup operations.'),
('a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a5', 'c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3', 5, 'What is the time complexity of Quick Sort in the worst case?', 'O(n^2), which happens when the pivot chosen is consistently the smallest or largest element.')
ON CONFLICT (id) DO NOTHING;
