# iOS Build & Distribution Guide

This document explains how to build, package, and distribute the **iOS version** of the Leitner Learning Platform after modifying the source code.

---

## ⭐️ Preferred & Default Method: Automated GitHub Actions Cloud Pipeline

The primary and default way to build and distribute the iOS version is through **GitHub Actions** on Apple Silicon **`macos-14`** cloud runners. This guarantees clean, reproducible builds without requiring a local Mac machine.

### Step-by-Step Workflow:

#### 1. Push Your Code Changes
Stage, commit, and push your latest code to `origin/master`:
```powershell
git add .
git commit -m "feat(mobile): your update description"
git push origin master
```
*(Or simply ask the AI agent: `"push"`).*

#### 2. Trigger the GitHub Actions iOS Builder
*   **Direct Link (Recommended):**
    Open 👉 **[GitHub Actions iOS Pipeline](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-ios.yml)**
    1. Click the **"Run workflow"** button on the right side.
    2. Keep default options:
       * **App Flavor**: `premium` (or `store`)
       * **Backend Target API URL**: `https://api.rightlearn.ir`
       * **Build Target**: `both` (creates both Physical IPA and Simulator bundle)
       * **Send to Rubika Bot**: Checked (`true`)
    3. Click **"Run workflow"**.

*   **Via Terminal Helper Script:**
    Alternatively, run the interactive helper on Windows to automatically launch the workflow page:
    ```powershell
    powershell -ExecutionPolicy Bypass -File .\scripts\build-ios.ps1
    ```

---

## Secondary / Alternative Method: Local macOS Workstation

If you are developing directly on a physical Mac workstation:
```bash
./scripts/build-ios.sh --flavor premium --target-url "https://api.rightlearn.ir" --build-type both
```
*(Or using PowerShell Core on Mac: `pwsh ./scripts/build-ios.ps1 -Flavor premium`)*

---

## Build Artifacts & Distribution

Every GitHub Actions execution automatically builds and exports:

| File Name | Target Platform | Description |
| :--- | :--- | :--- |
| **`app-premium-release.ipa`** | Physical iOS Devices | Sideloadable iOS Application Archive |
| **`app-premium-ios-release.zip`** | Universal Archive | Zipped `.ipa` package for messaging platforms |
| **`app-premium-ios-simulator.zip`** | iOS Simulator / Appetize | Zipped `Runner.app` for in-browser interactive streaming |

### Build Artifact Download
As soon as the macOS runner finishes compiling, all packages (`.ipa`, `.zip`, simulator `.zip`) are securely archived as GitHub Actions workflow artifacts and available directly for download from the workflow run summary.

---

## How to Install and Test the iOS Build

### 1. Physical iPhone / iPad (Sideloading via Sideloadly)
1. Download **[Sideloadly](https://sideloadly.io)** (Windows / macOS).
2. Connect your iPhone to your PC/Mac via USB (or same Wi-Fi network).
3. Drag `app-premium-release.ipa` into Sideloadly.
4. Enter your free Apple ID and click **Start**.
5. On your iPhone, go to **Settings &rarr; General &rarr; VPN & Device Management** and tap **Trust [Your Apple ID]**.
6. Open the **Leitner Box** app!

### 2. Sideloading via AltStore / Scarlet / TrollStore
*   Import `app-premium-release.ipa` directly into AltStore or Scarlet on your device.

### 3. In-Browser Live Interactive Streaming (No Mac or iPhone needed)
1. Go to **[Appetize.io Upload](https://appetize.io/upload)**.
2. Drag and drop **`app-premium-ios-simulator.zip`**.
3. Appetize generates an interactive web link to stream the iOS application directly in Google Chrome / Edge / Safari.
