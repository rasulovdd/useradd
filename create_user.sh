#!/bin/bash
# Очистка терминала перед выводом
clear

# Вывод шапки с информацией о проекте
echo -e "\033[1;36m"
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ ██████╗  █████╗ ███████╗██╗   ██╗██╗      ██████╗ ██╗   ██╗██████╗ ██████╗  │"
echo "│ ██╔══██╗██╔══██╗██╔════╝██║   ██║██║     ██╔═══██╗██║   ██║██╔══██╗██╔══██╗ │"
echo "│ ██████╔╝███████║███████╗██║   ██║██║     ██║   ██║██║   ██║██║  ██║██║  ██║ │"
echo "│ ██╔══██╗██╔══██║╚════██║██║   ██║██║     ██║   ██║╚██╗ ██╔╝██║  ██║██║  ██║ │"
echo "│ ██║  ██║██║  ██║███████║╚██████╔╝███████╗╚██████╔╝ ╚████╔╝ ██████╔╝██████╔╝ │"
echo "│ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝   ╚═══╝  ╚═════╝ ╚═════╝  │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo "useradd by rasulovdd"
echo "Проект: https://github.com/rasulovdd/useradd"
echo "Контакты: @RasulovDD"
echo "Версия: 1.1"

# Проверка, запущен ли скрипт от root
#if [ "$EUID" -ne 0 ]; then
#    echo -e "\033[1;31mОшибка: запустите скрипт от имени root (sudo ./create_user.sh)\033[0m"
#    exit 1
#fi

# Функция: создать обычного пользователя
create_user() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[1;31mОшибка: запустите скрипт от имени root (sudo ./create_user.sh)\033[0m"
        exit 1
    fi

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
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "\033[1;31m[-] Ошибка: некорректное имя пользователя. Имя должно:"
        echo -e "  - начинаться с буквы или подчёркивания"
        echo -e "  - содержать только строчные буквы, цифры, подчёркивание и дефис\033[0m"
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

    # Проверка длины пароля
    if [ ${#password} -lt 3 ]; then
        echo -e "\033[1;31m[-] Ошибка: пароль слишком короткий (минимум 3 символа)!\033[0m"
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
        ssh_key_added=1
        echo -e "\033[1;32m[+] SSH-ключ добавлен\033[0m"
    else
        echo -e "\033[1;33m[*] SSH-ключ не указан — пропуск\033[0m"
    fi

    # ВАЖНО: устанавливаем правильного владельца для всей SSH директории
    chown -R "$username":"$username" "$HOME_DIR/.ssh"

    # Предоставление sudo-прав (Enter или Y/y/yes = да; N/n/no = нет)
    read -p "Предоставить пользователю $username права sudo? [Y/n]: " sudo_choice
    echo

    # Если ввод пустой (Enter) или начинается с Y/y — считаем за "да"
    if [ -z "$sudo_choice" ] || [[ "$sudo_choice" =~ ^[yY] ]]; then
        if usermod -aG sudo "$username"; then
            sudo_granted=1
            echo -e "\033[1;32m[+] Права sudo предоставлены\033[0m"
        else
            echo -e "\033[1;31m[-] Ошибка: не удалось добавить в группу sudo\033[0m"
        fi
    # Если введено N/n/no — не предоставляем
    elif [[ "$sudo_choice" =~ ^[nN] ]]; then
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
        elif [[ "$sudo_choice" =~ ^[nN] ]]; then
            echo -e "\033[1;33m⁍ Права sudo не предоставлены (явный отказ)\033[0m"
        else
            echo -e "\033[1;33m⁍ Права sudo не предоставлены (ввод: '$sudo_choice')\033[0m"
        fi
    fi

    echo -e "\033[1;44m=================================================\033[0m"

    # Записываем всё в .bashrc
    cat <<'EOF' >> "$HOME_DIR/.bashrc"

# --- Custom Setup ---

# Алиасы 
alias ll='ls -alF'
alias gs='git status'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Красочный PS1
export PS1="\[$(tput setaf 3)\]bash\[$(tput setaf 4)\]:\[$(tput bold)\]\[$(tput setaf 6)\]\h\[$(tput setaf 4)\]@\[$(tput setaf 2)\]\u\[$(tput setaf 4)\]:\[$(tput setaf 5)\]\w\n\[$(tput setaf 3)\]\\$ \[$(tput sgr0)\]"

# Предупреждение для root
if [[ $(id -u) -eq 0 ]]; then
    export PS1="\[$(tput setab 1)\]Warning! You are root!\[$(tput sgr0)\]\n$PS1"
fi

# Предупреждение для root v2
#if [[ $(id -u) -eq 0 ]]; then
#    local red_bg=$(tput setab 1)
#    local white_fg=$(tput setaf 7)
#    local reset=$(tput sgr0)
#    export PS1="\[${red_bg}${white_fg}\]Warning! You are root!\[${reset}\]\n$PS1"
#fi

# Функция для распаковки архивов
extract() {
 for archive in "$@"; do
  if [ -f "$archive" ]; then
   case $archive in
    *.tar.bz2) tar xvjf $archive ;;
    *.tar.gz) tar xvzf $archive ;;
    *.bz2) bunzip2 $archive ;;
    *.rar) rar x $archive ;;
    *.gz) gunzip $archive ;;
    *.tar) tar xvf $archive ;;
    *.zip) unzip $archive ;;
    *.7z) 7z x $archive ;;
    *) echo "don't know how to extract '$archive'..." ;;
   esac
  else
   echo "'$archive' is not a valid file!"
  fi
 done
}

# Приветственное сообщение при входе
echo "Добро пожаловать, $username!"
echo "Рабочая директория: $(pwd)"
echo "Дата: $(date)"
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
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[1;31mОшибка: запустите скрипт от имени root (sudo ./create_user.sh)\033[0m"
        exit 1
    fi
    # Флаги для отслеживания этапов
    local user_exists=0
    local user_deleted=0

    # Запрос имени пользователя
    read -p "Введите имя пользователя для удаления: " username

    # Проверка существования пользователя
    if ! id "$username" &>/dev/null; then
        echo -e "\033[1;31m[-] Ошибка: пользователь '$username' не найден в системе!\033[0m"
        return 1
    fi
    user_exists=1
    echo -e "\033[1;32m[+] Пользователь '$username' найден в системе\033[0m"

    # Подтверждение удаления
    read -p "Вы уверены, что хотите удалить пользователя '$username'? [y/N]: " confirm
    echo

    if [[ ! "$confirm" =~ ^[yY] ]]; then
        echo -e "\033[1;33m[*] Удаление пользователя '$username' отменено\033[0m"
        return 0
    fi

    # Удаление пользователя БЕЗ домашней директории
    if userdel "$username"; then
        user_deleted=1
        echo -e "\033[1;32m[+] Пользователь '$username' удалён из системы\033[0m"
        echo -e "\033[1;33m[*] Домашняя директория /home/$username сохранена\033[0m"
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
        echo -e "\033[1;33m⁍ Домашняя директория /home/$username сохранена\033[0m"
    else
        echo -e "\033[1;31m✗ Не удалось удалить пользователя\033[0m"
    fi

    echo -e "\033[1;44m=================================================\033[0m"

    # Итоговый статус
    if [ $user_deleted -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

setup_bashrc() {
    local bashrc="$HOME/.bashrc"
    local backup_file="${bashrc}.backup.$(date +%Y%m%d_%H%M%S)"
    local temp_file=$(mktemp)
    
    # Цвета для вывода
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local BLUE='\033[0;34m'
    local NC='\033[0m' # No Color

    # Функция для вывода сообщений
    log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
    log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
    log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
    log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

    # Проверяем, существует ли .bashrc
    if [ ! -f "$bashrc" ]; then
        log_info "Файл $bashrc не найден. Создаём..."
        touch "$bashrc"
    fi

    # Создаём резервную копию
    log_info "Создаём резервную копию: $backup_file"
    cp "$bashrc" "$backup_file"

    # Копируем содержимое в временный файл
    cp "$bashrc" "$temp_file"

    # Добавляем разделитель если файл не пустой
    if [ -s "$temp_file" ]; then
        echo "" >> "$temp_file"
        echo "# ========================================================================" >> "$temp_file"
        echo "# Custom settings added by setup script on $(date)" >> "$temp_file"
        echo "# ========================================================================" >> "$temp_file"
        echo "" >> "$temp_file"
    fi

    # 1. Добавляем алиасы (если их ещё нет)
    if ! grep -q "alias ll='ls -alF'" "$temp_file"; then
        log_info "Добавляем алиасы..."
        echo "# === Алиасы ===" >> "$temp_file"
        echo "alias ll='ls -alF'" >> "$temp_file"
        echo "alias la='ls -A'" >> "$temp_file"
        echo "alias l='ls -CF'" >> "$temp_file"
        echo "alias gs='git status'" >> "$temp_file"
        echo "alias grep='grep --color=auto'" >> "$temp_file"
        echo "alias egrep='egrep --color=auto'" >> "$temp_file"
        echo "alias fgrep='fgrep --color=auto'" >> "$temp_file"
        echo "alias ..='cd ..'" >> "$temp_file"
        echo "alias ...='cd ../..'" >> "$temp_file"
        echo "" >> "$temp_file"
    else
        log_info "Алиасы уже настроены, пропускаем..."
    fi

    # 2. Добавляем красочный PS1 (если его ещё нет)
    if ! grep -q "export PS1=.*tput setaf" "$temp_file"; then
        log_info "Добавляем красочный PS1..."
        echo "# === Красочный Prompt ===" >> "$temp_file"
        
        # Основной PS1
        cat >> "$temp_file" << 'EOF'
export PS1="\[$(tput setaf 3)\]bash\[$(tput setaf 4)\]:\[$(tput bold)\]\[$(tput setaf 6)\]\h\[$(tput setaf 4)\]@\[$(tput setaf 2)\]\u\[$(tput setaf 4)\]:\[$(tput setaf 5)\]\w\n\[$(tput setaf 3)\]\\$ \[$(tput sgr0)\]"

# Предупреждение для root
if [[ $(id -u) -eq 0 ]]; then
    export PS1="\[$(tput setab 1)\]\[$(tput setaf 7)\]Warning! You are root!\[$(tput sgr0)\]\n$PS1"
fi

EOF
    else
        log_info "PS1 уже настроен, пропускаем..."
    fi

    # 3. Добавляем функцию extract (если её ещё нет)
    if ! grep -q "^extract()" "$temp_file"; then
        log_info "Добавляем функцию extract..."
        echo "# === Функция для распаковки архивов ===" >> "$temp_file"
        cat >> "$temp_file" << 'EOF'
extract() {
 for archive in "$@"; do
  if [ -f "$archive" ]; then
   case $archive in
    *.tar.bz2) tar xvjf $archive ;;
    *.tar.gz) tar xvzf $archive ;;
    *.bz2) bunzip2 $archive ;;
    *.rar) rar x $archive ;;
    *.gz) gunzip $archive ;;
    *.tar) tar xvf $archive ;;
    *.zip) unzip $archive ;;
    *.7z) 7z x $archive ;;
    *) echo "don't know how to extract '$archive'..." ;;
   esac
  else
   echo "'$archive' is not a valid file!"
  fi
 done
}
EOF
        echo "" >> "$temp_file"
    else
        log_info "Функция extract уже существует, пропускаем..."
    fi

    # 4. Добавляем полезные функции (если их ещё нет)
    if ! grep -q "^mkcd()" "$temp_file"; then
        log_info "Добавляем дополнительные функции..."
        echo "# === Дополнительные функции ===" >> "$temp_file"
        cat >> "$temp_file" << 'EOF'
# Создать директорию и перейти в неё
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Найти файл по имени
ff() {
    find . -type f -iname "*$1*" 2>/dev/null
}

# Найти директорию по имени
fd() {
    find . -type d -iname "*$1*" 2>/dev/null
}

# Показать размер файлов и директорий
ds() {
    du -sh "$@" 2>/dev/null | sort -h
}

EOF
    fi

    # 5. Добавляем настройки безопасности
    if ! grep -q "HISTCONTROL" "$temp_file"; then
        log_info "Добавляем настройки истории..."
        echo "# === Настройки истории ===" >> "$temp_file"
        echo "HISTCONTROL=ignoreboth" >> "$temp_file"
        echo "HISTSIZE=1000" >> "$temp_file"
        echo "HISTFILESIZE=2000" >> "$temp_file"
        echo "shopt -s histappend" >> "$temp_file"
        echo "" >> "$temp_file"
    fi

    # Проверяем изменения
    if diff "$bashrc" "$temp_file" > /dev/null; then
        log_info "Изменений не требуется, всё уже настроено."
        rm -f "$temp_file" "$backup_file"
        return 0
    fi

    # Копируем обратно в .bashrc
    if cp "$temp_file" "$bashrc"; then
        log_success "Настройки успешно применены к $bashrc"
        log_info "Резервная копия сохранена как: $backup_file"
    else
        log_error "Ошибка при записи в $bashrc"
        rm -f "$temp_file"
        return 1
    fi

    # Очистка временного файла
    rm -f "$temp_file"

    # Применяем изменения в текущей сессии
    log_info "Применяем изменения в текущей сессии..."
    if source "$bashrc" 2>/dev/null; then
        log_success "Изменения применены в текущей сессии"
    else
        log_warning "Для полного применения изменений выполните: source $bashrc"
    fi

    # Показываем summary
    echo
    log_success "Настройка завершена!"
    log_info "Добавлены:"
    log_info "  • Полезные алиасы (ll, la, gs, ...)"
    log_info "  • Красочный prompt (PS1)"
    log_info "  • Функция extract для архивов"
    log_info "  • Дополнительные функции (mkcd, ff, fd)"
    log_info "  • Настройки истории bash"
}



# Главное меню
while true; do
    echo -e "\033[1;34m─────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;36m          МЕНЮ управление пользователями       \033[0m"
    echo -e "\033[1;34m─────────────────────────────────────────────────\033[0m"
    echo "1. Создать пользователя"
    echo "2. Удалить пользователя"
    echo "3. Применить стандартные настройки"
    echo -e "\033[1;31m0. Выход\033[0m"
    echo -e "\033[1;34m─────────────────────────────────────────────────\033[0m"

    read -p "Выберите действие [0-3]: " choice

    case $choice in
        1)
            echo -e "\033[1;33m→  Создание пользователя\033[0m"
            create_user
            ;;
        2)
            echo -e "\033[1;33m→  Удаление пользователя\033[0m"
            delete_user
            ;;
        3)
            echo -e "\033[1;33m→  Применить стандартные настройки\033[0m"
            setup_bashrc
            ;;
        0)
            echo -e "\033[1;32mДо свидания!\033[0m"
            break
            ;;
        *)
            echo -e "\033[1;31m[-] Неверный выбор. Введите 0, 1, 2 или 3.\033[0m"
            ;;
    esac
    echo ""
done
