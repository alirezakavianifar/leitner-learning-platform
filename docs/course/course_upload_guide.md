# Course Compilation & Upload Guide

This guide explains how content creators can write raw Leitner flashcard courses, compile them into encrypted SQLite packages using the Course Authoring Kit, and upload them to the platform via the Web Admin Panel.

---

## 1. Raw Course Directory Structure

A course package starts as a directory containing course metadata (`manifest.json`) and raw media files (images and audio).

```text
course_source_directory/
├── manifest.json
├── images/
│   ├── card1_front.png
│   └── card2_example.jpg
└── audio/
    ├── card1_pronunciation.mp3
    └── card2_greeting.wav
```

### manifest.json Format
This file defines course metadata and the individual flashcard configurations.

```json
{
  "id": "english-vocabulary-101",
  "title": "Basic English Vocabulary",
  "description": "Essential nouns, verbs, and conversational phrases for beginners.",
  "category": "Language Learning",
  "difficulty": "Beginner",
  "price": 250000.0,
  "cards": [
    {
      "cardNumber": 1,
      "questionText": "What does the word 'Hello' mean?",
      "answerText": "A standard greeting used to begin a conversation.",
      "imagePath": "images/card1_front.png",
      "audioPath": "audio/card1_pronunciation.mp3"
    },
    {
      "cardNumber": 2,
      "questionText": "Define the word 'Book'.",
      "answerText": "A written or printed work consisting of pages glued together along one side.",
      "imagePath": null,
      "audioPath": null
    }
  ]
}
```

---

## 2. Compilation and Encryption (Course Authoring Kit)

To encrypt and bundle the course package so it can be securely parsed by the mobile client:

### A. Environment Prerequisites
Ensure Python 3.8+ and the `cryptography` package are installed:
```bash
pip install cryptography
```

### B. Compile the Course
Run the compilation tool. This generates the encrypted SQLite `course.db` inside the output directory and compresses the folder into a standard `.zip` distribution.

```bash
python course-authoring-kit/tools/compile_course.py \
  --source course-authoring-kit/sample_course_source \
  --output course-authoring-kit/sample_course_package \
  --schema course-authoring-kit/schema/course_schema.sql \
  --key "default_dev_course_secret_key_32_bytes_long" \
  --zip course-authoring-kit/sample_course_package/course_package.zip
```
* **`--source`**: Path to raw content source directory.
* **`--output`**: Target path to place the output SQLite file and copied assets.
* **`--schema`**: Database schema initialization file.
* **`--key`**: Encryption key string (must match the client-side decryption key configuration).
* **`--zip`**: Path of the resulting output zip file containing the compiled course structure.

### C. Verify the Compiled Output
To check the schema constraints and verify that media decryption processes successfully:
```bash
python course-authoring-kit/tools/verify_course.py
```

---

## 3. Uploading via Web Admin Panel

Once you have generated the compiled `.zip` file (e.g. `course_package.zip`), follow these steps to upload it to the platform:

1. **Log in** to the Admin Panel (`https://admin.yourdomain.com`).
2. Navigate to the **Courses** tab in the sidebar.
3. Click the **Create Course** or **Upload Course** button.
4. Fill in the course details:
   * **Course ID**: Must match the ID defined in `manifest.json` exactly.
   * **Title & Description**: Display names for the catalog.
   * **Price (IRR)**: Set to `0` for free courses.
   * **Target Audience Metadata**: Category, difficulty.
5. In the **Course Package File** selector, choose the compiled `.zip` file.
6. Click **Save & Upload**. The API server will verify the format, extract metadata entries to the server database, and save the zip package securely to the content directory.
7. Click the **Publish Toggle** to make the course instantly discoverable in the Student mobile catalog.
