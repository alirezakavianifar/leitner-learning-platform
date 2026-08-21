import os
import sys
import time
import socket
import argparse
import subprocess
import requests

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

RUBIKA_TOKEN = os.environ.get("RUBIKA_BOT_TOKEN", "CBGADB0AFGZDLMGWVNLANQKRQDWYEONKZZUGWWHCFZVZDUUFQYKAVHKZMABOOHXL")
DEFAULT_FILE_PATH = r"E:\projects\leitner-learning-platform\app-premium-release.zip"
if not os.path.exists(DEFAULT_FILE_PATH) and os.path.exists(r"E:\projects\leitner-learning-platform\app-premium-release.rar"):
    DEFAULT_FILE_PATH = r"E:\projects\leitner-learning-platform\app-premium-release.rar"

SERVER_IP = os.environ.get("DEPLOY_SERVER_IP", "45.94.215.188")
SERVER_USER = os.environ.get("DEPLOY_SERVER_USER", "root")
KEY_PATH = os.environ.get("DEPLOY_KEY_PATH", r"C:\Users\Administrator\.ssh\id_rsa_deploy")
SOCKS_PORT = int(os.environ.get("RUBIKA_SOCKS_PORT", "10808"))
CHUNK_SIZE = 1 * 1024 * 1024  # 1MB chunks for DPI resilience and fast per-chunk transfers

def render_progress_bar(current, total, prefix="Transfer", suffix="", length=28, fill="=", empty="-"):
    percent = (current / total) * 100 if total > 0 else 0
    filled_len = int(length * current // total) if total > 0 else 0
    bar = fill * filled_len + empty * (length - filled_len)
    print(f"  [{prefix}] [{bar}] {percent:5.1f}% {suffix}", flush=True)

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
    for attempt in range(1, 4):
        cmd = [
            "ssh",
            "-i", KEY_PATH,
            "-o", "StrictHostKeyChecking=no",
            "-o", "ServerAliveInterval=10",
            "-o", "ServerAliveCountMax=10",
            "-o", "ConnectTimeout=8",
            "-D", str(SOCKS_PORT),
            "-N",
            f"{SERVER_USER}@{SERVER_IP}"
        ]
        proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(8):
            time.sleep(1)
            if is_port_open(SOCKS_PORT):
                print(f"  [OK] SSH SOCKS5 tunnel active on port {SOCKS_PORT}.")
                return True
            if proc.poll() is not None:
                break
        try:
            proc.kill()
        except Exception:
            pass
        time.sleep(1)

    return is_port_open(SOCKS_PORT)

def get_session():
    s = requests.Session()
    if ensure_ssh_proxy() or is_port_open(SOCKS_PORT):
        s.proxies = {
            "http": f"socks5h://127.0.0.1:{SOCKS_PORT}",
            "https": f"socks5h://127.0.0.1:{SOCKS_PORT}"
        }
    return s

def get_active_chats(session=None):
    if session is None:
        session = get_session()
    chats = {"b09Oot0xD50c8c82ced516fe45377f0b"}
    try:
        updates_res = session.post(f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/getUpdates", json={}, timeout=15).json()
        if updates_res.get("status") == "OK":
            for upd in updates_res.get("data", {}).get("updates", []):
                chat_id = upd.get("chat_id") or upd.get("message", {}).get("chat_id")
                if chat_id:
                    chats.add(chat_id)
    except Exception as e:
        print(f"  [WARNING] getUpdates warning: {e}")
    return chats

def send_test_message(text=None):
    session = get_session()
    print(">> Testing Rubika Bot connectivity (getMe)...")
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

def upload_via_server_bridge(file_path):
    file_name = os.path.basename(file_path)
    file_size = os.path.getsize(file_path)
    remote_tmp = f"/tmp/{file_name}"
    chunks_dir = f"/tmp/chunks_{file_name}"
    local_chunks_dir = os.path.join(os.path.dirname(file_path), f"chunks_{file_name}")
    os.makedirs(local_chunks_dir, exist_ok=True)
    total_chunks = (file_size + CHUNK_SIZE - 1) // CHUNK_SIZE

    # Check if complete file already exists on remote
    chk_existing = subprocess.run(
        ["ssh", "-i", KEY_PATH, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10", f"{SERVER_USER}@{SERVER_IP}", f"stat -c %s {remote_tmp} 2>/dev/null || echo 0"],
        capture_output=True,
        text=True
    )
    existing_size = int(chk_existing.stdout.strip() or 0)

    if existing_size == file_size:
        print(f">> Verified existing archive ({file_size / (1024*1024):.2f} MB) on bridge server.")
    else:
        print(f">> Transferring '{file_name}' ({file_size / (1024*1024):.2f} MB in {total_chunks} chunks) to deployment bridge server ({SERVER_IP})...")

        # Ensure chunk directory exists
        subprocess.run(
            ["ssh", "-i", KEY_PATH, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10", f"{SERVER_USER}@{SERVER_IP}", f"mkdir -p {chunks_dir}"],
            capture_output=True
        )

        # Get list of existing valid chunks on remote
        ls_res = subprocess.run(
            ["ssh", "-i", KEY_PATH, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10", f"{SERVER_USER}@{SERVER_IP}", f"ls -l {chunks_dir} 2>/dev/null"],
            capture_output=True,
            text=True
        )
        existing_chunks = {}
        for line in ls_res.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 9 and parts[-1].endswith(".bin"):
                try:
                    existing_chunks[parts[-1]] = int(parts[4])
                except ValueError:
                    pass

        start_time = time.time()
        uploaded_bytes = 0

        # Resumable Atomic Chunked Transfer
        with open(file_path, "rb") as f:
            for idx in range(total_chunks):
                chunk_data = f.read(CHUNK_SIZE)
                chunk_len = len(chunk_data)
                chunk_file_name = f"chunk_{idx:04d}.bin"
                local_chunk_path = os.path.join(local_chunks_dir, chunk_file_name)
                remote_chunk_path = f"{chunks_dir}/{chunk_file_name}"
                remote_part_path = f"{chunks_dir}/{chunk_file_name}.part"

                if existing_chunks.get(chunk_file_name) == chunk_len:
                    uploaded_bytes += chunk_len
                    mb_done = uploaded_bytes / (1024 * 1024)
                    mb_total = file_size / (1024 * 1024)
                    suffix = f"({idx+1}/{total_chunks} chunks | {mb_done:.1f}/{mb_total:.1f} MB [cached])"
                    render_progress_bar(idx + 1, total_chunks, prefix="Uploading", suffix=suffix)
                    continue

                # Write chunk locally
                with open(local_chunk_path, "wb") as cf:
                    cf.write(chunk_data)

                chunk_success = False
                for attempt in range(1, 15):
                    # Check if already present on remote before or after attempt
                    chk_cmd = [
                        "ssh",
                        "-i", KEY_PATH,
                        "-o", "StrictHostKeyChecking=no",
                        "-o", "ConnectTimeout=10",
                        f"{SERVER_USER}@{SERVER_IP}",
                        f"stat -c %s {remote_chunk_path} 2>/dev/null || echo 0"
                    ]
                    try:
                        chk_p = subprocess.run(chk_cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
                        if int(chk_p.stdout.strip() or 0) == chunk_len:
                            chunk_success = True
                            break
                    except Exception:
                        pass

                    scp_cmd = [
                        "scp",
                        "-O",
                        "-C",
                        "-i", KEY_PATH,
                        "-o", "StrictHostKeyChecking=no",
                        "-o", "ConnectTimeout=15",
                        local_chunk_path,
                        f"{SERVER_USER}@{SERVER_IP}:{remote_chunk_path}"
                    ]
                    try:
                        proc = subprocess.run(scp_cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=45)
                        if proc.returncode == 0:
                            chunk_success = True
                            break
                    except Exception:
                        pass
                    time.sleep(2)

                if not chunk_success:
                    print(f"\n[ERROR] Failed to transfer chunk {idx+1}/{total_chunks}")
                    return False

                uploaded_bytes += chunk_len
                elapsed = time.time() - start_time
                speed = (uploaded_bytes / (1024 * 1024)) / elapsed if elapsed > 0 else 0
                mb_done = uploaded_bytes / (1024 * 1024)
                mb_total = file_size / (1024 * 1024)
                suffix = f"({idx+1}/{total_chunks} chunks | {mb_done:.1f}/{mb_total:.1f} MB @ {speed:.2f} MB/s)"
                render_progress_bar(idx + 1, total_chunks, prefix="Uploading", suffix=suffix)

        # Cleanup local chunks
        try:
            import shutil
            shutil.rmtree(local_chunks_dir, ignore_errors=True)
        except Exception:
            pass

        print("  >> Reassembling chunks on remote server...")
        reassemble_cmd = [
            "ssh",
            "-i", KEY_PATH,
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=20",
            f"{SERVER_USER}@{SERVER_IP}",
            f"cat {chunks_dir}/chunk_*.bin > {remote_tmp} && rm -rf {chunks_dir}"
        ]
        subprocess.run(reassemble_cmd, capture_output=True)

        print("  >> Verifying reassembled archive integrity...")
        chk = subprocess.run(
            ["ssh", "-i", KEY_PATH, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=15", f"{SERVER_USER}@{SERVER_IP}", f"stat -c %s {remote_tmp}"],
            capture_output=True,
            text=True
        )
        remote_size = int(chk.stdout.strip() or 0)
        if remote_size != file_size:
            print(f"[ERROR] Remote file size mismatch: {remote_size} != {file_size}")
            return False

    print(f"  [OK] Archive ready on server ({file_size} bytes). Delivering to Rubika cloud...")

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
        "ssh", "-i", KEY_PATH, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=15",
        f"{SERVER_USER}@{SERVER_IP}",
        f"echo {encoded_script} | base64 -d > {remote_script_path}"
    ]
    subprocess.run(prep_cmd, capture_output=True)

    exec_cmd = [
        "ssh", "-i", KEY_PATH, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=15",
        f"{SERVER_USER}@{SERVER_IP}",
        f"python3 {remote_script_path} ; rm -f {remote_script_path}"
    ]
    res = subprocess.run(exec_cmd, capture_output=True, text=True, encoding="utf-8", timeout=240)

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

    # If SSH key is configured, use the high-speed server bridge
    if os.path.exists(KEY_PATH):
        if upload_via_server_bridge(file_path):
            print(">> Rubika delivery finished successfully via server bridge.")
            return

    # Fallback to direct / SOCKS5 upload
    session = get_session()
    req_url = f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/requestSendFile"
    payload = {"file_name": file_name, "size": file_size, "type": "File"}

    try:
        res = session.post(req_url, json=payload, timeout=30)
        res_json = res.json()
        if res_json.get("status") != "OK":
            print(f"[ERROR] requestSendFile failed: {res_json}")
            sys.exit(1)

        upload_url = res_json["data"]["upload_url"]
        with open(file_path, "rb") as f:
            up_res = session.post(upload_url, files={"file": f}, timeout=300)
            up_json = up_res.json()

        if up_json.get("status") != "OK":
            print(f"[ERROR] Binary upload failed: {up_json}")
            sys.exit(1)

        file_id = up_json.get("data", {}).get("file_id") or up_json.get("data", {}).get("id")
        print(f"  [OK] Binary upload complete! File ID: {file_id}")

        chats = get_active_chats(session)
        for cid in chats:
            send_payload = {
                "chat_id": cid,
                "file_id": file_id,
                "text": f"🚀 New App Update (ZIP Archive): {file_name}\n\n⚠️ Note: Please extract/unzip this .zip file on your phone first, then install the APK inside."
            }
            send_res = session.post(f"https://botapi.rubika.ir/v3/{RUBIKA_TOKEN}/sendFile", json=send_payload, timeout=30).json()
            print(f"  [OK] Sent to chat {cid}: {send_res.get('status')}")

    except Exception as e:
        print(f"[ERROR] Rubika direct upload failed: {e}")
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
