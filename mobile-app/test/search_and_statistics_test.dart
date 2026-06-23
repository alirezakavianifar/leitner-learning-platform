import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/search_helper.dart';

void main() {
  group('Levenshtein Distance Tests', () {
    test('Should return 0 for identical strings', () {
      expect(SearchHelper.levenshtein('hello', 'hello'), 0);
      expect(SearchHelper.levenshtein('', ''), 0);
    });

    test('Should return length of non-empty string when compared to empty string', () {
      expect(SearchHelper.levenshtein('test', ''), 4);
      expect(SearchHelper.levenshtein('', 'apple'), 5);
    });

    test('Should return correct distance for insertions, deletions, and substitutions', () {
      // Substitution
      expect(SearchHelper.levenshtein('cat', 'bat'), 1);
      // Insertion
      expect(SearchHelper.levenshtein('cat', 'cats'), 1);
      // Deletion
      expect(SearchHelper.levenshtein('cats', 'cat'), 1);
      // Mixed
      expect(SearchHelper.levenshtein('kitten', 'sitting'), 3);
    });
  });

  group('Fuzzy Match Typo-Tolerant Search Tests', () {
    test('Should match direct exact/substring queries', () {
      expect(SearchHelper.fuzzyMatch('Advanced Mathematics', 'Math'), true);
      expect(SearchHelper.fuzzyMatch('English Grammar Essentials', 'english grammar'), true);
      expect(SearchHelper.fuzzyMatch('General Knowledge', 'Knowledge'), true);
    });

    test('Should match query with 1 typo for short words (length <= 4)', () {
      // "Math" vs "Msth" (substitution, distance 1)
      expect(SearchHelper.fuzzyMatch('Advanced Mathematics', 'Msth'), true);
      // "Word" vs "Wrd" (deletion, distance 1)
      expect(SearchHelper.fuzzyMatch('Vocabulary Words', 'Wrd'), true);
    });

    test('Should match query with 2 typos for longer words', () {
      // "Grammar" vs "Grammer" (distance 1)
      expect(SearchHelper.fuzzyMatch('English Grammar Essentials', 'grammer'), true);
      // "Vocabulary" vs "Vocabularx" (distance 1)
      expect(SearchHelper.fuzzyMatch('Important Vocabulary', 'vocabularx'), true);
      // "Vocabulary" vs "Vocabularix" (distance 2)
      expect(SearchHelper.fuzzyMatch('Important Vocabulary', 'vocabularix'), true);
    });

    test('Should fail if typos exceed the tolerated threshold', () {
      // "Math" vs "Msthx" (distance 2, word length 4 <= 4: allowed 1 typo)
      expect(SearchHelper.fuzzyMatch('Advanced Mathematics', 'Msthx'), false);
      // "Vocabulary" vs "Vcbly" (distance 5, too many typos)
      expect(SearchHelper.fuzzyMatch('Important Vocabulary', 'Vcbly'), false);
      // Unrelated words
      expect(SearchHelper.fuzzyMatch('Physics', 'History'), false);
    });

    test('Should support multi-word fuzzy matching', () {
      // "english grammer" matches "English Grammar"
      expect(SearchHelper.fuzzyMatch('English Grammar Essentials', 'englesh grammer'), true);
      // "physics formla" matches "Physics Formulas"
      expect(SearchHelper.fuzzyMatch('Physics Formulas Guide', 'physics formla'), true);
    });
  });
}
