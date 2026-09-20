#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

APP_REPO_URL="${1:?Application repository URL is required}"
APP_BRANCH="${2:-main}"
APP_COMMIT="${3:?Reviewed application commit SHA is required}"
RDS_SECRET_ARN="${4:?RDS secret ARN is required}"
APP_SECRET_ARN="${5:?Application secret ARN is required}"
RDS_HOST="${6:?RDS host is required}"
RDS_PORT="${7:-3306}"
APP_DOMAIN="${8:-okcomputerstuff.tech}"

EXPECTED_REPO_URL="https://github.com/NaimurRahmannn/okcomputerstuff.git"
EXPECTED_BRANCH="main"

if [[ "$APP_REPO_URL" != "$EXPECTED_REPO_URL" || "$APP_BRANCH" != "$EXPECTED_BRANCH" ]]; then
  echo "Refusing deployment from an unapproved repository or branch" >&2
  exit 1
fi

if [[ ! "$APP_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  echo "APP_COMMIT must be a lowercase 40-character Git commit SHA" >&2
  exit 1
fi

if [[ ! "$RDS_HOST" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]]; then
  echo "RDS_HOST must be a valid DNS hostname" >&2
  exit 1
fi

if [[ ! "$RDS_PORT" =~ ^[0-9]+$ ]] || (( RDS_PORT < 1 || RDS_PORT > 65535 )); then
  echo "RDS_PORT must be between 1 and 65535" >&2
  exit 1
fi

if [[ ! "$APP_DOMAIN" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]]; then
  echo "APP_DOMAIN must be a valid DNS hostname" >&2
  exit 1
fi

APP_ROOT=/opt/okcomputerstuff
RELEASE_ROOT="$APP_ROOT/releases"
RELEASE_DIR="$RELEASE_ROOT/$(date -u +%Y%m%d%H%M%S)"
FRONTEND_ROOT=/var/www/okcomputerstuff/frontend
ENV_FILE=/etc/okcomputerstuff/backend.env
TMP_DIR="$(mktemp -d /tmp/okcomputerstuff-deploy.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 git python3-venv python3-pip unzip wget

a2enmod proxy proxy_http rewrite headers

AWS_CLI_ROOT=/opt/aws-cli
AWS_CLI_BIN="$AWS_CLI_ROOT/v2/current/bin/aws"
wget -q "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O "$TMP_DIR/awscliv2.zip"
unzip -q "$TMP_DIR/awscliv2.zip" -d "$TMP_DIR"
"$TMP_DIR/aws/install" \
  --install-dir "$AWS_CLI_ROOT" \
  --bin-dir "$TMP_DIR/aws-bin" \
  --update >/dev/null
"$AWS_CLI_BIN" --version

mkdir -p "$RELEASE_ROOT" "$FRONTEND_ROOT" /etc/okcomputerstuff
chmod 755 "$APP_ROOT" "$RELEASE_ROOT" "$FRONTEND_ROOT"

cat >/etc/apache2/sites-available/okcomputerstuff.conf <<APACHE
<VirtualHost *:80>
    ServerName ${APP_DOMAIN}
    ServerAlias www.${APP_DOMAIN}
    DocumentRoot /var/www/okcomputerstuff/frontend

    ProxyPreserveHost On
    ProxyPass /api http://127.0.0.1:8000/api
    ProxyPassReverse /api http://127.0.0.1:8000/api

    <Directory /var/www/okcomputerstuff/frontend>
        Options -Indexes
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/okcomputerstuff-error.log
    CustomLog \${APACHE_LOG_DIR}/okcomputerstuff-access.log combined
</VirtualHost>
APACHE

a2dissite 000-default.conf || true
a2ensite okcomputerstuff.conf

git clone --depth 1 --branch "$APP_BRANCH" "$APP_REPO_URL" "$TMP_DIR/source"
git -C "$TMP_DIR/source" fetch --depth 1 origin "$APP_BRANCH"
test "$(git -C "$TMP_DIR/source" rev-parse "origin/$APP_BRANCH")" = "$APP_COMMIT"
git -C "$TMP_DIR/source" checkout --detach "$APP_COMMIT"
test "$(git -C "$TMP_DIR/source" rev-parse HEAD)" = "$APP_COMMIT"

test -f "$TMP_DIR/source/backend/run.py"
test -f "$TMP_DIR/source/backend/requirements.txt"
test -f "$TMP_DIR/source/frontend/index.html"

mkdir -p "$RELEASE_DIR"
cp -a "$TMP_DIR/source/backend" "$RELEASE_DIR/backend"
python3 -m venv "$APP_ROOT/.venv"
"$APP_ROOT/.venv/bin/pip" install --upgrade pip
"$APP_ROOT/.venv/bin/pip" install -r "$RELEASE_DIR/backend/requirements.txt"
chown -R www-data:www-data "$APP_ROOT/.venv"
chmod -R a+rX "$APP_ROOT/.venv"

rm -rf "$FRONTEND_ROOT"/*
cp -a "$TMP_DIR/source/frontend"/. "$FRONTEND_ROOT"/
chmod 755 /var/www /var/www/okcomputerstuff "$FRONTEND_ROOT"
chmod -R a+rX "$FRONTEND_ROOT"

"$AWS_CLI_BIN" secretsmanager get-secret-value \
  --secret-id "$RDS_SECRET_ARN" \
  --query SecretString \
  --output text > "$TMP_DIR/rds-secret.json"
"$AWS_CLI_BIN" secretsmanager get-secret-value \
  --secret-id "$APP_SECRET_ARN" \
  --query SecretString \
  --output text > "$TMP_DIR/app-secret.json"
chmod 600 "$TMP_DIR"/*.json

RDS_SECRET_FILE="$TMP_DIR/rds-secret.json" \
APP_SECRET_FILE="$TMP_DIR/app-secret.json" \
RDS_HOST="$RDS_HOST" \
RDS_PORT="$RDS_PORT" \
ENV_FILE="$ENV_FILE" \
python3 - <<'PY'
import json
import os
import shlex
from urllib.parse import quote_plus

with open(os.environ["RDS_SECRET_FILE"], encoding="utf-8") as stream:
    rds = json.load(stream)
with open(os.environ["APP_SECRET_FILE"], encoding="utf-8") as stream:
    app = json.load(stream)

required_rds = ("username", "password")
missing_rds = [key for key in required_rds if not rds.get(key)]
if missing_rds:
    raise SystemExit(f"RDS secret is missing: {', '.join(missing_rds)}")

required_app = ("secret_key", "admin_email", "admin_password")
missing_app = [key for key in required_app if not app.get(key)]
if missing_app:
    raise SystemExit(f"Application secret is missing: {', '.join(missing_app)}")

database_name = rds.get("dbname") or "okcomputerstuff"
database_url = (
    "mysql+pymysql://"
    f"{quote_plus(str(rds['username']))}:{quote_plus(str(rds['password']))}"
    f"@{os.environ['RDS_HOST']}:{os.environ['RDS_PORT']}/{database_name}"
)

values = {
    "SECRET_KEY": app["secret_key"],
    "DATABASE_URL": database_url,
    "SESSION_COOKIE_SECURE": "true",
    "ADMIN_EMAIL": app["admin_email"],
    "ADMIN_PASSWORD": app["admin_password"],
    "ADMIN_DISPLAY_NAME": app.get("admin_display_name", "okcomputerstuff author"),
}

with open(os.environ["ENV_FILE"], "w", encoding="utf-8") as stream:
    for key, value in values.items():
        stream.write(f"{key}={shlex.quote(str(value))}\n")
PY
chmod 600 "$ENV_FILE"

chown -R www-data:www-data "$RELEASE_ROOT" "$FRONTEND_ROOT"
chmod 755 "$APP_ROOT" "$RELEASE_ROOT" "$RELEASE_DIR" "$RELEASE_DIR/backend"

set -a
# EnvironmentFile uses shell-compatible values, so sourcing it here matches the
# variables used by the systemd service and the Flask CLI commands.
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

cd "$RELEASE_DIR/backend"
"$APP_ROOT/.venv/bin/flask" --app run init-db
"$APP_ROOT/.venv/bin/flask" --app run seed-admin

rm -rf "$APP_ROOT/backend"
ln -s "$RELEASE_DIR/backend" "$APP_ROOT/backend"

cat >/etc/systemd/system/okcomputerstuff.service <<'SERVICE'
[Unit]
Description=okcomputerstuff Flask API
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/okcomputerstuff/backend
EnvironmentFile=-/etc/okcomputerstuff/backend.env
ExecStart=/opt/okcomputerstuff/.venv/bin/gunicorn --workers 2 --bind 127.0.0.1:8000 run:app
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable okcomputerstuff.service
systemctl restart apache2
systemctl restart okcomputerstuff.service
systemctl reload apache2
systemctl is-active --quiet apache2
systemctl is-active --quiet okcomputerstuff.service

find "$RELEASE_ROOT" -mindepth 1 -maxdepth 1 -type d \
  -not -path "$RELEASE_DIR" \
  -exec rm -rf {} +

echo "Application deployment completed: $RELEASE_DIR"
