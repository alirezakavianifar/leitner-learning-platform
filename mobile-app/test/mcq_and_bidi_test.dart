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
        final list = parsed
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty && e.toLowerCase() != 'null' && e.toLowerCase() != 'none')
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {
      // Fallback: delimited string (newline, semicolon, comma)
      final parts = trimmed.contains('\n')
          ? trimmed.split('\n')
          : (trimmed.contains(';') ? trimmed.split(';') : trimmed.split(','));
      final list = parts
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.toLowerCase() != 'null' && e.toLowerCase() != 'none')
          .toList();
      if (list.isNotEmpty) return list;
    }
  }

  // 2. Try separate authoring columns (e.g. from templateDB or legacy schemas)
  const optKeys = [
    ['firstoption', 'option1', 'opt1', 'choice1', '1stoption', 'optiona', 'opta', 'choicea', 'gozine1', 'gozineh1', 'oneoption', '1st', 'opt1', 'opta'],
    ['secondoption', 'option2', 'opt2', 'choice2', '2ndoption', 'optionb', 'optb', 'choiceb', 'gozine2', 'gozineh2', 'twooption', '2nd', 'opt2', 'optb'],
    ['thirdoption', 'option3', 'opt3', 'choice3', '3rdoption', 'optionc', 'optc', 'choicec', 'gozine3', 'gozineh3', 'threeoption', '3rd', 'opt3', 'optc'],
    ['fourthoption', 'forthoption', 'option4', 'opt4', 'choice4', '4thoption', 'fouroption', 'optiond', 'optd', 'choiced', 'gozine4', 'gozineh4', 'four', '4th', 'opt4', 'optd'],
  ];

  final cleanMap = <String, dynamic>{};
  for (final entry in cardMap.entries) {
    final cleanKey = entry.key.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
    cleanMap[cleanKey] = entry.value;
  }

  final separateList = <String>[];
  for (final aliases in optKeys) {
    for (final alias in aliases) {
      if (cleanMap.containsKey(alias)) {
        final val = cleanMap[alias];
        if (val != null) {
          final str = val.toString().trim();
          final lower = str.toLowerCase();
          if (str.isNotEmpty && lower != 'null' && lower != 'none') {
            separateList.add(str);
            break;
          }
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

    test('Parses grammar_intro schema without spaces (firstoption .. fourthoption)', () {
      final map = {
        'questions': 'She _____ my best friend.',
        'firstoption': 'am',
        'secondoption': 'is',
        'thirdoption': 'are',
        'fourthoption': 'be',
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['am', 'is', 'are', 'be']));
    });

    test('Parses misspelled forthoption (without u)', () {
      final map = {
        'firstoption': 'until',
        'secondoption': 'unless',
        'thirdoption': 'despite',
        'forthoption': 'because',
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['until', 'unless', 'despite', 'because']));
    });

    test('Parses letter-based columns (option_a .. option_d)', () {
      final map = {
        'option_a': 'Option A',
        'option_b': 'Option B',
        'option_c': 'Option C',
        'option_d': 'Option D',
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['Option A', 'Option B', 'Option C', 'Option D']));
    });

    test('Parses Persian option columns (gozine1 .. gozine4)', () {
      final map = {
        'gozine1': 'الف',
        'gozine2': 'ب',
        'gozine3': 'ج',
        'gozine4': 'د',
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['الف', 'ب', 'ج', 'د']));
    });

    test('Ignores literal string NULL in non-MCQ cards', () {
      final map = {
        'questions': 'Rule explanation',
        'firstoption': 'NULL',
        'secondoption': 'NULL',
        'thirdoption': 'NULL',
        'fourthoption': 'NULL',
      };
      final result = parseTestCardOptions(map);
      expect(result, isNull);
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

    test('Parses Card #17 ("He _____ a teacher.") options correctly', () {
      final map = {
        'id': 'b5e1fcf6-8742-4d85-a60e-1d5a0b478106_17',
        'course_id': 'b5e1fcf6-8742-4d85-a60e-1d5a0b478106',
        'card_number': 17,
        'question_text': 'He _____ a teacher.',
        'answer_text': 'is',
        'options': '["am", "is", "are", "be"]',
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['am', 'is', 'are', 'be']));
    });

    test('Filters out "null" and "none" string literals inside JSON array', () {
      final map = {
        'options': '["am", "null", "is", "None", "are"]',
      };
      final result = parseTestCardOptions(map);
      expect(result, equals(['am', 'is', 'are']));
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

  group('BiDi TextPainter layout tests', () {
    testWidgets('TextPainter with LTR vs RTL on card 14 question', (tester) async {
      const text = "Hello, my name is Joshua Brown. Hi, my name is Isabella Martins. It's nice to meet you Isabella. Nice to meet you too. I'm sorry, what's your last name again? It's Martins.";
      
      // Paint with LTR
      final painterLtr = TextPainter(
        text: const TextSpan(text: text, style: TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      painterLtr.layout(maxWidth: 300);

      // Paint with RTL
      final painterRtl = TextPainter(
        text: const TextSpan(text: text, style: TextStyle(fontSize: 20)),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      );
      painterRtl.layout(maxWidth: 300);

      final boxesLtr = painterLtr.getBoxesForSelection(TextSelection(baseOffset: text.length - 1, extentOffset: text.length));
      final boxesRtl = painterRtl.getBoxesForSelection(TextSelection(baseOffset: text.length - 1, extentOffset: text.length));
      
      // In LTR, trailing period is at the right end of the text line
      // In RTL, trailing period flips to the visual left end
      expect(boxesLtr.first.left, greaterThan(boxesRtl.first.left));
      expect(detectTextDirection(text), equals(TextDirection.ltr));
    });
  });
}

