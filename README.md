# Lab 305

## Запуск приложения
Алгоритм установки и запуска приложения:
1. Скачать репозиторий с GitHub;
2. Скачать актуальную версию фреймворков:
    * Bootstrap (доступ: https://getbootstrap.com/docs/5.3/getting-started/download/);
    * Swiper (доступ: https://www.jsdelivr.com/package/npm/swiper);
3. В папку frontend/assets/css поместить файлы bootstrap.min.css и swiper-bundle.min.css;
4. В папку frontend/assets/js поместить файлы bootstrap.bundle.min.js и swiper-bundle.min.js;
5. Открыть в терминале папку backend командой: 
```bash
cd backend
```
6. Запустить приложение командой: 
```bash
fastapi dev main.py
```


## Структура проекта
Файловая структура проекта:
```text
lab305
|-- backend
|   |-- ...
|   |-- main.py
|-- frontend
    |-- assets
    |   |-- ccs
    |   |   |-- bootstrap.min.css
    |   |   |-- style.css
    |   |   |-- swiper-bundle.min.css
    |   |-- images
    |   |   |-- ...
    |   |-- js
    |   |   |-- bootstrap.bundle.min.js
    |   |   |-- swiper-bundle.min.js
    |-- pages
        |-- index.html
```


## Логика маршрутизации пользователей
Логика маршрутизации пользователя:
* Страница index.html открывается по умолчанию, доступна всем пользователям.
* Страница rules.html может быть открыта по прямой ссылке или по кнопке в index.html.
* Страница admin.html:
    * Если пользователь не авторизован: страница не загружается, открывается плашка с требованиемм логина и пароля. При корректном вводе загружается защищённая область страницы.
    * Если пользователь авторизован: открывается защищённая оласть страницы с доступом к скриптам.


## Используемые внешние ресурсы
### Используемые технологии и фреймворки
* Frontend:
    1. Bootstrap v5.3.8 (доступ: https://getbootstrap.com/docs/5.3/getting-started/download/);
    2. Swiper v14.3.0 (доступ: https://www.jsdelivr.com/package/npm/swiper);
* Backend:
    1. Phyton v3.15.1
    2. Python Fast

### Используемые изображения
* Логотип VLC Media Player (доступ: https://www.svgrepo.com/svg/424917/vlc-logo-player)
* Логотип Gitea (доступ: https://upload.wikimedia.org/wikipedia/commons/b/bb/Gitea_Logo.svg)
* Логотип DevDocs (доступ: https://github.com/freeCodeCamp/devdocs/blob/main/public/images/webkit-mask-icon.svg)
* Логотип Proget (доступ: https://inedo.com/wp-content/uploads/2021/02/proget-icon.svg)
* Логотип файлового сервера (доступ: https://uxwing.com/database-server-icon)


## Алгоритм добавления новой карточки
### Правки в HTML
В файле index.html, в блок .swiper-wrapper добавить шаблон:
```html
<div class="swiper-slide">
    <a class="card h-100 shadow-sm text-decoration-none" id="card__ID" href="#">
        <div class="card-body text-center">
            <div class="circle">
                <img class="logo img-thumbnail rounded-circle" src="../assets/images/" alt="">
            </div>
            <p>НАЗВАНИЕ</p>
        </div> 
    </a>
</div>
```
### Правки в CSS
В файле style.css (путь: ../assets/css/style.css) добавить код вида:
```css
#card__ID {
    background-color: #cecece;      /* Цвет карточки */
    --card-shadow-color: #cecece80; /* Цвет карточки с прозрачностью = 50% */
}
```
## Настройка прокрутки карточек
Если необходимо изменить колличество отображаемых на странице карточек, в файле index.html в скрипт слайдера.
Вы можете внести изменеие в строку
```js
1200: {
    slidesPerView: ВАШЕ_ЧИСЛО,
}
```
Так, на экранах с разрешением от 1200 пикселей будет отображаться ВАШЕ_ЧИСЛО карточек.

#### Другие изменеия в слайдере
Вы можете импортировать скрипт из index.html в официальный редактор от swiper (доступен по ссылке: ). Импортировав слайдер, вы сможете внести необходимые корректировки в графическом редакторе.