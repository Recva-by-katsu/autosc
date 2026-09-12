#!/bin/bash
# Install the autoscript REST API and its documentation site.
# Safe to re-run: existing API keys in /etc/autosc-api are preserved.

REPO="https://raw.githubusercontent.com/Revaa-Cerza/autosc/main"
NC='\033[0m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

echo -e "${GREEN}[INFO]${NC} Installing Autoscript API & documentation"

domain=$(cat /etc/xray/domain 2>/dev/null || cat /root/domain 2>/dev/null)
if [ -z "$domain" ]; then
    echo -e "${RED}[ERROR]${NC} Domain not found, skipping API install"
    exit 1
fi

apt install -y python3 >/dev/null 2>&1

mkdir -p /etc/autosc-api /usr/local/lib/autosc-api /home/vps/public_html/docs/assets
chmod 700 /etc/autosc-api

# ---------------------------------------------------------------- API service
wget -q -O /usr/local/bin/autosc-api "$REPO/data/api/autosc-api.py"
if [ ! -s /usr/local/bin/autosc-api ]; then
    echo -e "${RED}[ERROR]${NC} Failed to download the API server"
    exit 1
fi
chmod +x /usr/local/bin/autosc-api

wget -q -O /usr/local/lib/autosc-api/openapi.json "$REPO/data/api/openapi.json"

cat > /etc/systemd/system/autosc-api.service <<'END'
[Unit]
Description=Autoscript VPS REST API
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
Environment=AUTOSC_API_HOST=127.0.0.1
Environment=AUTOSC_API_PORT=8081
ExecStart=/usr/bin/python3 -u /usr/local/bin/autosc-api
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
END

# ------------------------------------------------------------- documentation
wget -q -O /home/vps/public_html/docs/index.html "$REPO/data/api/docs-index.html"

# Vendor the Scalar bundle (MIT) so the docs render without reaching a CDN.
echo -e "${GREEN}[INFO]${NC} Downloading API documentation template (Scalar, MIT)"
wget -q -O /home/vps/public_html/docs/assets/scalar.js \
    "https://cdn.jsdelivr.net/npm/@scalar/api-reference" || true
if [ ! -s /home/vps/public_html/docs/assets/scalar.js ]; then
    echo -e "${YELLOW}[WARN]${NC} Could not vendor the docs template; the page will load it from the CDN instead"
    rm -f /home/vps/public_html/docs/assets/scalar.js
fi

chown -R www-data:www-data /home/vps/public_html/docs 2>/dev/null

# -------------------------------------------------------------- nginx routing
# Served from the same vhost as the install domain, so docs live at
# https://<domain>/docs/ and the API at https://<domain>/api/.
#
# This snippet holds `location` blocks, which are only valid inside a `server`
# block. It must NOT live in /etc/nginx/conf.d/ because nginx.conf pulls that
# directory into `http{}` with a wildcard include, which would break nginx.
mkdir -p /etc/nginx/autosc
cat > /etc/nginx/autosc/api.conf <<'END'
# Autoscript API and documentation.
# Included into the xray server block by data/api/ins-api.sh.
location /api/ {
    proxy_pass http://127.0.0.1:8081/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 120s;
}

location /docs/ {
    alias /home/vps/public_html/docs/;
    index index.html;
    # A missing asset must 404, not fall back to index.html: that fallback
    # makes nginx loop when index.html itself cannot be read.
    try_files $uri $uri/ =404;
}
END

# Remove the snippet from a previous install that placed it in conf.d, where the
# wildcard include would load it into http{} and abort nginx on reload.
rm -f /etc/nginx/conf.d/autosc-api.conf

# The xray vhost has a catch-all `location /` that proxies to the SSH
# websocket. nginx matches the longest literal prefix first, so /api/ and /docs/
# win as long as they sit in the same server block.
XRAY_CONF=/etc/nginx/conf.d/xray.conf
if [ -f "$XRAY_CONF" ]; then
    sed -i '/autosc-api\.conf/d' "$XRAY_CONF"
    if ! grep -q 'autosc/api.conf' "$XRAY_CONF"; then
        # Insert just before the final closing brace of the server block.
        last_brace=$(grep -n '^}' "$XRAY_CONF" | tail -1 | cut -d: -f1)
        if [ -n "$last_brace" ]; then
            sed -i "${last_brace}i\\    include /etc/nginx/autosc/api.conf;" "$XRAY_CONF"
        else
            echo "include /etc/nginx/autosc/api.conf;" >> "$XRAY_CONF"
        fi
    fi
else
    echo -e "${YELLOW}[WARN]${NC} $XRAY_CONF not found; API will only be reachable on 127.0.0.1:8081"
fi

# ------------------------------------------------------------------- menu cli
wget -q -O /usr/bin/menu-api "$REPO/data/menu-api.sh" && chmod +x /usr/bin/menu-api

# ----------------------------------------------------------------- start them
systemctl daemon-reload
systemctl enable autosc-api >/dev/null 2>&1
systemctl restart autosc-api

if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx
else
    echo -e "${YELLOW}[WARN]${NC} nginx config test failed; API routes not reloaded"
    nginx -t
fi

# Generate the first API key only on a fresh install.
if [ ! -s /etc/autosc-api/keys.json ]; then
    sleep 2
    firstkey=$(python3 - <<'PY'
import sys
sys.path.insert(0, "/usr/local/bin")
import importlib.util
spec = importlib.util.spec_from_file_location("autoscapi", "/usr/local/bin/autosc-api")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
print(mod.create_key("default")["key"])
PY
)
    if [ -n "$firstkey" ]; then
        echo "$firstkey" > /etc/autosc-api/first-key.txt
        chmod 600 /etc/autosc-api/first-key.txt
    fi
fi

echo -e "${GREEN}[INFO]${NC} API        : https://$domain/api"
echo -e "${GREEN}[INFO]${NC} Docs       : https://$domain/docs/"
echo -e "${GREEN}[INFO]${NC} Manage keys: menu-api"
sleep 2
