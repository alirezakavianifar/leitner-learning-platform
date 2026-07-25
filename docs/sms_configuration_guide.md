# SMS & OTP Configuration Guide

This document provides a comprehensive guide to the SMS/OTP verification system, including code references, configuration settings, deployment options, and how the system behaves on the mobile and server sides.

---

## 1. Code Architecture

The SMS dispatch functionality is located in the C# backend projects:

* **Interface Contract**: 
  [ISmsService.cs](file:///e:/projects/leitner-learning-platform/backend/LeitnerPlatform.Core/Interfaces/ISmsService.cs)
  Declares the signature for sending One-Time Passwords (OTPs):
  ```csharp
  Task<bool> SendOtpAsync(string mobileNumber, string code);
  ```

* **Service Implementation**: 
  [SmsService.cs](file:///e:/projects/leitner-learning-platform/backend/LeitnerPlatform.Data/Services/SmsService.cs)
  Implements the integration adapters for domestic Iranian SMS gateways:
  * **Kavenegar** (Default fallback)
  * **Faraz SMS / IPPanel**
  * **IranPayamak**

* **API Endpoints**: 
  [AuthController.cs](file:///e:/projects/leitner-learning-platform/backend/LeitnerPlatform.API/Controllers/v1/AuthController.cs)
  Handles OTP registration requests at `POST /api/v1/auth/otp/request`. It generates a 5-digit code, caches it in Redis/Memory Cache (valid for 2 minutes), and triggers the SMS send via `_smsService.SendOtpAsync()`.

* **Dependency Injection**: 
  [Program.cs](file:///e:/projects/leitner-learning-platform/backend/LeitnerPlatform.API/Program.cs)
  Registers the HTTP Client and mapping:
  ```csharp
  builder.Services.AddHttpClient<ISmsService, SmsService>();
  ```

---

## 2. Configuration & Toggling SMS (ON / OFF)

The SMS service switches between live delivery and console log bypass depending on the environment variables defined on the server host:

* **To turn SMS OFF (Console Log Bypass / Local Dev)**:
  Remove, comment out, or clear the `SMS_GATEWAY_API_KEY` environment variable in your configuration (such as the [.env](file:///e:/projects/leitner-learning-platform/.env) file):
  ```env
  # SMS_GATEWAY_API_KEY=
  ```
  If `SMS_GATEWAY_API_KEY` is empty, the `SmsService` skips the HTTP request to the gateway, logs the code to the console/container log, and returns success:
  > `[SMS Bypass] SMS code for +989xxxxxxxxx is: 12345`

* **To turn SMS ON (Live Delivery)**:
  Define a non-empty, valid key for the SMS gateway in `.env`:
  ```env
  SMS_GATEWAY_API_KEY=your_actual_api_key_here
  SMS_PROVIDER=IranPayamak # or Kavenegar / FarazSms
  SMS_SENDER=your_sender_number
  SMS_PATTERN_CODE=your_pattern_code
  ```

---

## 3. Deployment-time Configuration

The automated server deployment script [deploy-to-server.ps1](file:///e:/projects/leitner-learning-platform/scripts/deploy-to-server.ps1) features an SMS toggle parameter that automatically edits the server's `.env` configuration file during staging.

### Script Usage:

```powershell
# 1. Deploy with SMS ON (Default)
powershell -ExecutionPolicy Bypass -File ./scripts/deploy-to-server.ps1

# 2. Deploy with SMS ON (Explicit)
powershell -ExecutionPolicy Bypass -File ./scripts/deploy-to-server.ps1 -Sms ON

# 3. Deploy with SMS OFF (Strips/Comments out the API key in the deployed .env)
powershell -ExecutionPolicy Bypass -File ./scripts/deploy-to-server.ps1 -Sms OFF
```

### Behind the Scenes:
When deploying with `-Sms OFF`, the script parses the staged `.env` file right before compression and comments out the `SMS_GATEWAY_API_KEY` line. When deploying with `-Sms ON`, the script uncomment any existing commented-out instance.

---

## 4. Mobile Client APK Considerations

When you deploy changes or toggle the SMS state, **you do not need to rebuild the mobile APK** using [build-apk.ps1](file:///e:/projects/leitner-learning-platform/scripts/build-apk.ps1).

* **Backend Encapsulation**: The mobile app interacts with the backend HTTP endpoint (`/api/v1/auth/otp/request`). The backend is solely responsible for determining whether to send a physical SMS or output the OTP to the logs.
* **When you actually need a new build**: You only need to rebuild the APK if you change client-side Dart files (UI, offline databases) or need the app binary to point to a new target host (using the `-TargetUrl` option).
