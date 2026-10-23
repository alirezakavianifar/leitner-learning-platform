import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/utils/search_helper.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/domain/entities/card_progress.dart';

void main() {
  group('Course & Flashcard Search Localization Tests', () {
    test('Search translation keys exist in both English and Persian', () {
      final enLoc = AppLocalizations(const Locale('en'));
      final faLoc = AppLocalizations(const Locale('fa'));

      expect(enLoc.translate('search_courses_tab'), 'Search Courses');
      expect(faLoc.translate('search_courses_tab'), 'جستجو در دوره‌ها');

      expect(enLoc.translate('search_cards_tab'), 'Search Cards');
      expect(faLoc.translate('search_cards_tab'), 'جستجو در کارت‌ها');

      expect(enLoc.translate('all_courses_filter'), 'All Courses');
      expect(faLoc.translate('all_courses_filter'), 'همه دوره‌ها');

      expect(enLoc.translate('search_courses_hint'), 'Search course or bundle title...');
      expect(faLoc.translate('search_courses_hint'), 'جستجوی عنوان دوره یا بسته...');

      expect(enLoc.translate('search_courses_catalog_hint'), 'Search courses and packages...');
      expect(faLoc.translate('search_courses_catalog_hint'), 'جستجو در عناوین دوره‌ها و بسته‌ها...');

      expect(enLoc.translate('no_courses_found_for_query'), 'No courses matched your query.');
      expect(faLoc.translate('no_courses_found_for_query'), 'دوره‌ای با این عنوان یافت نشد.');
    });
  });

  group('Catalog & My Courses Fuzzy Search Filtering Tests', () {
    const course1 = Course(
      id: 'c1',
      title: 'آموزش گرامر اینترچنج',
      description: 'آموزش قواعد و نکات دستوری زبان انگلیسی',
      price: 0,
      cardCount: 150,
      version: 1,
      isPurchased: true,
      isDownloaded: true,
    );

    const course2 = Course(
      id: 'c2',
      title: '۵۰۴ واژه کاملاً ضروری',
      description: 'لغات ضروری و پرکاربرد زبان انگلیسی برای کنکور و آیلتس',
      price: 50000,
      cardCount: 504,
      version: 1,
      isPurchased: false,
      isDownloaded: false,
    );

    const course3 = Course(
      id: 'c3',
      title: 'اصطلاحات کاربردی روزمره',
      description: 'اصطلاحات عامیانه آمریکایی و مکالمات خیابانی',
      price: 35000,
      cardCount: 200,
      version: 1,
      isPurchased: true,
      isDownloaded: false,
    );

    final courses = [course1, course2, course3];

    const package1 = CoursePackage(
      id: 'pkg-1',
      title: 'بسته طلایی زبان انگلیسی',
      description: 'شامل واژگان ۵۰۴ و گرامر',
      price: 70000,
      totalCardCount: 654,
      coursesCount: 2,
      isPurchased: false,
      courses: [course1, course2],
    );

    test('Filter courses by exact title match', () {
      final results = courses.where((c) =>
          SearchHelper.fuzzyMatch(c.title, 'گرامر') ||
          (c.description != null && SearchHelper.fuzzyMatch(c.description!, 'گرامر'))).toList();

      expect(results.length, 1);
      expect(results.first.id, 'c1');
    });

    test('Filter courses by description match', () {
      final results = courses.where((c) =>
          SearchHelper.fuzzyMatch(c.title, 'آیلتس') ||
          (c.description != null && SearchHelper.fuzzyMatch(c.description!, 'آیلتس'))).toList();

      expect(results.length, 1);
      expect(results.first.id, 'c2');
    });

    test('Filter courses with 1 typo tolerance', () {
      // "اینترچنگ" instead of "اینترچنج"
      final results = courses.where((c) =>
          SearchHelper.fuzzyMatch(c.title, 'اینترچنگ') ||
          (c.description != null && SearchHelper.fuzzyMatch(c.description!, 'اینترچنگ'))).toList();

      expect(results.length, 1);
      expect(results.first.id, 'c1');
    });

    test('Filter packages by title and by included course titles', () {
      final packages = [package1];

      // Query matched in package title
      final byPkgTitle = packages.where((pkg) {
        final titleMatch = SearchHelper.fuzzyMatch(pkg.title, 'طلایی');
        final descMatch = pkg.description != null && SearchHelper.fuzzyMatch(pkg.description!, 'طلایی');
        final courseMatch = pkg.courses.any((c) =>
            SearchHelper.fuzzyMatch(c.title, 'طلایی') ||
            (c.description != null && SearchHelper.fuzzyMatch(c.description!, 'طلایی')));
        return titleMatch || descMatch || courseMatch;
      }).toList();
      expect(byPkgTitle.length, 1);

      // Query matched inside one of the included courses ("۵۰۴")
      final byChildCourse = packages.where((pkg) {
        final titleMatch = SearchHelper.fuzzyMatch(pkg.title, '۵۰۴');
        final descMatch = pkg.description != null && SearchHelper.fuzzyMatch(pkg.description!, '۵۰۴');
        final courseMatch = pkg.courses.any((c) =>
            SearchHelper.fuzzyMatch(c.title, '۵۰۴') ||
            (c.description != null && SearchHelper.fuzzyMatch(c.description!, '۵۰۴')));
        return titleMatch || descMatch || courseMatch;
      }).toList();
      expect(byChildCourse.length, 1);
    });
  });

  group('Multi-Deck Flashcard Search Tests', () {
    const card1 = Flashcard(
      id: 'card-1',
      courseId: 'c1',
      cardNumber: 12,
      questionText: 'What is the present perfect tense?',
      answerText: 'have/has + past participle (V3)',
      progress: CardProgress(
        id: 'c1_12',
        courseId: 'c1',
        cardNumber: 12,
        currentBox: 1,
        isSynced: true,
        hasEnteredLeitner: true,
      ),
    );

    const card2 = Flashcard(
      id: 'card-2',
      courseId: 'c1',
      cardNumber: 13,
      questionText: 'Example of past continuous: I was studying',
      answerText: 'ماضی استمراری: من داشتم درس می‌خواندم',
      progress: CardProgress(
        id: 'c1_13',
        courseId: 'c1',
        cardNumber: 13,
        currentBox: 2,
        isSynced: true,
        hasEnteredLeitner: true,
      ),
    );

    const card3 = Flashcard(
      id: 'card-3',
      courseId: 'c2',
      cardNumber: 105,
      questionText: 'Abundant: existing or available in large quantities',
      answerText: 'فراوان، بسیار، بیشمار',
      progress: CardProgress(
        id: 'c2_105',
        courseId: 'c2',
        cardNumber: 105,
        currentBox: 4,
        isSynced: true,
        hasEnteredLeitner: true,
      ),
    );

    final allLoadedCards = [card1, card2, card3];

    test('Search card by exact card number across all decks', () {
      const query = '105';
      final results = allLoadedCards.where((card) {
        final matchesNumber = card.cardNumber.toString() == query.trim();
        final matchesQuestion = SearchHelper.fuzzyMatch(card.questionText, query);
        final matchesAnswer = SearchHelper.fuzzyMatch(card.answerText, query);
        return matchesNumber || matchesQuestion || matchesAnswer;
      }).toList();

      expect(results.length, 1);
      expect(results.first.id, 'card-3');
    });

    test('Search card by question text in Persian or English', () {
      const query = 'present perfect';
      final results = allLoadedCards.where((card) {
        final matchesNumber = card.cardNumber.toString() == query.trim();
        final matchesQuestion = SearchHelper.fuzzyMatch(card.questionText, query);
        final matchesAnswer = SearchHelper.fuzzyMatch(card.answerText, query);
        return matchesNumber || matchesQuestion || matchesAnswer;
      }).toList();

      expect(results.length, 1);
      expect(results.first.id, 'card-1');
    });

    test('Search card by answer text in Persian with typo tolerance', () {
      // Query "فراووان" has 1 extra letter, should match "فراوان"
      const query = 'فراووان';
      final results = allLoadedCards.where((card) {
        final matchesNumber = card.cardNumber.toString() == query.trim();
        final matchesQuestion = SearchHelper.fuzzyMatch(card.questionText, query);
        final matchesAnswer = SearchHelper.fuzzyMatch(card.answerText, query);
        return matchesNumber || matchesQuestion || matchesAnswer;
      }).toList();

      expect(results.length, 1);
      expect(results.first.id, 'card-3');
    });

    test('Scoped search filtering by selected courseId chip', () {
      const selectedCourseId = 'c1';
      final sourceCards = allLoadedCards.where((c) => c.courseId == selectedCourseId).toList();

      // Query "فراوان" only exists in c2, so searching in c1 returns empty
      const query = 'فراوان';
      final results = sourceCards.where((card) {
        final matchesNumber = card.cardNumber.toString() == query.trim();
        final matchesQuestion = SearchHelper.fuzzyMatch(card.questionText, query);
        final matchesAnswer = SearchHelper.fuzzyMatch(card.answerText, query);
        return matchesNumber || matchesQuestion || matchesAnswer;
      }).toList();

      expect(results, isEmpty);

      // But searching "studying" in c1 succeeds
      final resultsC1 = sourceCards.where((card) {
        final matchesNumber = card.cardNumber.toString() == 'studying';
        final matchesQuestion = SearchHelper.fuzzyMatch(card.questionText, 'studying');
        final matchesAnswer = SearchHelper.fuzzyMatch(card.answerText, 'studying');
        return matchesNumber || matchesQuestion || matchesAnswer;
      }).toList();

      expect(resultsC1.length, 1);
      expect(resultsC1.first.id, 'card-2');
    });
  });
}
