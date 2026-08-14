import os
import sys
import requests

RUBIKA_TOKEN = os.environ.get("RUBIKA_BOT_TOKEN", "CBGADB0AFGZDLMGWVNLANQKRQDWYEONKZZUGWWHCFZVZDUUFQYKAVHKZMABOOHXL")
DEFAULT_FILE_PATH = r"E:\projects\leitner-learning-platform\app-premium-release.zip"
if not os.path.exists(DEFAULT_FILE_PATH) and os.path.exists(r"E:\projects\leitner-learning-platform\app-premium-release.rar"):
    DEFAULT_FILE_PATH = r"E:\projects\leitner-learning-platform\app-premium-release.rar"

FILE_PATH = os.environ.get("UPLOAD_FILE_PATH", DEFAULT_FILE_PATH)

def upload_to_rubika():
    if not os.path.exists(FILE_PATH):
        print(f"[ERROR] File not found at: {FILE_PATH}")
        sys.exit(1)

    file_name = os.path.basename(FILE_PATH)
    file_size = os.path.getsize(FILE_PATH)
    print(f">> Preparing Rubika upload for '{file_name}' ({file_size / (1024*1024):.2f} MB)...")

    # Step 1: Request Upload URL
    req_url = f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/requestSendFile"
    payload = {
        "file_name": file_name,
        "size": file_size,
        "type": "File"
    }

    try:
        res = requests.post(req_url, json=payload, timeout=30)
        res_json = res.json()
        if res_json.get("status") != "OK":
            print(f"[ERROR] requestSendFile failed: {res_json}")
            sys.exit(1)

        data = res_json.get("data", {})
        upload_url = data.get("upload_url")
        if not upload_url:
            print(f"[ERROR] No upload_url returned from Rubika API: {res_json}")
            sys.exit(1)

        print(f">> Obtained Rubika upload URL: {upload_url[:45]}...")

        # Step 2: Binary Upload to upload_url
        print(">> Uploading binary archive data to Rubika media server...")
        with open(FILE_PATH, "rb") as f:
            up_res = requests.post(upload_url, files={"file": f}, timeout=180)
            up_json = up_res.json()

        if up_json.get("status") != "OK":
            print(f"[ERROR] Binary upload failed: {up_json}")
            sys.exit(1)

        file_id = up_json.get("data", {}).get("file_id") or up_json.get("data", {}).get("id")
        print(f"  [OK] Binary upload complete! File ID: {file_id}")

        # Step 3: Check recent chats & sendFile
        updates_res = requests.post(f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/getUpdates", timeout=10).json()
        chats = {"b09Oot0xD50c8c82ced516fe45377f0b"}
        if updates_res.get("status") == "OK":
            for upd in updates_res.get("data", {}).get("updates", []):
                chat_id = upd.get("chat_id") or upd.get("message", {}).get("chat_id")
                if chat_id:
                    chats.add(chat_id)

        if chats:
            print(f">> Delivering file to {len(chats)} active Rubika chat(s)...")
            for cid in chats:
                send_payload = {
                    "chat_id": cid,
                    "file_id": file_id,
                    "text": f"🚀 New App Update (ZIP Archive): {file_name}\n\n⚠️ Note: Please extract/unzip this .zip file on your phone first, then install the APK inside."
                }
                send_res = requests.post(f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/sendFile", json=send_payload).json()
                print(f"  [OK] Sent to chat {cid}: {send_res.get('status')}")
        else:
            print(">> Upload complete! File is registered and ready in Rubika cloud storage.")

    except Exception as e:
        print(f"[ERROR] Rubika upload failed with exception: {e}")
        sys.exit(1)

if __name__ == "__main__":
    upload_to_rubika()
