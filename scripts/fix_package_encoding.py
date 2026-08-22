import subprocess
import sys

sql = """
UPDATE course_packages 
SET 
    title = 'پکیج جامع واژگان زبان انگلیسی (504 + 1100 واژه)',
    description = 'مجموعه جامع و طلایی واژگان ضروری زبان انگلیسی شامل دو دوره پرطرفدار ۵۰۴ واژه کاملاً ضروری و ۱۱۰۰ واژه با تخفیف ویژه به همراه فایل‌های صوتی بومی و مثال‌های کاربردی.'
WHERE id = 'b1000000-0000-0000-0000-000000000001';
"""

ssh_cmd = [
    "ssh",
    "-i", r"C:\Users\Administrator\.ssh\id_rsa_deploy",
    "-o", "StrictHostKeyChecking=no",
    "root@45.94.215.188",
    "docker exec -i leitner-postgres-db psql -U leitner_admin -d leitner_db"
]

proc = subprocess.Popen(ssh_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
stdout, stderr = proc.communicate(input=sql.encode('utf-8'))

print("STDOUT:", stdout.decode('utf-8', errors='replace'))
print("STDERR:", stderr.decode('utf-8', errors='replace'))
print("Return code:", proc.returncode)
