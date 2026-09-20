#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 python3-venv python3-pip

a2enmod proxy proxy_http rewrite headers
mkdir -p /opt/okcomputerstuff/backend
mkdir -p /var/www/okcomputerstuff/frontend
mkdir -p /etc/okcomputerstuff

cat >/etc/apache2/sites-available/okcomputerstuff.conf <<'APACHE'
<VirtualHost *:80>
    ServerName ${domain_name}
    ServerAlias www.${domain_name}
    DocumentRoot /var/www/okcomputerstuff/frontend

    ProxyPreserveHost On
    ProxyPass /api http://127.0.0.1:8000/api
    ProxyPassReverse /api http://127.0.0.1:8000/api

    <Directory /var/www/okcomputerstuff/frontend>
        Options -Indexes
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog $${APACHE_LOG_DIR}/okcomputerstuff-error.log
    CustomLog $${APACHE_LOG_DIR}/okcomputerstuff-access.log combined
</VirtualHost>
APACHE

a2dissite 000-default.conf || true
a2ensite okcomputerstuff.conf

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
systemctl enable apache2
systemctl restart apache2
