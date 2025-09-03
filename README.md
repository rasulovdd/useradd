<h1 align="center">useradd</h1>

## Описание

Автоматизация создания пользователя в Linux

## Установка

1. Скачайте репозиторий<br/>

    ```bash
    git clone https://github.com/rasulovdd/useradd.git && cd useradd
    ```

2. Редактируйте Custom Setup, находим кусок кода в create_user.sh и добавляем все что вам нужно
   
    ```bash
    # 4. Aliases и welcome message
    cat <<EOF >> "$HOME_DIR/.bashrc"
    
    # --- Custom Setup ---
    alias ll='ls -alF'
    alias gs='git status'
    alias grep='grep --color=auto'
    alias egrep='egrep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias dclogs='docker compose logs'
    
    echo "Добро пожаловать, $USERNAME!"
    echo "Рабочая директория: \$(pwd)"
    echo "Дата: \$(date)"
    EOF
    ```
    
4. Даем права на запуск 
    ```bash
    chmod +x create_user.sh
    ```
    
3. запускайте)

## Пример использования:

1. С URL, если у вас pub ключ опубликован в интернете 
    ```bash
    ./create_user.sh dev1 https://example.com/dev1.pub
    ```

2. С путем к файлу, если у вас pub ключ в файле
    ```bash
    ./create_user.sh admin1 ~/.ssh/id_rsa.pub
    ```

3. С самим ключом
    ```bash
    ./create_user.sh user2 "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD... user@host"
    ```
