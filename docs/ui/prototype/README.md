# Leitner Learning Platform - Interactive UI/UX Prototype

This directory contains the clickable, interactive, responsive web-based prototype designed for Phase 4 of the Leitner Learning Platform development.

---

## 1. Quick Start

To view the prototype:
1. Navigate to `docs/ui/prototype/` in your local filesystem.
2. Double-click [index.html](file:///e:/projects/leitner-learning-platform/docs/ui/prototype/index.html) or open it using any modern web browser (Chrome, Firefox, Safari, Edge).
3. The layout displays a simulated mobile viewport on the right, and a **Simulation Control Panel** on the left.

---

## 2. Interactive Features to Test

### 2.1 Mode Toggling
*   **High-Fidelity UI:** Features premium Outfit/Inter typography, linear gradient action components, glassmorphism backdrops, card shadows, and animated transitions.
*   **Wireframe Mode:** Switches instantly to structural layout wireframes with flat gray layouts, monospaced placeholder fonts, and standard layout borders.

### 2.2 End-to-End User Flow Simulation
*   **OTP Authentication:** Login using the pre-filled mock code `12345` (simulates SMS dispatch wait).
*   **Terms & Rules acceptance:** Mandatory check-box validation enforcing spaced-repetition reset policies.
*   **Profile Setup:** Enter profile options (mobile number is locked to read-only).
*   **Guided Onboarding:** A step-by-step interactive pointer highlighting all critical application areas:
    `Courses -> Search -> Flashcard -> Know -> Don't Know -> Create Card -> Finished Cards -> Favorites -> My Courses -> Reports -> Today's Cards -> Statistics`.
*   **Auto-Rotating Banners:** View 5 dynamically looping banners on the home dashboard (rotating every 4 seconds).
*   **Downloaded vs. Not Downloaded Courses:** Downloaded items appear at the top outlined in a **green border**; others are shown below outlined in **yellow**.
*   **Offline Mode:** Toggle "Offline Mode" in the control panel to see immediate warning banners, disable search indexes, and filter courses dynamically to local offline storage cache.
*   **Leitner Spaced Repetition Study Engine:**
    - Click any card to perform a 3D Y-axis flip animation, revealing the answer and optional audio/image resources.
    - Click "Know" or "Don't Know" to progress cards forward or reset them instantly to Box 1.
    - Click "Card Index" (e.g. Card 3/12) to open the Jump-To-Card Dialog. Enter a card number; jumping to active boxes (2-5) triggers a reset warning prompt.
    - Click "Bookmark" to toggle Favorites. Inspecting cards from the favorites list triggers Box 1 warning resets.
*   **Statistics Charting:** View color-coded distribution bars matching exact client parameters (Orange = Box 1, Yellow = Box 2, Green = Box 3, Blue = Box 4, Purple = Box 5, Gold = Finished).
*   **Safety Logout Confirmations:** Test logging out under Settings to verify the confirmation warning modal.
