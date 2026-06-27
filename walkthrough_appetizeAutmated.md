# Walkthrough - Appetize.io Deployment and Automation

This walkthrough summarizes the changes made to introduce the automated deployment script and step-by-step documentation for testing the Leitner Learning Platform mobile application in the Appetize.io emulator.

---

## 🛠️ Changes Implemented

### 1. Root Configurations & Environment Variables
* **Created [`.env`](file:///e:/projects/leitner-learning-platform/.env)**: Set up with your credentials:
  - `APPETIZE_API_TOKEN` set to your provided token (`tok_qhft...`).
  - `APPETIZE_PUBLIC_KEY` set to the discovered public key (`b_q3mc3mwdwkrjoexfpyz7tzz7e`), mapping to `com.leitnerplatform.mobile_app.premium`.

### 2. Automation Script
* **Created [`scripts/deploy_to_appetize.ps1`](file:///e:/projects/leitner-learning-platform/scripts/deploy_to_appetize.ps1)**:
  - **Port Detection**: Queries `localhost:5217` to check if the .NET backend API is already running. If offline, it boots it via `dotnet run` in a separate process.
  - **Tunneling**: Checks if Ngrok is running. If not, it spins up an Ngrok HTTP tunnel forwarding port `5217`.
  - **Dynamic URL Extraction**: Interrogates Ngrok's local management API at `http://127.0.0.1:4040/api/tunnels` to fetch the public domain and appends `/api/v1` to form the API base URL.
  - **Compilation**: Clean-syncs dependencies (`flutter pub get`) and compiles the Flutter APK targeting the emulator architecture (`android-x64`) with the injected base URL variable: `--dart-define=API_BASE_URL=$apiUrl`.
  - **Appetize Upload & Update**: Discovers or updates your existing Appetize app using the REST API. If the credentials are not set, it falls back gracefully to print manual upload instructions and the local APK output path.

### 3. Comprehensive Documentation
* **Created [`docs/appetize_testing_guide.md`](file:///e:/projects/leitner-learning-platform/docs/appetize_testing_guide.md)**:
  - Detailed list of prerequisites.
  - Step-by-step manual setup instructions.
  - Automated one-click execution details.
  - Advanced troubleshooting tips for common network, platform compilation, or Ngrok session issues.

### 4. Project README Update
* **Modified [`README.md`](file:///e:/projects/leitner-learning-platform/README.md)**:
  - Appended references under the `Flutter Mobile Client` setup sections directing developers to the new Appetize Guide and script.

---

## 🧪 Verification & Testing Results

1. **Appetize.io API Verification**:
   - Sent a web request to `https://api.appetize.io/v1/apps` with your token.
   - Discovered the existing app `com.leitnerplatform.mobile_app.premium` and its active public key: `b_q3mc3mwdwkrjoexfpyz7tzz7e`.
2. **Script Parse Test**:
   - Ran a syntax compilation validation on the PowerShell script. The engine registered the command and parsed parameter validation lists without warnings or syntax errors.
