
# Agent Instructions

## Git Remote

Changes must be pushed to: **[https://github.com/alirezakavianifar/leitner-learning-platform.git](https://github.com/alirezakavianifar/freelancing_automation.git)**

Ensure the remote `origin` points to this URL. If not configured, use: `git remote add origin https://github.com/alirezakavianifar/leitner-learning-platform.git` or `git remote set-url origin <url>` to update).

## .gitignore

If `.gitignore` does not exist, create one based on the codebase structure and language. Adapt entries to match the project's technologies and build output locations.

## Git Push & Deploy Workflow

When performing git operations, follow these specific guidelines based on the user's prompt:

1. **Stage all changes**: standard `git add .`
2. **Infer Commit Message**: Generate a concise, descriptive, and professional commit message based on the recent file changes and conversation context. Do not ask the user for a commit message unless they explicitly provide one.
3. **Commit**: `git commit -m "<inferred_message>"`
4. **Push**: `git push` (or `git push -u origin <branch>` if the upstream is not set).

### Execution Rules by Keyword:

- **If the keyword `push` is used alone** (e.g., "push", "please push these changes"):

  - ONLY execute steps 1-4 to stage, commit, and push to GitHub.
  - DO NOT execute any post-push build or deployment scripts.
- **If the keyword `push&deploy` (or `push & deploy` / `push and deploy`) is used**:

  - Execute steps 1-4 to push changes to GitHub.
  - AND launch post-push deployment/build scripts in visible interactive PowerShell terminal windows on the user's desktop using `Start-Process powershell.exe` as necessary based on modified files:
    - If changes correspond to backend: `Start-Process powershell.exe -ArgumentList "-NoExit -ExecutionPolicy Bypass -File E:\projects\leitner-learning-platform\scripts\deploy-to-server.ps1"`
    - If changes correspond to frontend: `Start-Process powershell.exe -ArgumentList "-NoExit -ExecutionPolicy Bypass -File E:\projects\leitner-learning-platform\scripts\build-apk.ps1"`
    - If changes correspond to both, execute both `Start-Process powershell.exe` commands.
  - After running `scripts/build-apk.ps1`, ensure `app-premium-release.zip` contains the new `app-premium-release.apk` and upload to the Rubika bot via `scripts/upload-to-rubika.py`.

### Mobile Build, Release & Server Deployment Workflows (GitHub Actions):

- **Unified Mobile Build & Release Pipeline (Android & iOS in Parallel)**: Triggers concurrent builds for both Android and iOS simultaneously on cloud runners via [build-mobile.yml](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-mobile.yml). Automatically creates and updates official **GitHub Releases** on the repository page with downloadable `.apk`, `.zip`, `.aab`, and `.ipa` artifacts, generates release changelogs, and dispatches packages to the Rubika Bot (`@AliDeveloperBot`) in a separate, isolated job so Rubika network status never impacts releases or builds.
- **Android APK Build & Release Pipeline**: Android APKs (`.apk`, `.zip`, and `.aab`) can be built locally via `scripts/build-apk.ps1` or automated via GitHub Actions (`.github/workflows/build-apk.yml`) on `ubuntu-latest` cloud runners with options to publish directly to GitHub Releases and dispatch to Rubika Bot via an independent decoupled job. The pipeline supports custom flavors (`premium`/`store`/`all`), ABI selection (`arm64-v8a`/`universal`/`all`), and ProGuard size optimizations.
- **iOS Build & Release Pipeline**: All iOS builds are built using GitHub Actions (`.github/workflows/build-ios.yml`) on `macos-14` cloud runners. The pipeline builds `app-premium-release.ipa` and packages it into `app-premium-ios-release.zip`, publishing release assets directly to GitHub Releases.
- **Server Deployment Pipeline**: Automated backend deployment to production server `45.94.215.188` via [deploy-server.yml](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/deploy-server.yml). Automatically triggers on push when backend, admin-panel, deployment, or .env files change, or can be triggered manually via `workflow_dispatch` with SMS (`ON`/`OFF`) control.
- When pushing changes, remind the user that they can trigger the [Unified Mobile Build Pipeline](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-mobile.yml), [Android APK Build Pipeline](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-apk.yml), [iOS Build Pipeline](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-ios.yml), or [Server Deployment Pipeline](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/deploy-server.yml) directly on GitHub Actions, or download published binaries from the [GitHub Releases](https://github.com/alirezakavianifar/leitner-learning-platform/releases) section.

**Note:** You should proactively execute these commands without asking for extra confirmation.

## Mobile App Versioning & Release Protocol

Whenever releasing or updating the mobile application (for Direct/Rubika, Myket, Cafe Bazaar, or Google Play), you MUST strictly follow this release checklist:

### 1. Mandatory Version Bumping (Preventing Store Upload Errors)
App stores (Myket, Cafe Bazaar, Google Play) strictly reject any APK where `versionCode <= previousVersionCode` with errors like:
*«نسخه‌ای با همین version code یا version code بالاتر قبلا ثبت شده است. لطفا version code را افزایش دهید و دوباره بارگذاری کنید.»*

Before compiling a new release:
1. **`mobile-app/pubspec.yaml`**:
   - Increment `version: <versionName>+<buildNumber>` (e.g., `version: 1.0.4+6` -> `version: 1.0.5+7`).
   - Note: Flutter `--split-per-abi` for `arm64-v8a` computes `versionCode = 2000 + buildNumber` (e.g. build 6 = 2006). If ever switching between universal and split APKs, ensure the new `versionCode` is strictly greater than all historical builds uploaded to that store.
2. **`mobile-app/lib/injection_container.dart`**:
   - Synchronize runtime default values:
     `this.appVersion = const String.fromEnvironment('APP_VERSION', defaultValue: '<versionName>')`
     `this.buildNumber = const int.fromEnvironment('BUILD_NUMBER', defaultValue: <buildNumber>)`
3. **`mobile-app/android/local.properties`**:
   - Update: `flutter.versionName=<versionName>` and `flutter.versionCode=<buildNumber>`.
4. Run `flutter pub get` inside `mobile-app/` to update metadata.

### 2. Keystore Signing & Security Standards
- **Keystore**: Release APKs MUST be signed with the production keystore:
  - File: `mobile-app/android/app/upload-keystore.jks`
  - Alias: `upload`
  - Certificate DN: `CN=RightLearn Developer, OU=Mobile Development, O=Leitner Learning Platform, L=Tehran, ST=Tehran, C=IR`
- **Never Fall Back to Debug Keys**: The Gradle build will intentionally throw an error if `upload-keystore.jks` or `key.properties` is missing. NEVER sign release builds with `CN=Android Debug`.
- **Signature Schemes**: APK Signature Scheme **v2 and v3** are mandatory.
- **Verification Command**:
  ```powershell
  E:\Android_sdk\build-tools\35.0.0\apksigner.bat verify --verbose --print-certs <path-to-apk>
  ```
  Ensure signer is `CN=RightLearn Developer` and `Verified using v2 scheme: true` / `v3 scheme: true`.

### 3. Google Play Protect & Sideloading Compliance
- **Restricted Permissions**: NEVER add `android.permission.USE_EXACT_ALARM` to `AndroidManifest.xml`. Use standard `SCHEDULE_EXACT_ALARM`.
- **Network Security**: Strict HTTPS is enforced via `res/xml/network_security_config.xml`. Do NOT use global `android:usesCleartextTraffic="true"`.
- **First-Time Install Scanning**: Google Play Protect shows "App scan recommended" on newly generated APK hashes downloaded outside stores. When deploying a new direct APK:
  - Install it once on a test device and click **"Scan app"** to catalog the hash with Google's cloud scanner.
  - Deliver the 2-step Persian reassurance guide in Rubika and website messages so users proceed without hesitation.
  - Whitelist portal: If needed, submit to Google's official [Play Protect Appeal Form](https://support.google.com/googleplay/android-developer/contact/protectappeals).

### 4. Flavor-Specific Targets
- **Direct / Premium**: `.\scripts\build-apk.ps1 -Flavor "premium"` -> generates `app-premium-release.apk` with direct web payment.
- **Myket**: `flutter build apk --release --flavor myket -t lib/main_myket.dart --split-per-abi --target-platform android-arm64` -> generates `app-arm64-v8a-myket-release.apk` (packaged to `app-myket-release.apk`) with `ir.mservices.market.BILLING`.
- **Cafe Bazaar**: `flutter build apk --release --flavor bazaar -t lib/main_bazaar.dart --split-per-abi --target-platform android-arm64` -> generates `app-arm64-v8a-bazaar-release.apk` with `com.farsitel.bazaar.permission.PAY_THROUGH_BAZAAR`.
- **Google Play**: `flutter build appbundle --release --flavor googleplay -t lib/main_googleplay.dart` -> generates `.aab`.

## Language Rule

- Always respond and answer in English. Even if the user asks questions or provides input in another language (such as Persian), the agent must write all explanations, responses, and comments in English.

## README Requirement

- Always ensure the remote repository has an up-to-date `README.md` file that explains everything about the project, from how it is set up to how it is run. Include every single detail necessary so that if we were to run the project in the future, we can easily follow the steps in the README file and do exactly that.
