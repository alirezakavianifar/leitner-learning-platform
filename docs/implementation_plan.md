# Implementation Plan: Resolution of Audit Issues (۱۳ شهریور)

This implementation plan details the technical solutions and architectural changes required to resolve all 7 critical issues identified in the audit document `docs/ایرادات ۱۳ شهریور.PDF`.

---

## Summary of Identified Issues

| # | Issue Summary | Affected Components | Root Cause |
|---|---------------|---------------------|------------|
| **1** | **Splash Screen Appearance in ZarinPal vs. Bazaar** | `mobile-app` (Android styles/drawables) | ZarinPal build (`premium` flavor) splash screen does not use the circular adaptive icon mask present in the Bazaar build. |
| **2** | **Bazaar Paid Courses Downloaded for Free Without Payment** | `mobile-app` (Payment Provider) & `backend` (PurchaseController) | `BazaarPaymentProvider` submitted mock transaction tokens to `POST /purchases`, and the backend unconditionally marked them as `COMPLETED`, allowing free downloads. |
| **3** | **Course Distribution Flag for Target Flavors/Platforms** | `backend` (Course entity/API), `admin-panel`, `mobile-app` | No platform/flavor targeting exists on uploaded courses. All published courses appear everywhere regardless of target store. |
| **4** | **OTP Bypass `12345` Active & Admin Access Security** | `backend` (AuthController, AppSettings), `admin-panel` | Hardcoded bypass `isBypass = input.OtpCode == "12345"` permits login without SMS. Server admin access is not restricted strictly to the owner's verified mobile line. |
| **5** | **AI Tutor Option Not Exposed to Mobile Users** | `mobile-app` (Settings, Flashcards), `backend` (Config) | Server has `enable_ai_tutor` configuration, but the mobile client lacks user-facing settings to toggle and use the AI features on-demand. |
| **6** | **Payment Gateway Selector Popup in ZarinPal Flavor** | `mobile-app` (`courses_screen.dart`) | `_purchasePackage` displayed a multi-store bottom sheet modal (Bazaar, Myket, Google Play, ZarinPal) in the premium build instead of directly triggering ZarinPal. |
| **7** | **Flashcard Shuffling Button During Study** | `mobile-app` (`flashcard_bloc`, `flashcard_study_screen`) | No shuffle control exists during study. Users cannot randomize card display order while preserving original card numbers. |

---

## User Review Required

> [!IMPORTANT]
> **Owner Phone Number for Admin Access:**
> To ensure only the owner's phone number can access the Admin Panel, we will add an environment variable `ADMIN_ALLOWED_MOBILE_NUMBERS` (e.g. `0912...`). Any other mobile number attempting to log into the Admin panel or obtain the `Admin` role claim will be strictly rejected. Please confirm the owner's preferred mobile number(s).

> [!IMPORTANT]
> **Bazaar In-App Billing vs. Catalog Visibility:**
> For Issue 2 and Issue 3, mock purchases in Bazaar will be completely eliminated. With the new platform flags (Issue 3), you can choose to only display courses on Bazaar that you intend for Bazaar, and paid courses will never be downloaded without a verified purchase.

---

## Proposed Changes

### 1. Mobile App: Splash Screen & Flavor Unification (Issue 1)

#### [MODIFY] [styles.xml](file:///e:/projects/leitner_app/mobile-app/android/app/src/main/res/values/styles.xml)
#### [MODIFY] [styles.xml (night)](file:///e:/projects/leitner_app/mobile-app/android/app/src/main/res/values-night/styles.xml)
#### [MODIFY] [launch_background.xml](file:///e:/projects/leitner_app/mobile-app/android/app/src/main/res/drawable/launch_background.xml)
#### [MODIFY] [launch_background.xml (v21)](file:///e:/projects/leitner_app/mobile-app/android/app/src/main/res/drawable-v21/launch_background.xml)

- Configure `LaunchTheme` to explicitly set `android:windowSplashScreenAnimatedIcon` to `@mipmap/ic_launcher_round`.
- Ensure adaptive circular icon formatting is uniformly applied to both `premium` and `bazaar` flavors so the launch splash screen looks identical and round across all builds.
- Ensure `launch_background.xml` provides consistent background color matching the theme background.

---

### 2. Backend & Mobile App: Secure Payment & Prevent Free Downloads (Issue 2)

#### [MODIFY] [PurchaseController.cs](file:///e:/projects/leitner_app/backend/LeitnerPlatform.API/Controllers/v1/PurchaseController.cs)
- In `POST api/v1/purchases`, **remove the insecure auto-completion of unverified purchases**.
- Reject unverified client-submitted transactions that do not originate from a verified server-to-server gateway callback or verified store webhook.
- Guard against mock transactions (`BZ.mock-*`, `MK.mock-*`, `GPA.mock-*`).

#### [MODIFY] [payment_provider.dart](file:///e:/projects/leitner_app/mobile-app/lib/core/services/payment_provider.dart)
- Remove the fake mock completion from `BazaarPaymentProvider` that was sending mock transactions to `/purchases`.
- If an actual Cafe Bazaar In-App Purchase is not verified, fail securely and inform the user rather than unlocking courses for free.

---

### 3. Backend, Admin Panel, & Mobile App: Platform/Flavor Targeting for Courses (Issue 3)

#### [NEW] [V18__Add_Course_Allowed_Platforms.sql](file:///e:/projects/leitner_app/deployment/db/migrations/V18__Add_Course_Allowed_Platforms.sql)
- Add column `allowed_platforms VARCHAR(255) DEFAULT 'zarinpal,bazaar,myket,googleplay,ios'` to `courses` table.

#### [MODIFY] [Course.cs](file:///e:/projects/leitner_app/backend/LeitnerPlatform.Core/Entities/Course.cs)
- Add property `public string AllowedPlatforms { get; set; } = "zarinpal,bazaar,myket,googleplay,ios";`.

#### [MODIFY] [LeitnerDbContext.cs](file:///e:/projects/leitner_app/backend/LeitnerPlatform.Data/LeitnerDbContext.cs)
- Map `AllowedPlatforms` to `allowed_platforms` column.

#### [MODIFY] [CourseController.cs](file:///e:/projects/leitner_app/backend/LeitnerPlatform.API/Controllers/v1/CourseController.cs)
- Support `[FromQuery] string? platform` and header `X-App-Platform` on `GET /api/v1/courses`.
- Filter catalog queries so a client running a specific flavor only receives courses whose `allowed_platforms` contains that platform.

#### [MODIFY] [AdminController.cs](file:///e:/projects/leitner_app/backend/LeitnerPlatform.API/Controllers/v1/AdminController.cs)
- Accept `allowed_platforms` in course creation and update inputs. Return `allowed_platforms` in admin course listings.

#### [MODIFY] [courses/index.tsx](file:///e:/projects/leitner_app/admin-panel/src/modules/courses/index.tsx)
- Add multi-checkbox controls in the Course Upload and Course Edit modal dialogs:
  - ☑️ نسخه مستقیم / زرین‌پال (`zarinpal`)
  - ☑️ کافه بازار (`bazaar`)
  - ☑️ مایکت (`myket`)
  - ☑️ گوگل پلی (`googleplay`)
  - ☑️ آی‌او‌اس (`ios`)
- Display platform badges on each course in the admin courses table.

#### [MODIFY] [courses_screen.dart](file:///e:/projects/leitner_app/mobile-app/lib/features/courses/presentation/screens/courses_screen.dart) & [dio_client.dart](file:///e:/projects/leitner_app/mobile-app/lib/core/network/dio_client.dart)
- Send the active flavor/platform in requests (`X-App-Platform: bazaar`, `zarinpal`, etc.) to automatically fetch flavor-specific course catalogs.

---

### 4. Backend: Remove 12345 Bypass & Restrict Admin to Owner Phone Line (Issue 4)

#### [MODIFY] [AuthController.cs](file:///e:/projects/leitner_app/backend/LeitnerPlatform.API/Controllers/v1/AuthController.cs)
- **Delete the hardcoded OTP bypass:** Remove `bool isBypass = input.OtpCode == "12345";` and enforce that all verification requires valid, time-limited OTP generated and stored in Redis/memory.
- **Admin Access Restriction:** Read `ADMIN_ALLOWED_MOBILE_NUMBERS` (comma-separated list of authorized owner numbers from configuration).
- In `VerifyOtp`: Only assign `role = "Admin"` if the verified mobile number exists in the authorized admin list! Otherwise, force role to `"Student"`.
- If an unauthorized user attempts to access `/api/v1/admin/*`, return `403 Forbidden`.

#### [MODIFY] [appsettings.json](file:///e:/projects/leitner_app/backend/LeitnerPlatform.API/appsettings.json) & [.env.example](file:///e:/projects/leitner_app/.env.example) & [.env](file:///e:/projects/leitner_app/.env)
- Add `AdminSecurity:AllowedMobileNumbers` configuration setting, populated from environment variable `ADMIN_ALLOWED_MOBILE_NUMBERS`.

#### [MODIFY] [Login.tsx](file:///e:/projects/leitner_app/admin-panel/src/components/Login.tsx)
- Enforce that entering an unauthorized mobile number displays a clear, localized security notification that the number is not authorized for administrator console access.

---

### 5. Mobile App: User-Controlled AI Tutor Toggle & In-Study Integration (Issue 5)

#### [MODIFY] [settings_screen.dart](file:///e:/projects/leitner_app/mobile-app/lib/features/auth/presentation/screens/settings_screen.dart)
- Add an **AI Assistant (هوش مصنوعی / AI Tutor)** section in Settings.
- Add a toggle switch that allows the user to turn the AI learning feature ON or OFF at any time.
- Persist the preference locally in `SharedPreferences` (`user_enable_ai_tutor`).

#### [MODIFY] [flashcard_study_screen.dart](file:///e:/projects/leitner_app/mobile-app/lib/features/flashcards/presentation/screens/flashcard_study_screen.dart)
- When AI Tutor is active (enabled by the user and permitted by remote config), display an **AI Assistant Button** (sparkle / brain icon) in the card action bar.
- Tapping the button opens an AI learning breakdown / mnemonic hint / contextual explanation sheet for the current card.
- User can toggle or dismiss AI guidance anytime.

#### [MODIFY] [app_localizations.dart](file:///e:/projects/leitner_app/mobile-app/lib/core/localization/app_localizations.dart)
- Add Persian and English translations for AI Assistant settings and in-study hints (`ai_tutor_title`, `ai_tutor_desc`, `ai_hint`, `ai_smart_explanation`).

---

### 6. Mobile App: Flavor-Specific Direct Purchasing Without Multi-Store Chooser (Issue 6)

#### [MODIFY] [courses_screen.dart](file:///e:/projects/leitner_app/mobile-app/lib/features/courses/presentation/screens/courses_screen.dart)
- In `_purchasePackage` and `_purchaseCourse`:
  - In `premium` and `direct` builds: **Directly invoke `DirectPaymentProvider` (ZarinPal gateway)**.
  - **Eliminate the bottom sheet modal** listing Bazaar, Myket, and Google Play.
  - In `bazaar` build: directly invoke `BazaarPaymentProvider`.
  - In `myket` build: directly invoke `MyketPaymentProvider`.
  - In `googleplay` build: directly invoke `GooglePlayPaymentProvider`.
  - In `store` build: show store guidance.

---

### 7. Mobile App: Flashcard Shuffling Toggle During Study (Issue 7)

#### [MODIFY] [flashcard_event.dart](file:///e:/projects/leitner_app/mobile-app/lib/features/flashcards/presentation/bloc/flashcard_event.dart)
- Add `ToggleShuffleEvent extends FlashcardEvent {}`.

#### [MODIFY] [flashcard_state.dart](file:///e:/projects/leitner_app/mobile-app/lib/features/flashcards/presentation/bloc/flashcard_state.dart)
- In `FlashcardQueueLoaded`, add:
  - `final bool isShuffled;` (defaults to `false`)
  - `final List<Flashcard>? originalQueue;` (preserves original sequential order)

#### [MODIFY] [flashcard_bloc.dart](file:///e:/projects/leitner_app/mobile-app/lib/features/flashcards/presentation/bloc/flashcard_bloc.dart)
- Implement `_onToggleShuffle`:
  - When shuffling ON:
    - Save current queue as `originalQueue`.
    - Create a randomized copy of the cards list: `List<Flashcard>.from(state.queue)..shuffle()`.
    - Emit state with shuffled queue and `isShuffled: true`.
  - When shuffling OFF:
    - Restore the original sequential queue: `List<Flashcard>.from(state.originalQueue!)`.
    - Emit state with `isShuffled: false`.
  - **Critical requirement respected:** Card numbers (`card.cardNumber`) remain completely intact on each card; only the display sequence is randomized.

#### [MODIFY] [flashcard_study_screen.dart](file:///e:/projects/leitner_app/mobile-app/lib/features/flashcards/presentation/screens/flashcard_study_screen.dart)
- In the study card header, add an `IconButton` with `Icons.shuffle`.
- Visual state:
  - When inactive: neutral icon color (`AppColors.textSecondary`).
  - When active: highlighted accent color (`AppColors.secondary`) with subtle active glow or badge.
- Tapping triggers `ToggleShuffleEvent()`.
- Add tooltips: "بُر زدن کارت‌ها" / "Shuffle Cards" and "ترتیب اولیه" / "Original Order".

---

## Verification Plan

### Automated Tests
1. **Backend Unit Tests:**
   - Execute `dotnet test` on `backend/LeitnerPlatform.Tests`.
   - Verify OTP verification without 12345 fails when an incorrect OTP is supplied.
   - Verify non-authorized mobile numbers cannot obtain the `Admin` role.
   - Verify Course platform filtering returns only matching courses for `zarinpal`, `bazaar`, etc.
2. **Mobile App Tests:**
   - Run `flutter test test/flashcard_bloc_test.dart` (or new test) verifying `ToggleShuffleEvent` correctly shuffles cards, preserves card numbers, and returns to original order on toggle.
   - Verify `courses_screen` correctly triggers direct ZarinPal payment without opening a selector bottom sheet in `premium` flavor.

### Manual Verification
1. **Splash Screen Check:** Verify Android launch themes across `premium` and `bazaar` builds.
2. **Bazaar Purchase Check:** Verify paid courses cannot be downloaded without genuine payment confirmation.
3. **Course Platform Filter:** In Admin Panel, upload/edit a course with only `zarinpal` selected, verify it appears in `premium` build and does NOT appear in `bazaar` build.
4. **OTP & Admin Security:** Test logging in with code `12345` (must fail with invalid code). Test logging into Admin panel with an unconfigured mobile number (must be denied).
5. **AI Tutor Switch:** Toggle AI switch in Settings; verify AI assistant button appears during flashcard review.
6. **Shuffle Test:** Open a flashcard review with 10+ cards, note card sequence, tap Shuffle button (cards reorder randomly, card numbers unchanged), tap Shuffle again (cards return to initial sequence).
