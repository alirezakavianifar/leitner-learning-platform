# Implementation Plan - Diagnostics & Centralized Logging

This phase establishes a robust, structured, and correlated diagnostics logging mechanism across the Leitner Learning Platform (Backend API, Mobile Client, and Web Admin Panel) to facilitate rapid troubleshooting and monitoring of production issues.

---

## User Review Required

> [!IMPORTANT]
> **Correlation and Traceability:** 
> Every network call initiated by the Flutter Mobile App or React Admin Panel will carry a unique `X-Correlation-ID` header. 
> - If an API request fails, the server responds with a standardized JSON error format containing this Correlation ID.
> - The client will display this Correlation ID to the user in the error modal/prompt (e.g., *"Something went wrong. Reference: a5f8-b3d2-432a"*), enabling support agents to locate the exact backend stack trace instantly.
>
> **Log Retention and Privacy:**
> Logs generated on the backend and mobile devices will be structured (JSON) and rotated daily to prevent disk exhaustion. We must ensure that sensitive information (like user passwords or raw OTP codes) is automatically masked or excluded from the logged attributes.

---

## Open Questions

- *Should we integrate a cloud-based log aggregation provider in this phase (e.g., Seq, Sentry, or Application Insights), or do you prefer to output to daily rolling JSON files on-disk first?* (We propose configuring Serilog with both a Console sink and a daily rolling File sink, which can easily be routed toSeq or Elasticsearch later via configuration).
- *Do you want to enable the "Export Diagnostics Logs" feature in the production Flutter mobile app settings, or restrict it to beta/staging builds only?* (We propose enabling it for all builds but restricting the log level to `Warning` and `Error` in production to optimize performance).

---

## Proposed Changes

### Component 1: Backend Diagnostics System (.NET Web API)

We will integrate Serilog for structured logging, add middlewares for Correlation ID propagation, and write unhandled exceptions to structured rolling logs.

#### [MODIFY] [LeitnerPlatform.API.csproj](file:///e:/projects/leitner-learning-platform/backend/LeitnerPlatform.API/LeitnerPlatform.API.csproj)
- Add package reference: `Serilog.AspNetCore` (Version `8.*` to match .NET 8.0).
- Add package reference: `Serilog.Sinks.File` (Version `6.*`).

#### [NEW] [CorrelationIdMiddleware.cs](file:///e:/projects/leitner-learning-platform/backend/LeitnerPlatform.API/Services/CorrelationIdMiddleware.cs)
A middleware running early in the request pipeline:
- Checks if the request contains an `X-Correlation-ID` header.
- If not present, generates a new GUID and appends it to the request headers.
- Adds the Correlation ID to the `HttpContext.Items` and appends it as a response header (`X-Correlation-ID`).
- Pushes the Correlation ID property into Serilog's `LogContext` using `LogContext.PushProperty("CorrelationId", correlationId)`.

#### [NEW] [ExceptionHandlingMiddleware.cs](file:///e:/projects/leitner-learning-platform/backend/LeitnerPlatform.API/Services/ExceptionHandlingMiddleware.cs)
A global middleware to capture unhandled exceptions:
- Catches all exceptions bubbled up from controllers or services.
- Logs the exception with details and stack traces at the `Error` level.
- Returns a standardized JSON response:
  ```json
  {
    "error": "An unexpected error occurred. Please contact support.",
    "correlation_id": "a5f8-b3d2-432a-..."
  }
  ```
- Sets the HTTP response status code to `500 Internal Server Error`.

#### [MODIFY] [Program.cs](file:///e:/projects/leitner-learning-platform/backend/LeitnerPlatform.API/Program.cs)
- Bootstrap Serilog configuration inside the host builder:
  ```csharp
  builder.Host.UseSerilog((context, services, configuration) => configuration
      .ReadFrom.Configuration(context.Configuration)
      .ReadFrom.Services(services)
      .Enrich.FromLogContext());
  ```
- Insert `CorrelationIdMiddleware` and `ExceptionHandlingMiddleware` into the request pipeline (placed before authentication/authorization so rate-limiting and authorization failures are also correlated).
- Replace all raw `Console.WriteLine` statements (such as DB migration logs and event subscription handlers) with structured `_logger` calls.

#### [MODIFY] [appsettings.json](file:///e:/projects/leitner-learning-platform/backend/LeitnerPlatform.API/appsettings.json)
Configure Serilog sinks and levels:
- Add a `"Serilog"` section configuring `Console` and `File` sinks.
- Target rolling logs path: `Logs/api-.log` with daily rolling and format set to JSON or formatted text.

---

### Component 2: Mobile App Diagnostics System (Flutter Client)

We will introduce a logging utility in the mobile app, implement an interceptor to append the Correlation ID to Dio requests, and capture errors globally.

#### [MODIFY] [pubspec.yaml](file:///e:/projects/leitner-learning-platform/mobile-app/pubspec.yaml)
- Add dependency: `logger: ^2.4.0` (for console styling and structured layout).
- Add dependency: `uuid: ^4.3.3` (to generate Correlation IDs).

#### [NEW] [app_logger.dart](file:///e:/projects/leitner-learning-platform/mobile-app/lib/core/diagnostics/app_logger.dart)
A central logging helper class:
- Configures the `Logger` package for formatting (emojis, stack trace lines, error levels).
- Writes logs of level `Warning` and `Error` into a local rotating file using `path_provider` (e.g. `AppSupportLogs.txt`).
- Exposes a method `exportLogs()` which reads this local log file to be shared or emailed.

#### [NEW] [correlation_interceptor.dart](file:///e:/projects/leitner-learning-platform/mobile-app/lib/core/network/correlation_interceptor.dart)
A custom interceptor for the `Dio` HTTP client:
- For every request, generates a unique UUID if one is not present.
- Appends `X-Correlation-ID` header to request parameters.
- Inspects response headers. If an error is returned, extracts the Correlation ID and logs/re-throws the exception with the reference ID included.

#### [MODIFY] [dio_client.dart](file:///e:/projects/leitner-learning-platform/mobile-app/lib/core/network/dio_client.dart)
- Register `CorrelationInterceptor` in the `Dio` instance initialization.

#### [MODIFY] [main.dart](file:///e:/projects/leitner-learning-platform/mobile-app/lib/main.dart)
- Run the Flutter app within a `runZonedGuarded` block or register a `PlatformDispatcher.instance.onError` handler.
- Catch all uncaught Flutter/Dart runtime exceptions and log them using `AppLogger` so they are saved locally.

---

### Component 3: Admin Panel Diagnostics System (React Client)

We will ensure requests from the Admin Panel are tracked and correlation IDs are printed on failure.

#### [MODIFY] [package.json](file:///e:/projects/leitner-learning-platform/admin-panel/package.json)
- Add dependency: `uuid` (or a lightweight equivalent if generating IDs locally).

#### [NEW] [api_client.ts / axios.ts](file:///e:/projects/leitner-learning-platform/admin-panel/src/core/api.ts) (or corresponding API service)
- Implement an interceptor to generate and inject `X-Correlation-ID` on all Axios/Fetch calls.
- Format API exception responses to extract and display the correlation ID in the UI toast notifications.

---

## Verification Plan

### Automated Tests
- Create a unit test verifying that the `CorrelationIdMiddleware` injects an `X-Correlation-ID` header if missing, and preserves it if already provided.
- Create an integration test verifying that throwing an exception inside a controller endpoint triggers the `ExceptionHandlingMiddleware` and returns a standard `500` HTTP status code with the JSON correlation format.

### Manual Verification
1. **Correlation Trace test**:
   - Trigger a deliberate error on the Mobile App (e.g., requesting a course purchase under faulty conditions).
   - Observe the error dialog shown on the device. Note the reference ID.
   - Open the backend server log files. Search for the reference ID and verify that the stack trace details are logged under the corresponding `CorrelationId` property.
2. **Local Log Export**:
   - In the Mobile App settings, trigger "Export Logs" and check that the resulting file contains formatted Warning and Error messages.
