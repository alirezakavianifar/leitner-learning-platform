import os
import sys
import time
import socket
import argparse
import subprocess
import requests
from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

RUBIKA_TOKEN = os.environ.get("RUBIKA_BOT_TOKEN", "CBGADB0AFGZDLMGWVNLANQKRQDWYEONKZZUGWWHCFZVZDUUFQYKAVHKZMABOOHXL")
DEFAULT_FILE_PATH = r"E:\projects\leitner_app\app-premium-release.zip"
if not os.path.exists(DEFAULT_FILE_PATH) and os.path.exists(r"E:\projects\leitner-learning-platform\app-premium-release.zip"):
    DEFAULT_FILE_PATH = r"E:\projects\leitner-learning-platform\app-premium-release.zip"

SERVER_IP = os.environ.get("DEPLOY_SERVER_IP", "45.94.215.188")
SERVER_USER = os.environ.get("DEPLOY_SERVER_USER", "root")
KEY_PATH = os.environ.get("DEPLOY_KEY_PATH", r"C:\Users\Administrator\.ssh\id_rsa_deploy")
SOCKS_PORT = int(os.environ.get("RUBIKA_SOCKS_PORT", "10808"))


def is_port_open(port=SOCKS_PORT):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(1.0)
    res = sock.connect_ex(('127.0.0.1', port))
    sock.close()
    return res == 0


def ensure_ssh_proxy():
    if is_port_open(SOCKS_PORT):
        return True

    if not os.path.exists(KEY_PATH):
        return False

    print(f">> Establishing SSH SOCKS5 tunnel via {SERVER_IP}...")
    cmd = [
        "ssh",
        "-n",
        "-T",
        "-N",
        "-i", KEY_PATH,
        "-o", "StrictHostKeyChecking=no",
        "-o", "ServerAliveInterval=15",
        "-o", "ServerAliveCountMax=5",
        "-o", "ConnectTimeout=10",
        "-D", f"127.0.0.1:{SOCKS_PORT}",
        f"{SERVER_USER}@{SERVER_IP}"
    ]
    try:
        proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(12):
            time.sleep(0.5)
            if is_port_open(SOCKS_PORT):
                print(f"  [OK] SSH SOCKS5 tunnel active on port {SOCKS_PORT}.")
                return True
            if proc.poll() is not None:
                break
    except Exception as e:
        print(f"  [WARNING] Could not start SSH SOCKS5 tunnel: {e}")

    return is_port_open(SOCKS_PORT)


def get_active_chats(session):
    chats = {"b09Oot0xD50c8c82ced516fe45377f0b"}
    try:
        updates_res = session.post(f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/getUpdates", json={}, timeout=10).json()
        if updates_res.get("status") == "OK":
            for upd in updates_res.get("data", {}).get("updates", []):
                chat_id = upd.get("chat_id") or upd.get("message", {}).get("chat_id")
                if chat_id:
                    chats.add(chat_id)
    except Exception as e:
        print(f"  [WARNING] getUpdates warning: {e}")
    return chats


def send_test_message(text=None):
    session = requests.Session()
    # Test direct access first, fallback to proxy if needed
    try:
        me_res = session.post(f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/getMe", timeout=8).json()
    except Exception:
        ensure_ssh_proxy()
        if is_port_open(SOCKS_PORT):
            session.proxies = {
                "http": f"socks5h://127.0.0.1:{SOCKS_PORT}",
                "https": f"socks5h://127.0.0.1:{SOCKS_PORT}"
            }
        me_res = session.post(f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/getMe", timeout=15).json()

    if me_res.get("status") != "OK":
        print(f"[ERROR] getMe failed: {me_res}")
        sys.exit(1)

    bot_info = me_res.get("data", {}).get("bot", {})
    bot_name = bot_info.get("bot_title", "Unknown")
    bot_user = bot_info.get("username", "Unknown")
    print(f"  [OK] Bot connected: {bot_name} (@{bot_user})")

    chats = get_active_chats(session)
    msg_text = text or "🤖 [Test Message] Leitner Learning Platform: Rubika Bot connection test successful! ✅"
    print(f">> Sending message to {len(chats)} active chat(s)...")
    for cid in chats:
        payload = {
            "chat_id": cid,
            "text": msg_text
        }
        res = session.post(f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/sendMessage", json=payload, timeout=15).json()
        print(f"  [OK] Sent to chat {cid}: {res.get('status')}")
    print(">> Done.")


def upload_via_streaming(file_path, use_proxy=False):
    file_name = os.path.basename(file_path)
    file_size = os.path.getsize(file_path)
    mb_size = file_size / (1024 * 1024)

    session = requests.Session()
    if use_proxy:
        if ensure_ssh_proxy() or is_port_open(SOCKS_PORT):
            session.proxies = {
                "http": f"socks5h://127.0.0.1:{SOCKS_PORT}",
                "https": f"socks5h://127.0.0.1:{SOCKS_PORT}"
            }

    for attempt in range(1, 4):
        try:
            print(f">> Requesting Rubika upload slot (Attempt {attempt}/3) for '{file_name}' ({mb_size:.2f} MB) via {network_type}...")
            req_url = f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/requestSendFile"
            req_payload = {"file_name": file_name, "size": file_size, "type": "File"}
            res = session.post(req_url, json=req_payload, timeout=20).json()

            if res.get("status") != "OK":
                print(f"  [WARNING] requestSendFile failed: {res}. Retrying in 5s...")
                time.sleep(5)
                continue

            upload_url = res["data"]["upload_url"]
            print(f"  [OK] Upload endpoint received from Rubika CDN.")
            print(f">> Streaming '{file_name}' to Rubika with live socket progress...")

            start_time = time.time()
            last_print = [0]

            def create_progress_callback():
                def callback(monitor):
                    now = time.time()
                    if now - last_print[0] >= 0.3 or monitor.bytes_read >= monitor.len:
                        last_print[0] = now
                        elapsed = now - start_time
                        speed = (monitor.bytes_read / (1024 * 1024)) / elapsed if elapsed > 0 else 0
                        pct = (monitor.bytes_read / monitor.len) * 100
                        mb_done = monitor.bytes_read / (1024 * 1024)
                        mb_tot = monitor.len / (1024 * 1024)
                        bar_len = 30
                        filled = int(bar_len * monitor.bytes_read // monitor.len)
                        bar = "=" * filled + "-" * (bar_len - filled)
                        print(f"\r  [{bar}] {pct:5.1f}% ({mb_done:.1f}/{mb_tot:.1f} MB @ {speed:.2f} MB/s)", end="", flush=True)
                return callback

            with open(file_path, "rb") as f:
                encoder = MultipartEncoder(fields={"file": (file_name, f, "application/zip")})
                monitor = MultipartEncoderMonitor(encoder, create_progress_callback())
                up_res = session.post(upload_url, data=monitor, headers={"Content-Type": monitor.content_type}, timeout=180)
                up_json = up_res.json()

            print()
            if up_json.get("status") != "OK":
                print(f"  [WARNING] Binary upload failed on attempt {attempt}: {up_json}")
                if attempt < 3:
                    time.sleep(5)
                    continue
                return False

            file_id = up_json.get("data", {}).get("file_id") or up_json.get("data", {}).get("id")
            print(f"  [OK] Binary upload complete! File ID: {file_id}")

            # Send file message to chats
            chats = get_active_chats(session)
            for cid in chats:
                send_payload = {
                    "chat_id": cid,
                    "file_id": file_id,
                    "text": f"🚀 New App Update: {file_name}\n\n📦 File: {file_name} ({mb_size:.2f} MB)"
                }
                s_res = session.post(f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/sendFile", json=send_payload, timeout=20).json()
                print(f"  [OK] Delivered to chat {cid}: {s_res.get('status')}")

            return True
        except Exception as ex:
            print(f"\n  [WARNING] Attempt {attempt} encountered error: {ex}")
            if attempt < 3:
                time.sleep(5)

    return False


def upload_via_server_bridge(file_path):
    file_name = os.path.basename(file_path)
    file_size = os.path.getsize(file_path)
    remote_tmp = f"/tmp/{file_name}"

    print(f">> Transferring '{file_name}' ({file_size / (1024*1024):.2f} MB) to deployment bridge server ({SERVER_IP})...")
    scp_cmd = [
        "scp",
        "-O",
        "-C",
        "-i", KEY_PATH,
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=15",
        file_path,
        f"{SERVER_USER}@{SERVER_IP}:{remote_tmp}"
    ]
    res = subprocess.run(scp_cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=600)
    if res.returncode != 0:
        print(f"[ERROR] SCP transfer failed: {res.stderr}")
        return False

    print(f"  [OK] File uploaded to bridge server. Delivering to Rubika cloud...")
    remote_code = f"""import requests, json, sys, os
token = '{RUBIKA_TOKEN}'
file_path = '{remote_tmp}'
file_name = '{file_name}'
file_size = {file_size}

req_url = f'https://botapi.rubika.ir/v3/{{token}}/requestSendFile'
r = requests.post(req_url, json={{'file_name': file_name, 'size': file_size, 'type': 'File'}}, timeout=30).json()
if r.get('status') != 'OK':
    print('ERR_REQ:' + json.dumps(r))
    sys.exit(1)

upload_url = r['data']['upload_url']
with open(file_path, 'rb') as f:
    up = requests.post(upload_url, files={{'file': f}}, timeout=180).json()

if up.get('status') != 'OK':
    print('ERR_UP:' + json.dumps(up))
    sys.exit(1)

file_id = up.get('data', {{}}).get('file_id') or up.get('data', {{}}).get('id')
print(f'FILE_ID:{{file_id}}')

upd = requests.post(f'https://botapi.rubika.ir/v3/{{token}}/getUpdates', json={{}}, timeout=15).json()
chats = {{'b09Oot0xD50c8c82ced516fe45377f0b'}}
if upd.get('status') == 'OK':
    for u in upd.get('data', {{}}).get('updates', []):
        cid = u.get('chat_id') or u.get('message', {{}}).get('chat_id')
        if cid:
            chats.add(cid)

for cid in chats:
    send_payload = {{
        'chat_id': cid,
        'file_id': file_id,
        'text': '🚀 New App Update (ZIP Archive): {file_name}\\n\\n⚠️ Note: Please extract/unzip this .zip file on your phone first, then install the APK inside.'
    }}
    s_res = requests.post(f'https://botapi.rubika.ir/v3/{{token}}/sendFile', json=send_payload, timeout=30).json()
    print(f'DELIVERED:{{cid}}:{{s_res.get(\"status\")}}')

try:
    os.remove(file_path)
except Exception:
    pass
"""

    import base64
    encoded_script = base64.b64encode(remote_code.encode("utf-8")).decode("ascii")
    remote_script_path = f"/tmp/rubika_deliver_{int(time.time())}.py"

    prep_cmd = [
        "ssh", "-n", "-T", "-i", KEY_PATH, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=15",
        f"{SERVER_USER}@{SERVER_IP}",
        f"echo {encoded_script} | base64 -d > {remote_script_path}"
    ]
    subprocess.run(prep_cmd, stdin=subprocess.DEVNULL, capture_output=True)

    exec_cmd = [
        "ssh", "-n", "-T", "-i", KEY_PATH, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=15",
        f"{SERVER_USER}@{SERVER_IP}",
        f"python3 {remote_script_path} ; rm -f {remote_script_path}"
    ]
    res = subprocess.run(exec_cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, encoding="utf-8", timeout=240)

    if res.returncode != 0:
        print(f"[ERROR] Remote bridge execution failed: {res.stderr or res.stdout}")
        return False

    for line in res.stdout.splitlines():
        if line.startswith("FILE_ID:"):
            print(f"  [OK] Binary upload complete! File ID: {line.split(':', 1)[1]}")
        elif line.startswith("DELIVERED:"):
            parts = line.split(":")
            print(f"  [OK] Delivered to chat {parts[1]}: {parts[2]}")

    return True


def upload_to_rubika(target_path=None):
    file_path = target_path or os.environ.get("UPLOAD_FILE_PATH", DEFAULT_FILE_PATH)
    if not os.path.exists(file_path):
        print(f"[ERROR] File not found at: {file_path}")
        sys.exit(1)

    file_name = os.path.basename(file_path)
    file_size = os.path.getsize(file_path)
    print(f">> Preparing Rubika delivery for '{file_name}' ({file_size / (1024*1024):.2f} MB)...")

    # Primary method: Direct high-speed domestic upload
    try:
        if upload_via_streaming(file_path, use_proxy=False):
            print(">> Rubika delivery finished successfully via direct network.")
            return
    except Exception as e:
        print(f"  [WARNING] Direct upload encountered an issue ({e}). Trying SOCKS5 proxy...")

    # Secondary method: Streaming over SOCKS5 proxy
    try:
        if upload_via_streaming(file_path, use_proxy=True):
            print(">> Rubika delivery finished successfully via SOCKS5 proxy.")
            return
    except Exception as e:
        print(f"  [WARNING] Proxy upload encountered an issue ({e}). Trying server bridge fallback...")

    # Fallback method: Server Bridge direct SCP upload
    if os.path.exists(KEY_PATH):
        if upload_via_server_bridge(file_path):
            print(">> Rubika delivery finished successfully via server bridge.")
            return

    print("[ERROR] All Rubika upload methods failed.")
    sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Rubika Bot Upload & Messenger CLI")
    parser.add_argument("--test", action="store_true", help="Send a test message to verify connectivity")
    parser.add_argument("--message", type=str, help="Send a custom text message to active chats")
    parser.add_argument("--file", type=str, help="Path of the file to upload")
    args = parser.parse_args()

    if args.test or args.message:
        send_test_message(args.message)
    else:
        upload_to_rubika(args.file)
