#!/bin/bash

clear

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
echo "Версия: 1.2"
echo -e "\033[0m"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

require_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[1;31mОшибка: запустите скрипт от имени root (sudo ./create_user.sh)\033[0m"
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_admin_group() {
    if getent group sudo >/dev/null 2>&1; then
        echo "sudo"
        return 0
    fi

    if getent group wheel >/dev/null 2>&1; then
        echo "wheel"
        return 0
    fi

    return 1
}

check_sudo_support() {
    local admin_group
    admin_group="$(detect_admin_group)"

    if [ -z "$admin_group" ]; then
        log_warning "Не найдена группа sudo/wheel."
        log_warning "Если нужен sudo, проверь пакет sudo и настройки /etc/sudoers."
        return 1
    fi

    return 0
}

append_user_bashrc_block() {
    local username="$1"
    local home_dir="/home/$username"
    local bashrc="$home_dir/.bashrc"
    local marker_begin="# >>> RASULOVDD USERADD BLOCK BEGIN >>>"
    local marker_end="# <<< RASULOVDD USERADD BLOCK END <<<"

    touch "$bashrc"

    if grep -qF "$marker_begin" "$bashrc" 2>/dev/null; then
        log_info "Блок настроек уже есть в $bashrc, пропускаем..."
        chown "$username:$username" "$bashrc"
        return 0
    fi

    cat >> "$bashrc" <<EOF

$marker_begin
# Custom settings added by setup script on $(date '+%F %T')
# @RasulovDD

# Алиасы
alias ll='ls -alF'
alias gs='git status'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias run='tmux attach || tmux'

# Красочный PS1
if command -v tput >/dev/null 2>&1; then
    export PS1="\[\$(tput setaf 3)\]bash\[\$(tput setaf 4)\]:\[\$(tput bold)\]\[\$(tput setaf 6)\]\h\[\$(tput setaf 4)\]@\[\$(tput setaf 2)\]\u\[\$(tput setaf 4)\]:\[\$(tput setaf 5)\]\w\n\[\$(tput setaf 3)\]\\\\$ \[\$(tput sgr0)\]"

    if [[ \$(id -u) -eq 0 ]]; then
        export PS1="\[\$(tput setab 1)\]\[\$(tput setaf 7)\]Warning! You are root!\[\$(tput sgr0)\]\n\$PS1"
    fi
fi

# Настройки истории
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend
export HISTTIMEFORMAT="%F %T "

# Функция для распаковки архивов
extract() {
    for archive in "\$@"; do
        if [ -f "\$archive" ]; then
            case \$archive in
                *.tar.bz2) tar xvjf "\$archive" ;;
                *.tar.gz)  tar xvzf "\$archive" ;;
                *.bz2)     bunzip2 "\$archive" ;;
                *.rar)     rar x "\$archive" ;;
                *.gz)      gunzip "\$archive" ;;
                *.tar)     tar xvf "\$archive" ;;
                *.zip)     unzip "\$archive" ;;
                *.7z)      7z x "\$archive" ;;
                *)         echo "don't know how to extract '\$archive'..." ;;
            esac
        else
            echo "'\$archive' is not a valid file!"
        fi
    done
}

echo "Добро пожаловать, $username!"
echo "Дата: \$(date '+%F %T')"

$marker_end
EOF

    chown "$username:$username" "$bashrc"
    log_success "Базовые настройки добавлены в $bashrc"
}

create_user() {
    require_root

    local user_created=0
    local password_set=0
    local ssh_key_added=0
    local sudo_granted=0
    local username password password2 ssh_key sudo_choice admin_group
    local HOME_DIR

    read -p "Введите имя пользователя: " username

    if [ -z "$username" ]; then
        echo -e "\033[1;31m[-] Ошибка: имя пользователя не может быть пустым!\033[0m"
        return 1
    fi

    if id "$username" &>/dev/null; then
        echo -e "\033[1;31m[-] Ошибка: пользователь [$username] уже существует в системе!\033[0m"
        return 1
    fi

    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "\033[1;31m[-] Ошибка: некорректное имя пользователя. Имя должно:"
        echo -e "  - начинаться с буквы или подчёркивания"
        echo -e "  - содержать только строчные буквы, цифры, подчёркивание и дефис\033[0m"
        return 1
    fi

    read -s -p "Введите пароль: " password
    echo
    read -s -p "Подтвердите пароль: " password2
    echo

    if [ "$password" != "$password2" ]; then
        echo -e "\033[1;31m[-] Ошибка: пароли не совпадают!\033[0m"
        return 1
    fi

    if [ ${#password} -lt 3 ]; then
        echo -e "\033[1;31m[-] Ошибка: пароль слишком короткий (минимум 3 символа)!\033[0m"
        return 1
    fi

    if useradd -m -s /bin/bash -U "$username"; then
        user_created=1
        echo -e "\033[1;32m[+] Пользователь '$username' создан\033[0m"
    else
        echo -e "\033[1;31m[-] Ошибка: не удалось создать пользователя '$username'\033[0m"
        return 1
    fi

    if echo "$username:$password" | chpasswd; then
        password_set=1
        echo -e "\033[1;32m[+] Пароль установлен\033[0m"
    else
        echo -e "\033[1;31m[-] Ошибка: не удалось установить пароль\033[0m"
        userdel -r "$username" 2>/dev/null
        return 1
    fi

    HOME_DIR="/home/$username"
    mkdir -p "$HOME_DIR/.ssh"
    chmod 700 "$HOME_DIR/.ssh"

    read -p "Введите SSH-ключ (или нажмите Enter, чтобы пропустить): " ssh_key
    echo

    if [ -n "$ssh_key" ]; then
        printf '%s\n' "$ssh_key" >> "$HOME_DIR/.ssh/authorized_keys"
        chmod 600 "$HOME_DIR/.ssh/authorized_keys"
        ssh_key_added=1
        echo -e "\033[1;32m[+] SSH-ключ добавлен\033[0m"
    else
        echo -e "\033[1;33m[*] SSH-ключ не указан — пропуск\033[0m"
    fi

    chown -R "$username:$username" "$HOME_DIR/.ssh"

    read -p "Предоставить пользователю $username права sudo? [Y/n]: " sudo_choice
    echo

    if [ -z "$sudo_choice" ] || [[ "$sudo_choice" =~ ^[yY] ]]; then
        admin_group="$(detect_admin_group)"
        if [ -z "$admin_group" ]; then
            echo -e "\033[1;31m[-] Ошибка: не найдена группа sudo/wheel. Проверьте sudoers и установку sudo.\033[0m"
        else
            if usermod -aG "$admin_group" "$username"; then
                sudo_granted=1
                echo -e "\033[1;32m[+] Права sudo предоставлены через группу '$admin_group'\033[0m"
            else
                echo -e "\033[1;31m[-] Ошибка: не удалось добавить пользователя в группу '$admin_group'\033[0m"
            fi
        fi
    elif [[ "$sudo_choice" =~ ^[nN] ]]; then
        echo -e "\033[1;33m[*] Права sudo не предоставлены (выбор пользователя)\033[0m"
    else
        echo -e "\033[1;33m[*] Нераспознанный ввод ('$sudo_choice') — права sudo не предоставлены\033[0m"
    fi

    append_user_bashrc_block "$username"

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
            echo -e "\033[1;33m⁍ Права sudo не предоставлены\033[0m"
        elif [[ "$sudo_choice" =~ ^[nN] ]]; then
            echo -e "\033[1;33m⁍ Права sudo не предоставлены (явный отказ)\033[0m"
        else
            echo -e "\033[1;33m⁍ Права sudo не предоставлены (ввод: '$sudo_choice')\033[0m"
        fi
    fi

    echo -e "\033[1;44m=================================================\033[0m"

    return 0
}

delete_user() {
    require_root

    local user_exists=0
    local user_deleted=0
    local username confirm

    read -p "Введите имя пользователя для удаления: " username

    if ! id "$username" &>/dev/null; then
        echo -e "\033[1;31m[-] Ошибка: пользователь '$username' не найден в системе!\033[0m"
        return 1
    fi

    user_exists=1
    echo -e "\033[1;32m[+] Пользователь '$username' найден в системе\033[0m"

    read -p "Вы уверены, что хотите удалить пользователя '$username'? [y/N]: " confirm
    echo

    if [[ ! "$confirm" =~ ^[yY] ]]; then
        echo -e "\033[1;33m[*] Удаление пользователя '$username' отменено\033[0m"
        return 0
    fi

    if userdel "$username"; then
        user_deleted=1
        echo -e "\033[1;32m[+] Пользователь '$username' удалён из системы\033[0m"
        echo -e "\033[1;33m[*] Домашняя директория /home/$username сохранена\033[0m"
    else
        echo -e "\033[1;31m[-] Ошибка: не удалось удалить пользователя '$username'\033[0m"
        return 1
    fi

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

    return 0
}

setup_bashrc() {
    local bashrc="$HOME/.bashrc"
    local backup_file="${bashrc}.backup.$(date +%Y%m%d_%H%M%S)"
    local temp_file
    temp_file=$(mktemp)

    if [ ! -f "$bashrc" ]; then
        log_info "Файл $bashrc не найден. Создаём..."
        touch "$bashrc"
    fi

    log_info "Создаём резервную копию: $backup_file"
    cp "$bashrc" "$backup_file" || {
        log_error "Не удалось создать резервную копию"
        rm -f "$temp_file"
        return 1
    }

    cp "$bashrc" "$temp_file" || {
        log_error "Не удалось подготовить временный файл"
        rm -f "$temp_file"
        return 1
    }

    if ! grep -q "alias ll='ls -alF'" "$temp_file"; then
        log_info "Добавляем алиасы..."
        cat >> "$temp_file" <<'EOF'

# ========================================================================
# Custom settings added by setup script
# ========================================================================

# === Алиасы ===
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
EOF
    else
        log_info "Алиасы уже настроены, пропускаем..."
    fi

    if ! grep -q "alias run='tmux attach || tmux'" "$temp_file"; then
        log_info "Добавляем алиас run..."
        cat >> "$temp_file" <<'EOF'

# === Алиас RUN ===
alias run='tmux attach || tmux'
EOF
    else
        log_info "Алиас run уже настроен, пропускаем..."
    fi

    if ! grep -q "^extract()" "$temp_file"; then
        log_info "Добавляем функцию extract..."
        cat >> "$temp_file" <<'EOF'

# === Функция для распаковки архивов ===
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
                *)         echo "don't know how to extract '$archive'..." ;;
            esac
        else
            echo "'$archive' is not a valid file!"
        fi
    done
}
EOF
    else
        log_info "Функция extract уже существует, пропускаем..."
    fi

    if ! grep -q "^mkcd()" "$temp_file"; then
        log_info "Добавляем дополнительные функции..."
        cat >> "$temp_file" <<'EOF'

# === Дополнительные функции ===
mkcd() {
    mkdir -p "$1" && cd "$1"
}

ff() {
    find . -type f -iname "*$1*" 2>/dev/null
}

fd() {
    find . -type d -iname "*$1*" 2>/dev/null
}

ds() {
    du -sh "$@" 2>/dev/null | sort -h
}
EOF
    else
        log_info "Дополнительные функции уже настроены, пропускаем..."
    fi

    if ! grep -q "HISTCONTROL=ignoreboth" "$temp_file"; then
        log_info "Добавляем настройки истории..."
        cat >> "$temp_file" <<'EOF'

# === Настройки истории ===
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend
export HISTTIMEFORMAT='%F %T '
EOF
    else
        log_info "Настройки истории уже есть, пропускаем..."
    fi

    if ! grep -q "export PS1=.*tput setaf" "$temp_file"; then
        log_info "Добавляем красочный PS1..."
        cat >> "$temp_file" <<'EOF'

# === Красочный Prompt ===
if command -v tput >/dev/null 2>&1; then
    export PS1="\[$(tput setaf 3)\]bash\[$(tput setaf 4)\]:\[$(tput bold)\]\[$(tput setaf 6)\]\h\[$(tput setaf 4)\]@\[$(tput setaf 2)\]\u\[$(tput setaf 4)\]:\[$(tput setaf 5)\]\w\n\[$(tput setaf 3)\]\\$ \[$(tput sgr0)\]"

    if [[ $(id -u) -eq 0 ]]; then
        export PS1="\[$(tput setab 1)\]\[$(tput setaf 7)\]Warning! You are root!\[$(tput sgr0)\]\n$PS1"
    fi
fi
EOF
    else
        log_info "PS1 уже настроен, пропускаем..."
    fi

    if diff "$bashrc" "$temp_file" >/dev/null; then
        log_info "Изменений не требуется, всё уже настроено."
        rm -f "$temp_file"
        return 0
    fi

    if cp "$temp_file" "$bashrc"; then
        log_success "Настройки успешно применены к $bashrc"
        log_info "Резервная копия сохранена как: $backup_file"
    else
        log_error "Ошибка при записи в $bashrc"
        rm -f "$temp_file"
        return 1
    fi

    rm -f "$temp_file"

    log_info "Применяем изменения в текущей сессии..."
    # shellcheck disable=SC1090
    if source "$bashrc" 2>/dev/null; then
        log_success "Изменения применены в текущей сессии"
    else
        log_warning "Для полного применения изменений выполните: source $bashrc"
    fi

    echo
    log_success "Настройка завершена!"
    log_info "Добавлены:"
    log_info "  • Полезные алиасы (ll, la, gs, ...)"
    log_info "  • Красочный prompt (PS1)"
    log_info "  • Функция extract для архивов"
    log_info "  • Дополнительные функции (mkcd, ff, fd, ds)"
    log_info "  • Настройки истории bash"
}

while true; do
    echo -e "\033[1;34m─────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;36m          МЕНЮ управление пользователями       \033[0m"
    echo -e "\033[1;34m─────────────────────────────────────────────────\033[0m"
    echo "1. Создать пользователя"
    echo "2. Удалить пользователя"
    echo "3. Применить продвинутые настройки"
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
            echo -e "\033[1;33m→  Применить продвинутые настройки\033[0m"
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