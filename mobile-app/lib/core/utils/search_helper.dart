import 'dart:math';

/// A helper class providing typo-tolerant search matching using Levenshtein distance.
class SearchHelper {
  /// Computes the Levenshtein distance between two strings.
  static int levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }

      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v0[t.length];
  }

  /// Determines if [text] matches [query] with typo tolerance.
  /// Substring match is prioritized. For non-substring match, Levenshtein distance
  /// allows up to 1 typo for short words (<= 4 chars) and 2 typos for longer words.
  static bool fuzzyMatch(String text, String query) {
    final cleanText = text.toLowerCase().trim();
    final cleanQuery = query.toLowerCase().trim();

    if (cleanQuery.isEmpty) return true;
    if (cleanText.isEmpty) return false;

    // Direct substring match is a match
    if (cleanText.contains(cleanQuery)) return true;

    final queryWords = cleanQuery.split(RegExp(r'\s+'));
    final textWords = cleanText.split(RegExp(r'\s+'));

    for (final qWord in queryWords) {
      if (qWord.isEmpty) continue;

      bool foundWordMatch = false;
      for (final tWord in textWords) {
        if (tWord.isEmpty) continue;

        // Substring check for individual word
        if (tWord.contains(qWord)) {
          foundWordMatch = true;
          break;
        }

        // Prefix-tolerant Levenshtein check
        // Check prefixes of length qWord.length - 1, qWord.length, qWord.length + 1
        int minDistance = 999;
        final startLen = max(1, qWord.length - 1);
        final endLen = min(tWord.length, qWord.length + 1);

        for (int len = startLen; len <= endLen; len++) {
          final targetCompare = tWord.substring(0, len);
          final distance = levenshtein(qWord, targetCompare);
          if (distance < minDistance) {
            minDistance = distance;
          }
        }

        final allowedTypos = qWord.length <= 5 ? 1 : 2;
        if (minDistance <= allowedTypos) {
          foundWordMatch = true;
          break;
        }
      }

      if (!foundWordMatch) return false;
    }

    return true;
  }
}
