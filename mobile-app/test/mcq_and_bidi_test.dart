import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/bidi_utils.dart';

List<String>? parseTestCardOptions(Map<String, dynamic> cardMap) {
  // 1. Try single options column
  final optionsStr = cardMap['options'] as String?;
  if (optionsStr != null && optionsStr.trim().isNotEmpty) {
    final trimmed = optionsStr.trim();
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is List) {
        final list = parsed.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {
      // Fallback: delimited string (newline, semicolon, comma)
      final parts = trimmed.contains('\n')
          ? trimmed.split('\n')
          : (trimmed.contains(';') ? trimmed.split(';') : trimmed.split(','));
      final list = parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (list.isNotEmpty) return list;
    }
  }

  // 2. Try separate authoring columns (e.g. from templateDB or legacy schemas)
  const optKeys = [
    ['first option', 'first_option', 'option 1', 'option_1', 'option1', 'choice 1', 'choice_1', 'choice1'],
    ['second option', 'second_option', 'option 2', 'option_2', 'option2', 'choice 2', 'choice_2', 'choice2'],
    ['third option', 'third_option', 'option 3', 'option_3', 'option3', 'choice 3', 'choice_3', 'choice3'],
    ['fourth option', 'fourth_option', 'option 4', 'option_4', 'option4', 'choice 4', 'choice_4', 'choice4'],
  ];

  final lowerMap = <String, dynamic>{};
  for (final entry in cardMap.entries) {
    lowerMap[entry.key.toLowerCase().trim()] = entry.value;
  }

  final separateList = <String>[];
  for (final aliases in optKeys) {
    for (final alias in aliases) {
      if (lowerMap.containsKey(alias)) {
        final val = lowerMap[alias];
        if (val != null && val.toString().trim().isNotEmpty) {
          separateList.add(val.toString().trim());
          break;
        }
      }
    }
  }

  return separateList.isNotEmpty ? separateList : null;
}

void main() {
  group('BiDi Text Direction Detection', () {
    test('English sentence ending with period resolves to LTR', () {
      final direction = detectTextDirection('We are from Canada.');
      expect(direction, equals(TextDirection.ltr));
    });

    test('English fill-in-the-blank question resolves to LTR', () {
      final direction = detectTextDirection('We _____ from Canada.');
      expect(direction, equals(TextDirection.ltr));
    });

    test('English MCQ option with punctuation resolves to LTR', () {
      final direction = detectTextDirection('(A) are.');
      expect(direction, equals(TextDirection.ltr));
    });

    test('Persian sentence ending with period resolves to RTL', () {
      final direction = detectTextDirection('ما اهل کانادا هستیم.');
      expect(direction, equals(TextDirection.rtl));
    });

    test('Empty or whitespace text defaults to LTR', () {
      expect(detectTextDirection(null), equals(TextDirection.ltr));
      expect(detectTextDirection(''), equals(TextDirection.ltr));
      expect(detectTextDirection('   '), equals(TextDirection.ltr));
    });
  });

  group('Multiple-Choice Options Parsing', () {
    test('Parses standard JSON array string', () {
      final map = {
        'options': '["am", "is", "are", "be"]',
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['am', 'is', 'are', 'be']));
    });

    test('Parses comma-separated options string', () {
      final map = {
        'options': 'am, is, are, be',
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['am', 'is', 'are', 'be']));
    });

    test('Parses newline-separated options string', () {
      final map = {
        'options': "am\nis\nare\nbe",
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['am', 'is', 'are', 'be']));
    });

    test('Parses separate authoring columns (first option .. fourth option)', () {
      final map = {
        'first option': 'am',
        'second option': 'is',
        'third option': 'are',
        'fourth option': 'be',
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['am', 'is', 'are', 'be']));
    });

    test('Parses case-insensitive and aliased columns (Option 1 .. Option 4)', () {
      final map = {
        'Option 1': 'A',
        'OPTION 2': 'B',
        'Option 3': 'C',
        'Option 4': 'D',
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['A', 'B', 'C', 'D']));
    });

    test('Returns null when no options exist', () {
      final map = <String, dynamic>{
        'question_text': 'Question',
        'answer_text': 'Answer',
      };
      final result = parseTestCardOptions(map);
      expect(result, isNull);
    });
  });
}
