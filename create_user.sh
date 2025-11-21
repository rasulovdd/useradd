#!/bin/bash
# Очистка терминала перед выводом
clear

# Вывод шапки с информацией о проекте
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ ██████╗  █████╗ ███████╗██╗   ██╗██╗      ██████╗ ██╗   ██╗██████╗ ██████╗  │"
echo "│ ██╔══██╗██╔══██╗██╔════╝██║   ██║██║     ██╔═══██╗██║   ██║██╔══██╗██╔══██╗ │"
echo "│ ██████╔╝███████║███████╗██║   ██║██║     ██║   ██║██║   ██║██║  ██║██║  ██║ │"
echo "│ ██╔══██╗██╔══██║╚════██║██║   ██║██║     ██║   ██║╚██╗ ██╔╝██║  ██║██║  ██║ │"
echo "│ ██║  ██║██║  ██║███████║╚██████╔╝███████╗╚██████╔╝ ╚████╔╝ ██████╔╝██████╔╝ │"
echo "│ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝   ╚═══╝  ╚═════╝ ╚═════╝  │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo ""
# echo "───────────────────────────────────────────────────────────────────────────────"
echo "useradd by rasulovdd"
echo "Проект: https://github.com/rasulovdd/useradd"
echo "Контакты: @RasulovDD"
echo "Версия: 1.1"
echo "─────────────────────────────────────────────────"
echo ""

# Проверка, запущен ли скрипт от root
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31mОшибка: запустите скрипт от имени root (sudo ./create_user.sh)\033[0m"
    exit 1
fi

# Функция: создать обычного пользователя
create_user() {
    # Флаг для отслеживания этапов
    local user_created=0
    local password_set=0
    local ssh_key_added=0
    local sudo_granted=0

    # Запрос имени пользователя
    read -p "Введите имя пользователя: " username

    # Проверка, существует ли пользователь
    if id "$username" &>/dev/null; then
        echo -e "\033[1;31m[-] Ошибка: пользователь [$username] уже существует в системе!\033[0m"
        return 1
    fi

    # Проверка корректности имени пользователя
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        echo -e "\033[1;31m[-] Ошибка: некорректное имя пользователя. Имя должно:"
        echo -e "  - начинаться с буквы или подчёркивания"
        echo -e "  - содержать только строчные буквы, цифры, подчёркивание и дефис"
        echo -e "  - не заканчиваться дефисом\033[0m"
        return 1
    fi

    # Ввод пароля
    read -s -p "Введите пароль: " password
    echo
    read -s -p "Подтвердите пароль: " password2
    echo

    # Проверка совпадения паролей
    if [ "$password" != "$password2" ]; then
        echo -e "\033[1;31m[-] Ошибка: пароли не совпадают!\033[0m"
        return 1
    fi

    # Создание пользователя
    if useradd -m -s /bin/bash "$username"; then
        user_created=1
        echo -e "\033[1;32m[+] Пользователь '$username' создан\033[0m"
    else
        echo -e "\033[1;31m[-] Ошибка: не удалось создать пользователя '$username'\033[0m"
        return 1
    fi

    # Установка пароля
    if echo "$username:$password" | chpasswd; then
        password_set=1
        echo -e "\033[1;32m[+] Пароль установлен\033[0m"
    else
        echo -e "\033[1;31m[-] Ошибка: не удалось установить пароль\033[0m"
        userdel -r "$username" 2>/dev/null
        return 1
    fi

    # Настройка SSH
    HOME_DIR="/home/$username"
    mkdir -p "$HOME_DIR/.ssh"
    chmod 700 "$HOME_DIR/.ssh"

    # Запрос SSH-ключа
    read -p "Введите SSH-ключ (или нажмите Enter, чтобы пропустить): " ssh_key
    echo

    if [ -n "$ssh_key" ]; then
        echo "$ssh_key" >> "$HOME_DIR/.ssh/authorized_keys"
        chmod 600 "$HOME_DIR/.ssh/authorized_keys"
        chown "$username":"$username" "$HOME_DIR/.ssh/authorized_keys"
        ssh_key_added=1
        echo -e "\033[1;32m[+] SSH-ключ добавлен\033[0m"
    else
        echo -e "\033[1;33m[*] SSH-ключ не указан — пропуск\033[0m"
    fi

    # Предоставление sudo-прав (Enter или Y/y/yes = да; N/n/no = нет)
    read -p "Предоставить пользователю $username права sudo? [Y/n]: " sudo_choice
    echo

    # Если ввод пустой (Enter) или начинается с Y/y — считаем за "да"
    if [ -z "$sudo_choice" ] || [[ "$sudo_choice" =~ ^[yY][eE]?[sS]?$ ]]; then
        if usermod -aG sudo "$username"; then
            sudo_granted=1
            echo -e "\033[1;32m[+] Права sudo предоставлены\033[0m"
        else
            echo -e "\033[1;31m[-] Ошибка: не удалось добавить в группу sudo\033[0m"
        fi
    # Если введено N/n/no/NO — не предоставляем
    elif [[ "$sudo_choice" =~ ^[nN][oO]?$ ]]; then
        echo -e "\033[1;33m[*] Права sudo не предоставлены (выбор пользователя)\033[0m"
    # Любой другой ввод — тоже считаем за отказ (с пояснением)
    else
        echo -e "\033[1;33m[*] Нераспознанный ввод ('$sudo_choice') — права sudo не предоставлены\033[0m"
    fi

    # Финальный сводный отчёт
    echo
    echo -e "\033[1;44m====================== ИТОГ =====================\033[0m"
    if [ $user_created -eq 1 ]; then
        echo -e "\033[1;32m✓ Пользователь '$username' успешно создан\033[0m"
    else
        echo -e "\033[1;31m✗ Пользователь НЕ создан\033[0m"
    fi

    if [ $password_set -eq 1 ]; then
        echo -e "\033[1;32m✓ Пароль установлен\033[0m"
    else
        echo -e "\033[1;31m✗ Пароль НЕ установлен\033[0m"
    fi

    if [ $ssh_key_added -eq 1 ]; then
        echo -e "\033[1;32m✓ SSH-ключ добавлен\033[0m"
    else
        echo -e "\033[1;33m⁍ SSH-ключ не добавлен\033[0m"
    fi

    if [ $sudo_granted -eq 1 ]; then
        echo -e "\033[1;32m✓ Права sudo предоставлены\033[0m"
    else
        if [ -z "$sudo_choice" ]; then
            echo -e "\033[1;31m✗ Не удалось предоставить права sudo (по умолчанию)\033[0m"
        elif [[ "$sudo_choice" =~ ^[nN][oO]?$ ]]; then
            echo -e "\033[1;33m⁍ Права sudo не предоставлены (явный отказ)\033[0m"
        else
            echo -e "\033[1;33m⁍ Права sudo не предоставлены (ввод: '$sudo_choice')\033[0m"
        fi
    fi

    echo -e "\033[1;44m=================================================\033[0m"

    # Записываем всё в .bashrc
    cat <<EOF >> "$HOME_DIR/.bashrc"

    # --- Custom Setup ---

    # Алиасы 
    alias ll='ls -alF'
    alias gs='git status'
    alias grep='grep --color=auto'
    alias egrep='egrep --color=auto'
    alias fgrep='fgrep --color=auto'

    # Красочный PS1
    export PS1="\[$(tput setaf 3)\]bash\[$(tput setaf 4)\]:\[$(tput bold)\]\[$(tput setaf 6)\]\h\[$(tput setaf 4)\]@\[$(tput setaf 2)\]\u\[$(tput setaf 4)\]:\[$(tput setaf 5)\]\w\n\[$(tput setaf 3)\]\\$ \[$(tput sgr0)\]"

    # Если пользователь — root, добавляем предупреждение
    if [[ $(id -u) -eq 0 ]]; then
        export PS1="\[$(tput setab 1)\]Warning! You are root!\[$(tput sgr0)\]\n$PS1"
    fi

    # Функция для распаковки архивов
    extract() {
        for archive in "$@"; do
            if [ -f "$archive" ]; then
                case $archive in
                    *.tar.bz2) tar xvjf "$archive" ;;
                    *.tar.gz)  tar xvzf "$archive" ;;
                    *.bz2)     bunzip2 "$archive" ;;
                    *.rar)     rar x "$archive" ;;
                    *.gz)      gunzip "$archive" ;;
                    *.tar)     tar xvf "$archive" ;;
                    *.zip)     unzip "$archive" ;;
                    *.7z)      7z x "$archive" ;;
                    *)         echo "Don't know how to extract '$archive'..." ;;
                esac
            else
                echo "'$archive' is not a valid file!"
            fi
        done
    }

    # Приветственное сообщение при входе
    echo "Добро пожаловать, $username!"
    echo "Рабочая директория: \$(pwd)"
    echo "Дата: \$(date)"
    EOF

    # Устанавливаем владельца файла — пользователь, а не root
    chown "$username:$username" "$HOME_DIR/.bashrc"

    # Итоговый статус
    if [ $user_created -eq 1 ] && [ $password_set -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

delete_user() {
    # Флаги для отслеживания этапов
    local user_exists=0
    local user_deleted=0
    local home_dir_removed=0

    # Запрос имени пользователя
    read -p "Введите имя пользователя для удаления: " username

    # Проверка существования пользователя
    if ! id "$username" &>/dev/null; then
        echo -e "\033[1;31m[-] Ошибка: пользователь '$username' не найден в системе!\033[0m"
        return 1
    fi
    user_exists=1
    echo -e "\033[1;32m[+] Пользователь '$username' найден в системе\033[0m"

    # Запрос на удаление домашней папки (по умолчанию — оставить)
    read -p "Удалить домашнюю папку пользователя (/home/$username)? [n/Y]: " remove_home
    echo

    # Логика обработки ввода:
    # - пустой ввод или 'n'/'no' → не удалять папку
    # - 'y'/'yes' → удалить папку
    if [ -z "$remove_home" ] || [[ "$remove_home" =~ ^[nN][oO]?$ ]]; then
        echo -e "\033[1;33m[*] Домашняя папка будет сохранена\033[0m"
    elif [[ "$remove_home" =~ ^[yY][eE]?[sS]?$ ]]; then
        if rm -rf "/home/$username"; then
            home_dir_removed=1
            echo -e "\033[1;32m[+] Домашняя папка /home/$username удалена\033[0m"
        else
            echo -e "\033[1;31m[-] Ошибка: не удалось удалить домашнюю папку /home/$username\033[0m"
        fi
    else
        echo -e "\033[1;33m[*] Нераспознанный ввод ('$remove_home') — домашняя папка сохранена\033[0m"
    fi

    # Удаление пользователя
    if userdel "$username"; then
        user_deleted=1
        echo -e "\033[1;32m[+] Пользователь '$username' удалён из системы\033[0m"
    else
        echo -e "\033[1;31m[-] Ошибка: не удалось удалить пользователя '$username'\033[0m"
        return 1
    fi

    # Финальный сводный отчёт
    echo
    echo -e "\033[1;44m====================== ИТОГ =====================\033[0m"
    if [ $user_exists -eq 1 ]; then
        echo -e "\033[1;32m✓ Пользователь '$username' присутствовал в системе\033[0m"
    else
        echo -e "\033[1;31m✗ Пользователь '$username' не найден\033[0m"
    fi

    if [ $user_deleted -eq 1 ]; then
        echo -e "\033[1;32m✓ Пользователь успешно удалён\033[0m"
    else
        echo -e "\033[1;31m✗ Не удалось удалить пользователя\033[0m"
    fi

    if [ $home_dir_removed -eq 1 ]; then
        echo -e "\033[1;32m✓ Домашняя папка /home/$username удалена\033[0m"
    else
        echo -e "\033[1;33m⁍ Домашняя папка /home/$username сохранена\033[0m"
    fi

    echo -e "\033[1;44m=================================================\033[0m"

    # Итоговый статус
    if [ $user_deleted -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

# --- Custom Setup ---
alias ll='ls -alF'
alias gs='git status'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias dclogs='docker compose logs'

# Главное меню
while true; do
    echo -e "\033[1;34м─────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;36м          МЕНЮ управление пользователями       \033[0m"
    echo -e "\033[1;34м─────────────────────────────────────────────────\033[0m"
    echo "1. Создать пользователя"
    echo "2. Удалить пользователя"
    echo -e "\033[1;31m0. Выход\033[0m"
    echo -e "\033[1;34м─────────────────────────────────────────────────\033[0m"

    read -p "Выберите действие [0-2]: " choice

echo "[+] Пользователь $USERNAME создан и готов к работе!"
echo "[+] SSH ключ настроен: $HOME_DIR/.ssh/authorized_keys"
