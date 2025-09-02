#!/bin/bash

USERNAME="$1"
PUBKEY_SOURCE="$2"  # Может быть: URL, путь к файлу, или сам ключ

if [[ -z "$USERNAME" || -z "$PUBKEY_SOURCE" ]]; then
  echo "Usage: $0 <username> <pubkey_url|file_path|public_key>"
  exit 1
fi

# 1. Создание пользователя
useradd -m -s /bin/bash "$USERNAME"

# 2. Добавление в sudoers
usermod -aG sudo "$USERNAME"

# 3. Настройка SSH
HOME_DIR="/home/$USERNAME"
mkdir -p "$HOME_DIR/.ssh"
chmod 700 "$HOME_DIR/.ssh"

# Определяем тип источника ключа и обрабатываем соответствующим образом
if [[ "$PUBKEY_SOURCE" =~ ^ssh- ]]; then
  # Это сам ключ (начинается с "ssh-")
  echo "$PUBKEY_SOURCE" > "$HOME_DIR/.ssh/authorized_keys"
  echo "[+] Использован переданный публичный ключ"
  
elif [[ "$PUBKEY_SOURCE" =~ ^http ]]; then
  # Это URL
  curl -s "$PUBKEY_SOURCE" -o "$HOME_DIR/.ssh/authorized_keys"
  echo "[+] Ключ загружен по URL: $PUBKEY_SOURCE"
  
elif [[ -f "$PUBKEY_SOURCE" ]]; then
  # Это локальный файл
  cp "$PUBKEY_SOURCE" "$HOME_DIR/.ssh/authorized_keys"
  echo "[+] Ключ скопирован из файла: $PUBKEY_SOURCE"
  
else
  echo "[-] Ошибка: Не удалось определить тип источника ключа"
  echo "[-] Источник должен быть: URL, путь к файлу, или публичный ключ"
  exit 1
fi

chmod 600 "$HOME_DIR/.ssh/authorized_keys"
chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.ssh"

# 4. Aliases и welcome message
cat <<EOF >> "$HOME_DIR/.bashrc"

# --- Custom Setup ---
alias ll='ls -alF'
alias gs='git status'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

echo "Добро пожаловать, $USERNAME!"
echo "Рабочая директория: \$(pwd)"
echo "Дата: \$(date)"
EOF

chown "$USERNAME:$USERNAME" "$HOME_DIR/.bashrc"

echo "[+] Пользователь $USERNAME создан и готов к работе!"
echo "[+] SSH ключ настроен: $HOME_DIR/.ssh/authorized_keys"