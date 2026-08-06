#!/bin/bash
set -euo pipefail

# =========================================
# 🚀 KIANA-2.4 GCP DEPLOYER | BOTH LINKS INCLUDED
# ✅ FIXED LIST SYNTAX ERROR
# ✅ SHOWS SHORT LINK + FULL LINK
# ✅ REGION SELECTOR WITH TAIWAN
# ✅ PERSISTENT MENU LOOP
# ✅ BALANCED XRAY/NGINX CONFIG
# =========================================

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

# ==============================================
# ✅ FIXED: List All Deployed Services
# ==============================================
list_deployed_services() {
  echo -e "\n======================================"
  echo -e "${CYAN}📋 ALL DEPLOYED KIANA 2.4-XRAY SERVICES${NC}"
  echo -e "======================================"
  PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
  echo "Project: $PROJECT_ID"
  echo ""
  
  gcloud run services list \
    --format="table(metadata.name, status.url, region, metadata.creationTimestamp.date(%Y-%m-%d))" \
    --filter="metadata.name~^xray-" \
    --project="$PROJECT_ID" || {
      echo -e "${YELLOW}ℹ️ No 'xray-' services found. Showing ALL services:\n${NC}"
      gcloud run services list --format="table(metadata.name, status.url, region)" --project="$PROJECT_ID"
    }
  
  echo -e "\n======================================"
  read -p "Press [Enter] to return to Main Menu..."
}

# ==============================================
# Region Selection Menu
# ==============================================
select_region() {
  echo -e "\n=== GCP Cloud Run Region Selection ==="
  echo "--- North America ---"
  echo "1) us-central1      (Iowa, US - Recommended)"
  echo "2) us-east1         (South Carolina, US)"
  echo "3) us-east4         (Northern Virginia, US)"
  echo "4) us-west1         (Oregon, US)"
  echo ""
  echo "--- Asia Pacific ---"
  echo "5) asia-east1       (Taiwan 🇹🇼)"
  echo "6) asia-southeast1  (Singapore)"
  echo "7) asia-northeast1  (Tokyo, Japan)"
  echo "8) asia-northeast3  (Seoul, South Korea)"
  echo ""
  echo "--- Europe ---"
  echo "9) europe-west1     (Belgium)"
  echo "10) europe-west4    (Netherlands)"
  echo "11) europe-west9    (Paris, France)"
  echo ""
  echo "0) Manually enter custom region code"
  echo ""

  read -p "Enter number for your selected region: " REGION_NUM

  case $REGION_NUM in
    1) REGION="us-central1" ;;
    2) REGION="us-east1" ;;
    3) REGION="us-east4" ;;
    4) REGION="us-west1" ;;
    5) REGION="asia-east1" ;;
    6) REGION="asia-southeast1" ;;
    7) REGION="asia-northeast1" ;;
    8) REGION="asia-northeast3" ;;
    9) REGION="europe-west1" ;;
    10) REGION="europe-west4" ;;
    11) REGION="europe-west9" ;;
    0) read -p "Enter full region code: " REGION ;;
    *) echo -e "${YELLOW}⚠️ Invalid input! Using default: us-central1${NC}"; REGION="us-central1" ;;
  esac

  echo -e "${GREEN}✅ Selected Region:${NC} $REGION"
}

# ==============================================
# Full Deployment Process
# ==============================================
deploy_new_service() {
  select_region

  PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
  RAND=$(openssl rand -hex 3 2>/dev/null)
  CLOUD_RUN_SERVICE_NAME="xray-balanced-$RAND"
  BUILD_DIR=$(mktemp -d)

  cleanup() { rm -rf "$BUILD_DIR" || true; }
  trap cleanup EXIT

  clear
  echo ""
  echo -e "${CYAN}==========================================================${NC}"
  echo -e "${GREEN}        KIANA 2.4 GCP CLOUDSHELL DEPLOYER BY Con Fig${NC}"
  echo -e "${YELLOW}       TROJAN & VLESS WS + TLS PROTOCOLS ONLY${NC}"
  echo -e "${RED}          MANUAL SET REGION,INSTANCES,BILLING,MEMORY & vCPU${NC}"
  echo -e "${GREEN}        BALANCED XRAY.JSON AND NGINX.CONF${NC}"
  echo -e "${YELLOW}       BALANCED SPEED & LOW BATTERY${NC}"
  echo -e "${RED}          FOR FREENET USE ONLY DAHIL ANG MAHAL NG LOAD😄✌️${NC}"
  echo -e "${CYAN}==========================================================${NC}"
  echo -e "${GREEN}✅ Project:${NC} $PROJECT_ID"
  echo -e "${GREEN}✅ Region:${NC} $REGION"
  echo -e "${GREEN}✅ Service Name:${NC} $CLOUD_RUN_SERVICE_NAME"
  echo ""

  if [ -z "$PROJECT_ID" ]; then
      echo -e "${RED}ERROR: No GCP project set!${NC}"
      echo -e "Run: gcloud config set project YOUR_PROJECT_ID"
      read -p "Press [Enter] to return to Main Menu..."
      return
  fi

  gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --project="$PROJECT_ID" --quiet

  echo -e "${CYAN}=========================================${NC}"
  echo -e "${GREEN}          BILLING MODE${NC}"
  echo -e "${CYAN}=========================================${NC}"
  echo -e "${YELLOW}Instance-Based = More Stable, No Throttling${NC}"
  echo "1) Request-Based  |  2) Instance-Based"
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
  echo -e "${YELLOW}Recommended: 2Gi RAM + 2vCPU / 4Gi + 2vCPU${NC}"
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

  echo -e "${YELLOW}💡 Min Instances = 1 = No Disconnects${NC}"
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

  # Xray Config
  cat > config.json <<'EOF'
{
  "log": { "loglevel": "warning" },
  "policy": {
    "levels": {
      "0": { "handshake": 2, "connIdle": 86400, "bufferSize": 2097152 }
    }
  },
  "inbounds": [
    {
      "tag": "trojan-ws", "port": 10001, "listen": "127.0.0.1", "protocol": "trojan",
      "settings": { "clients": [{"password": "kiana-2", "level": 0}] },
      "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"], "routeOnly": true },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/tr-ws?ed=2560" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true } }
    },
    {
      "tag": "vless-ws", "port": 10002, "listen": "127.0.0.1", "protocol": "vless",
      "settings": { "clients": [{"id": "a1b2c3d4-5678-40ef-98ab-cdef01234567", "level": 0}], "decryption": "none" },
      "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"], "routeOnly": true },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vl-ws?ed=2560" }, "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true } }
    }
  ],
  "outbounds": [{"protocol": "freedom", "settings": { "domainStrategy": "UseIPv4v6" }}]
}
EOF

  # Nginx Config
  cat > nginx.conf <<'EOF'
worker_processes auto; worker_rlimit_nofile 65535; worker_priority -10;
events { worker_connections 4096; use epoll; multi_accept on; accept_mutex off; }
http {
  include mime.types; default_type application/octet-stream;
  sendfile on; tcp_nodelay on; tcp_nopush on; keepalive_timeout 86400;
  client_max_body_size 0; proxy_buffering off; proxy_http_version 1.1;
  map $http_upgrade $connection_upgrade { default upgrade; '' close; }
  server {
    listen 8080; server_name _;
    location /health { return 200 "OK\n"; add_header Content-Type text/plain; }
    location / { proxy_pass https://www.google.com; proxy_set_header Host www.google.com; }
    location /tr-ws { proxy_pass http://127.0.0.1:10001; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; }
    location /vl-ws { proxy_pass http://127.0.0.1:10002; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; }
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
RUN curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o xray.zip && unzip -q xray.zip xray geosite.dat geoip.dat && chmod +x xray
FROM openresty/openresty:alpine-fat
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

  echo -e "${CYAN}Building image...${NC}"
  gcloud builds submit --project="$PROJECT_ID" --tag gcr.io/$PROJECT_ID/$CLOUD_RUN_SERVICE_NAME . --quiet

  BILLING_FLAGS=$([ "$BILLING_MODE" = "instance" ] && echo "--no-cpu-throttling" || echo "--cpu-throttling")

  echo -e "${CYAN}Deploying to Cloud Run...${NC}"
  gcloud run deploy $CLOUD_RUN_SERVICE_NAME \
    --image gcr.io/$PROJECT_ID/$CLOUD_RUN_SERVICE_NAME \
    --project="$PROJECT_ID" --platform managed --region "$REGION" --allow-unauthenticated \
    --port 8080 --memory $MEMORY --cpu $CPU --concurrency $CONCURRENCY \
    --timeout $TIMEOUT --min-instances $MIN_INST --max-instances $MAX_INST \
    --execution-environment gen2 --cpu-boost $BILLING_FLAGS --quiet

  # Get final URLs
  CLOUD_RUN_URL=$(gcloud run services describe $CLOUD_RUN_SERVICE_NAME --project="$PROJECT_ID" --region="$REGION" --format='value(status.url)')
  DOMAIN=$(echo "$CLOUD_RUN_URL" | sed 's|https://||')
  SHORT_LINK="$CLOUD_RUN_URL"
  FULL_LINK="$CLOUD_RUN_URL"

  # Final Output with BOTH links
  echo -e "\n${CYAN}=========================================${NC}"
  echo -e "${GREEN}✅ DEPLOYMENT SUCCESS!${NC}"
  echo -e "${CYAN}=========================================${NC}"
  echo -e "${GREEN}Service Name:${NC} $CLOUD_RUN_SERVICE_NAME"
  echo -e "${GREEN}Region:${NC} $REGION"
  echo ""
  echo -e "${GREEN}🔗 SHORT LINK:${NC}"
  echo -e "   https://$SHORT_LINK"
  echo ""
  echo -e "${GREEN}🔗 FULL LINK:${NC}"
  echo -e "   https://$FULL_LINK"
  echo ""
  echo -e "${GREEN}💚 HEALTH CHECK:${NC}"
  echo -e "   $FULL_LINK/health"
  echo ""
  echo -e "${GREEN}🌐 DOMAIN:${NC} $DOMAIN"
  echo -e "${GREEN}🔌 PORT:${NC} 443"
  echo -e "\n${YELLOW}===== NETMOD CONFIGURATIONS =====${NC}"
  echo -e "${GREEN}🔹 TROJAN + WS + TLS${NC}"
  echo "   Address: firebase-settings.crashlytics.com"
  echo "   Port: 443"
  echo "   Password: kiana-2"
  echo "   Host: $DOMAIN"
  echo "   Path: /tr-ws"
  echo "   SNI: firebase-settings.crashlytics.com"
  echo -e "\n${GREEN}🔹 VLESS + WS + TLS${NC}"
  echo "   Address: firebaseremoteconfigrealtime.googleapis.com"
  echo "   Port: 443"
  echo "   UUID: a1b2c3d4-5678-40ef-98ab-cdef01234567"
  echo "   Host: $DOMAIN"
  echo "   Path: /vl-ws"
  echo "   Security: TLS"
  echo "   SNI: firebaseremoteconfigrealtime.googleapis.com"
  echo -e "${CYAN}=========================================${NC}"
  echo -e "${YELLOW}💡 Balanced config = no overheating, stable speeds, low battery drain!${NC}"

  read -p "\nPress [Enter] to return to Main Menu..."
}

# ==============================================
# Main Menu Loop
# ==============================================
while true; do
  clear
  echo "======================================"
  echo "   🚀 KIANA-2.4 GCP DEPLOYER MENU    "
  echo "======================================"
  echo "1) Deploy new balanced Xray service"
  echo "2) List all deployed services & URLs"
  echo "3) Exit script"
  echo "======================================"
  read -p "Select an option [1-3]: " MENU_CHOICE

  case $MENU_CHOICE in
    1) deploy_new_service ;;
    2) list_deployed_services ;;
    3) echo -e "\n👋 Goodbye!"; exit 0 ;;
    *) echo -e "${RED}❌ Invalid selection! Enter 1/2/3 only.${NC}"; sleep 2 ;;
  esac
done
