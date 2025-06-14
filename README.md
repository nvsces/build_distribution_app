# Build Distribution App (BDA)

**BDA** — удобный инструмент для разработчиков, который упрощает распространение Android-сборок (.apk и .aab) среди команды, тестировщиков и клиентов.

---

## Как это работает

BDA использует API Google Drive для хранения и управления Android-билдами. Все ваши сборки загружаются в заранее созданные папки на Google Drive, доступ к которым осуществляется через сервисный аккаунт.

---

## Настройка приложения

1. **Создайте сервисный аккаунт в Google Cloud Console**:
   - Перейдите в [Google Cloud Console](https://console.cloud.google.com/).
   - Создайте новый проект или используйте существующий.
   - В разделе "IAM и администрирование" создайте сервисный аккаунт.
   - Сгенерируйте JSON-ключ и скачайте его.

2. **Создайте нужные папки в Google Drive**:
   - Войдите в Google Drive под аккаунтом, которому принадлежит сервисный аккаунт.
   - Создайте папки для разных типов сборок, например: `test`, `staging`, `predprod`.
   - Добавьте сервисный аккаунт (его email из JSON-ключа) в список доступа к этим папкам с правами редактирования.

3. **Подготовьте файл конфигурации**:
   - Создайте в вашем проекте папку `assets` (если ещё нет).
   - В `assets` создайте файл `config.json` со структурой, аналогичной следующей:

```json
{
  "service_account": {
    "type": "service_account",
    "project_id": "your-project-id",
    "private_key_id": "your-private-key-id",
    "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
    "client_email": "your-service-account-email@project.iam.gserviceaccount.com",
    "client_id": "your-client-id",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/your-service-account-email@project.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com"
  },
  "folders": [
    {
      "name": "test",
      "package": "com.example.test",
      "id": "folder-id-for-test"
    },
    {
      "name": "staging",
      "package": "com.example.staging",
      "id": "folder-id-for-staging"
    },
    {
      "name": "predprod",
      "package": "com.example.predprod",
      "id": "folder-id-for-predprod"
    }
  ]
}
```


Поля `project_id`, `private_key_id`, `private_key`, `client_email`, `client_id` и другие берутся из скачанного JSON-ключа сервисного аккаунта.

В блоке `"folders"` указывайте название папки, соответствующий `package name` и `id` папки из Google Drive (можно получить из URL папки).

---

### 🛠 Рекомендуемая утилита для загрузки сборок

Для удобной и быстрой загрузки сборок воспользуйтесь утилитой [`build_distribution_cli`](https://github.com/nvsces/build_distribution_cli).  
Она позволяет автоматизировать процесс отправки `.apk` файлов в нужные папки Google Drive, используя тот же `config.json`.

---

### ✅ Итог

После настройки сервисного аккаунта и `config.json` вы сможете легко загружать, управлять и делиться Android-сборками напрямую из **BDA** через **Google Drive** без лишних действий.
