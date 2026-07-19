#!/bin/bash
set -euo pipefail

# =========================================
# KIANA-2.3 GCP DEPLOYER BALANCED EDITION
# ✅ NO PHONE OVERHEATING
# ✅ FASTER DOWNLOAD: 8-25MB/s+
# ✅ STABLE | LOW BATTERY USAGE
# ✅ FIXED CREDS: Pass=kiana-2 | UUID=a1b2c3d4-5678-40ef-98ab-cdef01234567
# =========================================

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
REGION="${1:-us-central1}"
RAND=$(openssl rand -hex 3 2>/dev/null)
CLOUD_RUN_SERVICE_NAME="xray-balanced-$RAND"
BUILD_DIR=$(mktemp -d)

cleanup() { rm -rf "$BUILD_DIR" || true; }
trap cleanup EXIT

clear
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}     TROJAN + VLESS WS/TLS${NC}"
echo -e "${GREEN}     BALANCED SPEED & LOW HEAT${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo -e "${GREEN}✅ Region:${NC} $REGION"
echo ""

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}ERROR: No project set!${NC}"
    echo -e "Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --project="$PROJECT_ID" --quiet

echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}          BILLING MODE${NC}"
echo -e "${CYAN}=========================================${NC}"
echo -e "${YELLOW}Instance-Based = More Stable, No Throttling${NC}"
echo -e "1) Request-Based  |  2) Instance-Based"
while true; do
    read -p "Select [1-2]: " BILLING_CHOICE
    case $BILLING_CHOICE in
        1) BILLING_MODE="request"; break ;;
        2) BILLING_MODE="instance"; break ;;
        *) echo -e "${RED}Invalid input!${NC}" ;;
    esac
done

echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}      RESOURCE ALLOCATION${NC}"
echo -e "${CYAN}=========================================${NC}"
echo -e "${YELLOW}Recommended: 2Gi RAM + 2vCPU (Perfect Balance)${NC}"
while true; do
    read -p "Memory [1=1Gi|2=2Gi|3=4Gi]: " MEM
    case $MEM in
        1) MEMORY="1Gi"; break ;;
        2) MEMORY="2Gi"; break ;;
        3) MEMORY="4Gi"; break ;;
    esac
done
while true; do
    read -p "vCPU [1=1|2=2|3=4]: " CPU_SEL
    case $CPU_SEL in
        1) CPU="1"; break ;;
        2) CPU="2"; break ;;
        3) CPU="4"; break ;;
    esac
done

if [ "$CPU" = "1" ] || [ "$MEMORY" = "1Gi" ]; then
    CONCURRENCY="300"
else
    CONCURRENCY="800"
fi
TIMEOUT="3600"

echo -e "${YELLOW}💡 Min Instances = 1 = No Disconnect${NC}"
while true; do
    read -p "Min Instances [0/1, default=0]: " MIN_INST
    MIN_INST=${MIN_INST:-0}
    [[ "$MIN_INST" =~ ^[0-1]$ ]] && break || echo -e "${RED}Only 0 or 1 allowed${NC}"
done
while true; do
    read -p "Max Instances [1-2, default=1]: " MAX_INST
    MAX_INST=${MAX_INST:-1}
    [[ "$MAX_INST" =~ ^[1-2]$ ]] && break || echo -e "${RED}Only 1-2 allowed${NC}"
done

cd "$BUILD_DIR" || exit 1

# =========================
# ✅ BALANCED XRAY CONFIG
# Not too heavy, not too slow — NO PHONE HEATING
# =========================
cat > config.json <<'EOF'
{
  "log": { "loglevel": "warning" },
  "policy": {
    "levels": {
      "0": {
        "handshake": 2,
        "connIdle": 86400,
        "uplinkOnly": 0,
        "downlinkOnly": 0,
        "bufferSize": 2097152
      }
    }
  },
  "inbounds": [
    {
      "tag": "trojan-ws",
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": { "clients": [{"password": "kiana-2", "level": 0}] },
      "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"], "routeOnly": true },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/tr-ws?ed=2560", "maxEarlyData": 1048576 },
        "sockopt": {
          "tcpNoDelay": true,
          "tcpFastOpen": true,
          "tcpKeepAlive": true,
          "tcpKeepAliveIdle": 15,
          "tcpKeepAliveInterval": 10,
          "tcpKeepAliveCount": 5
        }
      }
    },
    {
      "tag": "vless-ws",
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [{"id": "a1b2c3d4-5678-40ef-98ab-cdef01234567", "level": 0}], "decryption": "none" },
      "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"], "routeOnly": true },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vl-ws?ed=2560", "maxEarlyData": 1048576 },
        "sockopt": {
          "tcpNoDelay": true,
          "tcpFastOpen": true,
          "tcpKeepAlive": true,
          "tcpKeepAliveIdle": 15,
          "tcpKeepAliveInterval": 10,
          "tcpKeepAliveCount": 5
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4v6",
        "tcpKeepAliveIdle": 15,
        "tcpKeepAliveInterval": 10
      }
    }
  ]
}
EOF

# =========================
# ✅ BALANCED NGINX
# No heavy buffering, light & fast
# =========================
cat > nginx.conf <<'EOF'
worker_processes auto;
worker_rlimit_nofile 65535;
worker_priority -10;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
    accept_mutex off;
}

http {
    include mime.types;
    default_type application/octet-stream;

    sendfile on;
    tcp_nodelay on;
    tcp_nopush on;
    types_hash_max_size 2048;

    keepalive_timeout 86400;
    keepalive_requests 100000;

    client_max_body_size 0;
    client_body_buffer_size 128k;

    proxy_buffering off;
    proxy_request_buffering off;
    proxy_cache off;
    proxy_http_version 1.1;
    proxy_set_header Connection "";

    proxy_connect_timeout 10s;
    proxy_send_timeout 86400s;
    proxy_read_timeout 86400s;

    server_tokens off;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }

    server {
        listen 8080 deferred reuseport;
        server_name _;

        location / {
            proxy_pass https://www.google.com;
            proxy_set_header Host www.google.com;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_ssl_server_name on;
            proxy_ssl_protocols TLSv1.2 TLSv1.3;
        }

        location /tr-ws {
            proxy_pass http://127.0.0.1:10001;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_buffering off;
        }

        location /vl-ws {
            proxy_pass http://127.0.0.1:10002;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_buffering off;
        }
    }
}
EOF

cat > entrypoint.sh <<'EOF'
#!/bin/sh
/usr/local/bin/xray run -c /etc/xray.json &
sleep 3
exec /usr/local/openresty/bin/openresty -g 'daemon off;'
EOF
chmod +x entrypoint.sh

cat > Dockerfile <<'EOF'
FROM alpine:3.20 AS builder
RUN apk add --no-cache curl unzip ca-certificates
RUN curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o xray.zip \
 && unzip -q xray.zip xray geosite.dat geoip.dat \
 && chmod +x xray

FROM openresty/openresty:alpine-fat
RUN apk add --no-cache ca-certificates tzdata bash

COPY --from=builder /xray /usr/local/bin/xray
COPY --from=builder /geosite.dat /usr/local/share/xray/
COPY --from=builder /geoip.dat /usr/local/share/xray/
COPY config.json /etc/xray.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /usr/local/bin/xray /entrypoint.sh
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
EOF

echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}          BUILDING IMAGE${NC}"
echo -e "${CYAN}=========================================${NC}"
gcloud builds submit --project="$PROJECT_ID" --tag gcr.io/$PROJECT_ID/$CLOUD_RUN_SERVICE_NAME . --quiet

BILLING_FLAGS=$([ "$BILLING_MODE" = "instance" ] && echo "--no-cpu-throttling" || echo "--cpu-throttling")

echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}         DEPLOYING TO CLOUD RUN${NC}"
echo -e "${CYAN}=========================================${NC}"
gcloud run deploy $CLOUD_RUN_SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$CLOUD_RUN_SERVICE_NAME \
  --project="$PROJECT_ID" --platform managed --region "$REGION" --allow-unauthenticated \
  --port 8080 --memory $MEMORY --cpu $CPU --concurrency $CONCURRENCY \
  --timeout $TIMEOUT --min-instances $MIN_INST --max-instances $MAX_INST \
  --execution-environment gen2 --cpu-boost $BILLING_FLAGS --quiet

CLOUD_RUN_URL=$(gcloud run services describe $CLOUD_RUN_SERVICE_NAME --project="$PROJECT_ID" --region="$REGION" --format='value(status.url)')
DOMAIN=$(echo "$CLOUD_RUN_URL" | sed 's|https://||')

echo -e "\n${CYAN}=========================================${NC}"
echo -e "${GREEN}✅ DEPLOYMENT SUCCESS! BALANCED PERFORMANCE${NC}"
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}Service:${NC} $CLOUD_RUN_SERVICE_NAME"
echo -e "${GREEN}🔗 FULL LINK:${NC}"
echo -e "https://$DOMAIN"
echo -e "${GREEN}🌐 DOMAIN:${NC} $DOMAIN"
echo -e "${GREEN}Port:${NC} 443"
echo -e "\n${YELLOW}--- CLIENT CONFIGS ---${NC}"
echo -e "${GREEN}🔹 TROJAN + WS + TLS${NC}"
echo "   Address: $DOMAIN"
echo "   Port: 443"
echo "   Password: kiana-2"
echo "   Path: /tr-ws"
echo "   SNI: $DOMAIN"
echo -e "\n${GREEN}🔹 VLESS + WS + TLS${NC}"
echo "   Address: $DOMAIN"
echo "   Port: 443"
echo "   UUID: a1b2c3d4-5678-40ef-98ab-cdef01234567"
echo "   Path: /vl-ws"
echo "   SNI: $DOMAIN"
echo -e "${CYAN}=========================================${NC}"
echo -e "${YELLOW}💡 Lightweight, No Overheat, Better Download Speed!${NC}"
