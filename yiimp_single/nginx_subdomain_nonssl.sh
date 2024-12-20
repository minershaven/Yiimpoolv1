#!/usr/bin/env bash

#####################################################
# Created by Afiniel for Yiimpool use...
#####################################################

# Source necessary configuration files
source /etc/functions.sh
source /etc/yiimpool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
source "$HOME/Yiimpoolv1/yiimp_single/.wireguard.install.cnf"

# Enable strict mode and error handling
set -euo pipefail

# Function to print error trace on error
function print_error {
	read -r line file <<< "$(caller)"
	echo "An error occurred in line $line of file $file:" >&2
	sed "${line}q;d" "$file" >&2
}
trap print_error ERR

# Source wireguard configuration if enabled
if [[ "$wireguard" == "true" ]]; then
	source "$STORAGE_ROOT/yiimp/.wireguard.conf"
fi

# Generate NGINX configuration for the domain
echo '#####################################################
# Source Generated by nginxconfig.io
# Updated by afiniel for crypto use...
#####################################################
# NGINX Simple DDoS Defense
limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
limit_conn conn_limit_per_ip 80;
limit_req zone=req_limit_per_ip burst=80 nodelay;
limit_req_zone $binary_remote_addr zone=req_limit_per_ip:40m rate=5r/s;
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name '"${DomainName}"';
	set $base "/var/www/'"${DomainName}"'/html";
	root $base/web;
	# SSL
	ssl_certificate '"${STORAGE_ROOT}"'/ssl/ssl_certificate.pem;
	ssl_certificate_key '"${STORAGE_ROOT}"'/ssl/ssl_private_key.pem;
	# security
	include yiimpool/security.conf;
	# logging
	access_log '"${STORAGE_ROOT}"'/yiimp/site/log/'"${DomainName}"'.app.access.log;
	error_log '"${STORAGE_ROOT}"'/yiimp/site/log/'"${DomainName}"'.app.error.log warn;
	# index.php
	index index.php;
	# index.php fallback
	location / {
		try_files $uri $uri/ /index.php?$args;
	}
	location @rewrite {
		rewrite ^/(.*)$ /index.php?r=$1;
	}
	# handle .php
	location ~ \.php$ {
		include yiimpool/php_fastcgi.conf;
	}
	# additional config
	include yiimpool/general.conf;
}
# HTTP redirect
server {
	listen 80;
	listen [::]:80;
	server_name .'"${DomainName}"';
	include yiimpool/letsencrypt.conf;
	location / {
		return 301 https://'"${DomainName}"'$request_uri;
	}
}
' | sudo -E tee "/etc/nginx/sites-available/${DomainName}.conf" >/dev/null 2>&1

# Check if symbolic link already exists before creating it
if [[ -L "/etc/nginx/sites-enabled/${DomainName}.conf" ]]; then
  echo -e "${YELLOW}Symbolic link /etc/nginx/sites-enabled/${DomainName}.conf already exists. Skipping creation.${NC}"
else
  sudo ln -sf "/etc/nginx/sites-available/${DomainName}.conf" "/etc/nginx/sites-enabled/${DomainName}.conf"
fi
sudo ln -sf "$STORAGE_ROOT/yiimp/site/web" "/var/www/${DomainName}/html"

# Restart NGINX and PHP-FPM services
restart_service nginx
restart_service php7.3-fpm

# Disable strict mode to avoid unintended errors in subsequent commands
set +euo pipefail

cd $HOME/Yiimpoolv1/yiimp_single
