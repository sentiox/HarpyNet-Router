# HarpyNet Router

Публичный установщик и релизы пакетов HarpyNet для OpenWrt.

HarpyNet помогает управлять маршрутизацией, прокси, диагностикой и LuCI-интерфейсом на роутере. Этот репозиторий нужен только для установки и обновления на роутере: здесь лежат `install.sh`, `uninstall.sh` и готовые `.ipk` / `.apk` пакеты в Releases.

Исходный код HarpyNet здесь не публикуется.

## Быстрая установка

Подключитесь к роутеру по SSH и выполните:

```sh
sh <(wget -O - https://raw.githubusercontent.com/sentiox/HarpyNet-Router/main/install.sh)
```

После установки откройте LuCI:

```text
http://192.168.7.1/cgi-bin/luci/admin/services/harpynet
```

Если LuCI попросит логин, используйте учётные данные вашего роутера.

## Обновление

Для обновления используйте ту же команду:

```sh
sh <(wget -O - https://raw.githubusercontent.com/sentiox/HarpyNet-Router/main/install.sh)
```

Установщик определяет, установлен ли HarpyNet, скачивает свежие пакеты из последнего релиза и обновляет их.

При обновлении настройки не сбрасываются. Перед установкой текущий конфиг `/etc/config/harpynet` сохраняется во временный backup, затем восстанавливается после установки пакетов.

## Удаление

Если HarpyNet больше не нужен:

```sh
sh <(wget -O - https://raw.githubusercontent.com/sentiox/HarpyNet-Router/main/uninstall.sh)
```

Скрипт удаления:

- останавливает и отключает сервис HarpyNet;
- удаляет `harpynet`, `luci-app-harpynet` и русский перевод LuCI;
- сохраняет backup конфига в `/etc/config/harpynet.backup-before-uninstall`;
- спрашивает, удалять ли сам `/etc/config/harpynet`;
- чистит LuCI cache и перезапускает `rpcd`.

## Как это работает

1. GitHub Actions собирает пакеты HarpyNet в закрытом build-репозитории.
2. Готовые `.ipk` и `.apk` автоматически публикуются в Releases этого репозитория.
3. `install.sh` на роутере определяет пакетный менеджер:
   - `opkg` для `.ipk`;
   - `apk` для `.apk`.
4. Скрипт скачивает подходящие пакеты из последнего релиза.
5. Пакеты устанавливаются локально на роутер.
6. LuCI cache очищается при удалении, а при обновлении настройки HarpyNet сохраняются.

## Что скачивается

Установщик берёт только готовые release assets:

- `harpynet-*.ipk` или `harpynet-*.apk`;
- `luci-app-harpynet-*.ipk` или `luci-app-harpynet-*.apk`;
- `luci-i18n-harpynet-ru-*.ipk` или `luci-i18n-harpynet-ru-*.apk`.

Ссылки `Source code (zip)` и `Source code (tar.gz)` в GitHub Releases добавляются GitHub автоматически. В них находится только содержимое этого публичного репозитория: установщик, удаление и README. Исходный код HarpyNet туда не попадает.

## Требования

- OpenWrt с доступом в интернет.
- Рабочий DNS на роутере.
- Достаточно свободного места во flash.
- Поддерживаемый пакетный менеджер: `opkg` или `apk`.

OpenWrt 23.05 не поддерживается текущими релизами HarpyNet. Для него используйте старую совместимую версию HarpyNet или устанавливайте зависимости вручную.

## LuCI

После установки страница HarpyNet находится в LuCI:

```text
Сервисы -> HarpyNet
```

Если LuCI не показывает страницу сразу после установки или удаления, обновите страницу браузера. При перезапуске `rpcd` LuCI может попросить войти заново.

## Безопасность настроек

Обновление через `install.sh` не должно обнулять настройки HarpyNet.

При удалении конфиг по умолчанию сохраняется. Полное удаление конфига происходит только если пользователь подтверждает это в `uninstall.sh`.

## Полезные ссылки

- Releases: https://github.com/sentiox/HarpyNet-Router/releases
- Install script: https://raw.githubusercontent.com/sentiox/HarpyNet-Router/main/install.sh
- Uninstall script: https://raw.githubusercontent.com/sentiox/HarpyNet-Router/main/uninstall.sh
