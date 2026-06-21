# Versioned REST API Specification (v1)

All system endpoints are served over HTTPS and versioned with the `/api/v1/` routing prefix.

---

## 1. Authentication Domain (`/api/v1/auth`)

### A. Request SMS OTP
Initiates authentication. Sends a one-time SMS verification token.
*   **Path:** `/api/v1/auth/otp/request`
*   **Method:** `POST`
*   **Request Headers:** `Content-Type: application/json`
*   **Request Body:**
    ```json
    {
      "mobile_number": "+989123456789"
    }
    ```
*   **Response (200 OK):**
    ```json
    {
      "success": true,
      "message": "OTP verification code sent successfully.",
      "expires_in_seconds": 120
    }
    ```
*   **Response (400 Bad Request):**
    ```json
    {
      "success": false,
      "error_code": "INVALID_MOBILE_NUMBER",
      "message": "The provided mobile number is invalid."
    }
    ```

### B. Verify OTP & Authenticate
Verifies the SMS code. Returns a JWT access token and user status.
*   **Path:** `/api/v1/auth/otp/verify`
*   **Method:** `POST`
*   **Request Body:**
    ```json
    {
      "mobile_number": "+989123456789",
      "otp_code": "482015"
    }
    ```
*   **Response (200 OK):**
    ```json
    {
      "success": true,
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refresh_token": "8f8b88e1-5e8c-4f81-998c-02cf17...",
      "user_status": "NEW_USER" -- or "PROFILE_PENDING", "ACTIVE"
    }
    ```
*   **Response (401 Unauthorized):**
    ```json
    {
      "success": false,
      "error_code": "INVALID_OTP",
      "message": "The verification code is incorrect or expired."
    }
    ```

---

## 2. User & Profile Domain (`/api/v1/user`)

*Requires Authentication Header:* `Authorization: Bearer <token>`

### A. Get Profile Details
Fetches active user details.
*   **Path:** `/api/v1/user/profile`
*   **Method:** `GET`
*   **Response (200 OK):**
    ```json
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "username": "student_alpha",
      "mobile_number": "+989123456789", -- Strictly read-only for the client
      "interests": "computer science, mathematics",
      "educational_field": "Engineering",
      "educational_level": "Undergraduate",
      "created_at": "2026-06-21T07:50:37Z"
    }
    ```

### B. Update Profile Info
Allows updating configurable fields.
*   **Path:** `/api/v1/user/profile`
*   **Method:** `PUT`
*   **Request Body:**
    ```json
    {
      "username": "student_alpha_updated",
      "interests": "computer science, mathematics, statistics",
      "educational_field": "Software Engineering",
      "educational_level": "Graduate"
    }
    ```
    > [!IMPORTANT]
    > **Mobile Number Read-Only Rule:** The `mobile_number` field must not be present in the update body. If it is sent, the server must discard/ignore it or return a validation error to prevent tampering with authenticated accounts.
*   **Response (200 OK):**
    ```json
    {
      "success": true,
      "message": "Profile updated successfully.",
      "profile": {
        "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "username": "student_alpha_updated",
        "mobile_number": "+989123456789",
        "interests": "computer science, mathematics, statistics",
        "educational_field": "Software Engineering",
        "educational_level": "Graduate",
        "created_at": "2026-06-21T07:50:37Z"
      }
    }
    ```

---

## 3. Courses Domain (`/api/v1/courses`)

### A. List Courses Catalog
Returns a list of all courses available for purchase/study.
*   **Path:** `/api/v1/courses`
*   **Method:** `GET`
*   **Response (200 OK):**
    ```json
    [
      {
        "id": "7ac148c2-48df-41c3-88c9-0268ec3ba041",
        "title": "Essential English Vocabulary",
        "description": "Learn 504 absolutely essential words.",
        "category": "Languages",
        "difficulty": "Intermediate",
        "price": 150000.00,
        "card_count": 504,
        "is_purchased": false,
        "download_url": null
      },
      {
        "id": "1198fb9c-48c1-4ca3-99cf-dfc24d981248",
        "title": "Mathematics Foundations",
        "description": "Calculus and linear algebra basics.",
        "category": "Science",
        "difficulty": "Advanced",
        "price": 0.00,
        "card_count": 220,
        "is_purchased": true,
        "download_url": "https://content.leitnerapp.com/packages/1198fb9c-48c1-4ca3-99cf-dfc24d981248.zip?token=xyz"
      }
    ]
    ```

### B. Request Course Download Token
Generates a temp token to download the SQLite course package.
*   **Path:** `/api/v1/courses/{id}/download-token`
*   **Method:** `POST`
*   **Response (200 OK):**
    ```json
    {
      "success": true,
      "download_url": "https://content.leitnerapp.com/packages/7ac148c2-48df-41c3-88c9-0268ec3ba041.zip",
      "token": "temp_sec_token_99a8c1f9d",
      "checksum": "sha256-a1b2c3d4e5f6..."
    }
    ```
*   **Response (403 Forbidden - Course Not Purchased):**
    ```json
    {
      "success": false,
      "error_code": "PURCHASE_REQUIRED",
      "message": "You must purchase this course before downloading."
    }
    ```

---

## 4. Purchases Domain (`/api/v1/purchases`)

### A. Verify Store Receipt / Token
Processes payment validation from Google Play, Cafe Bazaar, Myket, or Direct Gateways.
*   **Path:** `/api/v1/purchases/verify`
*   **Method:** `POST`
*   **Request Body:**
    ```json
    {
      "course_id": "7ac148c2-48df-41c3-88c9-0268ec3ba041",
      "payment_provider": "CAFE_BAZAAR", -- 'GOOGLE_PLAY', 'CAFE_BAZAAR', 'MYKET', 'DIRECT'
      "purchase_token": "tok_9918a8bca01e23f",
      "transaction_id": "tx_88a1b203c9"
    }
    ```
*   **Response (200 OK):**
    ```json
    {
      "success": true,
      "status": "COMPLETED",
      "course_id": "7ac148c2-48df-41c3-88c9-0268ec3ba041",
      "purchased_at": "2026-06-21T07:51:00Z"
    }
    ```

---

## 5. Reports & Feedback Domain (`/api/v1/reports`)

### A. Submit Flashcard Correction Report
Allows reporting card errors (typos, incorrect answers).
*   **Path:** `/api/v1/reports/submit`
*   **Method:** `POST`
*   **Request Body:**
    ```json
    {
      "course_id": "7ac148c2-48df-41c3-88c9-0268ec3ba041",
      "card_number": 42,
      "report_text": "The spelling of the word is incorrect on the answer side."
    }
    ```
*   **Response (201 Created):**
    ```json
    {
      "success": true,
      "report_id": "89ab8c1d-1eef-411a-ba22-83b8e72c81a1",
      "message": "Report submitted successfully."
    }
    ```

---

## 6. Remote Configuration Domain (`/api/v1/config`)

### A. Fetch Remote Config & Feature Flags
Returns dynamic setup rules. App queries this endpoint at boot or once every 24 hours.
*   **Path:** `/api/v1/config/features`
*   **Method:** `GET`
*   **Response (200 OK):**
    ```json
    {
      "maintenance_mode": false,
      "endpoints": {
        "api_server": "https://api.leitnerapp.com",
        "content_server": "https://content.leitnerapp.com",
        "banner_server": "https://banners.leitnerapp.com"
      },
      "feature_flags": {
        "enable_ai_tutor": false,
        "enable_custom_themes": true,
        "enable_search_v2": true
      },
      "banner_configs": {
        "rotation_interval_seconds": 4,
        "max_banner_count": 5
      },
      "announcements": [
        {
          "id": "1",
          "title": "Welcome to Version 1.0!",
          "content": "Start learning with spaced repetition.",
          "published_at": "2026-06-20T12:00:00Z"
        }
      ],
      "banners": [
        {
          "id": "b1",
          "image_url": "https://banners.leitnerapp.com/img1.jpg",
          "link_url": "https://leitnerapp.com/promo1",
          "display_order": 1
        }
      ]
    }
    ```

---

## 7. Administrative APIs (`/api/v1/admin`)

*Requires Authentication Header:* `Authorization: Bearer <admin_token>`

### A. List Flashcard Reports
Browse card feedback with status filter.
*   **Path:** `/api/v1/admin/reports`
*   **Method:** `GET`
*   **Parameters:** `status=PENDING` (optional)
*   **Response (200 OK):**
    ```json
    [
      {
        "report_id": "89ab8c1d-1eef-411a-ba22-83b8e72c81a1",
        "user_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "course_id": "7ac148c2-48df-41c3-88c9-0268ec3ba041",
        "card_number": 42,
        "report_text": "The spelling of the word is incorrect on the answer side.",
        "submitted_at": "2026-06-21T07:51:00Z",
        "status": "PENDING"
      }
    ]
    ```

### B. Manually Toggle User Course Access
Bypasses payment gateways for user activation. Enforces detailed auditing logs.
*   **Path:** `/api/v1/admin/users/{userId}/courses/{courseId}`
*   **Method:** `PATCH`
*   **Request Body:**
    ```json
    {
      "grant_access": true,
      "reason": "Customer support manual bypass"
    }
    ```
*   **Response (200 OK):**
    ```json
    {
      "success": true,
      "message": "Course access updated and change logged.",
      "audit_id": "c1c463f2-1e9a-4f99-92c2-72f8832a8291"
    }
    ```
