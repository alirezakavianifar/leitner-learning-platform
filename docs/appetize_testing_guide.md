# Leitner Learning Platform - Appetize.io & Ngrok Testing Guide

This guide describes how to run and test the Flutter mobile application in a web-based Android emulator using **Appetize.io**, connected to a local backend API through **Ngrok**. 

It contains both the **manual step-by-step instructions** and the **automated script workflow**.

---

## 🛠️ Prerequisites

To build and test the app, ensure you have the following installed on your developer machine:

1. **Flutter SDK** (v3.22.x or later) added to your system's `PATH`.
2. **.NET Core SDK** (v8.0 or later) to build and run the backend.
3. **Ngrok CLI** installed and authenticated:
   - Sign up at [ngrok.com](https://ngrok.com)
   - Authenticate the CLI on your machine: `ngrok config add-authtoken <your_token>`
4. **Appetize.io Account** (Optional for manual testing, but required for automated updates):
   - Obtain your **API Token** from the Appetize Dashboard -> **Organization Settings -> API Tokens**.

---

## ⚡ Option A: Automated Deployment (Recommended)

An automated PowerShell script is available at the root under `scripts/deploy_to_appetize.ps1`. This script handles starting the backend, starting ngrok, extracting the tunnel URL, compiling the Flutter app with the injected API endpoint, and uploading the binary directly to Appetize.io.

### 1. Configure Credentials
Add your Appetize credentials to the `.env` file at the root of the project:
```env
APPETIZE_API_TOKEN=tok_qhftwn6tnukiws2egyyulpmeuy
APPETIZE_PUBLIC_KEY=b_q3mc3mwdwkrjoexfpyz7tzz7e
```
*Note: The script automatically performs auto-discovery to find your matching app's public key if you only supply the `APPETIZE_API_TOKEN`.*

### 2. Run the Script
Open **PowerShell** and execute the script:
```powershell
.\scripts\deploy_to_appetize.ps1
```

### 3. Customize Options
You can configure the target build flavor or architecture:
```powershell
# Compiles the "premium" flavor targeting x86_64 emulators (Fastest build, default)
.\scripts\deploy_to_appetize.ps1 -Flavor premium -TargetPlatform android-x64

# Compiles a universal APK that works on physical ARM devices + emulators
.\scripts\deploy_to_appetize.ps1 -Flavor premium -TargetPlatform universal

# Compiles the store-release flavor
.\scripts\deploy_to_appetize.ps1 -Flavor store
```

---

## 📖 Option B: Manual Step-by-Step Instructions

If you prefer to perform each step manually or want to understand what the automation script is doing under the hood, follow these instructions:

### Step 1: Start the Backend API
The backend must be running locally to receive API requests. Run the .NET project:
```bash
dotnet run --project backend/LeitnerPlatform.API/LeitnerPlatform.API.csproj --launch-profile http
```
The API is configured to listen on `http://localhost:5217`. Verify it is active by visiting `http://localhost:5217/swagger` in your browser.

### Step 2: Establish the Ngrok Tunnel
Because Appetize.io runs emulators in the cloud, it cannot connect directly to `localhost`. You must expose your local backend port `5217` to the public internet using Ngrok:
```bash
ngrok http 5217
```
Ngrok will start and display a forwarding URL, for example:
`Forwarding  https://a1b2-34-56-78-90.ngrok-free.app -> http://localhost:5217`

### Step 3: Format the API Base URL
In the mobile app, backend endpoints are prefixed with `/api/v1`. 
Take your Ngrok forwarding address and append `/api/v1` to the end. This is your compile-time API base URL:
`https://a1b2-34-56-78-90.ngrok-free.app/api/v1`

### Step 4: Compile the Flutter Application
Navigate to the `mobile-app` directory and compile the release binary. Make sure to inject the API URL using `--dart-define`:

```bash
cd mobile-app

# Resolve packages
flutter pub get

# Build APK targeting x86_64 Emulators (such as Appetize)
flutter build apk --flavor premium -t lib/main_premium.dart --release --target-platform android-x64 --dart-define=API_BASE_URL=https://a1b2-34-56-78-90.ngrok-free.app/api/v1
```

Once the compilation finishes, the generated APK file will be located at:
`mobile-app/build/app/outputs/flutter-apk/app-premium-release.apk`

### Step 5: Upload the APK to Appetize.io

#### Method 1: Web Interface (Manual)
1. Navigate to the Appetize.io upload dashboard: [appetize.io/upload](https://appetize.io/upload)
2. Drag and drop the `app-premium-release.apk` compiled in Step 4.
3. Once processed, click **Start Session** to play/test your app!

#### Method 2: HTTP Update API (Command Line)
If you already have an existing app and want to update its binary using the API:
```bash
curl -X POST https://api.appetize.io/v1/apps/b_q3mc3mwdwkrjoexfpyz7tzz7e \
  -H "X-API-KEY: tok_qhftwn6tnukiws2egyyulpmeuy" \
  -F "file=@mobile-app/build/app/outputs/flutter-apk/app-premium-release.apk" \
  -F "platform=android"
```

---

## 🔍 Troubleshooting & Key Learnings

### 1. Emulator Lag / "App Crashing" on Launch
* **Cause**: Emulators in Appetize.io run on `x86_64` (Intel/AMD) virtualized architecture. If your APK is compiled only for ARM (`arm64-v8a` / `armeabi-v7a`), Appetize must translate those instructions, causing a significant performance drop or launch failures.
* **Solution**: Ensure you build with the parameter `--target-platform android-x64` to compile native x86_64 binaries.

### 2. Network / Connection Errors inside the App
* **Cause**: Your Ngrok tunnel URL changes every time you restart Ngrok unless you use a reserved domain. If you restart Ngrok, you **must rebuild** the Flutter app with the new Ngrok URL injected.
* **Verification**:
  - Run `curl -I https://<your-ngrok-subdomain>.ngrok-free.app/api/v1/config` to check if your backend replies to the tunnel.
  - If you see a **404** or **502 Bad Gateway** error, Ngrok is running but your .NET backend is either offline or listening on a different port.

### 3. Ngrok Session Limit Reached
* **Cause**: The free tier of Ngrok allows only a single active tunnel session.
* **Solution**: Check if another instance of Ngrok is running in the background. You can stop all ngrok processes by running:
  - Windows: `Stop-Process -Name "ngrok" -Force`
  - Linux/macOS: `killall ngrok`

### 4. Updating API Base URL without Recompiling
* **Explanation**: Because the Flutter app uses `String.fromEnvironment('API_BASE_URL')` (loaded during build time), you **cannot** update the API URL dynamically inside an already-compiled APK. Any change to the backend URL requires a fresh compile (`flutter build apk`).
