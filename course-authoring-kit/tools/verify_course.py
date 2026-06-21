#!/usr/bin/env python3
# File: verify_course.py
# Verification tool for Leitner course packages.
# Inspects course.db schema, verifies contents, and tests decryption of encrypted media assets.

import os
import sys
import json
import sqlite3
import zipfile
import hashlib

try:
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    from cryptography.hazmat.primitives import padding
except ImportError:
    print("Error: The 'cryptography' library is required to run this script.")
    sys.exit(1)

def decrypt_data(encrypted_payload: bytes, key: bytes) -> bytes:
    """
    Decrypts an AES-256-CBC encrypted byte array with prepended IV.
    """
    iv = encrypted_payload[:16]
    ciphertext = encrypted_payload[16:]

    cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
    decryptor = cipher.decryptor()
    padded_data = decryptor.update(ciphertext) + decryptor.finalize()

    # Unpad PKCS7
    unpadder = padding.PKCS7(128).unpadder()
    return unpadder.update(padded_data) + unpadder.finalize()

def verify_package(package_dir: str, key_str: str, zip_path: str):
    print("=" * 60)
    print("  Course Database Verification  ")
    print("=" * 60)
    print(f"Package Dir: {package_dir}")
    print(f"Zip Path:    {zip_path}")
    print("-" * 60)

    # 1. Verify ZIP existence and validity
    if not os.path.exists(zip_path):
        print(f"[FAIL] ZIP file does not exist: {zip_path}")
        sys.exit(1)
    
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            test_zip = zip_ref.testzip()
            if test_zip:
                print(f"[FAIL] ZIP file is corrupt. First bad file: {test_zip}")
                sys.exit(1)
            zip_files = zip_ref.namelist()
            print(f"[PASS] ZIP is valid. Contains {len(zip_files)} files:")
            for f in zip_files:
                print(f" - {f}")
    except Exception as e:
        print(f"[FAIL] Failed to open ZIP file: {e}")
        sys.exit(1)

    print("-" * 60)

    # 2. Check Database existence
    db_path = os.path.join(package_dir, 'course.db')
    if not os.path.exists(db_path):
        print(f"[FAIL] Database file not found: {db_path}")
        sys.exit(1)

    # 3. Read SQLite Database
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Query Course table
        cursor.execute("SELECT id, title, category, difficulty, price, version FROM course")
        course_row = cursor.fetchone()
        if not course_row:
            print("[FAIL] Course table is empty.")
            sys.exit(1)
        
        course_id, title, category, difficulty, price, version = course_row
        print(f"[PASS] Course table query success:")
        print(f"  ID:         {course_id}")
        print(f"  Title:      {title}")
        print(f"  Category:   {category}")
        print(f"  Difficulty: {difficulty}")
        print(f"  Price:      {price}")
        print(f"  Version:    {version}")

        # Query Cards table
        cursor.execute("SELECT id, card_number, question_text, image_name, audio_name FROM cards ORDER BY card_number")
        cards = cursor.fetchall()
        print(f"[PASS] Cards table contains {len(cards)} entries:")
        
        # Derive key for asset decryption test
        key = hashlib.sha256(key_str.encode('utf-8')).digest()

        for card in cards:
            c_id, c_num, q_text, img_name, aud_name = card
            print(f"  Card #{c_num}: {q_text[:40]}...")
            
            # Verify Image Decryptability
            if img_name:
                img_path = os.path.join(package_dir, 'images', img_name)
                if not os.path.exists(img_path):
                    print(f"    [FAIL] Encrypted image file missing: {img_path}")
                else:
                    with open(img_path, 'rb') as f:
                        enc_bytes = f.read()
                    try:
                        dec_bytes = decrypt_data(enc_bytes, key)
                        print(f"    [PASS] Image decrypted successfully ({len(dec_bytes)} bytes)")
                    except Exception as e:
                        print(f"    [FAIL] Failed to decrypt image: {e}")

            # Verify Audio Decryptability
            if aud_name:
                aud_path = os.path.join(package_dir, 'audio', aud_name)
                if not os.path.exists(aud_path):
                    print(f"    [FAIL] Encrypted audio file missing: {aud_path}")
                else:
                    with open(aud_path, 'rb') as f:
                        enc_bytes = f.read()
                    try:
                        dec_bytes = decrypt_data(enc_bytes, key)
                        print(f"    [PASS] Audio decrypted successfully ({len(dec_bytes)} bytes)")
                    except Exception as e:
                        print(f"    [FAIL] Failed to decrypt audio: {e}")

        # Verify Metadata table
        cursor.execute("SELECT key, value FROM metadata")
        meta = cursor.fetchall()
        print(f"[PASS] Metadata table query success:")
        for m in meta:
            print(f"  {m[0]}: {m[1]}")

        conn.close()

    except Exception as e:
        print(f"[FAIL] SQLite Verification Error: {e}")
        sys.exit(1)

    print("-" * 60)
    
    # 4. Verify manifest SHA256 Checksum matches actual course.db
    manifest_path = os.path.join(package_dir, 'manifest.json')
    if not os.path.exists(manifest_path):
        print(f"[FAIL] manifest.json missing: {manifest_path}")
        sys.exit(1)

    with open(manifest_path, 'r', encoding='utf-8') as f:
        manifest = json.load(f)

    expected_hash = manifest.get('db_checksum_sha256')
    
    sha256 = hashlib.sha256()
    with open(db_path, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256.update(chunk)
    actual_hash = sha256.hexdigest()

    if expected_hash == actual_hash:
        print(f"[PASS] Checksum matched: {actual_hash}")
    else:
        print(f"[FAIL] Checksum mismatch! Manifest expects {expected_hash}, actual is {actual_hash}")
        sys.exit(1)

    print("=" * 60)
    print("  VERIFICATION SUCCESSFUL!  ")
    print("=" * 60)

if __name__ == '__main__':
    verify_package(
        package_dir='course-authoring-kit/sample_course_package',
        key_str='default_dev_course_secret_key_32_bytes_long',
        zip_path='course-authoring-kit/sample_course_package/course_package.zip'
    )
