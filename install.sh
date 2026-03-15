#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║          Messenger Proxy — One-Command Installer             ║
# ║          WhatsApp + Telegram MTProto                         ║
# ║          https://github.com/World-Face/messenger-proxy       ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

# ─── Цвета ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
info() { echo -e "${CYAN}  → $1${NC}"; }
warn() { echo -e "${YELLOW}  ! $1${NC}"; }
err()  { echo -e "${RED}  ✗ $1${NC}"; exit 1; }
step() { echo -e "\n${BOLD}${BLUE}[$1]${NC} $2"; }

# ─── Баннер ──────────────────────────────────────────────────
clear
echo -e "${BLUE}${BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║        Messenger Proxy Installer             ║"
echo "  ║        WhatsApp  +  Telegram MTProto         ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Проверка root ───────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Запустите скрипт от root: sudo bash install.sh"

# ─── Проверка OS ─────────────────────────────────────────────
if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
  warn "Скрипт оптимизирован под Ubuntu. Продолжаем на свой риск."
fi

# ─── Ввод параметров ─────────────────────────────────────────
# Перенаправляем stdin на терминал (на случай запуска через bash <(curl ...))
[[ ! -t 0 ]] && exec < /dev/tty

echo -e "${YELLOW}${BOLD}  Введите параметры конфигурации:${NC}\n"

# IP сервера
while true; do
  read -rp "  IP адрес этого сервера: " SERVER_IP
  [[ $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
  warn "Некорректный IP, попробуйте снова."
done

echo ""

# WhatsApp
echo -e "  ${CYAN}── WhatsApp Proxy ──${NC}"
read -rp "  Домен WhatsApp (напр. whatsapp.example.com): " WA_DOMAIN
read -rp "  Порт Chat [8443]: " WA_CHAT_PORT
WA_CHAT_PORT=${WA_CHAT_PORT:-8443}
read -rp "  Порт Media [7777]: " WA_MEDIA_PORT
WA_MEDIA_PORT=${WA_MEDIA_PORT:-7777}

echo ""

# Telegram
echo -e "  ${CYAN}── Telegram MTProto Proxy ──${NC}"
read -rp "  Домен Telegram (напр. telegram.example.com): " TG_DOMAIN
read -rp "  Порт [9443]: " TG_PORT
TG_PORT=${TG_PORT:-9443}

# ─── Подтверждение ───────────────────────────────────────────
echo ""
echo -e "${BOLD}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${BOLD}  │           Итоговая конфигурация          │${NC}"
echo -e "${BOLD}  ├─────────────────────────────────────────┤${NC}"
printf "  │  %-22s  %-18s│\n" "IP сервера:"        "$SERVER_IP"
printf "  │  %-22s  %-18s│\n" "WhatsApp домен:"    "$WA_DOMAIN"
printf "  │  %-22s  %-18s│\n" "WhatsApp Chat порт:" ":$WA_CHAT_PORT"
printf "  │  %-22s  %-18s│\n" "WhatsApp Media порт:" ":$WA_MEDIA_PORT"
printf "  │  %-22s  %-18s│\n" "Telegram домен:"    "$TG_DOMAIN"
printf "  │  %-22s  %-18s│\n" "Telegram порт:"     ":$TG_PORT"
echo -e "${BOLD}  └─────────────────────────────────────────┘${NC}"
echo ""
read -rp "  Продолжить установку? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && echo "  Отменено." && exit 0

# ─── 1. Системные зависимости ────────────────────────────────
step "1/7" "Установка системных зависимостей"
apt-get update -qq
apt-get install -y -qq \
  ca-certificates curl gnupg lsb-release \
  openssl netcat-openbsd git 2>/dev/null
ok "Зависимости установлены"

# ─── 2. Docker ───────────────────────────────────────────────
step "2/7" "Установка Docker"
if command -v docker &>/dev/null; then
  ok "Docker уже установлен ($(docker --version | cut -d' ' -f3 | tr -d ','))"
else
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
  ok "Docker установлен и запущен"
fi

# ─── 3. mtg (Telegram MTProto proxy) ─────────────────────────
step "3/7" "Установка mtg (Telegram proxy)"
if command -v mtg &>/dev/null; then
  ok "mtg уже установлен ($(mtg --version | head -1))"
else
  MTG_VERSION=$(curl -s https://api.github.com/repos/9seconds/mtg/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4 | tr -d 'v')
  info "Скачиваем mtg v${MTG_VERSION}..."
  curl -sL "https://github.com/9seconds/mtg/releases/download/v${MTG_VERSION}/mtg-${MTG_VERSION}-linux-amd64.tar.gz" \
    -o /tmp/mtg.tar.gz
  tar xz -C /tmp/ -f /tmp/mtg.tar.gz
  cp "/tmp/mtg-${MTG_VERSION}-linux-amd64/mtg" /usr/local/bin/mtg
  chmod +x /usr/local/bin/mtg
  rm -rf /tmp/mtg.tar.gz "/tmp/mtg-${MTG_VERSION}-linux-amd64"
  ok "mtg $(mtg --version | head -1) установлен"
fi

# ─── 4. Директории и конфиги ─────────────────────────────────
step "4/7" "Создание конфигурации"
mkdir -p /opt/messenger-proxy/whatsapp/src
mkdir -p /opt/messenger-proxy/whatsapp/ssl
mkdir -p /opt/messenger-proxy/telegram/proxy-data

# ── generate-certs.sh (официальный скрипт Meta/WhatsApp) ──
cat > /opt/messenger-proxy/whatsapp/src/generate-certs.sh <<'CERTEOF'
#!/bin/bash
export RANDOM_CA=$(head -c 60 /dev/urandom | tr -dc 'a-zA-Z0-9')
export CA_KEY="ca-key.pem"
export CA_CERT="ca.pem"
export CA_SUBJECT="${RANDOM_CA}"
export CA_EXPIRE="36500"
export SSL_CONFIG="openssl.cnf"
export SSL_KEY="key.pem"
export SSL_CSR="key.csr"
export SSL_CERT="cert.pem"
export SSL_SIZE="4096"
export SSL_EXPIRE="3650"
export RANDOM_SSL=$(head -c 60 /dev/urandom | tr -dc 'a-zA-Z0-9')
export SSL_SUBJECT="${RANDOM_SSL}.net"

openssl genrsa -out ${CA_KEY} 4096 2>/dev/null
openssl req -x509 -new -nodes -key ${CA_KEY} -days ${CA_EXPIRE} \
  -out ${CA_CERT} -subj "/CN=${CA_SUBJECT}" 2>/dev/null

cat > ${SSL_CONFIG} <<EOM
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${SSL_DNS:-localhost}
IP.1 = ${SSL_IP:-127.0.0.1}
EOM

openssl genrsa -out ${SSL_KEY} ${SSL_SIZE} 2>/dev/null
openssl req -new -key ${SSL_KEY} -out ${SSL_CSR} \
  -subj "/CN=${SSL_SUBJECT}" -config ${SSL_CONFIG} 2>/dev/null
openssl x509 -req -in ${SSL_CSR} -CA ${CA_CERT} -CAkey ${CA_KEY} \
  -CAcreateserial -out ${SSL_CERT} -days ${SSL_EXPIRE} \
  -extensions v3_req -extfile ${SSL_CONFIG} 2>/dev/null
cat ${SSL_KEY} > proxy.whatsapp.net.pem
cat ${SSL_CERT} >> proxy.whatsapp.net.pem
echo "Certificate generated."
CERTEOF
chmod +x /opt/messenger-proxy/whatsapp/src/generate-certs.sh

# ── haproxy.cfg ──
cat > /opt/messenger-proxy/whatsapp/haproxy.cfg <<HAEOF
global
  tune.bufsize 4096
  maxconn 27500
  spread-checks 5
  ssl-server-verify none

defaults
  mode tcp
  timeout client-fin 1s
  timeout server-fin 1s
  timeout connect 5s
  timeout client 200s
  timeout server 200s
  default-server inter 10s fastinter 1s downinter 3s error-limit 50

listen stats
  bind *:8199
  mode http
  stats uri /
  stats refresh 10s

frontend fe_chat_${WA_CHAT_PORT}
  maxconn 27495
  bind ipv4@*:${WA_CHAT_PORT} ssl crt /etc/haproxy/ssl/proxy.whatsapp.net.pem
  tcp-request connection set-dst ipv4(${SERVER_IP})
  default_backend wa_chat

backend wa_chat
  default-server check inter 60000 observe layer4 send-proxy
  server g_whatsapp_net g.whatsapp.net:5222

frontend fe_media_${WA_MEDIA_PORT}
  maxconn 27495
  bind ipv4@*:${WA_MEDIA_PORT}
  tcp-request connection set-dst ipv4(${SERVER_IP})
  default_backend wa_media

backend wa_media
  default-server check inter 60000 observe layer4
  server whatsapp_net whatsapp.net:443
HAEOF

# ── Dockerfile ──
cat > /opt/messenger-proxy/whatsapp/Dockerfile <<DOCKEREOF
FROM haproxy:lts-alpine
USER root
RUN apk --no-cache add curl openssl bash
WORKDIR /certs
COPY src/generate-certs.sh /usr/local/bin/generate-certs.sh
RUN chmod +x /usr/local/bin/generate-certs.sh && \
    SSL_DNS="${WA_DOMAIN}" SSL_IP="${SERVER_IP}" /usr/local/bin/generate-certs.sh && \
    mkdir -p /etc/haproxy/ssl/ && \
    mv /certs/proxy.whatsapp.net.pem /etc/haproxy/ssl/proxy.whatsapp.net.pem && \
    chown -R haproxy:haproxy /etc/haproxy/
WORKDIR /
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
RUN chown haproxy:haproxy /usr/local/etc/haproxy/haproxy.cfg
RUN haproxy -c -V -f /usr/local/etc/haproxy/haproxy.cfg
USER haproxy
EXPOSE ${WA_CHAT_PORT}/tcp
EXPOSE ${WA_MEDIA_PORT}/tcp
EXPOSE 8199/tcp
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
DOCKEREOF

# ── docker-compose.yml ──
cat > /opt/messenger-proxy/whatsapp/docker-compose.yml <<COMPOSEEOF
services:
  whatsapp-proxy:
    build: .
    image: whatsapp-proxy-local:latest
    container_name: whatsapp-proxy
    restart: always
    network_mode: host
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
COMPOSEEOF

# ── Telegram config.toml ──
TG_SECRET=$(mtg generate-secret --hex "$TG_DOMAIN")
cat > /opt/messenger-proxy/telegram/config.toml <<TGEOF
secret   = "${TG_SECRET}"
bind-to  = "0.0.0.0:${TG_PORT}"

[network]
  [network.timeout]
    tcp  = "10s"
    http = "10s"
    idle = "3m"

[stats]
  bind-to = "127.0.0.1:3129"
TGEOF

ok "Конфигурации созданы"

# ─── 5. Сборка WhatsApp образа ───────────────────────────────
step "5/7" "Сборка WhatsApp proxy (HAProxy + SSL)"
info "Собираем Docker образ..."
docker compose -f /opt/messenger-proxy/whatsapp/docker-compose.yml build --quiet
ok "Docker образ собран"

# ─── 6. Открытие портов ──────────────────────────────────────
step "6/7" "Открытие портов в firewall"
for PORT in "$WA_CHAT_PORT" "$WA_MEDIA_PORT" "$TG_PORT"; do
  iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || true
  ufw allow "$PORT/tcp" 2>/dev/null || true
done
ok "Порты ${WA_CHAT_PORT}, ${WA_MEDIA_PORT}, ${TG_PORT} открыты"

# ─── 7. Systemd сервисы ──────────────────────────────────────
step "7/7" "Создание systemd сервисов и запуск"

# WhatsApp systemd unit
cat > /etc/systemd/system/whatsapp-proxy.service <<WAUNIT
[Unit]
Description=WhatsApp Proxy (HAProxy)
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/messenger-proxy/whatsapp
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
WAUNIT

# Telegram systemd unit
cat > /etc/systemd/system/telegram-proxy.service <<TGUNIT
[Unit]
Description=Telegram MTProto Proxy (mtg)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mtg run /opt/messenger-proxy/telegram/config.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
TGUNIT

systemctl daemon-reload
systemctl enable whatsapp-proxy telegram-proxy

# Запуск
info "Запускаем WhatsApp proxy..."
systemctl start whatsapp-proxy
info "Запускаем Telegram proxy..."
systemctl start telegram-proxy

sleep 5

# ─── Проверка ────────────────────────────────────────────────
echo ""
WA_OK=false
TG_OK=false
nc -z 127.0.0.1 "$WA_CHAT_PORT" -w3 2>/dev/null && WA_OK=true
nc -z 127.0.0.1 "$TG_PORT"      -w3 2>/dev/null && TG_OK=true

# ─── Итоговый вывод ──────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║                    Установка завершена!                      ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}  WhatsApp Proxy${NC}"
$WA_OK && echo -e "  ${GREEN}✓ Статус: работает${NC}" || echo -e "  ${RED}✗ Статус: ошибка (проверьте: systemctl status whatsapp-proxy)${NC}"
echo "  Адрес для подключения: ${WA_DOMAIN}:${WA_CHAT_PORT}"
echo "  (в настройках WhatsApp: Настройки → Конфиденциальность → Прокси)"
echo ""

echo -e "${BOLD}  Telegram MTProto Proxy${NC}"
$TG_OK && echo -e "  ${GREEN}✓ Статус: работает${NC}" || echo -e "  ${RED}✗ Статус: ошибка (проверьте: systemctl status telegram-proxy)${NC}"
echo "  Secret: ${TG_SECRET}"
echo ""
echo "  Ссылка для подключения:"
echo -e "  ${CYAN}https://t.me/proxy?server=${SERVER_IP}&port=${TG_PORT}&secret=${TG_SECRET}${NC}"
echo ""

echo -e "${BOLD}  Управление:${NC}"
echo "  systemctl status  whatsapp-proxy telegram-proxy"
echo "  systemctl restart whatsapp-proxy"
echo "  systemctl restart telegram-proxy"
echo "  journalctl -u telegram-proxy -f"
echo ""
echo -e "${BOLD}  Конфиги:${NC}"
echo "  /opt/messenger-proxy/whatsapp/haproxy.cfg"
echo "  /opt/messenger-proxy/telegram/config.toml"
echo ""
echo -e "${GREEN}${BOLD}  Сервисы запустятся автоматически после перезагрузки сервера.${NC}"
echo ""
