# Agent Instructions

## Git Remote

Changes must be pushed to: **[https://github.com/alirezakavianifar/leitner-learning-platform.git](https://github.com/alirezakavianifar/freelancing_automation.git)**

Ensure the remote `origin` points to this URL. If not configured, use: `git remote add origin https://github.com/alirezakavianifar/leitner-learning-platform.git` or `git remote set-url origin <url>` to update).

## .gitignore

If `.gitignore` does not exist, create one based on the codebase structure and language. Adapt entries to match the project's technologies and build output locations.

## Git Push Workflow

When the user uses the keyword "push" in a request (e.g., "please push these changes", "push", or similar), you MUST follow this specific workflow:

1. **Stage all changes**: standard `git add .`
2. **Infer Commit Message**: Generate a concise, descriptive, and professional commit message based on the recent file changes and conversation context. Do not ask the user for a commit message unless they explicitly provide one.
3. **Commit**: `git commit -m "<inferred_message>"`
4. **Push**: `git push` (or `git push -u origin <branch>` if the upstream is not set).
5. **Post-Push Execution**:
   - Post-push deployment and build scripts MUST be launched in a visible interactive PowerShell terminal window on the user's desktop using `Start-Process powershell.exe` so the user can visually monitor full live output scrolling in real-time:
     - If changes correspond to backend: `Start-Process powershell.exe -ArgumentList "-NoExit -ExecutionPolicy Bypass -File E:\projects\leitner-learning-platform\scripts\deploy-to-server.ps1"`
     - If changes correspond to frontend: `Start-Process powershell.exe -ArgumentList "-NoExit -ExecutionPolicy Bypass -File E:\projects\leitner-learning-platform\scripts\build-apk.ps1"`
     - If changes correspond to both, execute both `Start-Process powershell.exe` commands.
   - After running `scripts/build-apk.ps1`, override `app-premium-release.rar` with the new `app-premium-release.apk`.

**Note:** You should proactively execute these commands without asking for extra confirmation if the user explicitly said "push".

## Language Rule

- Always respond and answer in English. Even if the user asks questions or provides input in another language (such as Persian), the agent must write all explanations, responses, and comments in English.

## README Requirement

- Always ensure the remote repository has an up-to-date `README.md` file that explains everything about the project, from how it is set up to how it is run. Include every single detail necessary so that if we were to run the project in the future, we can easily follow the steps in the README file and do exactly that.
