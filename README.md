<h1 align="center">useradd</h1>

## Описание

Автоматизация создания пользователя в Linux

## Установка

1. Скачайте репозиторий<br/>

    ```bash
    git clone https://github.com/rasulovdd/useradd.git && cd useradd
    ```

2. Устанавливаем виртуальное окружение<br/>

    ```bash
    python3 -m venv env
    ```

3. Активируем её <br/>

    ```bash
    source env/bin/activate
    ```

4. Скачиваем и устанавливаем нужные библиотеки<br/>

    ```bash
    pip install -r requirements.txt
    ```

5. Создаем .env файл с вашими данными, можно создать из шаблона и просто поправить поля <br/>

    ```bash
    cp .env.sample .env
    nano .env
    ```

## Дополнительно
пример заполнения .env файла:

    bot_tokken="Токен бота"
    #пользователь c правами администратора (поменять на свой)
    admins_id="2964812"
    #статус debug режима
    debug_on=1 
