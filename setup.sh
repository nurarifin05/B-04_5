#!/bin/bash
# ==============================================================================
# Script Setup Lab VM-05: Final CTF Corporate Password Recovery
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "[!] Dilarang menjalankan script ini tanpa akses root. Gunakan: sudo $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[+] Menginstal dependensi sistem (SQLite3, MySQL, Hashcat, OpenSSL, Python3)..."
apt-get update -qq
apt-get install -y -qq sqlite3 mysql-server hashcat openssl zip unzip python3 python3-pip python3-bcrypt python3-passlib > /dev/null

# Memastikan user student tersedia
if ! id "student" &>/dev/null; then
    echo "[+] Membuat user 'student'..."
    useradd -m -s /bin/bash student
    echo "student:student123" | chpasswd
fi

TARGET_DIR="/home/student/evidence"

echo "[+] Membuat struktur direktori dan file pengecoh di $TARGET_DIR..."
mkdir -p "$TARGET_DIR/backup"
mkdir -p "$TARGET_DIR/logs"
mkdir -p "$TARGET_DIR/documents"
mkdir -p "$TARGET_DIR/wordlists"

# 1. README.txt
cat << 'EOF' > "$TARGET_DIR/README.txt"
===================================================================
CAPSTONE CTF: CORPORATE PASSWORD RECOVERY — VM-05
===================================================================
Sistem pendeteksi ancaman menemukan indikasi aktivitas abnormal pada
beberapa server internal PT Example Corp.

Tugas Investigasi Anda:
1. Temukan seluruh artefak kredensial yang tersebar di sub-folder.
2. Filter file artefak utama dari file kecoh (decoy).
3. Analisis dokumen 'password_policy.txt' di folder documents/.
4. Pecahkan hash kredensial utama dan korelasikan dengan log autentikasi.
5. Gunakan kata sandi akun administrator untuk membuka 'final_flag.enc'.
===================================================================
EOF

# 2. File Pengecoh (Decoy Files)
cat << 'EOF' > "$TARGET_DIR/server_notes.txt"
Catatan Perawatan Server:
- Rutin lakukan pembersihan direktori /tmp setiap minggu.
- Server backup otomatis menyinkronkan folder setiap pukul 02:00 WIB.
EOF

cat << 'EOF' > "$TARGET_DIR/logs/application.log"
2026-03-01 08:00:12 [INFO] ERP Service started successfully.
2026-03-01 08:15:00 [INFO] Scheduled database maintenance completed.
2026-03-01 09:30:22 [INFO] Health check status: OK.
EOF

cat << 'EOF' > "$TARGET_DIR/documents/migration_notes.txt"
Catatan Migrasi Sistem 2026:
- Akun lama pada server legacy diarsipkan ke dalam database SQLite.
- Akun produksi aktif menggunakan tabel pengguna utama di database SQL.
EOF

# 3. Documents: password_policy.txt
cat << 'EOF' > "$TARGET_DIR/documents/password_policy.txt"
KEBIJAKAN KATA SANDI PT EXAMPLE CORP (2026)
-------------------------------------------------------------------
1. Panjang minimal: 8 Karakter.
2. Wajib memuat nama organisasi: 'Example' atau 'example'.
3. Wajib memuat angka tahun berjalan: '2026'.
4. Wajib diakhiri simbol karakter khusus: '!'.

Contoh Format: Example + Tahun + Simbol (misal: Example2026!)
-------------------------------------------------------------------
EOF

# 4. Logs: authentication.log (Sangat Penting untuk Korelasi)
cat << 'EOF' > "$TARGET_DIR/logs/authentication.log"
2026-03-01 10:05:12 [SUCCESS] User 'administrator' logged in from 192.168.1.10
2026-03-01 10:12:00 [SUCCESS] User 'legacy_admin' logged in from 10.0.0.5
2026-03-01 10:15:33 [FAILED] User 'guest_user' failed login attempt from 10.0.0.99
2026-03-01 10:20:01 [SUCCESS] User 'user_txt_01' logged in from 192.168.1.15
EOF

# 5. Wordlist Dasar
cat << 'EOF' > "$TARGET_DIR/wordlists/company_words.txt"
example
Example
EXAMPLE
legacy
Legacy
welcome
EOF

# 6. Generator Hash Menggunakan Python & Passlib
echo "[+] Membangkitkan artefak hash dan basis data..."
python3 -c "
import hashlib, sqlite3, passlib.hash

# Passwords:
# 1. administrator : Example2026! (SHA-512 Crypt $6$)
# 2. legacy_admin  : Legacy2026!  (SHA-1)
# 3. user_txt_01   : example123   (MD5)
# 4. user_txt_02   : Welcome2026! (SHA-256)

admin_hash = passlib.hash.sha512_crypt.hash('Example2026!', salt='salttest')
legacy_hash = hashlib.sha1(b'Legacy2026!').hexdigest()
md5_p1 = hashlib.md5(b'example123').hexdigest()
sha256_p2 = hashlib.sha256(b'Welcome2026!').hexdigest()

# File 1: backup/credentials.txt
with open('$TARGET_DIR/backup/credentials.txt', 'w') as f:
    f.write(f'user_txt_01:{md5_p1}\n')
    f.write(f'user_txt_02:{sha256_p2}\n')

# File 2: backup/users.sql
with open('$TARGET_DIR/backup/users.sql', 'w') as f:
    f.write('-- Dump User Production\n')
    f.write('CREATE TABLE users (id INT, username VARCHAR(50), password_hash VARCHAR(255));\n')
    f.write(f\"INSERT INTO users VALUES (1, 'administrator', '{admin_hash}');\n\")

# File 3: backup/old_users.db
conn = sqlite3.connect('$TARGET_DIR/backup/old_users.db')
cur = conn.cursor()
cur.execute('CREATE TABLE legacy_accounts (id INT, username TEXT, hash TEXT)')
cur.execute('INSERT INTO legacy_accounts VALUES (1, \"legacy_admin\", ?)', (legacy_hash,))
conn.commit()
conn.close()
"

# 7. Membikin file terenkripsi Capstone Flag
echo "FLAG{CORPORATE_PASSWORD_RECOVERY_CAPSTONE_SOLVED_2026}" | openssl enc -aes-256-cbc -pbkdf2 -out "$TARGET_DIR/final_flag.enc" -k "Example2026!" 2>/dev/null

# Hak akses direktori
chown -R student:student /home/student
chmod -R 755 "$TARGET_DIR"

echo "==================================================================="
echo "[+] Setup Lab Capstone VM-05 Selesai!"
echo "==================================================================="
