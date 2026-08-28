# iOS Build & Distribution Guide

This document explains how to build, package, and distribute the **iOS version** of the Leitner Learning Platform after modifying the source code.

---

## Overview

Because Apple requires **macOS + Xcode + CocoaPods** to compile native iOS binaries (`.ipa`), this repository provides a **hybrid workflow**:
1. **Windows Developers**: Use GitHub Actions (Apple Silicon `macos-14` cloud runners) to build and deliver the `.ipa` and simulator `.zip` to Rubika with 1 click without needing a physical Mac.
2. **Mac Developers**: Run the local build script (`./scripts/build-ios.sh` or `pwsh ./scripts/build-ios.ps1`) directly on macOS.

---

## How to Build iOS After Modifying Source Code

### Workflow 1: From Windows (Automated Cloud Pipeline)

Whenever you edit files in `mobile-app/` or backend configuration:

#### Step 1: Push Your Changes to GitHub
Push your commits to `origin/master`:
```powershell
git add .
git commit -m "feat(mobile): describe your updates"
git push origin master
```
*(Or simply ask the AI agent to `"push"`).*

#### Step 2: Trigger the Build
You have two quick options:

*   **Option A — Via Helper Script (Terminal):**
    Run the PowerShell helper:
    ```powershell
    powershell -ExecutionPolicy Bypass -File .\scripts\build-ios.ps1
    ```
    The script validates parameters and offers a 1-click prompt to launch the cloud builder in your browser.

*   **Option B — Directly via GitHub Actions:**
    1. Open the [iOS Build & Distribution Pipeline on GitHub](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-ios.yml).
    2. Click **Run workflow** on the right side:
       * **App Flavor**: `premium` (or `store`)
       * **Backend Target API URL**: `https://api.rightlearn.ir`
       * **Build Target**: `both` (or `ipa` / `simulator`)
       * **Send to Rubika Bot**: Checked (true)
    3. Click **Run workflow**.

---

### Workflow 2: On a Mac (Workstation / Local CI)

If you are working on a macOS machine with Flutter and Xcode installed:

```bash
# Compile both Physical IPA and Simulator package:
./scripts/build-ios.sh --flavor premium --target-url "https://api.rightlearn.ir" --build-type both
```

Or using PowerShell Core on Mac:
```powershell
pwsh ./scripts/build-ios.ps1 -Flavor premium -TargetUrl "https://api.rightlearn.ir"
```

---

## Build Artifacts & Distribution

Every build automatically generates:

| File Name | Target Platform | Description |
| :--- | :--- | :--- |
| **`app-premium-release.ipa`** | Physical iOS Devices | Sideloadable iOS Application Archive |
| **`app-premium-ios-release.zip`** | Universal Archive | Zipped `.ipa` package for messaging platforms |
| **`app-premium-ios-simulator.zip`** | iOS Simulator / Appetize | Zipped `Runner.app` for in-browser interactive streaming |

### Automated Delivery to Rubika
Once the GitHub Actions macOS runner compiles the binaries, it immediately runs `scripts/upload-to-rubika.py` and transfers the packaged `.zip` directly to the Rubika Bot (`@AliDeveloperBot`).

---

## How to Install and Test the iOS Build

### Option 1: Physical iPhone / iPad (Sideloading via Sideloadly)
1. Download **[Sideloadly](https://sideloadly.io)** (Windows / macOS).
2. Connect your iPhone to your PC/Mac via USB (or same Wi-Fi network).
3. Drag `app-premium-release.ipa` into Sideloadly.
4. Enter your free Apple ID and click **Start**.
5. On your iPhone, go to **Settings &rarr; General &rarr; VPN & Device Management** and tap **Trust [Your Apple ID]**.
6. Open the **Leitner Box** app!

### Option 2: Sideloading via AltStore / Scarlet / TrollStore
*   Import `app-premium-release.ipa` directly into AltStore or Scarlet on your device.

### Option 3: In-Browser Live Interactive Streaming (No Mac or iPhone needed)
1. Go to **[Appetize.io Upload](https://appetize.io/upload)**.
2. Drag and drop **`app-premium-ios-simulator.zip`**.
3. Appetize will generate an interactive web link to test and stream the iOS application directly in Google Chrome / Edge / Safari.
