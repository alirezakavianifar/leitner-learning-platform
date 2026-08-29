
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

### Mobile Build & Server Deployment Workflows (GitHub Actions):

- **Unified Mobile Build Pipeline (Android & iOS in Parallel)**: Triggers concurrent builds for both Android and iOS simultaneously on cloud runners via [build-mobile.yml](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-mobile.yml).
- **Android APK Build Pipeline**: Android APKs (`.apk` and `.zip`) can be built locally via `scripts/build-apk.ps1` or automated via GitHub Actions (`.github/workflows/build-apk.yml`) on `ubuntu-latest` cloud runners. The pipeline supports custom flavors (`premium`/`store`), ABI selection (`arm64-v8a`/`universal`/`all`), ProGuard size optimizations, and automatically uploads the package to the Rubika Bot (`@AliDeveloperBot`).
- **iOS Build Pipeline**: All iOS builds (`.ipa` and simulator `.zip`) are built using GitHub Actions (`.github/workflows/build-ios.yml`) on `macos-14` cloud runners. The pipeline builds `app-premium-release.ipa` and `app-premium-ios-simulator.zip`, and automatically uploads the package to the Rubika Bot (`@AliDeveloperBot`).
- **Server Deployment Pipeline**: Automated backend deployment to production server `45.94.215.188` via [deploy-server.yml](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/deploy-server.yml). Automatically triggers on push when backend, admin-panel, deployment, or .env files change, or can be triggered manually via `workflow_dispatch` with SMS (`ON`/`OFF`) control.
- When pushing changes, remind the user that they can trigger the [Unified Mobile Build Pipeline](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-mobile.yml), [Android APK Build Pipeline](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-apk.yml), [iOS Build Pipeline](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-ios.yml), or [Server Deployment Pipeline](https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/deploy-server.yml) directly on GitHub Actions.

**Note:** You should proactively execute these commands without asking for extra confirmation.

## Language Rule

- Always respond and answer in English. Even if the user asks questions or provides input in another language (such as Persian), the agent must write all explanations, responses, and comments in English.

## README Requirement

- Always ensure the remote repository has an up-to-date `README.md` file that explains everything about the project, from how it is set up to how it is run. Include every single detail necessary so that if we were to run the project in the future, we can easily follow the steps in the README file and do exactly that.
