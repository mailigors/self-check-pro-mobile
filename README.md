# Self-Check Pro

Flutter-приложение исполнителя. Web-сборка публикуется на GitHub Pages как PWA.

## Face ID / Touch ID

После первого входа по паролю в нативном приложении iOS появляется предложение
включить Face ID (или Touch ID). Его также можно включить в
**Профиль → Безопасность → Вход с Face ID**.
Настройка появляется, если биометрия настроена на устройстве, и включается
после системного подтверждения. При следующем запуске автоматически вызывается
биометрия, чтобы открыть сохранённую сессию. При отмене можно повторить
проверку или войти по паролю. Пароль не сохраняется; используются токены
из защищённого хранилища. Вход по паролю в тот же аккаунт сохраняет настройку;
выход из аккаунта, истечение сессии и смена аккаунта сбрасывают её.
Если биометрия не включена, предложение появляется после входа по паролю;
старый отказ, оставшийся в Keychain после переустановки, его не подавляет.
Для завершения работы с сохранением Face ID используйте **Заблокировать приложение**.
**Выйти из аккаунта** отзывает серверную сессию и требует нового входа по паролю.
В web/PWA и Android этот сценарий не включён.

Для ручной проверки на iPhone: включить Face ID в профиле, завершить приложение,
запустить снова, проверить успешное распознавание и отмену, затем выход из
аккаунта. В симуляторе включить **Features → Face ID → Enrolled** и использовать
**Matching Face / Non-matching Face**.

Проверка настоящего Keychain между отдельными запусками на iOS-симуляторе:

```sh
flutter test integration_test/biometric_storage_test.dart -d DEVICE_ID --dart-define=BIOMETRIC_STORAGE_PHASE=seed
flutter test integration_test/biometric_storage_test.dart -d DEVICE_ID --dart-define=BIOMETRIC_STORAGE_PHASE=verify
```

Тест использует отдельное хранилище, не затрагивая токены пользователя.
После теста перед запуском из Xcode восстановите обычную точку входа:

```sh
flutter build ios --release --config-only --target=lib/main.dart
```

## GitHub Pages

После пуша в `main` workflow собирает `flutter build web` и выкладывает `build/web`.

1. Репозиторий должен быть **public** (на бесплатном плане Pages недоступен для private).
2. Включите Pages **до** деплоя: [Settings → Pages](https://github.com/mailigors/self-check-pro-mobile/settings/pages) → **Build and deployment → Source: GitHub Actions**.
3. Перезапустите workflow **Deploy GitHub Pages** (Actions → failed run → Re-run jobs).
4. Сайт: `https://mailigors.github.io/self-check-pro-mobile/`.

На iPhone: открыть этот URL в **Safari** → Поделиться → **На экран «Домой»**.

Адрес API задаётся переменной репозитория **Settings → Secrets and variables → Actions → Variables → `API_ORIGIN`**. Если её нет, используется `https://selfcheck.pro`.

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
