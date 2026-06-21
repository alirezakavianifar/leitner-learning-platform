# Leitner Platform – Course Authoring Kit

The **Course Authoring Kit** provides instructions, schemas, and automation scripts to compile raw card content and media files into secure, production-ready Leitner course database packages.

---

## 1. Project Directory Structure

```text
course-authoring-kit/
├── schema/
│   └── course_schema.sql           # Official SQLite table schema definition
├── tools/
│   └── compile_course.py           # Cross-platform compiler python script
├── sample_course_source/           # Source folder (raw content and media)
│   ├── manifest.json               # Course description & properties
│   ├── cards.json                  # Flashcard listings
│   ├── images/                     # Raw image assets (.png, .webp, .jpg)
│   └── audio/                      # Raw audio voiceover files (.mp3, .aac)
└── README.md                       # This instruction documentation
```

---

## 2. Prerequisites

To execute the compiler script, you need:
1. **Python 3.8+** (compiled and tested on Python 3.14)
2. **`cryptography` library** for AES-256-CBC media encryption.

You can install the required packages using pip:
```bash
pip install cryptography
```

---

## 3. Preparing Course Content Source

An uncompiled course consists of a directory (e.g. `sample_course_source/`) with the following elements:

### A. Manifest File (`manifest.json`)
Defines the course properties and pricing parameters.
```json
{
  "course_id": "7ac148c2-48df-41c3-88c9-0268ec3ba041",
  "title": "IELTS Word Master - Core Essentials",
  "category": "Languages",
  "difficulty": "Intermediate",
  "price": 250000.0,
  "version": 1,
  "card_count": 3,
  "created_at": "2026-06-21T08:10:00Z"
}
```

### B. Cards File (`cards.json`)
Defines the array of flashcards. The cards are referenced using an ordered, unique `card_number` sequence.
```json
[
  {
    "card_number": 1,
    "question_text": "What does the word 'obsolete' mean?",
    "answer_text": "No longer produced or used; out of date.",
    "image_name": "obsolete.png",
    "audio_name": "obsolete.mp3"
  }
]
```
*   **`image_name` / `audio_name`:** Name of the raw asset inside `images/` or `audio/`. The compiler will encrypt them, append `.enc` to the name, and store the `.enc` name in the final database.

---

## 4. Running the Course Compiler

Run the `compile_course.py` python script from the root workspace folder:

```bash
python course-authoring-kit/tools/compile_course.py \
  --source course-authoring-kit/sample_course_source \
  --output course-authoring-kit/sample_course_package \
  --schema course-authoring-kit/schema/course_schema.sql \
  --key "default_dev_course_secret_key_32_bytes_long" \
  --zip course-authoring-kit/sample_course_package/course_package.zip
```

### CLI Options

| Option | Default | Description |
| :--- | :--- | :--- |
| `--source` | `course-authoring-kit/sample_course_source` | Root folder containing raw manifest, card files, and assets. |
| `--output` | `course-authoring-kit/sample_course_package` | Folder where compiled, encrypted artifacts will be generated. |
| `--schema` | `course-authoring-kit/schema/course_schema.sql` | Path to the database table schema file. |
| `--key` | `default_dev_course_secret_key_32_bytes_long` | The passphrase string (or a 64-character hex key) used to encrypt assets. |
| `--zip` | `course-authoring-kit/sample_course_package/course_package.zip` | Output path of the compressed ZIP archive. |

---

## 5. Output Format Specifications

The compiler generates a compiled distribution folder and a corresponding ZIP package:

```text
compiled_package/
├── course.db          # Plaintext SQLite database containing card metadata
├── manifest.json      # Metadata descriptor (includes calculated SHA256 checksum)
├── images/            # Folder of encrypted images (.enc extension)
└── audio/             # Folder of encrypted audio clips (.enc extension)
```

### Security Details (At-Rest Protection)
*   **Media Assets:** The compiler uses **AES-256-CBC** to encrypt each asset file. It generates a cryptographically random 16-byte Initialization Vector (IV) per file and prepends it to the encrypted output stream. The client must read the first 16 bytes as the IV to decrypt the asset.
*   **Database Encryption:** In a production pipeline, after compiling the SQLite `course.db` file, it can be encrypted using standard SQLCipher tools with a key derived from the user's keystore credentials to prevent direct extraction of course details.
