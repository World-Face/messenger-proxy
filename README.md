# Messenger Proxy

Одной командой разворачивает **WhatsApp** и **Telegram MTProto** прокси-серверы на чистом Ubuntu VPS.

## Быстрый старт

```bash
curl -sSL https://raw.githubusercontent.com/World-Face/messenger-proxy/main/install.sh -o /tmp/install.sh && sudo bash /tmp/install.sh
```

## Что спросит установщик

| Вопрос | Пример | По умолчанию |
|---|---|---|
| IP адрес сервера | `45.38.143.163` | — |
| Домен WhatsApp | `whatsapp.example.com` | — |
| Порт Chat (WhatsApp) | `8443` | `8443` |
| Порт Media (WhatsApp) | `7777` | `7777` |
| Домен Telegram | `telegram.example.com` | — |
| Порт Telegram | `9443` | `9443` |

## Что установится

- **Docker** (если не установлен)
- **WhatsApp Proxy** — HAProxy с SSL-терминацией (официальная схема Meta)
  - Chat порт → `g.whatsapp.net:5222`
  - Media порт → `whatsapp.net:443`
- **Telegram MTProto Proxy** — [mtg v2](https://github.com/9seconds/mtg) с FakeTLS-обфускацией

## Автозапуск

Оба сервиса добавляются в systemd и **автоматически стартуют** после перезагрузки сервера.

## Управление

```bash
# Статус
systemctl status whatsapp-proxy
systemctl status telegram-proxy

# Перезапуск
systemctl restart whatsapp-proxy
systemctl restart telegram-proxy

# Логи в реальном времени
journalctl -u whatsapp-proxy -f
journalctl -u telegram-proxy -f
```

## Конфиги

```
/opt/messenger-proxy/whatsapp/haproxy.cfg
/opt/messenger-proxy/telegram/config.toml
```

## Требования

- Ubuntu 20.04 / 22.04 / 24.04
- Доступ root
- Открытые порты в панели провайдера (если есть внешний firewall)
