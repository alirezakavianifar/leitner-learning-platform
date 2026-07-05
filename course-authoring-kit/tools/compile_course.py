#!/usr/bin/env python3
# File: compile_course.py
# Course compiler tool for the Leitner Learning Platform
# Compiles raw JSON/CSV content and media assets into encrypted course packages.

import os
import sys
import json
import sqlite3
import zipfile
import hashlib
import argparse
from datetime import datetime

# Import cryptography libraries
try:
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    from cryptography.hazmat.primitives import padding
except ImportError:
    print("Error: The 'cryptography' library is required to run this script.")
    print("Please install it using: pip install cryptography")
    sys.exit(1)

def derive_key(key_input: str) -> bytes:
    """
    Derives a 32-byte key from a password string using SHA-256.
    If the key_input is already a 64-character hex string, decodes it directly.
    """
    if len(key_input) == 64:
        try:
            return bytes.fromhex(key_input)
        except ValueError:
            pass
    return hashlib.sha256(key_input.encode('utf-8')).digest()

def encrypt_file(src_path: str, dest_path: str, key: bytes):
    """
    Encrypts a file using AES-256-CBC and prepends the random 16-byte IV.
    """
    with open(src_path, 'rb') as f:
        plaintext = f.read()

    # Generate a random 16-byte IV
    iv = os.urandom(16)

    # Pad plain text using PKCS7 (128-bit block size)
    padder = padding.PKCS7(128).padder()
    padded_data = padder.update(plaintext) + padder.finalize()

    # Setup Cipher
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
    encryptor = cipher.encryptor()
    ciphertext = encryptor.update(padded_data) + encryptor.finalize()

    # Write IV + ciphertext
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    with open(dest_path, 'wb') as f:
        f.write(iv + ciphertext)

def calculate_sha256(file_path: str) -> str:
    """
    Calculates the SHA-256 checksum of a file.
    """
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256.update(chunk)
    return sha256.hexdigest()

def compile_course(source_dir: str, output_dir: str, schema_path: str, key_str: str, zip_path: str):
    print("=" * 60)
    print("  Leitner Course Database Compiler  ")
    print("=" * 60)
    print(f"Source Dir:      {source_dir}")
    print(f"Output Dir:      {output_dir}")
    print(f"Schema Path:     {schema_path}")
    print(f"Zip Destination: {zip_path}")
    print("-" * 60)

    # Derive 32-byte key
    key = derive_key(key_str)
    print(f"Derived Key (SHA-256): {key.hex()}")

    # 1. Load manifest and cards files
    manifest_path = os.path.join(source_dir, 'manifest.json')
    cards_path = os.path.join(source_dir, 'cards.json')

    if not os.path.exists(manifest_path):
        print(f"Error: manifest.json not found at {manifest_path}")
        sys.exit(1)
    if not os.path.exists(cards_path):
        print(f"Error: cards.json not found at {cards_path}")
        sys.exit(1)

    with open(manifest_path, 'r', encoding='utf-8') as f:
        manifest = json.load(f)
    with open(cards_path, 'r', encoding='utf-8') as f:
        cards = json.load(f)

    # Validate cards count
    declared_count = manifest.get('card_count', 0)
    actual_count = len(cards)
    print(f"Course: {manifest.get('title')} (ID: {manifest.get('course_id')})")
    print(f"Version: {manifest.get('version')}")
    print(f"Cards (Manifest vs JSON): {declared_count} / {actual_count}")

    if declared_count != actual_count:
        print(f"Warning: Manifest declares {declared_count} cards, but {actual_count} were found. Updating manifest.")
        manifest['card_count'] = actual_count

    # 2. Build directories
    os.makedirs(output_dir, exist_ok=True)
    images_out_dir = os.path.join(output_dir, 'images')
    audio_out_dir = os.path.join(output_dir, 'audio')
    os.makedirs(images_out_dir, exist_ok=True)
    os.makedirs(audio_out_dir, exist_ok=True)

    db_path = os.path.join(output_dir, 'course.db')
    if os.path.exists(db_path):
        os.remove(db_path)

    # 3. Create SQLite Database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Load and execute schema DDL
    if not os.path.exists(schema_path):
        print(f"Error: Schema SQL file not found at {schema_path}")
        conn.close()
        sys.exit(1)

    with open(schema_path, 'r', encoding='utf-8') as f:
        schema_sql = f.read()

    cursor.executescript(schema_sql)
    conn.commit()

    # 4. Insert Course Metadata
    print("Writing metadata to database...")
    cursor.execute("""
        INSERT INTO course (id, title, description, category, difficulty, price, version, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        manifest.get('course_id'),
        manifest.get('title'),
        manifest.get('description'),
        manifest.get('category'),
        manifest.get('difficulty'),
        manifest.get('price', 0.0),
        manifest.get('version', 1),
        manifest.get('created_at')
    ))

    # 5. Insert Flashcard items & Encrypt assets
    print("Writing cards & encrypting assets...")
    for idx, card in enumerate(cards):
        card_num = card.get('card_number', idx + 1)
        q_text = card.get('question_text', '')
        a_text = card.get('answer_text', '')
        image_name = card.get('image_name')
        audio_name = card.get('audio_name')
        options = card.get('options')
        options_json = json.dumps(options) if options else None

        card_id = f"{manifest.get('course_id')}_{card_num}"

        # Image Encryption
        encrypted_image_name = None
        if image_name:
            src_img_path = os.path.join(source_dir, 'images', image_name)
            if os.path.exists(src_img_path):
                encrypted_image_name = f"{image_name}.enc"
                dest_img_path = os.path.join(images_out_dir, encrypted_image_name)
                encrypt_file(src_img_path, dest_img_path, key)
            else:
                print(f"Warning: Image file not found: {src_img_path}")

        # Audio Encryption
        encrypted_audio_name = None
        if audio_name:
            src_aud_path = os.path.join(source_dir, 'audio', audio_name)
            if os.path.exists(src_aud_path):
                encrypted_audio_name = f"{audio_name}.enc"
                dest_aud_path = os.path.join(audio_out_dir, encrypted_audio_name)
                encrypt_file(src_aud_path, dest_aud_path, key)
            else:
                print(f"Warning: Audio file not found: {src_aud_path}")

        cursor.execute("""
            INSERT INTO cards (id, course_id, card_number, question_text, answer_text, image_name, audio_name, options)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            card_id,
            manifest.get('course_id'),
            card_num,
            q_text,
            a_text,
            encrypted_image_name,
            encrypted_audio_name,
            options_json
        ))

    # 6. Write to metadata table
    cursor.execute("INSERT INTO metadata (key, value) VALUES (?, ?)", ('version', str(manifest.get('version'))))
    cursor.execute("INSERT INTO metadata (key, value) VALUES (?, ?)", ('compiled_at', datetime.utcnow().isoformat() + "Z"))
    cursor.execute("INSERT INTO metadata (key, value) VALUES (?, ?)", ('compiler', 'Antigravity Course Compiler v1.0'))

    conn.commit()
    conn.close()
    print("Database populate completed successfully.")

    # 7. Checksum calculation and final manifest file
    db_checksum = calculate_sha256(db_path)
    manifest['db_checksum_sha256'] = db_checksum

    manifest_out_path = os.path.join(output_dir, 'manifest.json')
    with open(manifest_out_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2)
    print("Manifest checksum written.")

    # 8. Create ZIP package
    print(f"Packaging into zip file: {zip_path} ...")
    zip_dir = os.path.dirname(zip_path)
    if zip_dir:
        os.makedirs(zip_dir, exist_ok=True)

    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
        # Add course.db
        zip_ref.write(db_path, arcname='course.db')
        # Add manifest.json
        zip_ref.write(manifest_out_path, arcname='manifest.json')
        # Add encrypted images
        for file in os.listdir(images_out_dir):
            if file.endswith('.enc'):
                zip_ref.write(os.path.join(images_out_dir, file), arcname=os.path.join('images', file))
        # Add encrypted audio
        for file in os.listdir(audio_out_dir):
            if file.endswith('.enc'):
                zip_ref.write(os.path.join(audio_out_dir, file), arcname=os.path.join('audio', file))

    print("-" * 60)
    print("COMPILATION SUCCESSFUL!")
    print(f"Compiled Database Checksum (SHA-256): {db_checksum}")
    print(f"Packaged ZIP created at: {zip_path}")
    print("=" * 60)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Compile Leitner Course package.")
    parser.add_argument('--source', default='course-authoring-kit/sample_course_source',
                        help='Path to source raw course folder')
    parser.add_argument('--output', default='course-authoring-kit/sample_course_package',
                        help='Path to output compiled folder')
    parser.add_argument('--schema', default='course-authoring-kit/schema/course_schema.sql',
                        help='Path to course schema DDL')
    parser.add_argument('--key', default='default_dev_course_secret_key_32_bytes_long',
                        help='Encryption password/key (ASCII or 64-char Hex)')
    parser.add_argument('--zip', default='course-authoring-kit/sample_course_package/course_package.zip',
                        help='Destination ZIP filepath')

    args = parser.parse_args()

    # Resolve paths relative to the current workspace root if needed
    source_dir = os.path.abspath(args.source)
    output_dir = os.path.abspath(args.output)
    schema_path = os.path.abspath(args.schema)
    zip_path = os.path.abspath(args.zip)

    compile_course(source_dir, output_dir, schema_path, args.key, zip_path)
