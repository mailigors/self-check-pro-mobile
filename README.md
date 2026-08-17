# Self-Check Pro

Flutter-приложение исполнителя. Web-сборка публикуется на GitHub Pages как PWA.

## GitHub Pages

После пуша в `main` workflow собирает `flutter build web` и выкладывает `build/web`.

1. Репозиторий должен быть **public** (на бесплатном плане Pages недоступен для private).
2. Включите Pages **до** деплоя: [Settings → Pages](https://github.com/mailigors/self-check-pro-mobile/settings/pages) → **Build and deployment → Source: GitHub Actions**.
3. Перезапустите workflow **Deploy GitHub Pages** (Actions → failed run → Re-run jobs).
4. Сайт: `https://mailigors.github.io/self-check-pro-mobile/`.

На iPhone: открыть этот URL в **Safari** → Поделиться → **На экран «Домой»**.

Адрес API задаётся переменной репозитория **Settings → Secrets and variables → Actions → Variables → `API_ORIGIN`**. Если её нет, используется `https://185.108.211.9:3002`.

На бэкенде нужен CORS для origin GitHub Pages:

```
Access-Control-Allow-Origin: https://<user>.github.io
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
```

Локальная проверка той же сборки:

```bash
flutter build web --release --base-href /self-check-pro-mobile/ --no-web-resources-cdn
python3 -m http.server 8080 --directory build/web
```
