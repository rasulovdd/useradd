<h1 align="center">useradd</h1>

## Описание

Автоматизация создания пользователя в Linux

## Установка

1. Скачайте репозиторий<br/>

    ```bash
    git clone https://github.com/rasulovdd/useradd.git && cd useradd
    ```

2. Редактируйте Custom Setup, например можно добавить alias 

3. Даем права на запуск 
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
