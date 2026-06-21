# Requirements Clarification Document (RCD)

**Project:** Leitner Learning Platform  
**Status:** Under Review (Phase 0 - Scope Locked Draft)  
**Date:** June 21, 2026  

---

## 1. Project Overview & Deliverables

The **Leitner Learning Platform** is an offline-first mobile application (for both Android and iOS) powered by a central backend API and an administrative panel. It leverages the classical Leitner spaced repetition system, enhanced with custom business rules designed by the client to maximize memory retention and content security.

This document serves as the formal **Requirements Clarification Document (RCD)** for **Phase 0 (Project Scope Definition & Contract Lock)** as specified in the [plan.md](file:///e:/projects/leitner-learning-platform/plan.md).

---

## 2. Scope Hierarchy Rule

> [!IMPORTANT]
> **Scope Hierarchy Rule:** Any functionality explicitly stated in the client's requirement PDF (`document.PDF`), in written conversation agreements, or reasonably required for a complete, secure, and production-ready implementation of those requirements shall be considered included in the project scope unless specifically excluded in writing within this document. The PDF defines the framework; standard application best practices (e.g., input validation, basic error logging, user experience flows) are included by default.

---

## 3. Included Features

The following features are officially in-scope and will be implemented during the project lifecycle:

### A. Mobile Application (Android & iOS)
1. **Offline-First Capabilities:** After downloading course packages (structured SQLite databases + associated media files), the app must be fully functional offline without requiring an active internet connection.
2. **OTP Verification:** First-time login and user authentication via SMS One-Time Passwords (OTP).
3. **Mandatory Terms & Rules Acceptance Screen:** Users must accept a set of rules and terms after OTP verification and before completing their profile.
4. **Profile Management:** Users can edit their username, educational interests, educational field, and educational level. The **mobile number field must be read-only** and non-editable.
5. **Global Bottom Navigation:** A persistent bottom navigation bar visible on all main screens (Home, Review, Courses).
6. **Dynamic Home Dashboard:**
   - Ad Banner Carousel: Up to 5 banners rotating automatically every 4 seconds. Updates from the server once every 24 hours. Clicking navigates to internal app pages or external web links.
   - Announcements / Notifications list.
7. **Course List Screen:**
   - Purchased/downloaded courses are displayed at the top of the list.
   - Green borders indicate downloaded courses; yellow borders indicate unpurchased or not-yet-downloaded courses.
   - Cards show course title, card count, paid/free status, and the colored status border.
   - *Offline Behavior:* Shows cached courses and displays a status message stating: *"Internet connection unavailable; course catalog update not performed."*
8. **My Courses Screen:** Displays only purchased and downloaded courses with a green border.
9. **Leitner Review Screen (Flashcard Loop):**
   - Three-section presentation layout: Fixed header (course title, colored Leitner stage indicator), rotating center card (flips on tap to show question/answer, displays images and audio, hides missing elements dynamically), and fixed footer.
   - Navigation buttons (left/right arrows) and a star icon to favorite cards.
   - Direct card jump: Clicking the card number prompts for input. If the card is in active Leitner Boxes 2-5, a warning dialog must confirm that viewing the card resets its progress to Box 1.
   - Spaced repetition algorithm mapping (6 stages: Boxes 1–5, and Finished Cards).
10. **Custom Leitner Business & Reset Rules:**
    - *Incorrect Answer Reset:* Answering incorrectly resets the card's progress immediately back to Box 1.
    - *Due-Date Overdue Reset (Rule A):* If a card is due on a given day and the user does NOT review it on that day, it is reset back to Box 1.
    - *Favorites View Reset (Rule B):* Viewing a card from the "Favorites" screen resets its progress to Box 1 (requires user confirmation before viewing).
    - *Card Number View Reset (Rule C):* Directly searching/navigating to a card in Boxes 2-5 resets its progress to Box 1 (requires user confirmation).
    - *Only Due Cards Restriction:* Navigation within a course restricts users from browsing or reviewing cards in intermediate boxes (Boxes 2–5) before their due date.
    - *Finished Cards Behavior:* Pressing "Know It" does nothing. Pressing "Don't Know" resets the card back to Box 1.
11. **User-Created Cards:**
    - Stored strictly locally on the device (device-only storage).
    - Includes offline local backup/restore functionality to export cards/progress to an encrypted file (sharable via system share sheet) and import it after app reinstallation.
12. **Settings Screen:** Option to change flashcard font size, select theme (dark/light), and a Logout button with a mandatory confirmation modal dialog.
13. **Guided Tutorials & Color Guides:**
    - First-run guided onboarding walkthrough following the PDF sequence: *Courses -> Search -> Flashcard -> Know button -> Don't Know button -> Create Card -> Finished Cards -> Favorites -> My Courses -> Reports -> Today's Cards -> Statistics*.
    - Leitner system explanation screen and a color guide screen mapping box statuses: Orange (Box 1), Yellow (Box 2), Green (Box 3), Blue (Box 4), Purple (Box 5), and Gold (Finished Cards).
14. **Progress Statistics Screen:**
    - Global metrics showing total courses and total cards count.
    - Leitner box distribution percentage bars matching corresponding box colors (Orange, Yellow, Green, Blue, Purple, Gold).
    - Per-course statistics list at the bottom showing progress bars.
15. **Targeted Search System:**
    - Typo-tolerant search across courses and cards.
    - Search process: Search courses -> select one/multiple courses -> search cards inside selected courses -> view matching card list -> tap card to view (Rule C warnings apply).
16. **Flashcard Reporting System:** Users can submit reports/feedback on cards. Submitted reports store User ID, Course ID/title, Card number, Report text, and Timestamp.
17. **Support Screen:** Support contacts and social media links.
18. **About Us Screen:** Team descriptions (text provided by client).
19. **Content Protection:**
    - Local SQLite database encryption and media encryption.
    - Discourage piracy with watermarked content displays.

### B. Backend API & Server
1. **Domain-Separated Clean Architecture:** decoupled domain modules (Auth, User, Course, Purchase, Notification, Analytics, Configuration).
2. **Versioned REST API routes:** prefixing all endpoints (e.g., `/api/v1/auth`, `/api/v1/courses`).
3. **Database Migration Framework:** server database schemas managed under version control.
4. **Dynamic Remote Configuration & Feature Flags:** remote config service allowing server endpoints (API server, content server, banner server), feature flags, active notification configurations, and global maintenance modes to be updated dynamically without app store updates.
5. **Immediate Off-Server Replication Backups:** automated, immediate replication of user registration and purchase data upon changes, stored securely outside the server (e.g. S3 or remote FTP storage).
6. **Docker Containerization:** Dockerfile configurations and a `Docker Compose` package to run the Backend API, Database, Cache (Redis), and background workers.
7. **Cross-Platform Compatibility:** tested and run identically on both Windows Server 2025 (development) and Ubuntu 24.04 LTS (production target).
8. **Secrets Management:** zero hardcoded secrets in source code; configuration driven purely by environment variables.

### C. Web-Based Admin Panel
1. **Pluggable Architecture:** independent administrative views loaded as plugins (Users, Courses, Purchases, Reports, Notifications, Banners, Settings).
2. **User & Purchase Management Plugin:** manually edit user info, edit purchase records, and manually activate or deactivate purchased courses for specific users.
3. **Course Management Plugin:** upload course SQLite databases and media directories, edit metadata (title, category, difficulty, pricing), and toggle course visibility (publish/deactivate).
4. **Ad Banner & Announcement Plugin:** upload/edit promotional banners (up to 5) and schedule announcements.
5. **Flashcard Reports Review Plugin:** interface to filter, read, and manage submitted user reports.
6. **Detailed Audit Logging Plugin:** logs every admin action (who, what, when, before values, after values) to ensure accountability.

---

## 4. Excluded Features

The following features are explicitly **excluded** from the current project scope and will not be implemented:

*   **Web Application Client:** No web client interface for studying flashcards (only the mobile apps for Android & iOS and the React-based Web Admin Panel are included).
*   **Multi-language / Localization Support:** The application and content default to Persian/English as specified; full multi-language localization systems are excluded.
*   **AI-Generated Flashcards:** Auto-generation of flashcards using LLMs or third-party AI services is not supported (content must be authored manually or imported via the Course Authoring Kit).
*   **Social Networking Features:** User profiles are private; friends lists, community forums, or public leaderboard systems are excluded.
*   **Live Chat Support:** In-app real-time messaging with support personnel is excluded (traditional contact links and support emails are included).

---

## 5. Support & Revision Policy

### A. Bug Warranty Period
*   **1-Month Bug-Fix Warranty:** Starts immediately upon final handover and publication. Includes free resolution of any bugs, runtime errors, or deviations from the specifications.
*   **Lifetime Support:** Investigation, consultation, and troubleshooting guidance for technical issues. Any actual implementation work or code modifications required after the warranty period will be billed separately.

### B. Revisions
*   **1 Free Revision Cycle:** The client is entitled to one round of minor adjustments.
    - *Scope:* Limited to UI layout refinements, text/copy updates, configuration tweaks, and minor logic updates that do not impact database schemas or architectural boundaries.
    - *Limits:* Limited to a maximum of **15 developer hours**, and must be requested within **14 calendar days** of the delivery of the Phase 18 release candidate. Any additional revisions will be billed as new features.

---

## 6. Publishing Responsibilities

*   **Developer Responsibility:** The developer is responsible for compiling, submitting, and securing approval for both the Store and Premium editions of the mobile application on:
    - **Google Play**
    - **Cafe Bazaar**
    - **Myket**
*   **Two Build Configurations:**
    - *Build A (Premium):* Includes in-app purchases (IAP) for course unlocks, distributed via direct download/website/Telegram.
    - *Build B (Store):* Excludes in-app purchase links to comply with store policies, distributed via official app stores.
*   **Client Responsibility:** The client is responsible for providing active developer console accounts, payment gateway credentials, and merchant agreements.

---

## 7. Source Code Ownership & Relocation

*   **Full Ownership Transfer:** Upon final project payment, complete ownership of all custom source code, databases, design assets, and documentation is transferred to the client.
*   **Non-Reuse Clause:** The development team is strictly prohibited from reusing the custom code, branding, or project assets for competitors or other commercial platforms.
*   **Training Handover:** Includes a server deployment guide, course authoring guide, and updated architectural diagrams, accompanied by training walkthroughs for server management, backups, and migrations.

---

## 8. Project Timeline & Delay Penalties

*   **Total Duration:** 60 Calendar Days.
*   **Delay Penalty:** If project delivery is delayed due to developer-side errors or delays (excluding client feedback delays or scope modifications), a penalty of **1% of the total project value** will be deducted for each day of delay.

---

## 9. Acceptance Criteria (Contract Lock)

This document is finalized and locked. By approving this document, the client agrees that all requirements are fully documented.

### Client Review Status:
- [x] **Phase 0 Deliverable Met**
- [ ] **Client Approved (Sign-off Required to initiate Phase 1)**
