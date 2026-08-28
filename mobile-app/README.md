# Leitner Learning Platform - Mobile Application

A cross-platform mobile application built with Flutter & Dart for Leitner box flashcard review, course catalog browsing, and offline study.

## Features & UI Design

- **Modern Glassmorphic UI**: Vibrant theme system (`AppColors`), smooth blur backdrops, and active pill indicators.
- **Enhanced Main Page Navigation**: Modern rounded icons (`Icons.dashboard_rounded`, `Icons.style_rounded`, `Icons.school_rounded`) scaled to 28px with primary active glow containers.
- **Graphical Course Tabs**: Image-enhanced tab switcher incorporating asset illustrations (`courses_list.png` for Catalog and `my_courses.png` for My Courses).
- **Leitner Box Engine**: Automatic review interval calculations, box progression (Boxes 1–7), and offline SQLite database synchronization.
- **Top Status Bar Review Notifications & Reminders**: Background scheduled notifications alerting users when cards are due for review even when outside the app, daily study reminders, and custom reminder scheduling.
- **Store & Direct Payment Support**: Supports Zarinpal, Bazaar, Myket, and Google Play billing providers.

## Project Structure

```text
mobile-app/
├── assets/
│   ├── fonts/           # Custom typography (Vazirmatn)
│   └── images/          # Course & feature asset illustrations
├── lib/
│   ├── app/             # Application themes & state
│   ├── core/            # Common services, localization, and utilities
│   ├── features/
│   │   ├── auth/        # Authentication & Home Hub (HomeHubScreen, DashboardScreen)
│   │   ├── courses/     # Catalog & My Courses views (CoursesScreen, CourseSearchScreen)
│   │   ├── flashcards/  # Study, review tabs & Leitner engine
│   │   └── notifications/# Banners & system notifications
│   └── main.dart        # Main application entry point
├── pubspec.yaml         # Dependencies & asset declarations
└── test/                # Unit, widget, and engine test suite
```

## Setup & Running Locally

### Prerequisites

- Flutter SDK `^3.12.2` or later
- Dart SDK
- Android Studio / Xcode for device emulation

### Steps

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the application in debug mode:
   ```bash
   flutter run
   ```

3. Run static code analysis:
   ```bash
   flutter analyze
   ```

4. Execute unit & widget test suite:
   ```bash
   flutter test
   ```

## Build Artifacts

To build the release APK for Android:
```bash
flutter build apk --release
```
